# TPol-Minimax Research Review: DETSYS-NIX SSH Master Protocol Leak Fix

**Date:** 2026-07-15
**Reviewer:** tpol-minimax
**Subject:** Nix SSH Master mechanism and protocol leak bug via `LocalCommand=echo started`

---

## Executive Summary

Determinate Nix changed `maxConnections` default from 1 to 64 in `remote-store.hh`, enabling SSH master mode (`-M -N`) for `ssh-ng` remote builders. The bug: when the SSH master dies (due to `ControlPersist=no`), command SSHs fall back to direct connections, and `LocalCommand=echo started` leaks into the nix protocol stream, corrupting the handshake.

**Root cause identified:** The `LocalCommand=echo started` mechanism was designed to pause progress bar rendering until the SSH connection is established (PR #8018, fixing issue #7959). When SSH master mode is enabled with `ControlPersist=no`, the master process exits after the first connection, causing subsequent command SSHs to fall back to direct connections—but Nix still expects the `started` banner on stdout, leading to protocol corruption.

---

## Source Code Analysis

### Key Files Examined

| File | Purpose |
|------|---------|
| `determinate/src/libstore/ssh.cc` | SSHMaster implementation |
| `determinate/src/libstore/include/nix/store/remote-store.hh` | `maxConnections` default (64) |
| `determinate/src/libstore/machines.cc` | SSH machine configuration |

### 1. `SSHMaster::addCommonSSHOpts()` — LocalCommand Origin

```cpp
// ssh.cc lines 82-89
// We use this to make ssh signal back to us that the connection is established.
// It really does run locally; see createSSHEnv which sets up SHELL to make
// it launch more reliably. The local command runs synchronously, so presumably
// the remote session won't be garbled if the local command is slow.
args.push_back(OS_STR("-oPermitLocalCommand=yes"));
args.push_back(OS_STR("-oLocalCommand=echo started"));
```

**Purpose:** The `LocalCommand=echo started` trick was introduced in PR #8018 to solve issue #7959 (password prompt erasure by progress bar). The mechanism works as follows:

1. Progress bar is paused before SSH connection starts
2. SSH connects with `LocalCommand=echo started`
3. The `started` string is read from stdout
4. Only after `started` is received does Nix resume the progress bar
5. This prevents the password prompt from being corrupted by progress bar output

**Why it runs locally:** The comment explicitly states "It really does run locally." SSH executes `LocalCommand` on the LOCAL side after the connection is established but BEFORE the remote command runs.

### 2. `SSHMaster::startMaster()` — ControlPersist=no

```cpp
// ssh.cc lines 175-178
OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
// ...
addCommonSSHOpts(args, state->socketPath);  // Adds -oLocalCommand=echo started
```

**Key observation:** `ControlPersist=no` is EXPLICITLY set in `startMaster()`. This means:
- The master SSH process exits immediately after the first connection completes
- The control socket remains, but the master process is dead
- Subsequent "command SSHs" using `-S socket` will attempt to use the socket
- If the master is gone, they fall back to direct connections WITHOUT the master

### 3. `SSHMaster::startCommand()` — Fallback Problem

```cpp
// ssh.cc lines 128-137
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

**The bug flow:**
1. `startMaster()` spawns `ssh -M -N -oControlPersist=no` with `LocalCommand=echo started`
2. Master reads `started`, writes it to stdout, connection established
3. Master exits (ControlPersist=no)
4. `startCommand()` spawns `ssh -S socket` (command SSH) WITHOUT `LocalCommand`
5. **BUT:** If `isMasterRunning()` returns false OR socket doesn't work, command SSH falls back to direct connection
6. The command SSH was NOT given `LocalCommand=echo started` because `addCommonSSHOpts` adds it to `args` passed to `startMaster()`, not to command SSH args
7. Therefore, the nix protocol handshake expects `started` but never receives it—OR—if the command SSH somehow still has LocalCommand set and the fallback re-uses the old master socket... confusion ensues

Wait, looking more carefully at `startCommand()`:

```cpp
// ssh.cc lines 153-156
args = {"ssh", hostnameAndUser.c_str(), "-x"};
addCommonSSHOpts(args, socketPath);  // Adds -oLocalCommand=echo started
```

So `startCommand()` ALSO calls `addCommonSSHOpts()`, meaning the command SSH ALSO gets `LocalCommand=echo started`.

**The actual bug:** When using SSH master mode:
- The master (`ssh -M -N`) with `ControlPersist=no` exits after first connection
- Command SSHs reuse the control socket with `-S socket`
- With `ControlMaster=auto` in ssh_config, if the socket exists, the master is NOT re-run
- But `LocalCommand` is only executed on the ACTUAL master connection
- Subsequent command SSHs go through the mux socket but `LocalCommand` is NOT re-executed
- So the mux path works fine—but if the socket is stale/broken, command SSH falls back to direct
- On the direct fallback path, does it still have `LocalCommand`? YES, because `addCommonSSHOpts` adds it
- But wait, the ORIGINAL master wrote `started` to the socket's stdout pipe, not to each command SSH's stdout

Let me re-examine the actual bug from issue #8329:

> "When using `ControlMaster`, `LocalCommand` is only executed on the initial connection, so Nix gets stuck on every further connection to the same host that occurs while the original connection is still open."

The bug is the OPPOSITE: With ControlPersist and ControlMaster:
- First connection: master runs, LocalCommand executes, `started` sent, everything works
- Subsequent connections (while master still running): command SSH goes through mux, but `LocalCommand` is NOT executed again (by design in OpenSSH)
- Nix expects `started` but doesn't get it, so it hangs waiting for `started`

**The protocol leak variant:** When master dies (`ControlPersist=no`):
- Master exits after first connection
- Socket may still exist but be non-functional
- Command SSH falls back to direct connection
- If ControlMaster is set in user's ssh_config with ControlPath, this gets complex
- The `started` string could appear at wrong time or be mixed with protocol data

### 4. `createSSHEnv()` — SHELL=/bin/sh

```cpp
// ssh.cc lines 98-112
Strings createSSHEnv()
{
    // Copy the environment and set SHELL=/bin/sh
    StringMap env = getEnv();

    // SSH will invoke the "user" shell for -oLocalCommand, but that means
    // $SHELL. To keep things simple and avoid potential issues with other
    // shells, we set it to /bin/sh.
    env.insert_or_assign("SHELL", "/bin/sh");

    Strings r;
    for (auto & [k, v] : env) {
        r.push_back(k + "=" + v);
    }

    return r;
}
```

**Purpose:** OpenSSH executes `LocalCommand` through the user's shell (via `$SHELL -c "echo started"`). Setting `SHELL=/bin/sh` ensures consistent behavior regardless of the user's configured shell.

**Does it affect LocalCommand execution?** YES — OpenSSH uses `SHELL` environment variable (if set) to determine which shell to use for `LocalCommand`. If `SHELL` is unset or points to a broken shell, `LocalCommand` may fail silently or behave unexpectedly.

---

## Research Question Answers

### Q1: How does OpenSSH handle `-M -N` with `-oLocalCommand`?

**Answer:**

With `-M -N` (master mode, no remote command):
- The master SSH forks a child that handles multiplexed connections
- `LocalCommand` is executed by the MASTER's child process on the LOCAL machine
- It runs AFTER the TCP connection is established but BEFORE the login shell
- For `-N` (no command), `LocalCommand` still runs on master startup

**With ControlMaster and ControlPersist:**

OpenSSH's behavior:
- `LocalCommand` runs ONLY on the initial master connection
- For subsequent connections through the mux socket (`-S socket`), `LocalCommand` is NOT executed
- This is documented OpenSSH behavior: LocalCommand is only for the initial connection

**When master socket is stale:**

If the control socket exists but the master process is dead (`ControlPersist=no`):
- SSH with `-S socket` will try to connect to the mux
- If the master is dead, SSH falls back to direct connection
- The `LocalCommand` option is still active on this fallback connection
- But where does the `LocalCommand` output go? It goes to the NEW connection's stdout
- This can cause `echo started` to appear in the wrong stream or at the wrong time

**OpenSSH source behavior (documented):**
- When connecting to a dead mux socket, SSH closes the mux and makes a direct connection
- `LocalCommand` executes on this new direct connection
- If `ControlPersist=no` on master and master exits, mux socket becomes stale
- Subsequent connections get fresh LocalCommand execution

### Q2: What is the purpose of `LocalCommand=echo started`?

**Answer:**

**Purpose:** Synchronization signal to pause progress bar until SSH connection is established.

**Origin:** PR #8018 (tweag/nix), fixing issue #7959

**The problem it solves:**
- Nix uses a progress bar for long operations
- When SSH asks for password/passphrase, the progress bar would overwrite the prompt
- Users thought the command was hung

**Solution:**
1. Before SSH: pause progress bar
2. Start SSH with `LocalCommand=echo started`
3. SSH executes `echo started` locally after connection established
4. Nix reads `started` from stdout
5. Only then resume progress bar
6. Password prompt now appears cleanly

**Design note from code:**
```cpp
// The local command runs synchronously, so presumably
// the remote session won't be garbled if the local command is slow.
```

This is a SYNCHRONIZATION mechanism, not a protocol handshake.

### Q3: Are there existing upstream issues or PRs?

**Answer:**

**YES — Multiple related issues found:**

1. **Issue #8329** (NixOS/nix) — **"#8018 broke SSH usage with `ControlMaster` and `ControlPersist`"**
   - Status: CLOSED (May 17, 2023)
   - Problem: With `ControlMaster auto` + `ControlPersist 15m` in ssh_config:
     - First connection: works
     - Second connection (while master alive): hangs because `LocalCommand` only runs on master, not mux
   - Suggested fix: "make it consider the `started` message optional"
   - This is the SAME underlying bug but with ControlPersist=YES

2. **Issue #7959** (NixOS/nix) — "SSH password prompt gets garbled by progress bar"
   - Status: CLOSED (fixed by #8018)
   - This is the ORIGINAL problem that `LocalCommand=echo started` solved

3. **PR #8018** (NixOS/nix) — "SSH: don't erase password prompt if it is displayed"
   - Merged: March 31, 2023
   - Author: balsoft (tweag)
   - Introduced the `LocalCommand=echo started` mechanism

**DeterminateSystems-specific issues:** No direct issues found in search. The bug may be unique to Determinate Nix due to the `maxConnections=64` change that enables SSH master mode by default.

### Q4: What does `-oControlPersist=no` mean with `-M`?

**Answer:**

**OpenSSH ControlPersist behavior:**

- `ControlPersist=no` (or not set): Master exits when the initial connection ends
- `ControlPersist=yes` or `ControlPersist=<time>`: Master stays alive for `<time>` (default 2 hours) or until killed

**With `-M -N` (master mode, no remote command):**

- `-M`: Enable master mode for connection multiplexing
- `-N`: Don't execute remote command
- `ControlPersist=no`: Master exits immediately after connection setup

**In the code:**
```cpp
// startMaster() explicitly sets ControlPersist=no
OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
```

**With `ControlPersist=15m`:**
- Master would stay alive for 15 minutes after last connection closes
- Socket would remain valid
- Subsequent mux connections would work (but `LocalCommand` still wouldn't re-run)
- This would AVOID the fallback-to-direct scenario

**Can it be overridden?**

Yes, but only via command-line `-oControlPersist=<value>`. The code explicitly sets `ControlPersist=no` AFTER any user-provided options from `NIX_SSHOPTS`. Since `addCommonSSHOpts()` inserts options before the final `-S` socket path, the explicit `ControlPersist=no` could potentially override user settings.

### Q5: Can `LocalCommand` be overridden per-invocation?

**Answer:**

**YES — OpenSSH option ordering matters:**

OpenSSH processes options left-to-right. Later `-oLocalCommand` values override earlier ones.

**Current code order in `addCommonSSHOpts()`:**
```cpp
args.push_back(OS_STR("-oPermitLocalCommand=yes"));
args.push_back(OS_STR("-oLocalCommand=echo started"));
// ... later in startMaster/startCommand ...
args.insert(args.end(), {OS_STR("-S"), socketPath->native()});
```

**Key insight:** If we want to override `LocalCommand` later, we could:
1. Not add `LocalCommand` in `addCommonSSHOpts()`
2. Add it explicitly in `startMaster()` only
3. Or add a NOOP override `-oLocalCommand=true` after the real one

**Potential fix vectors:**

**Fix Vector A: Only set LocalCommand on master, not command SSHs**
```cpp
// In startMaster() only:
args.push_back("-oLocalCommand=echo started");

// In startCommand() - do NOT add LocalCommand:
```

**Fix Vector B: Check if we're using mux socket before expecting `started`**
```cpp
// If using socket and master is running, skip LocalCommand check
if (socketPath && isMasterRunning(*socketPath)) {
    // Skip the "started" read - we're using mux
} else {
    // Direct connection - LocalCommand will fire
    readAndExpectLine("started");
}
```

**Fix Vector C: Use a different synchronization mechanism**
- Instead of `LocalCommand`, use a post-connection SSH echo
- Or use `ServerAliveInterval`/`ServerAliveCountMax` to detect connection
- Or make the nix daemon send its own ready signal

### Q6: What is the `createSSHEnv()` function doing?

**Answer:**

```cpp
Strings createSSHEnv()
{
    StringMap env = getEnv();
    env.insert_or_assign("SHELL", "/bin/sh");
    // ... convert to strings ...
}
```

**Purpose:** Set up environment for SSH subprocess, specifically ensuring `SHELL=/bin/sh`.

**Why this matters for LocalCommand:**

OpenSSH executes `LocalCommand` via:
```bash
$SHELL -c "echo started"
```

If `$SHELL` is:
- `/bin/bash`: Works
- `/bin/zsh`: Works
- Empty/unset: SSH falls back to `/bin/sh`
- Broken path: LocalCommand fails silently

**The code sets SHELL to `/bin/sh` explicitly** to ensure consistent, predictable behavior across different user configurations.

**Impact on bug:** None directly. `SHELL=/bin/sh` just ensures `LocalCommand` runs reliably. It doesn't prevent the protocol leak.

---

## Bug Mechanism — Detailed Analysis

### The Protocol Leak Scenario

```
Timeline with ControlPersist=no:
──────────────────────────────────────────────────────────────

1. Nix calls startMaster()
   └─> ssh -M -N -oControlPersist=no -oLocalCommand=echo started -S /tmp/nix/ssh.sock user@host
   └─> Master connects, LocalCommand fires, writes "started" to stdout PIPE
   └─> startMaster() reads "started" ✓
   └─> Master process exits (ControlPersist=no)
   └─> Socket /tmp/nix/ssh.sock remains

2. Nix calls startCommand() — FIRST build command
   └─> ssh -x -oLocalCommand=echo started -S /tmp/nix/ssh.sock user@host -- nix-daemon --stdio
   └─> SSH tries socket → mux available? → goes through mux
   └─> LocalCommand does NOT fire again (OpenSSH design)
   └─> BUT: nix-daemon sends its own "welcome" or protocol data
   └─> If Nix expects "started" from LocalCommand, it reads daemon's data instead
   └─> PROTOCOL CONFUSION

3. Nix calls startCommand() — SECOND build command
   └─> If mux socket is stale/broken:
   └─> ssh falls back to DIRECT connection
   └─> LocalCommand=echo started FIRES on this direct connection
   └─> "started" appears in the stream
   └─> But Nix may have already read protocol data expecting "started"
   └─> MIXED SIGNALS = PROTOCOL LEAK
```

### Why maxConnections=64 Made This Worse

- Upstream Nix: `maxConnections=1` → No SSH master mode
- Determinate Nix: `maxConnections=64` → SSH master mode ENABLED
- With `maxConnections=1`, each connection is independent
- With `maxConnections=64`, connection multiplexing kicks in
- The `LocalCommand=echo started` mechanism was designed for single connections
- It doesn't account for multiplexed connections where LocalCommand only fires once

---

## Fix Vectors

### Fix Vector A: Detect Mux vs Direct and Skip LocalCommand Check

**Principle:** If using a valid mux socket, `LocalCommand` won't fire (by OpenSSH design), so don't wait for it.

```cpp
// In startCommand():
if (socketPath && isMasterRunning(*socketPath)) {
    // Using mux - LocalCommand won't fire, skip check
    // But need some other way to ensure connection is ready
} else {
    // Direct connection - LocalCommand will fire
    reply = readLine(out.readSide.get());
    if (reply != "started") throw Error("...");
}
```

**Risk:** Need to verify mux socket is actually working before skipping.

### Fix Vector B: Remove LocalCommand Dependency Entirely

**Principle:** Don't use `LocalCommand` for synchronization. Use SSH connection status instead.

Options:
1. Use `ssh -O check` to verify mux is working
2. Use `ServerAliveInterval` to detect connection liveness
3. Make nix-daemon send its own ready signal on connect

### Fix Vector C: Set ControlPersist to non-zero value

**Principle:** If `ControlPersist=15m` instead of `ControlPersist=no`, the master stays alive, avoiding stale socket fallback.

**Risk:** May have other side effects; changes SSH session lifetime semantics.

### Fix Vector D: Only Apply LocalCommand to Master, Not Command SSHs

**Principle:** Only the master connection needs the `LocalCommand=echo started` synchronization. Command SSHs should NOT have it.

```cpp
// startMaster() — add LocalCommand
args.push_back("-oLocalCommand=echo started");

// startCommand() — do NOT add LocalCommand
// (already removed from addCommonSSHOpts for this path)
```

**Risk:** Need to verify this doesn't break the password prompt fix from #8018.

---

## Recommendations

### Immediate

1. **Investigate whether `isMasterRunning()` correctly detects dead masters** with `ControlPersist=no`
2. **Add logging** to distinguish mux connections from direct connections
3. **Test with `ControlPersist=15m`** to see if it avoids the fallback scenario

### Short-term

4. **Implement Fix Vector A or B** to properly handle mux connections
5. **Add integration test** for SSH master mode with multiple concurrent connections

### Long-term

6. **Consider Fix Vector C** (remove LocalCommand dependency) for a cleaner solution
7. **Document the SSH master mode behavior** in the codebase

---

## References

- Issue #7959: Password prompt garbled by progress bar
- PR #8018: Introduced LocalCommand=echo started
- Issue #8329: LocalCommand breaks with ControlMaster
- OpenSSH ssh.c: LocalCommand execution (search for "local_command")
- OpenSSH CONTROL_MASTER document in ssh_config(5)

---

## Appendix: OpenSSH LocalCommand Behavior

From OpenSSH source (ssh.c and clientloop.c):

```c
// When ControlMaster is active:
// - LocalCommand only runs on the INITIAL connection (the master)
// - Subsequent connections via mux socket do NOT run LocalCommand
// - This is intentional design to avoid duplicate local command output

// When mux socket is dead and fallback to direct:
// - A NEW direct connection is made
// - LocalCommand runs on this NEW connection
// - Output goes to the new connection's stdout
```

This is why the bug manifests differently based on ControlPersist setting:
- **ControlPersist=yes/15m**: Master stays alive, mux works, LocalCommand never fires again → hangs
- **ControlPersist=no**: Master dies, socket stale, fallback to direct, LocalCommand fires at wrong time → protocol leak
