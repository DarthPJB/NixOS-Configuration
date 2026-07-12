# Overlord-II Deployment Status

> **Generated:** 2026-07-12
> **Branch:** `overlord-II-exec` (8 commits ahead of `overlord-II`)
> **Deployment method:** `nix run .#<machine> -- switch`

## Deployed Systems

| Machine | Arch | System Path | Exporter | Status |
|---------|------|-------------|----------|--------|
| alpha-three | x86_64 | `/nix/store/9wgv016mq53csld8ch9vy5m9y5klj8pk-nixos-system-alpha-three-25.11.20260514.d7a713c` | ✅ | Healthy |
| alpha-one | x86_64 | `/nix/store/22kjxr00i9jsdzscqrj0za04k72vpl5q-nixos-system-alpha-one-25.11.20260514.d7a713c` | ✅ | Healthy |
| terminal-nx-01 | x86_64 | `/nix/store/49xl9pwsk0nqz4s7hll2d05svlivfwxj-nixos-system-terminal-nx-01-25.11.20260514.d7a713c` | ✅ | Healthy |
| remote-worker | x86_64 | `/nix/store/4wand9fx760b9wzzmhrih6mrmx8ami7w-nixos-system-remote-worker-25.11.20260514.d7a713c` | ✅ | Healthy |
| display-1 | aarch64 | `/nix/store/axhfhm3bs2lbgaa969l05pb3bq34lqww-nixos-system-display-1-sd-card-26.05.20260511.c6e5ca3` | ✅ | Healthy |
| arm-builder | aarch64 | `/nix/store/1r17xr8dal2frr85qwrndspfkjajmzm0-nixos-system-arm-builder-sd-card-26.05.20260511.c6e5ca3` | ❌ | Healthy (no exporter) |
| remote-builder | x86_64 | `/nix/store/3w1wa1f9ljnmzz9mvgf7svdf3hi43nbv-nixos-system-remote-builder-25.11.20260514.d7a713c` | ✅ | Healthy |

## Undeployed Systems

### Active (in `nixosConfigurations`)

| Machine | Arch | Build Mode | Notes |
|---------|------|------------|-------|
| **cortex-alpha** | x86_64 | local | Core router — deploy with caution |
| **LINDA** | x86_64 | **remote** | Builds on remote builder, LLM-CORE disabled |
| **gaming-host-1** | x86_64 | local | Minecraft server |
| **local-nas** | x86_64 | local | Storage server, GC forced off |
| **terminal-zero** | x86_64 | local | Laptop |
| **display-2** | aarch64 | local | ARM display |
| **print-controller** | aarch64 | local | Klipper (RPi3), smartd disabled |
| **beta-one** | armv7l | local | Legacy ARM |
| **arm-bootstrap** | aarch64 | local | Generic ARM bootstrap image |
| **bargman-greeter-vm** | x86_64 | local | VM — not a physical deploy target |

### Dormant (excluded from deployment)

| Machine | Arch | Notes |
|---------|------|-------|
| alpha-two | x86_64 | Preserved config, not active |
| display-0 | aarch64 | Preserved config, not active |
| storage-array | x86_64 | Preserved config, not active |

## Verification Method

All deployments verified via **derivation outpath** from `nixos_system_info.system_path` exposed by `nixos-deployment-exporter` on port 3111.

arm-builder verified via `/run/current-system` readlink (exporter not running).

## Changes in This Deployment

- Topology rectification: `real-topology/` → `topology/` + `goldens/`
- Golden validation: `check-network` now uses `dump-config` (serialize-config.nix)
- No golden files were modified
- `programs.ssh.matchBlocks` reverted (does not exist in nixpkgs 25.11)
