# Incident Report: gaming-host-1 Total Failure

**Date:** 2026-06-05
**Machine:** gaming-host-1 (10.88.127.52, public: 65.108.141.32)
**Severity:** Critical — complete loss of boot, all 5 game servers offline
**Status:** ✅ **RESOLVED — system recovered via nixos-install, all game servers running**

## Timeline

| Date | Event |
|---|---|
| 2026-05-28 | WireGuard topology migration deployed (commit `3ef526d`): SSH moved to WireGuard IP only, listenPort changed to 2108 |
| 2026-06-01 15:30 | Config 13 deployed (commit `ade4786`): MC service enabled, system-13-link created; Config 13 uses kernel 6.12.87 vs Config 12's 6.12.69 |
| 2026-06-01 15:30+ | MC service fails immediately: `rsync: command not found` (exit 127); restart storm begins |
| 2026-06-01 18:10 | Network dies: `dhcpcd: dhcp_sendudp: Network is unreachable` on `enp8s0` |
| 2026-06-01 18:14:54 | Last journal entry — MC restart counter at **648**; system crashes (unclean shutdown, no kernel panic captured) |
| 2026-06-01 20:49 | `system` symlink updated → Config 12 (rollback during recovery attempt) |
| 2026-06-05 | gaming-host-1 found unresponsive — no WireGuard, no SSH, only rescue console accessible |
| 2026-06-06 | Rescue recovery: e2fsck, ext2→ext4 conversion, data backup to LINDA, code fixes committed (`c21b4f6`) |
| 2026-06-06 | nixos-installer booted via kexec; root cause identified: `hardware-configuration.nix` had `fsType = "ext2"` |
| 2026-06-06 | `fsType` fixed to `"ext4"` in flake; `nixos-install --flake` completed successfully |
| 2026-06-06 19:43 | System rebooted — NixOS boots on kernel 6.12.87, ext4 root, 0 failed units |
| 2026-06-06 19:49 | All game servers confirmed running: Space Engineers, Dragonwilds, Windrose, TerraTech |

## Root Cause Analysis

### Primary Trigger: `rsync: command not found`

The Minecraft CurseForge module's `ExecStartPre` script called bare `rsync` instead of `${lib.getExe pkgs.rsync}`:

```
/nix/store/...-mc-curseforge-all-the-mons-exec-start-pre: line 8: rsync: command not found
```

Since the service has a minimal PATH (not including `rsync`), this failed immediately with exit code 127 on every attempt.

**Secondary trigger:** The builder (`pkgs/minecraft-curseforge/default.nix`) patched `startserver.sh`/`ServerStart.sh`/`LaunchServer.sh` but never created `start.sh`. The module's `ExecStart` hardcoded `${dataDir}/start.sh` which didn't exist. This would have been the second failure if rsync had succeeded.

### Escalation: Unlimited Restart Storm

```nix
Restart = "on-failure";   # restart on any failure
RestartSec = 15;           # every 15 seconds
# Missing: StartLimitBurst / StartLimitIntervalSec
```

The service restarted **648 times** over ~2.7 hours before the system went down. Each restart cycle ran the failing ExecStartPre and ExecStop scripts.

### Contributing Factor: ext2 Root Filesystem

The root filesystem was **ext2** (no journaling). After the crash, the mandatory fsck on a 462G partition with hundreds of accumulated bitmap/inode errors prevented boot. Directory count mismatches, extended attribute block corruption, and bitmap errors were found across 22+ block groups.

### Critical Finding: `hardware-configuration.nix` fsType Mismatch (discovered 2026-06-06)

The on-disk `hardware-configuration.nix` (and our flake copy at `machines/gaming-host-1/hardware-configuration.nix`) declared:

```nix
fileSystems."/" = {
  device = "/dev/disk/by-uuid/07b3f314-f2ed-456b-8f7a-fe8cf61be5bf";
  fsType = "ext2";    # ← WRONG — filesystem was converted to ext4
};
```

During Phase B recovery, the filesystem was converted ext2 → ext4 via `tune2fs -O has_journal,extents,dir_index,uninit_bg`. The actual partition now reports as `TYPE="ext4"` with journaling enabled. However, `hardware-configuration.nix` still said `ext2`.

When `nixos-install` or `nixos-rebuild` generates the initrd, it uses this fsType to determine which filesystem modules to include. An initrd generated for `ext2` may not include the ext4 journal driver, causing the kernel to fail to mount the root filesystem at boot.

**This is the most likely reason the system does not boot despite the boot chain being structurally intact.**

**Fix applied:** Changed `fsType = "ext2"` to `fsType = "ext4"` in `machines/gaming-host-1/hardware-configuration.nix`.

## Recovery Actions Performed

### Phase A: Diagnostics
- Confirmed rescue console access, disk mounted
- Identified ext2 filesystem corruption (e2fsck dry-run: 1000+ errors)
- Found all game server data intact (Space Engineers 11G, TerraTech 6.7G, Dragonwilds 4.2G, Windrose 4.7G)
- Disk was NOT full (65G used of 455G, 15%)
- MC data directory was empty (only tmpfiles dirs, no world data written)

