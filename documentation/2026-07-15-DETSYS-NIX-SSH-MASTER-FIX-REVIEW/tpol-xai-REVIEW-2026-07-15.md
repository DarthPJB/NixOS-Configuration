# Determinate Nix SSH Master Protocol Leak — Vector Evaluation

**Date:** 2026-07-15  
**Reviewer:** tpol-xai  
**Source:** REVIEW.md (7 vectors) + source inspection of ssh.cc, remote-store.hh, machines.cc, ssh-store.cc

---

## Executive Summary

The root cause is clear: `maxConnections=64` (Determinate default) enables `useMaster=true` in `SSHStore` constructor → `SSHMaster` uses `LocalCommand=echo started` (via `addCommonSSHOpts`) on the master SSH → when the master dies (default `ControlPersist=no`), command SSHs fall back to direct connections and emit `"started"` on stdout → `startCommand()` skips the read because `useMaster=true` → protocol corruption.

**Most promising vectors:** Vector 4 (no-op `LocalCommand` override) and Vector 3 (`ControlPersist`). Vector 4 is the cleanest surgical fix. Vector 3 is a pragmatic mitigation. A hybrid (Vector 3 + Vector 4) is recommended for robustness.

---

## Per-Vector Evaluation

### Vector 1: Always consume "started" in `startCommand()`

**Feasibility:** Broken as stated. When `useMaster=true` and master is alive, command SSH stdout is the nix-daemon protocol stream (WORKER_MAGIC_2 first). `readLine()` would block or read protocol bytes as `"started"`, causing immediate failure.

**Risk:** High — breaks all live master connections. Race window between master death and read is unfixable without additional state.

**Upstreamability:** Nix upstream would reject — violates the invariant that `LocalCommand` only runs on direct connections.

**Complexity:** Low (one-line change) but incorrect.

**Verdict:** Rejected.

---

### Vector 2: Detect dead master before consuming "started"

**Feasibility:** Technically viable but fragile. After `startProcess()` in `startCommand()`, call `isMasterRunning(*socketPath)`. If false, consume `"started"`. If true, skip.

**Risk:**
- Race: master dies between `isMasterRunning()` check and `readLine()` → still leaks.
- `ssh -O check` overhead on every `startCommand()` (even for live masters).
- `isMasterRunning()` signature requires socketPath; the check in `startCommand()` currently uses `!(socketPath && isMasterRunning(*socketPath))`.

**Upstreamability:** Acceptable as a defensive check, but the race condition makes it incomplete. Upstream would likely prefer a deterministic fix.

**Complexity:** Medium — adds a check + conditional read path.

**Verdict:** Partial mitigation only. Not sufficient alone.

---

### Vector 3: Set `ControlPersist=15m` on the master SSH

**Feasibility:** High. In `startMaster()` line 265:
```cpp
args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
```
Change to:
```cpp
args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=15m"};
```

**Risk:**
- Does not fix the bug — only reduces trigger probability.
- Masters still die on: network flaps, OOM kills, explicit `ssh -O exit`, machine sleep/resume, SSH config overrides (`ControlPersist` in user `~/.ssh/config`).
- Long-lived masters accumulate stale sockets if not cleaned (tmpDir `AutoDelete` helps on process exit, but not on crash).

**Upstreamability:** High. `ControlPersist` is a standard OpenSSH option. Upstream Nix already sets `-oControlPersist=no` explicitly; changing the value is a one-line config tweak with no API change.

**Complexity:** Very low — single-line edit in `startMaster()`.

**Verdict:** Recommended as a **companion fix**. Should be combined with Vector 4 for defense-in-depth.

---

### Vector 4: Use `-oLocalCommand=true` on command SSHs (no-op)

**Feasibility:** High. The implementation sketch in REVIEW.md is correct:

In `startCommand()` (around line 190), after:
```cpp
addCommonSSHOpts(args, socketPath);
```
add:
```cpp
if (useMaster) {
    args.push_back(OS_STR("-oLocalCommand=true"));
}
```

Because SSH option precedence is **last-wins**, `-oLocalCommand=true` overrides the earlier `LocalCommand=echo started` from `addCommonSSHOpts`. When a command SSH falls back to a direct connection, `LocalCommand` is a no-op → no `"started"` emitted → `startCommand()` correctly skips the read (because `useMaster=true`).

**Risk:**
- Edge case: What if user SSH config has `LocalCommand` set globally? The `-o` on command line still wins (OpenSSH `-o` has higher precedence than config file).
- Edge case: `LocalCommand` with `PermitLocalCommand=no` in sshd_config on the remote? Irrelevant — `LocalCommand` runs on the *client* side before the connection is established.
- Edge case: Windows (`_WIN32` path)? The entire SSH master path is already `#ifdef _WIN32` guarded with `UnimplementedError`.
- No behavior change for live masters (they never emit `"started"` anyway).

**Upstreamability:** Excellent. This is a minimal, targeted fix that:
- Preserves the `LocalCommand` mechanism for its original purpose (signaling direct connections).
- Only affects the `useMaster=true` code path.
- Requires no new options, no protocol changes, no config changes.
- Solves the exact failure mode without side effects.

