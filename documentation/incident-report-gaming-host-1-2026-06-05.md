# Incident Report: gaming-host-1 Total Failure

**Date:** 2026-06-05
**Machine:** gaming-host-1 (10.88.127.52, public: 65.108.141.32)
**Severity:** Critical — complete loss of boot, all 5 game servers offline
**Status:** ⚠️ **UNRESOLVED — system does not boot, investigation continues**

## Timeline

| Date | Event |
|---|---|
| 2026-05-28 | WireGuard topology migration deployed (commit `3ef526d`): SSH moved to WireGuard IP only, listenPort changed to 2108 |
| 2026-06-01 17:30 | Minecraft CurseForge All-the-Mons enabled with 8G heap (commit `ade4786`); Config 13 generated but system profile never switched |
| 2026-06-01 17:30 | NixOS activation partially ran: MC user created, tmpfiles created MC dirs, but system profile remained on Config 12 |
| 2026-06-01 20:12-20:14 | Game servers still running (Space Engineers LastSession.sbl, Dragonwilds SaveGames timestamps); MC service restarting every 15s |
| 2026-06-01 20:14 | Last journal entry captured — `rsync: command not found` in ExecStartPre, restart counter at **648** |
| 2026-06-01 20:14+ | Unclean shutdown (cause unknown — possible kernel panic or force-reboot) |
| 2026-06-05 | gaming-host-1 found unresponsive — no WireGuard, no SSH, only rescue console accessible |

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

**⚠️ SYSTEM DOES NOT BOOT — INVESTIGATION CONTINUES**

The boot chain on disk has been fully verified as intact:
- GRUB stage1 in MBR of nvme0n1 ✓
- Partition boot flag set ✓
- Kernel (bzImage) present ✓
- Initrd present ✓
- System profile link valid (Config 12, March 15) ✓
- All UUIDs match ✓
- Filesystem is clean ext4 ✓

**The machine boots into rescue instead of NixOS because the Hetzner console is configured to "Boot rescue system" rather than "Boot from hard drive."**

### Next Steps for Resolution

1. **Hetzner Console:** Switch from "Rescue System" boot to **"Boot from hard drive"**
2. **Reboot** and verify NixOS boots (monitor ping on 65.108.141.32, SSH on 10.88.127.52:1108)
3. **Post-boot:** let machine stabilize on Config 12 (pre-Minecraft, pre-WG-topology-migration)
4. **Future:** deploy from flake when fix (`c21b4f6`) is verified; MC service disabled by default

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
