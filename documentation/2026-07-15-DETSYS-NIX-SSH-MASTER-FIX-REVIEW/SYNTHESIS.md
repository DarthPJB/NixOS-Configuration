# Synthesis: Determinate Nix SSH Master Protocol Leak Fix

**Date:** 2026-07-15  
**Status:** Consensus reached across all three reviewers

---

## Consensus: Vector 4 (No-op LocalCommand Override) + Vector 3 (ControlPersist)

All three reviewers agree: **Vector 4 is the correct primary fix.** It eliminates the bug at the producer side — the command SSH never writes `"started"` to stdout, regardless of whether the master is alive or dead. No race conditions. No TOCTOU issues. No behavioral change for live master connections.

**Vector 3** is a recommended companion fix that reduces the frequency of master death, providing defense-in-depth.

## The Fix (2-Line Diff)

In `ssh.cc`, `SSHMaster::startCommand()`, after `addCommonSSHOpts()` and `extraSshArgs`:

```diff
  args.splice(args.end(), std::move(extraSshArgs));
+ if (useMaster) args.push_back(OS_STR("-oLocalCommand=true"));
  args.push_back("--");
```

And optionally in `startMaster()`:

```diff
- OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=no"};
+ OsStrings args = {"ssh", hostnameAndUser.c_str(), "-M", "-N", "-oControlPersist=15m"};
```

## Why This Works

| Scenario | LocalCommand fires? | What runs? | stdout output |
|---|---|---|---|
| Through live multiplex | No | — | Nothing (correct) |
| Direct connection (no master) | Yes | `true` (no-op) | Nothing (correct) |
| Fallback (stale socket) | Yes | `true` (no-op) | Nothing (correct) |

SSH processes `-o` options in order; last one wins. `addCommonSSHOpts()` adds `-oLocalCommand=echo started`. Our override `-oLocalCommand=true` comes later and wins. The `true` command is POSIX, always available, and produces no output.

## Why Other Vectors Are Rejected

| Vector | Verdict | Reason |
|--------|---------|--------|
| 1. Always consume "started" | Rejected | Breaks live master connections — `readLine()` would block or read protocol bytes |
| 2. Detect dead master | Insufficient | Inherently racy — `isMasterRunning()` is point-in-time, can't eliminate TOCTOU |
| 5. Separate fd for "started" | Rejected | Complex, SSH doesn't pass arbitrary file descriptors cleanly |
| 6. `-F /dev/null` | Rejected | Breaks SSH config-based ProxyJump, IdentityFile, StrictHostKeyChecking |
| 7. `max-connections=1` for ssh-ng | Rejected | Limits functionality, defeats purpose of Determinate's 64 default |

## Upstream Path

This fix is:
- **Minimal** — 2 lines of code
- **Deterministic** — no race conditions
- **Backward compatible** — no behavioral change for non-master mode
- **Easy to reason about** — "when using master mode, override LocalCommand to no-op on command SSHs"
- **Addresses a latent bug** — exists in both upstream and Determinate Nix, but only reachable when `maxConnections > 1`

The upstream PR should:
1. Add the `-oLocalCommand=true` override in `startCommand()` when `useMaster=true`
2. Optionally change `ControlPersist=no` to `ControlPersist=15m` in `startMaster()`
3. Add a test case that verifies the stale-socket-fallback scenario
4. Reference NixOS/nix#8329 and NixOS/nix#7959 for context

## References

- NixOS/nix#7959: Original problem (password prompt garbled) — fixed by PR #8018
- NixOS/nix#8018: Introduced `LocalCommand=echo started` — merged March 2023
- NixOS/nix#8329: Same bug with ControlPersist=yes — closed as duplicate of design issue
- Blog: `personal-website-blog/draft-blogs/2026-07-15-nix-ssh-multiplex-protocol-mismatch.md`