**Complexity:** Low — ~3 lines in `startCommand()`. The conditional is already present in spirit (`if (!fakeSSH && !useMaster)` guards the read).

**Implementation Detail (Validated):**
- `addCommonSSHOpts` is called at line 190 inside the lambda passed to `startProcess`.
- `useMaster` is a member of `SSHMaster`, accessible in `startCommand()`.
- The `args` vector is local to the lambda; pushing after `addCommonSSHOpts` is safe.
- This matches the REVIEW.md suggestion exactly.

**Verdict:** **Strongly recommended as primary fix.**

---

### Vector 5: Use a separate file descriptor for "started" signal

**Feasibility:** Possible but over-engineered. Would require:
- Changing `LocalCommand` to `echo started >&3`
- Passing fd 3 through `startProcess`
- Modifying `startCommand()` and `startMaster()` to read from fd 3 instead of stdout

**Risk:** High complexity. SSH's `LocalCommand` runs in the client shell; redirecting to fd 3 requires `sh -c` wrapping or `LocalCommand` with explicit redirection. File descriptor passing across `execvpe` is fragile. Introduces new failure modes (fd leaks, shell quoting issues).

**Upstreamability:** Low. Too invasive for a bug fix; upstream would prefer simpler approaches.

**Complexity:** High — touches process spawning, fd management, and both master/command paths.

**Verdict:** Rejected. Overkill for the problem.

---

### Vector 6: Use `-F /dev/null` on all Nix SSH invocations

**Feasibility:** Works but heavy-handed. In `addCommonSSHOpts()`:
```cpp
args.push_back(OS_STR("-F"));
args.push_back(OS_STR("/dev/null"));
```

**Risk:**
- Disables *all* user SSH config (IdentityFile, UserKnownHostsFile, ProxyJump, Match blocks, etc.).
- Nix already passes many options via command line (`-i`, `-o` for known hosts, etc.), so it *might* work, but it's a policy change that removes user control.
- Breaks legitimate use cases where users configure SSH via `~/.ssh/config` for Nix hosts.

**Upstreamability:** Low. Upstream Nix values user configurability. This would be seen as removing a feature.

**Complexity:** Low, but the blast radius is large.

**Verdict:** Rejected. Too invasive.

---

### Vector 7: Set `max-connections=1` for `ssh-ng` in `machines.cc`

**Feasibility:** Trivial (one-line change in `Machine` constructor).

**Risk:** Directly violates the constraint: "Must NOT reduce `maxConnections` default (64 is intentional for Determinate daemon performance)." This would regress Determinate's performance goals.

**Upstreamability:** N/A — rejected by product requirements.

**Verdict:** Rejected per constraints.

---

## Hybrid Approaches & New Vectors

### Recommended: Vector 3 + Vector 4 (Defense-in-Depth)

**Rationale:**
- Vector 4 is the *correct* fix — it eliminates the protocol leak at the source.
- Vector 3 (`ControlPersist=15m`) makes the master *resilient* to transient disconnects, reducing how often fallback occurs.
- Together they handle both the common case (stale socket after idle) and the rare case (master dies for other reasons).

**Implementation:**
1. In `startMaster()` line 265: change `-oControlPersist=no` → `-oControlPersist=15m`
2. In `startCommand()` after `addCommonSSHOpts(args, socketPath)` (line 190), add:
   ```cpp
   if (useMaster) {
       args.push_back(OS_STR("-oLocalCommand=true"));
   }
   ```

This is minimal, upstreamable, and robust.

---

### New Vector: Explicit master health check + reconnect (not recommended)

Add a `reconnectMaster()` path that detects `ECONNREFUSED` / socket missing on `startCommand()` and relaunches the master. This is more complex than Vector 4 and doesn't address the root cause (the `"started"` emission on fallback).

---

### New Vector: Make `LocalCommand` conditional on `!useMaster` at the source

Instead of overriding in `startCommand()`, move the `LocalCommand=echo started` emission *inside* `addCommonSSHOpts()` to only apply when `!useMaster` or `!socketPath`. This would require changing the function signature or adding a parameter.

**Feasibility:** Viable, but more invasive than the post-hoc override in Vector 4. The current `addCommonSSHOpts` is called from both master and command paths; adding a `bool forMaster` parameter would work but touches more call sites.

**Verdict:** Vector 4 is simpler and achieves the same result.

---

## Final Recommendation

| Priority | Vector | Action |
|----------|--------|--------|
| **Primary** | Vector 4 | Implement `-oLocalCommand=true` override in `startCommand()` for `useMaster` path |
| **Companion** | Vector 3 | Change `ControlPersist=no` → `ControlPersist=15m` in `startMaster()` |
| **Reject** | 1, 5, 6, 7 | Too risky, too complex, or violates constraints |
| **Partial** | 2 | Can be added later as an extra defensive check if needed |

The combination of Vector 4 (surgical) + Vector 3 (pragmatic) is the minimal, correct, upstreamable fix that preserves `maxConnections=64` while eliminating the protocol leak.