### Phase B: Filesystem Repair
- Backed up all game data to LINDA (`/bulk-storage/88-FS-V3/gaming-host-1-recovery/`, 27.4G verified byte-for-byte)
- Ran `e2fsck -fy /dev/nvme0n1p1`: fixed all errors (extended attr, block bitmaps, inode bitmaps, directory counts)
- Converted ext2 → ext4: `tune2fs -O has_journal,extents,dir_index,uninit_bg` (adds journaling, prevents future corruption on crash)
- Ran `fstrim`: reclaimed 390 GB of free blocks on NVMe

### Phase C: Code Fixes (committed)
- **Builder** (`pkgs/minecraft-curseforge/default.nix`): creates `start.sh` symlink → discovered script
- **Module** (`server_services/game_servers/minecraft-curseforge.nix`):
  - `rsync` → `${lib.getExe pkgs.rsync}`
  - `ExecStart` → `${lib.getExe pkgs.bash} ${dataDir}/start.sh`
  - Added `StartLimitBurst = 5`, `StartLimitIntervalSec = 600`
  - Added 14-day backup rotation (`find ... -mtime +14 -delete`)
- **Machine config** (`machines/gaming-host-1/default.nix`): set `enable = false` for MC service

### Phase D: Backup Status
All critical game data backed up to LINDA:
| Service | Size | LINDA Path |
|---|---|---|
| Space Engineers `KJTNewWorld` | 10.8G | `/bulk-storage/88-FS-V3/gaming-host-1-recovery/spaceengineers/` |
| TerraTech Worlds | 7.2G | `/bulk-storage/88-FS-V3/gaming-host-1-recovery/terratech-worlds/` |
| Dragonwilds `FoxAndWolf` | 4.4G | `/bulk-storage/88-FS-V3/gaming-host-1-recovery/dragonwilds/` |
| Windrose `Fox and Wolf` | 5.0G | `/bulk-storage/88-FS-V3/gaming-host-1-recovery/windrose/` |

## Current State (2026-06-06)

**✅ SYSTEM RECOVERED — ALL GAME SERVERS RUNNING**

### Recovery Completed

The system was recovered via `nixos-install` from the nixos-installer environment. The root cause (ext2 fsType mismatch) has been resolved.

**Post-recovery verification:**
- NixOS boots on kernel `6.12.87` (fresh build from current nixpkgs) ✓
- Root filesystem mounted as `ext4` with journaling ✓
- 258 units loaded, **0 failed** ✓
- WireGuard SSH accessible on port 1108 ✓
- Disk: 65G used / 367G free (15%) — all game data preserved ✓
- MC service not running (disabled as intended) ✓

### Game Server Status

| Service | Status |
|---|---|
| `docker-se-ds` (Space Engineers) | ✅ Running |
| `docker-windrose` (Windrose) | ✅ Running |
| `dragonwilds-server` | ✅ Running |
| `terratech-worlds-server` | ✅ Running |
| `mc-curseforge-all-the-mons` | ⏸ Disabled (by design) |

### Minor Issue: SSH Socket

`Failed to listen on SSH Socket` (4 times at boot). SSH works on port 1108 via WireGuard — this is a socket activation config conflict, not critical. Investigate separately.

### Recovery Plan: `nixos-install` from nixos-installer ✅ COMPLETED

### Post-Mortem

**Total downtime:** ~5 days (Jun 1 18:14 → Jun 6 19:43)
**Data loss:** None — all game data preserved through recovery
**Root causes (cascading):**
1. Bare `rsync` in ExecStartPre → restart storm (code bug)
2. No `StartLimitBurst` → unlimited restarts (missing systemd hardening)
3. ext2 filesystem → corruption on crash (filesystem choice)
4. `fsType = "ext2"` in hardware config → initrd couldn't mount ext4 root (config mismatch)

**What went well:**
- Game data survived the entire incident (no formatting, no data loss)
- Rescue console access provided diagnosis path
- `nixos-install` recovered the system cleanly
- All game servers came back up with their data intact

**What needs improvement:**
- All executable paths must use `lib.getExe` (now documented in AGENTS.md)
- All systemd services need `StartLimitBurst` / `StartLimitIntervalSec`
- Hardware configs must match actual filesystem state
- Need automated backups (restic/ZFS snapshots)
- Need emergency SSH not dependent on WireGuard

### Long-Term Prevention

| Task | Priority |
|---|---|
| Convert `/bulk-storage` to separate partition/ZFS dataset (use nvme1n1) | High |
| Enable ZFS auto-snapshot or restic backup on gaming-host-1 | High |
| Add Prometheus disk usage alerting | Medium |
| Add emergency SSH not dependent on WireGuard | Medium |
| Document backup/restore procedures | Medium |

## Related Commits

- `3ef526d` — WireGuard topology migration
- `ade4786` — Minecraft All-the-Mons wired into gaming-host-1
- `f91c2d9` — Formatting pass
- `c21b4f6` — fix(minecraft): use lib.getExe, add restart limits, builder creates start.sh (this incident)
- *(pending)* — fix(hardware): ext2 → ext4 fsType in hardware-configuration.nix (this incident)
