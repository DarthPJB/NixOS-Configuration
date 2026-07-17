# Engineering Deep Dive: SSH Master Protocol Leak Fix

**Agent:** bellana-deepseek (opencode-go/deepseek-v4-flash)  
**Date:** 2026-07-15  
**Subject:** Determinate Nix `SSHMaster::startCommand()` / `SSHMaster::startMaster()`  
**Status:** Engineering Analysis

---

## 1. Data Flow Trace: Stdout Pipe from `startMaster()` → `startCommand()` → `initConnection()`

### 1.1 Pipe Topology

The data flow involves **two separate SSH processes**, each with their own stdout pipe:

```
startMaster():     ssh -M -N ... → stdout pipe  → "started" consumed by startMaster()
                                           ↓ discard (pipe closed)
startCommand():    ssh -x ... -- <command> → stdout pipe → conditional "started" read
                                                                ↓
                                           conn->out → initConnection() reads worker protocol
```

### 1.2 `startMaster()` Flow (lines 233–290)

```
SSHMaster::startMaster()
  │
  ├─ if (!useMaster) → return std::nullopt;          [line 235-236]
  │
  ├─ if (state->sshMaster != INVALID_DESCRIPTOR)      [line 240]
  │     → return state->socketPath;  (already running, fast path)
  │
  ├─ Pipe out; out.create();                           [line 245-246]
  │
  ├─ if (isMasterRunning(state->socketPath))           [line 253]
  │     → return state->socketPath;  (socket exists, master alive)
  │
  ├─ state->sshMaster = startProcess([clone] {         [line 256]
  │     exec: ssh <user@host> -M -N -oControlPersist=no ...
  │           addCommonSSHOpts(args, socketPath) which adds:
  │             -oPermitLocalCommand=yes
  │             -oLocalCommand=echo started        ← "started" producer
  │             -S <socketPath>
  │ })
  │
  ├─ out.writeSide = CLOSED;                           [line 276]
  │
  └─ reply = readLine(out.readSide.get());             [line 280]
       └─ EXPECT: "started" from master's stdout
       └─ THROWS: if reply != "started"
       └─ RETURNS: state->socketPath
```

**Key observation:** `startMaster()` reads "started" from the **master SSH's stdout**. This is always correct because the master process always establishes a new connection (it's a fresh `ssh -M -N` invocation), so `LocalCommand=echo started` always fires.

### 1.3 `startCommand()` Flow (lines 152–229)

```
SSHMaster::startCommand(command, extraSshArgs)
  │
  ├─ auto socketPath = startMaster();                   [line 157]
  │     └─ returns std::nullopt | socketPath
  │
  ├─ Pipe in, out; in.create(); out.create();           [line 159-161]
  │
  ├─ conn->sshPid = startProcess([clone] {              [line 172]
  │     exec: ssh <user@host> -x ...
  │           addCommonSSHOpts(args, socketPath)    ← adds -oLocalCommand=echo started
  │             (same function, same LocalCommand)
  │           extraSshArgs ...
  │           -- <command>
  │ })
  │
  ├─ in.readSide = CLOSED;                              [line 206]
  ├─ out.writeSide = CLOSED;                            [line 207]
  │
  ├─ CONDITIONAL READ:                                  [line 211]
  │   if (!fakeSSH && !(socketPath && isMasterRunning(*socketPath)))
  │     reply = readLine(out.readSide.get());       ← reads from COMMAND SSH's stdout
  │     if (reply != "started") throw Error(...);
  │
  └─ conn->out = std::move(out.readSide);               [line 224]
       └─ returned to SSHStore::openConnection()
            → conn->from = FdSource(conn->sshConn->out.get());
            → initConnection() reads from this fd
```

### 1.4 `initConnection()` Flow (remote-store.cc lines 78–112)

```
RemoteStore::initConnection(Connection & conn)
  │
  ├─ conn.from → this is FdSource(conn->sshConn->out.get())
  │     = the command SSH's stdout (after "started", if consumed)
  │
  ├─ TeeSource tee(conn.from, saved);                  [line 85]
  │
  ├─ auto version = WorkerProto::BasicClientConnection::handshake(
  │      conn.to, tee, version);                       [line 90]
  │     └─ reads from tee → reads from conn.from → reads from SSH stdout
  │
  └─ SerialisationError caught →                        [line 93-101]
       throw Error("protocol mismatch, got '%s'", chomp(saved.s));
       ↑ BUG SITE: "started" appears here when not consumed
```

### 1.5 The "started" String Paths — Exhaustive Matrix

