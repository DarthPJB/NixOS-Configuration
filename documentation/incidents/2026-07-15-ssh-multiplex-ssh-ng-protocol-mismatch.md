# Incident: SSH Multiplexing Corrupts ssh-ng Protocol Handshake

**Date:** 2026-07-15  
**Severity:** High (blocks all ARM builds from x86_64 host)  
**Status:** Resolved  
**Supersedes:** `2026-07-14-nix-protocol-mismatch-arm-builder.md` (incorrect root cause)

---

## Summary

Building `display-1` (aarch64) from LINDA (x86_64) failed with `protocol mismatch, got 'started'` when the nix-daemon's ssh-ng connection to `arm-builder` (10.88.127.43) was corrupted by SSH ControlMaster multiplexing. The fleet-wide `ssh-multiplex.nix` module applied `ControlMaster auto` to `Host *`, which intercepted the nix-daemon's SSH sessions and caused the ssh-ng protocol handshake to receive SSH-level preamble data instead of the expected nix daemon greeting.

## Environment

| Property | Local (LINDA) | Remote (arm-builder) |
|----------|--------------|---------------------|
| **Hostname** | LINDA | arm-builder |
| **WireGuard IP** | 10.88.127.88 | 10.88.127.43 |
| **Architecture** | x86_64-linux | aarch64-linux |
| **Nix Distribution** | Determinate Nix 3.21.5 | Determinate Nix 3.21.5 |
| **Nix Base Version** | 2.34.8 | 2.34.8 |
| **Nix Daemon** | `determinate-nixd` | `determinate-nixd` |
| **SSH Protocol** | `ssh-ng` | `ssh-ng` |
| **SSH User** | — | `build` (port 22, WireGuard only) |

## Error

```
error: cannot open connection to remote store 'ssh-ng://build@10.88.127.43': protocol mismatch, got 'started'
error: Cannot build '/nix/store/8pcxdrymg4hl191c0jr8xxdj7c4h0y7p-linux-rpi-6.18.34-stable_20260609.drv'.
```

## Root Cause

### Primary: SSH ControlMaster Multiplexing

The `ssh-multiplex.nix` module (imported in `commonModules`, flake.nix line 60) applied:

```ssh-config
Host *
  ControlMaster auto
  ControlPath /run/ssh-mux/%r@%h:%p
  ControlPersist 15m
```

This matched ALL SSH connections, including the nix-daemon's ssh-ng sessions to the build user. When ControlMaster is active:

1. SSH reuses existing control sockets or creates new ones
2. The ssh-ng protocol expects a clean channel where the remote `nix-daemon --stdio` speaks binary protocol
3. With ControlMaster, the channel may carry SSH-level preamble or stale buffered data
4. The nix client reads this as protocol data — receiving `"started"` instead of the expected binary greeting
5. Protocol handshake fails with `protocol mismatch, got 'started'`

**Confirmed by:** NixOS/nix#14132, DeterminateSystems/nix-src#441

### Contributing: Stale Installer nix.conf

The remote builder's `/etc/nix/nix.conf` was a regular file written by the Determinate installer (2026-07-14), not managed by NixOS. The Determinate module uses a two-file approach (`nix.conf` + `nix.custom.conf` via `!include`), but the installer's stale `nix.conf` blocked NixOS from regenerating it. This was resolved by removing the file so the rebuild cycle can regenerate it.

## Resolution

### 1. SSH Multiplexing Scoping (declarative)

**`modules/ssh-multiplex.nix`:**
- Changed `Host *` to `Host 10.88.127.* 10.88.128.*` — multiplexing restricted to topology subnets only
- Added `sshMultiplex.exclusions` option for host patterns that must never multiplex
- Exclusion blocks are emitted before the topology match (SSH first-match-wins ordering)

**`modifier_imports/remote-builder.nix`:**
- Wires `nix.buildMachines` hostnames into `sshMultiplex.exclusions` dynamically
- Added explicit `Host build@*` block with `ControlMaster no` as belt-and-suspenders

### 2. Stale nix.conf Removal (imperative, required)

Removed `/etc/nix/nix.conf` from arm-builder — the Determinate installer's regular file was blocking NixOS from managing it. The rebuild cycle will regenerate it from the module system.

## Verification

SSH config resolution confirmed correct via `ssh -G`:

| Connection | Expected | Actual |
|-----------|----------|--------|
| `build@10.88.127.43` | `ControlMaster no` | `controlmaster false` |
| `build@100.107.101.14` | `ControlMaster no` | `controlmaster false` |
| `hyperhyper` (mgmt) | `ControlMaster auto` | `controlmaster auto` |
| `10.88.127.1` (topology) | `ControlMaster auto` | `controlmaster auto` |
| `193.16.42.36` (external) | `ControlMaster no` | `controlmaster false` |

Build test after fix: 12+ derivations successfully built on arm-builder via ssh-ng, including `linux-rpi-6.18.34-stable_20260609` (the exact derivation from the original error). Remaining intermittent failures under heavy parallel load are attributed to remote daemon state (logged as `unexpected Nix daemon error: error: interrupted by the user`).

## Files Changed

- `modules/ssh-multiplex.nix` — topology-only scoping, exclusion list option
- `modifier_imports/remote-builder.nix` — builder exclusion wiring, explicit `Host build@*` block

## References

- NixOS/nix#14132: SSH ControlMaster breaks ssh-ng remote store
- DeterminateSystems/nix-src#441: Remote store fails with SSH multiplexing
- Prior incident: `2026-07-14-nix-protocol-mismatch-arm-builder.md` (superseded — incorrect root cause attributed to Nix distribution mismatch)

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 2026-07-14 09:07 | First incident — protocol mismatch on `boehm-gc` build |
| 2026-07-14 09:16 | Mitigated by daemon reset; root cause misidentified as Determinate vs standard Nix |
| 2026-07-15 ~09:00 | Recurrence — `nixos-rebuild build --flake .#display-1` fails with same error |
| 2026-07-15 ~10:00 | Root cause correctly identified as SSH ControlMaster multiplexing |
| 2026-07-15 ~10:15 | SSH multiplexing scoped to topology subnets; exclusion list added |
| 2026-07-15 ~10:25 | Build test: 12+ derivations succeed on remote builder |
| 2026-07-15 ~10:30 | Stale `/etc/nix/nix.conf` removed from arm-builder |
| 2026-07-15 ~10:40 | Incident report written |
