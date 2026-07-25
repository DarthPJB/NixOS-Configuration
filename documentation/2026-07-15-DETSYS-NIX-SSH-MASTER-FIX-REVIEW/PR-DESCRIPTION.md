# PR: Fix LocalCommand "started" leak on stale SSH master socket

## Motivation

When `maxConnections > 1` (the Determinate default is 64), `SSHMaster` creates SSH masters with `-M -N`. Command SSHs connect through the master socket. When the master dies (`ControlPersist=no` is the default with `-M`), the socket becomes stale. The next command SSH falls back to a direct connection, which runs `LocalCommand=echo started`. Since `startCommand()` skips reading `"started"` when `useMaster=true` (it assumes the master already consumed it), the string leaks into the nix protocol stream:

```
error: cannot open connection to remote store 'ssh-ng://build@10.88.127.43': protocol mismatch, got 'started'
```

Upstream Nix defaults `maxConnections` to 1, so `useMaster=false` and the bug is never reachable. Determinate's default of 64 enables SSH master mode, exposing this latent code path.

## Context

- **Upstream issue:** NixOS/nix#14132 — "SSH `ControlMaster auto` breaks `ssh-ng://` remote store"
- **Related:** NixOS/nix#8329 — same bug variant with `ControlPersist=yes`
- **Origin of `LocalCommand`:** NixOS/nix#8018 / PR #8018 — introduced `LocalCommand=echo started` to prevent progress bar output from garbling SSH password prompts
- **Determinate issue:** DeterminateSystems/nix-src#441 — "Remote store access fails when using SSH multiplexing"

The `LocalCommand=echo started` mechanism was designed for the `useMaster=false` case (direct connections). When `useMaster=true`, the code correctly skips reading `"started"` from command SSHs because OpenSSH does not run `LocalCommand` on connections through a live master socket. The bug only manifests when the master is dead and the command SSH falls back to a direct connection.

## Implementation

Two changes in `src/libstore/ssh.cc`:

### 1. Override `LocalCommand` to no-op on command SSHs when `useMaster=true`

In `startCommand()`, after `extraSshArgs` are spliced into the args list:

```cpp
if (useMaster)
    args.push_back(OS_STR("-oLocalCommand=true"));
```

SSH processes `-o` options in order; the last value for a keyword wins. `addCommonSSHOpts()` adds `-oLocalCommand=echo started` earlier. Our override `-oLocalCommand=true` (the POSIX no-op command) comes later and wins.

**Behavioral matrix after fix:**

| Scenario | `LocalCommand` fires? | What runs? | stdout output |
|---|---|---|---|
| Through live multiplex | No | — | Nothing (correct) |
| Direct connection (no master) | Yes | `echo started` | `"started"` consumed by `startCommand()` (correct) |
| Fallback (stale socket) | Yes | `true` (no-op) | Nothing (correct) |

### 2. (Optional) Change `ControlPersist` from `no` to `15m`

In `startMaster()`:

```cpp
- OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
+ OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=15m"};
```

This keeps masters alive longer, reducing the frequency of master death and fallback scenarios. Not required for the fix (Vector 4 handles the fallback correctly), but a pragmatic performance optimization.

## Alternative Approaches Considered

1. **Always consume `"started"` in `startCommand()`** — Broken. When `useMaster=true` and master is alive, command SSH stdout is the nix protocol stream. `readLine()` would read `WORKER_MAGIC_2` as `"started"`, causing immediate failure.

2. **Detect dead master before consuming `"started"`** — Inherently racy. `isMasterRunning()` is a point-in-time check; the master can die between the check and the read (TOCTOU).

3. **`-F /dev/null` to ignore SSH config** — Breaks SSH config-based `ProxyJump`, `IdentityFile`, and `StrictHostKeyChecking`.

4. **Set `max-connections=1` for `ssh-ng` in `machines.cc`** — Limits functionality. Defeats the purpose of the `maxConnections=64` default.

The chosen approach (no-op `LocalCommand` override) is deterministic, eliminates the bug at the producer side, has no race conditions, and is backward compatible.