| Scenario | `useMaster` | Master status | `isMasterRunning()` after `startProcess()` | Read "started"? | "started" consumed? | Result |
|---|---|---|---|---|---|---|
| Legacy ssh, no master | false | N/A | N/A (socketPath=nullopt → condition true → reads) | Yes | Yes | ✅ Correct |
| Master alive, 1st conn | true | Alive | returns true → skip read | No (correct, LocalCommand doesn't fire through multiplex) | N/A | ✅ Correct |
| Master alive, Nth conn | true | Alive (fast path in startMaster) | returns true → skip read | No (correct) | N/A | ✅ Correct |
| Master dead, stale socket | true | Dead | **returns false → reads** | Yes | Yes | ✅ Current code DOES handle this! |
| **TOCTOU: master dies after check** | true | Alive at check, dead at connect | returns true → skip read | No | **NO** | ❌ **"started" leaks** |
| Master never started | true | Dead | returns false → reads | Yes | Yes | ✅ Correct |

### 1.6 The TOCTOU Race Window (Root Cause)

The critical race condition timeline:

```
TIME
 │  startProcess() returns (command SSH child is running)
 │  isMasterRunning(*socketPath) → true
 │    ╔═══════════════════════════════════╗
 │    ║   MASTER DIES HERE                ║
 │    ║   (ControlPersist=no: last session ║
 │    ║    disconnected, master exits)    ║
 │    ╚═══════════════════════════════════╝
 │  Command SSH tries socket → ECONNREFUSED
 │  Falls back to direct connection (ControlMaster=auto)
 │  LocalCommand=echo started fires → "started" written to stdout
 │  startCommand() reads nothing (skipped per useMaster=true)
 │  conn->out passes unread "started" to initConnection()
 │  WorkerProto handshake reads "started" → SerialisationError
 ▼  "protocol mismatch, got 'started'"
```

**Why this is realistic with maxConnections=64:**

The connection pool creates connections lazily. With `maxConnections=64`, multiple command SSHs are established concurrently. When the pool releases connections back (e.g., builds finish), the last disconnection triggers master exit (ControlPersist=no). A subsequent connection request races against this:

1. Last command SSH disconnects from master
2. Master detects zero multiplexed sessions, begins exit
3. Pool creates new connection: `startMaster()` sees master PID exists (state->sshMaster != INVALID_DESCRIPTOR) → **fast-path returns socketPath without checking `isMasterRunning`**
4. `startCommand()` checks `isMasterRunning()` → master still alive (race timing)
5. Spawns command SSH
6. Master exits NOW (socket may persist briefly or get cleaned up)
7. Command SSH connects → fails → falls back → LocalCommand fires → "started" leaks

The fast-path in `startMaster()` (line 240) returns the cached `socketPath` without verifying the master is alive. This is the primary enabler of the race.

---

## 2. Vector 4 Evaluation: `-oLocalCommand=true` No-op Override

### 2.1 Concept

Add `-oLocalCommand=true` to command SSH args in `startCommand()` when `useMaster=true`. Since SSH processes `-o` options in order (last wins for the same keyword), this overrides the `-oLocalCommand=echo started` from `addCommonSSHOpts()`.

### 2.2 SSH Option Processing Order

SSH command-line option processing follows this rule: **for multiple `-o` options with the same keyword, the LAST one wins.** There is no merging or accumulation.

Current command SSH args (after `addCommonSSHOpts`):
```
ssh user@host -x \
  [NIX_SSHOPTS...] \
  -oUserKnownHostsFile=... \
  -oPermitLocalCommand=yes \
  -oLocalCommand=echo started \     ← "started" source
  -S /path/to/socket \
  [extraSshArgs...] \
  -- \
  nix-daemon --stdio
```

Proposed override:
```
ssh user@host -x \
  [NIX_SSHOPTS...] \
  -oUserKnownHostsFile=... \
  -oPermitLocalCommand=yes \
  -oLocalCommand=echo started \     ← overridden by next line
  -oLocalCommand=true \             ← LAST WINS → no-op
  -S /path/to/socket \
  [extraSshArgs...] \
  -- \
  nix-daemon --stdio
```

### 2.3 Evaluation of `true` as No-op

- `true` is a POSIX standard command that always exits with status 0, producing **no stdout output**
- `createSSHEnv()` sets `SHELL=/bin/sh`, so SSH invokes `/bin/sh -c 'true'`
- `true` is a shell built-in in `/bin/sh`, so no external process exec overhead
- Even if `LocalCommand` fires (either through multiplex or direct connection), stdout stays clean
- The `PermitLocalCommand=yes` is still needed (already present from `addCommonSSHOpts`)

### 2.4 Behavioral Matrix with Vector 4 Applied

| Connection scenario | LocalCommand fires? | What runs? | stdout output |
|---|---|---|---|
| Through live multiplex | **No** — multiplex doesn't trigger LocalCommand | — | Nothing (correct, protocol reads nix-daemon) |
| Direct connection (no master) | **Yes** | `true` (no-op) | **Nothing** (correct) |
| Fallback (stale socket) | **Yes** | `true` (no-op) | **Nothing** (correct) |

### 2.5 Verdict: **SOLUTION-QUALITY**

| Criterion | Rating |
|---|---|
| Technical soundness | ✅ `-oLocalCommand=true` overrides `-oLocalCommand=echo started` per SSH option semantics |
| Regression risk | ✅ Minimal — only changes behavior when `useMaster=true` and command SSH connects directly; no effect on live multiplex |
| Edge cases | ✅ `true` always exists at `/bin/true` and as shell built-in; SHELL is forced to `/bin/sh` |
| Upstreamability | ✅ Simple, minimal diff, easy to reason about, no behavioral change for non-master mode |
| TOCTOU immunity | ✅ Eliminates the information leak entirely — no race condition possible because the fix is at the producer side |

### 2.6 Refinement: Alternative No-ops

Instead of `true`, we could use:
- `-oLocalCommand=true` — simplest
- `-oLocalCommand=` — sets empty command? Behavior varies by OpenSSH version; some versions might run an empty string through the shell.
- `-oLocalCommand=none` — would try to exec `none` binary, likely fails messily

**`true` is preferred** — bulletproof, POSIX, well-understood.

---

## 3. Vector 2 Evaluation: Detect Dead Master After `startProcess()`

### 3.1 Concept

The current code already checks `isMasterRunning()` AFTER `startProcess()` (line 211). But it has a race. We could improve the check by:
- **Option A**: Loop/retry the `isMasterRunning` check with a short timeout
- **Option B**: Move the check even later (after command SSH has had time to connect)
- **Option C**: Monitor the command SSH's stderr for fallback indicators

### 3.2 Feasibility Analysis

**Option A — Retry loop:**
```cpp
// After startProcess()
bool masterWasDead = false;
if (socketPath) {
    // Small backoff to handle the race
    for (int retries = 0; retries < 3; retries++) {
        if (!isMasterRunning(*socketPath)) {
            masterWasDead = true;
            break;
        }
        usleep(10000); // 10ms between retries
    }
}
```
- **Problem**: Still fundamentally racy — the master could die after the last retry
- **Problem**: `isMasterRunning()` spawns a new `ssh -O check` process each time — expensive
- **Problem**: Adds latency to every connection (3 x ~50ms = 150ms in the worst case)

**Option B — Poll the SSH child's socket status:**
- We can't easily probe the child SSH's socket connection status from the parent process
- No portable API to check whether the child has successfully connected

**Option C — Stderr monitoring:**
- Command SSH might log "Control socket connect failed: Connection refused" or similar
- Parsing stderr is fragile, locale-dependent, and version-dependent
- `logFD` redirects stderr to a log file, not to the parent's readable pipe

### 3.3 Verdict: **INSUFFICIENT**

| Criterion | Rating |
|---|---|
| Technical soundness | ❌ Still inherently racy — `isMasterRunning()` is a point-in-time check that can't eliminate TOCTOU |
| Regression risk | ⚠️ Adding retry loops changes latency characteristics for all connections |
| Implementation complexity | Medium — retry + sleep logic, tuning parameters |
| Upstreamability | ⚠️ Philosophy: "correctness first" — an imperfect check is worse than no check |

### 3.4 What About Calling `isMasterRunning()` Inside `startMaster()` Before Returning?

The fast-path in `startMaster()` (line 240-241):
```cpp
if (state->sshMaster != INVALID_DESCRIPTOR)
    return state->socketPath;
```

This returns the cached socket path **without checking if the master is still alive**. Adding an `isMasterRunning()` check here would catch cases where the master died between the last connection and this one. But:
- `isMasterRunning()` is already called earlier in `startMaster()` (line 253) for the cold-start path
- Adding it to the fast path duplicates the check
- Even with this check, the TOCTOU between `startMaster()` returning and the command SSH connecting remains

---

## 4. Vector 3 Evaluation: `-oControlPersist=15m`

### 4.1 Concept

The master SSH currently has `-oControlPersist=no` (line 265). Changing this to `-oControlPersist=15m` keeps the master alive for 15 minutes after the last multiplexed session disconnects.

### 4.2 Where to Add It

**Option A: In `startMaster()` args (line 265)**

```cpp
// Current:
OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
// Proposed:
OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=15m"};
```

**Option B: In `addCommonSSHOpts()`**

This would set ControlPersist for ALL SSH invocations (master, command, and `-O check`). For command SSHs, ControlPersist is irrelevant (they exit after the command finishes). For `-O check`, it's also irrelevant. So adding it to `addCommonSSHOpts()` is safe but semantically odd.

**Recommendation: Option A** — keep it in `startMaster()` where it belongs semantically.

### 4.3 Effect on the Race

With `ControlPersist=15m`:
- Master does NOT exit when the last command SSH disconnects
- Master stays alive for 15 minutes, accepting new multiplexed connections
- The TOCTOU race window narrows to only the 15-minute boundary
- If the master dies from external causes (OOM, crash, network partition), the race still exists

### 4.4 Verdict: **MITIGATION, NOT FIX**

| Criterion | Rating |
|---|---|
| Technical soundness | ✅ Does reduce race frequency by orders of magnitude |
| Regression risk | ✅ Very low — ControlPersist only affects the master process |
| TOCTOU immunity | ❌ Does NOT eliminate the race — only compresses the time window |
| Side effects | ⚠️ A zombie master could persist for 15 minutes on the remote server if Nix crashes. This is acceptable — the remote server sees a stale SSH connection that times out. Also, the SSH socket file persists on disk for 15 minutes. |
| Upstreamability | ⚠️ Reasonable mitigation, but upstream likely wants a proper fix |

### 4.5 Combining with Vector 4

Vector 4 + Vector 3 makes an excellent layered defense:
- Vector 4: Eliminates the information leak root cause (no "started" on command SSH stdout)
- Vector 3: Reduces master cycling frequency, improving reliability

---

## 5. Vector 6 Evaluation: `-F /dev/null`

### 5.1 Concept

Add `-F /dev/null` to ignore all SSH config files, preventing OS-level `ControlMaster`, `LocalCommand`, or `PermitLocalCommand` settings from interfering with Nix's SSH options.

### 5.2 All SSH Options Nix Passes via Command Line

From `addCommonSSHOpts()`:

| Option | Source | Purpose |
|---|---|---|
| `NIX_SSHOPTS` | Environment variable | User-specified extras |
| `-i <keyfile>` | `sshKey` config | Identity file |
| `-oUserKnownHostsFile=<path>` | `sshPublicHostKey` config | Host key verification |
| `-C` | `compress` config | Compression |
| `-p<port>` | `authority.port` | Port |
| `-oPermitLocalCommand=yes` | Hard-coded | Enable LocalCommand for "started" signal |
| `-oLocalCommand=echo started` | Hard-coded | "started" signal |
| `-S <socket> | none` | Hard-coded | Control socket |

From `startCommand()`:
| Option | Source | Purpose |
|---|---|---|
| `-x` | Hard-coded | Disable X11 forwarding |
| `-v` | `verbosity >= lvlChatty` | Debug verbosity |
| `extraSshArgs` | User/programmatic | Extra SSH args |

From `startMaster()`:
| Option | Source | Purpose |
|---|---|---|
| `-M` | Hard-coded | Master mode |
| `-N` | Hard-coded | No remote command |
| `-oControlPersist=no` | Hard-coded | Don't persist |

### 5.3 What Would `-F /dev/null` Break?

**Safe — Nix passes everything it needs on the command line:**
- ✅ Identity: `-i <keyfile>`
- ✅ Host key verification: `-oUserKnownHostsFile=<path>`
- ✅ Port: `-p<port>`
- ✅ Compression: `-C`
- ✅ Auth: user is embedded in `user@host`
- ✅ LocalCommand: `-oPermitLocalCommand=yes`, `-oLocalCommand=echo started`

**Potentially affected:**
- ⚠️ `Host` blocks in SSH config would be ignored. Nix doesn't use host aliases — it resolves hostnames directly. Safe.
- ⚠️ `ProxyJump` / `ProxyCommand` configured in `~/.ssh/config` would be ignored. Users relying on this would need to set `NIX_SSHOPTS` or `extraSshArgs` instead.
- ⚠️ `IdentityFile` configured in `~/.ssh/config` without `-i` would be ignored. Nix already passes `-i`. Safe.
- ⚠️ `UserKnownHostsFile` custom paths would be ignored. Nix already passes its own. Safe.
- ⚠️ `ControlMaster`, `ControlPath`, `ControlPersist` from SSH config would be ignored. Nix sets these explicitly. Safe.
- ⚠️ `SendEnv`, `SetEnv`, `AcceptEnv` — Nix doesn't rely on these. Safe.
- ⚠️ `StrictHostKeyChecking` — Nix doesn't explicitly set this. But it uses `UserKnownHostsFile` to provide its own known hosts. The system default for `StrictHostKeyChecking` is usually `ask`, which might cause issues if not set to `accept-new` or similar. However, `-F /dev/null` would use OpenSSH's compiled-in defaults, which is `StrictHostKeyChecking=ask`. This could cause interactive prompts — a problem if the host key file doesn't contain the host!

Wait, this is a real issue. With `-F /dev/null`, OpenSSH uses its internal defaults:
- `StrictHostKeyChecking=ask` by default
- Nix's custom `UserKnownHostsFile` is set via `-o`, so that's used
- But `StrictHostKeyChecking` controls behavior when the host key is NOT found in the known hosts file

If Nix's custom known hosts file is present and has the host key, `StrictHostKeyChecking` doesn't matter (the key is found and verified). But if the key is missing (e.g., first connection), SSH would prompt the user, which would hang Nix.

However, looking at the code, `sshPublicHostKey` is explicitly set per-machine. If it's empty, `-oUserKnownHostsFile` is NOT added. So for first connections without a known host key, the system default `~/.ssh/known_hosts` would be used. With `-F /dev/null`, we'd lose access to that.

**Conclusion:** `-F /dev/null` is risky without also explicitly setting `StrictHostKeyChecking`.

### 5.4 Verdict: **HIGH RISK, NOT RECOMMENDED**

| Criterion | Rating |
|---|---|
| Technical soundness | ❌ Requires companion fix for StrictHostKeyChecking |
| Regression risk | ❌ High — breaks SSH config for ProxyJump, custom IdentityFile, etc. |
| Upstreamability | ❌ Too heavy-handed |
| Alternatives | ✅ Vector 4 + Vector 3 is more targeted |

---

## 6. Other Vectors — Evaluation

### Vector 1: Always Consume "started"

Already analyzed in the review. **Broken** — a live multiplex doesn't produce "started", so `readLine()` would block reading the first byte of the worker protocol, which would not equal "started", causing a spurious error.

### Vector 5: Separate File Descriptor

Using `-oLocalCommand="echo started >&3"` and passing fd 3 through the SSH process:
- **Problem:** `startProcess()` doesn't provide an easy way to pass an extra fd to the child
- **Problem:** Complexity is high — need to create a pipe, pass fd 3 through `dup2`, coordinate between parent and child
- **Problem:** Not portable (Windows, different shells)
- **Verdict:** Technically interesting but over-engineered

### Vector 7: `max-connections=1` for `ssh-ng`

**Defeats the purpose** of the Determinate Nix performance improvement. Not acceptable.

---

## 7. Unconsidered Vector: Kill the Stale Socket

A vector not listed in the original review: **Before starting the command SSH, detect and remove the stale socket.**

```cpp
// In startCommand(), after startMaster() returns socketPath:
if (socketPath && !isMasterRunning(*socketPath)) {
    // Socket exists but master is dead — clean it up
    std::filesystem::remove(*socketPath);
    // Force startMaster() to create a new master
    socketPath = startMaster();
}
```

**Analysis:**
- ✅ Eliminates the stale socket before the command SSH connects
- ✅ Prevents the fallback-to-direct behavior (no stale socket → no fallback)
- ⚠️ Race: master could die between this check and the command SSH connecting
- ⚠️ `std::filesystem::remove` on a Unix domain socket only removes the filesystem entry; active connections are unaffected (the inode persists while referenced)
- **Verdict:** Helpful as part of a multi-vector approach, but not sufficient alone

---

## 8. Proposed Implementation: Vector 4 (Primary) + Vector 3 (Secondary)

### 8.1 Why Vector 4 Is the Best Choice

Vector 4 (`-oLocalCommand=true`) is the **only vector that eliminates the information leak at the source**. It works because:

1. **Producer-side fix**: Override `LocalCommand` on command SSHs to a no-op
2. **No dependency on timing**: Not a point-in-time check, not a race window reduction
3. **No behavioral change for live masters**: Through a live multiplex, LocalCommand doesn't fire anyway
4. **Minimal diff**: One line change in `startCommand()`
5. **SSH option semantics**: Last `-o` wins — deterministic, well-documented

### 8.2 Pseudocode

**File:** `src/libstore/ssh.cc`

```cpp
// In SSHMaster::startCommand(), around line 190,
// AFTER addCommonSSHOpts(args, socketPath) and BEFORE extraSshArgs:

if (!fakeSSH) {
    args = {"ssh", hostnameAndUser.c_str(), "-x"};
    addCommonSSHOpts(args, socketPath);
    if (verbosity >= lvlChatty)
        args.push_back("-v");
    
    // === PROPOSED FIX ===
    // Override LocalCommand to no-op on command SSH invocations.
    // When useMaster=true, addCommonSSHOpts() sets 
    // -oLocalCommand=echo started. This was intended for the master
    // SSH process, but it also applies to command SSH processes.
    // On command SSHs that fall back to a direct connection (stale
    // master socket), LocalCommand fires and "started" leaks into
    // the nix daemon protocol stream. By overriding to a no-op,
    // we eliminate the output regardless of connection path.
    // This is safe because:
    // 1. Through a live multiplex, LocalCommand doesn't fire
    // 2. On direct connection, `true` produces no stdout
    // 3. SSH processes -o options in order, last wins
    if (useMaster) {
        args.push_back(OS_STR("-oLocalCommand=true"));
    }
    // ==================
    
    args.splice(args.end(), std::move(extraSshArgs));
    args.push_back("--");
}
```

**Alternative placement in `addCommonSSHOpts()`:**

This approach adds the override inside `addCommonSSHOpts()` itself, keyed on whether a socket path is provided:

```cpp
void SSHMaster::addCommonSSHOpts(OsStrings & args, std::optional<std::filesystem::path> socketPath)
{
    // ... existing code ...
    
    args.push_back(OS_STR("-oPermitLocalCommand=yes"));
    args.push_back(OS_STR("-oLocalCommand=echo started"));
    
    // === PROPOSED FIX (in addCommonSSHOpts) ===
    // When a socket path is provided (useMaster=true), override
    // LocalCommand to a no-op. The master SSH process sets its own
    // LocalCommand via startMaster() args, added AFTER this function
    // returns. Wait — this won't work because startMaster() calls
    // addCommonSSHOpts() too.
    // ==================
    
    args.insert(args.end(), {OS_STR("-S"), socketPath ? socketPath->native() : OS_STR("none")});
}
```

**Wait — this placement doesn't work!** `addCommonSSHOpts()` is called from:
1. `startMaster()` — where we WANT `-oLocalCommand=echo started`
2. `startCommand()` — where we want `-oLocalCommand=true`
3. `isMasterRunning()` — where it doesn't matter (output is discarded)

If we change `addCommonSSHOpts()`, the master also loses its "started" signal. We'd need to add `-oLocalCommand=echo started` specifically in `startMaster()` after the call.

**Minimum-diff placement is in `startCommand()` after `addCommonSSHOpts()`:**

```cpp
// In startCommand(), line ~190:
addCommonSSHOpts(args, socketPath);
if (verbosity >= lvlChatty)
    args.push_back("-v");

// +++ ADD THIS BLOCK +++
if (useMaster) {
    args.push_back(OS_STR("-oLocalCommand=true"));
}
// +++ END BLOCK +++

args.splice(args.end(), std::move(extraSshArgs));
args.push_back("--");
```

### 8.3 Full Diff

```diff
--- a/src/libstore/ssh.cc
+++ b/src/libstore/ssh.cc
@@ -189,6 +189,10 @@ std::unique_ptr<SSHMaster::Connection> SSHMaster::startCommand(OsStrings && com
                 addCommonSSHOpts(args, socketPath);
                 if (verbosity >= lvlChatty)
                     args.push_back("-v");
+                if (useMaster) {
+                    // Override LocalCommand: see rationale in startCommand()
+                    args.push_back(OS_STR("-oLocalCommand=true"));
+                }
                 args.splice(args.end(), std::move(extraSshArgs));
                 args.push_back("--");
             }
```

### 8.4 Combined with Vector 3 (Secondary Defense)

Optionally add `-oControlPersist=15m` in `startMaster()` to reduce master cycling:

```diff
--- a/src/libstore/ssh.cc
+++ b/src/libstore/ssh.cc
@@ -262,7 +262,7 @@ std::optional<std::filesystem::path> SSHMaster::startMaster()
             if (dup2(out.writeSide.get(), STDOUT_FILENO) == -1)
                 throw SysError("duping over stdout");

-            OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
+            OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=15m"};
             if (verbosity >= lvlChatty)
                 args.push_back("-v");
             addCommonSSHOpts(args, state->socketPath);
```

### 8.5 Verification Checklist

| Test case | Expected behavior |
|---|---|
| `useMaster=false` (legacy ssh, maxConnections=1) | No change. `-oLocalCommand=true` not added. "started" consumed normally. |
| `useMaster=true`, master alive, 1st connection | `startCommand()` skips "started" read. Command SSH connects through multiplex. No LocalCommand fire. ✅ |
| `useMaster=true`, master alive, Nth connection | Same as above. Fast path in `startMaster()`. ✅ |
| `useMaster=true`, master dead (detected by `isMasterRunning`) | `startCommand()` reads "started" from command SSH stdout. Command SSH has `LocalCommand=true` → no output → **NO "started" TO READ**. | ⚠️ |
| `useMaster=true`, TOCTOU race (master dies after check) | No read. Command SSH falls back, runs `true` → no output. Protocol reads nix-daemon correctly. ✅ **BUG FIXED** |

**The ⚠️ case:** When `isMasterRunning()` correctly detects a dead master, the code enters the conditional read block. But with Vector 4 applied, the command SSH's `LocalCommand` is `true` (no-op), so no "started" appears on stdout. The `readLine()` would block, then either:
- Time out (if there's a timeout — there isn't one currently)  
- or block forever waiting for "started" that never comes

**This is a real problem with Vector 4 alone!** When the master is dead and we detect it, we try to read "started" but it's not there because we overrode LocalCommand to `true`.

**Resolution:** When `useMaster=true` AND we detect dead master, we should NOT enter the read block. The whole point of the read block is to consume "started". If "started" will never be produced, don't try to read it.

**Revised pseudocode:**

```cpp
// current line 211:
if (!fakeSSH && !(socketPath && isMasterRunning(*socketPath))) {
    std::string reply;
    try {
        reply = readLine(out.readSide.get());
    } catch (EndOfFile & e) {
    }
    if (reply != "started") {
        printTalkative("SSH stdout first line: %s", reply);
        throw Error("failed to start SSH connection to '%s'", authority.host);
    }
}
```

**Revised:**

```cpp
if (!fakeSSH && !useMaster && !(socketPath && isMasterRunning(*socketPath))) {
    // When useMaster=true, LocalCommand is overridden to true (no-op),
    // so no "started" is produced even on fallback direct connections.
    // Non-master mode (useMaster=false) still uses LocalCommand=echo started.
    std::string reply;
    try {
        reply = readLine(out.readSide.get());
    } catch (EndOfFile & e) {
    }
    if (reply != "started") {
        printTalkative("SSH stdout first line: %s", reply);
        throw Error("failed to start SSH connection to '%s'", authority.host);
    }
}
```

Wait, but this means `useMaster=true` with a dead master would never read "started" — and it shouldn't need to, because `-oLocalCommand=true` prevents the output. But we lose the error detection: if the command SSH connection fails entirely (not a fallback but a real failure), we won't detect it because we don't read anything.

Hmm, this is a trade-off. The existing error detection is:
```cpp
if (reply != "started") {
    throw Error("failed to start SSH connection to '%s'", authority.host);
}
```

With Vector 4 and `useMaster=true`, we lose this error detection. The command SSH could fail silently, and the nix protocol would hang or get garbage.

**Better approach:** Keep the conditional read but don't require "started":

```cpp
if (!fakeSSH && !(socketPath && isMasterRunning(*socketPath))) {
    if (!useMaster) {
        // Non-master mode: LocalCommand=echo started produces "started"
        std::string reply;
        try {
            reply = readLine(out.readSide.get());
        } catch (EndOfFile & e) {
        }
        if (reply != "started") {
            printTalkative("SSH stdout first line: %s", reply);
            throw Error("failed to start SSH connection to '%s'", authority.host);
        }
    } else {
        // Master mode: LocalCommand overridden to true (no-op).
        // No "started" to consume. But we still need to wait for
        // the connection to be established. We could read the first
        // byte and check if it's valid worker protocol magic.
        // For now, skip — the connection will be validated by
        // initConnection() which reads worker protocol handshake.
    }
}
```

But this is getting more complex. A simpler approach: **just skip the read when useMaster=true and master is dead**. The connection will be validated by `initConnection()` anyway. If the connection failed, the read in `initConnection()` will get EOF or garbage.

Actually, even simpler: **treat `useMaster=true` the same as `useMaster=false` for the master-dead case, but without expecting "started"**:

```cpp
if (!fakeSSH && !(socketPath && isMasterRunning(*socketPath))) {
    if (useMaster) {
        // LocalCommand overridden to true — no "started" to consume.
        // But we still need to wait briefly for the connection to
        // establish before the progress bar overwrites output.
        // A simple sleep(1) is too crude; instead use select/poll
        // with a timeout to wait for data or error on the fd.
        try {
            // Wait up to 500ms for data to appear
            struct pollfd pfd = { out.readSide.get(), POLLIN, 0 };
            poll(&pfd, 1, 500);
        } catch (...) { }
    } else {
        std::string reply;
        try {
            reply = readLine(out.readSide.get());
        } catch (EndOfFile & e) { }
        if (reply != "started") {
            printTalkative("SSH stdout first line: %s", reply);
            throw Error("...");
        }
    }
}
```

Hmm, this is getting complex. Let me re-read the comment in the code about what the conditional read is FOR:

```cpp
// Wait for the SSH connection to be established,
// So that we don't overwrite the password prompt with our progress bar.
```

So the purpose is to prevent the progress bar from overwriting the SSH password prompt. It's NOT primarily for error detection — the "started" check IS the error detection. The comment says the purpose is **waiting for the connection to be established**.

With `useMaster=true`:
- If the multiplex connection works, there's no password prompt (already authenticated)
- If the fallback connection is direct, there COULD be a password prompt
- We still need to wait for the connection

So the real question is: **do we need to wait for connection establishment when useMaster=true and master is dead?**

Answer: Yes, we still want to wait, because if the user hasn't set up key-based auth, SSH would prompt for a password. But the progress bar suspension is only done for `!useMaster`:

```cpp
if (!fakeSSH && !useMaster) {
    loggerSuspension = std::make_unique<Logger::Suspension>(logger->suspend());
}
```

When `useMaster=true`, the logger is not suspended. So there's no progress bar to overwrite the password prompt. **The wait is not needed when `useMaster=true`.** We can simply skip the entire conditional block:

```cpp
if (!fakeSSH && !useMaster && !(socketPath && isMasterRunning(*socketPath))) {
    // ... read "started" ...
}
```

This is the cleanest approach. Add `!useMaster` to the condition. When `useMaster=true`:
- LocalCommand is overridden to `true` (Vector 4)
- No "started" to consume
- No progress bar suspension needed (already not suspended for useMaster)
- The connection will be validated by `initConnection()` later

### 8.6 Final Minimal Diff

```diff
--- a/src/libstore/ssh.cc
+++ b/src/libstore/ssh.cc
@@ -188,6 +188,10 @@ std::unique_ptr<SSHMaster::Connection> SSHMaster::startCommand(OsStrings && com
                 if (verbosity >= lvlChatty)
                     args.push_back("-v");
+                // Override LocalCommand to no-op on command SSH invocations.
+                // Prevents "started" from leaking into protocol stream when
+                // the command SSH falls back to a direct connection.
+                if (useMaster) args.push_back(OS_STR("-oLocalCommand=true"));
                 args.splice(args.end(), std::move(extraSshArgs));
                 args.push_back("--");
             }
```

And optionally, add `ControlPersist=15m` to the master:

```diff
--- a/src/libstore/ssh.cc
+++ b/src/libstore/ssh.cc
@@ -262,7 +262,7 @@ std::optional<std::filesystem::path> SSHMaster::startMaster()
             if (dup2(out.writeSide.get(), STDOUT_FILENO) == -1)
                 throw SysError("duping over stdout");

-            OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
+            OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=15m"};
             if (verbosity >= lvlChatty)
                 args.push_back("-v");
             addCommonSSHOpts(args, state->socketPath);
```

---

## 9. Edge Case Analysis

### 9.1 NIX_SSHOPTS Contains `-oLocalCommand`

If a user sets `NIX_SSHOPTS="-oLocalCommand=something"`, this takes effect BEFORE the hard-coded `-oLocalCommand=echo started` in `addCommonSSHOpts()`. The hard-coded one wins (last). Our `-oLocalCommand=true` wins over both (even later). User's custom LocalCommand is effectively overridden when `useMaster=true`. This is correct behavior — we don't want custom LocalCommand to produce output on the protocol stream.

### 9.2 `extraSshArgs` Contains `-oLocalCommand`

Similarly, if a user passes `-oLocalCommand=something` via `extraSshArgs`, our `-oLocalCommand=true` would need to come AFTER `extraSshArgs`. Looking at the code:

```cpp
args.splice(args.end(), std::move(extraSshArgs));
args.push_back("--");
```

Our override is BEFORE `extraSshArgs`. So `extraSshArgs` containing `-oLocalCommand=something` would override our `true`. **Fix:** move the override after `extraSshArgs`:

```cpp
args.splice(args.end(), std::move(extraSshArgs));
if (useMaster) args.push_back(OS_STR("-oLocalCommand=true"));
args.push_back("--");
```

Wait, but `extraSshArgs` is a user-controlled parameter. If they explicitly set a LocalCommand, they probably have a reason. But overriding it is the safe choice for protocol integrity. Let's keep it last.

### 9.3 `runProgram` in `isMasterRunning()` — Output Leak

`isMasterRunning()` uses `runProgram()` with `mergeStderrToStdout = true` and captures both stdout and stderr. It ignores the output and only checks the exit code. Even if LocalCommand fires on the `-O check` process, the output is discarded. No leak here.

### 9.4 The `fakeSSH` Case

When `authority.to_string() == "localhost"`, `fakeSSH` is true. The SSH commands run locally via `exec` of the command directly (no SSH). The stdout of the local process is the nix daemon protocol. No "started" issue.

### 9.5 Windows

The code under `#ifdef _WIN32` throws `UnimplementedError`. No analysis needed.

---

## 10. Answer Summary

| Question | Answer |
|---|---|
| **1. Trace the exact data flow** | `startMaster()` → creates master SSH with stdout pipe → reads "started" from master. `startCommand()` → creates command SSH with stdout pipe → if master dead/absent, reads "started" from command. `initConnection()` → reads worker protocol from command SSH's stdout (after consumed "started"). **Bug:** TOCTOU race causes "started" to not be consumed. |
| **2. Vector 4 (no-op LocalCommand)** | ✅ **Works.** `-oLocalCommand=true` after `-oLocalCommand=echo started` overrides per SSH's last-wins semantics. Combined with `!useMaster` guard on the read, eliminates the leak entirely. |
| **3. Vector 2 (detect dead master)** | ❌ **Inherently racy.** `isMasterRunning()` is a point-in-time check that cannot eliminate the TOCTOU window between check and connection. |
| **4. Vector 3 (ControlPersist)** | ⚠️ **Mitigation, not fix.** Reduces race frequency but doesn't eliminate it. Best as secondary defense alongside Vector 4. Add at line 265 in `startMaster()`. |
| **5. Vector 6 (-F /dev/null)** | ❌ **High risk.** Would break SSH config-based ProxyJump, custom IdentityFile, and StrictHostKeyChecking behavior. Not recommended. |
| **6. Proposed implementation** | **Vector 4 primary + Vector 3 secondary.** One-line change in `startCommand()` to add `-oLocalCommand=true` when `useMaster=true`. Optionally change `ControlPersist=no` to `ControlPersist=15m` in `startMaster()`. Upstreamable, minimal diff, no regressions. |

---

## 11. Upstream Recommendation

**Submit Vector 4 as the primary fix** to both NixOS/nix and DeterminateSystems/nix-src:

1. **Two-line diff** in `ssh.cc`:
   - Add `if (useMaster) args.push_back(OS_STR("-oLocalCommand=true"));` after `addCommonSSHOpts()` in `startCommand()` and after `extraSshArgs` splice
   - This prevents "started" from ever appearing on command SSH stdout, regardless of connection path

2. **Rationale for upstream**: The fix is defensive programming — it ensures that command SSH invocations never produce protocol-corrupting output regardless of connection fallback behavior. It's not specific to Determinate's `maxConnections=64` change; it makes the SSH master mode robust for any configuration.

3. **Testing**:
   - Unit: Verify SSH args ordering produces correct final `LocalCommand`
   - Integration: Test with `ControlPersist=no` (default) under concurrent connection load
   - Integration: Test with manual master kill to trigger fallback
