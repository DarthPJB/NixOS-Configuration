# Overlord-II Deployment Status

> **Generated:** 2026-07-12
> **Branch:** `overlord-II-exec` (10 commits ahead of `overlord-II`)
> **Deployment method:** `nix run .#<machine> -- switch`
> **Status:** ✅ DEPLOYMENT PHASE SUCCESSFUL

## Deployed Systems (12 machines)

| Machine | Arch | System Path | Exporter | Status |
|---------|------|-------------|----------|--------|
| cortex-alpha | x86_64 | `vgjqbk03smrmiiqp68gjmq92kpjpzh8p-nixos-system-cortex-alpha-25.11.20260514.d7a713c` | ✅ | Healthy |
| LINDA | x86_64 | (manual switch by user) | ✅ | Healthy |
| alpha-three | x86_64 | `9wgv016mq53csld8ch9vy5m9y5klj8pk-nixos-system-alpha-three-25.11.20260514.d7a713c` | ✅ | Healthy |
| alpha-one | x86_64 | `22kjxr00i9jsdzscqrj0za04k72vpl5q-nixos-system-alpha-one-25.11.20260514.d7a713c` | ✅ | Healthy |
| terminal-nx-01 | x86_64 | `49xl9pwsk0nqz4s7hll2d05svlivfwxj-nixos-system-terminal-nx-01-25.11.20260514.d7a713c` | ✅ | Healthy |
| remote-worker | x86_64 | `4wand9fx760b9wzzmhrih6mrmx8ami7w-nixos-system-remote-worker-25.11.20260514.d7a713c` | ✅ | Healthy |
| terminal-zero | x86_64 | `gscgja4hwyx1p1lvsbl2alqd7i26zyn9-nixos-system-terminal-zero-25.11.20260514.d7a713c` | ✅ | Healthy |
| gaming-host-1 | x86_64 | `c1xkq737sx8zc4y35lp5bqp1n7g3rw6d-nixos-system-gaming-host-1-25.11.20260514.d7a713c` | ✅ | Healthy |
| local-nas | x86_64 | `923p9y31by4l20zlm5bnll8r617ilaai-nixos-system-local-nas-25.11.20260514.d7a713c` | ✅ | Healthy |
| display-1 | aarch64 | `axhfhm3bs2lbgaa969l05pb3bq34lqww-nixos-system-display-1-sd-card-26.05.20260511.c6e5ca3` | ✅ | Healthy |
| arm-builder | aarch64 | `1r17xr8dal2frr85qwrndspfkjajmzm0-nixos-system-arm-builder-sd-card-26.05.20260511.c6e5ca3` | ❌ | Healthy (no exporter) |
| remote-builder | x86_64 | `3w1wa1f9ljnmzz9mvgf7svdf3hi43nbv-nixos-system-remote-builder-25.11.20260514.d7a713c` | ✅ | Healthy |

## Not Deployed (by design)

| Machine | Reason |
|---------|--------|
| bargman-greeter-vm | Not a real system — VM test harness only |
| arm-bootstrap | Not a real system — generic ARM bootstrap image |
| beta-one | Under maintenance |
| display-2 | Under maintenance |
| print-controller | Under maintenance |

## Dormant (excluded from deployment)

| Machine | Arch |
|---------|------|
| alpha-two | x86_64 |
| display-0 | aarch64 |
| storage-array | x86_64 |

## Known Issues

### Exporter `system_path` Discrepancy

The `nixos-deployment-exporter` records a stale `system_path` in `/var/lib/nixos-deployment/state.json` after activation. The actual running system (`/run/current-system`) is correct, but the exporter metric may lag by one generation.

Affects: cortex-alpha, local-nas (observed during this session).

Root cause: The activation script reads the system path before the symlink is fully updated during `--test` and `--switch`. This is a pre-existing bug in the exporter module, not caused by overlord-II changes.

### `programs.ssh.matchBlocks` Does Not Exist

The SSH multiplexing plan (`ssh-multiplex-topology-2026-07-03.md`) assumed `programs.ssh.matchBlocks` was a valid NixOS option. It does not exist in nixpkgs 25.11. Plan needs redesign using `programs.ssh.extraConfig`.

## Changes Deployed

- Topology rectification: `real-topology/` → `topology/` + `goldens/`
- Golden validation: `check-network` now uses `dump-config` (serialize-config.nix)
- No golden files were modified
- All 18 goldens identical to `v1.9-Golden` tag
