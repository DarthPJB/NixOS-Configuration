# Backup Capacity Survey — 2026-06-14

**Purpose:** Assess available disk space across all systems to plan Phase A backup capabilities.

## Connectivity Summary

| Status | Count | Machines |
|---|---|---|
| ✅ Reachable | 13 | cortex-alpha, local-nas, alpha-one, alpha-three, LINDA, print-controller, terminal-nx-01, display-1, display-2, remote-builder, gaming-host-1, remote-worker, cluster-box |
| ❌ No route to host | 7 | terminal-zero, storage-array, display-0, alpha-two, building-b, office-1, office-2 |
| ⏱️ Connection timed out | 2 | dlyon, grimterm |

---

## Per-Machine Disk Summary

### cortex-alpha (10.88.127.1) — Hub/Router

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/mmcblk0p2 | 29G | 2.3G | 25G | 9% | / |
| /dev/nvme0n1p2 | 183G | 6.9G | 167G | 4% | /nix |
| /dev/nvme0n1p3 | 32G | 373M | 30G | 2% | /home |
| /dev/sda1 (zpool: external) | 3.6T | 3.5T | 54G | 99% | /external |

**ZFS Pools:**
| Pool | Size | Alloc | Free | Cap | Health |
|---|---|---|---|---|---|
| external | 3.62T | 3.46T | 169G | 95% | ONLINE |

**⚠️ `external` pool is 95% full (169G free).** Not suitable as backup target without expansion.

---

### local-nas (10.88.127.3) — NAS / Backup Target Candidate

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/sdd1 | 212G | 20G | 182G | 10% | / |
| bulk-storage | 5.4T | 4.1T | 1.3T | 75% | /bulk-storage |
| archive | 2.7T | 1.4T | 1.3T | 51% | /archive |

**ZFS Pools:**
| Pool | Size | Alloc | Free | Cap | Dedup | Health |
|---|---|---|---|---|---|---|
| bulk-storage | 5.45T | 4.12T | 1.33T | 75% | 1.04x | ONLINE |
| archive | 2.72T | 1.41T | 1.31T | 51% | 1.00x | ONLINE |

**Physical Disks:** sda 3.6T, sdb 2.7T, sdc 1.8T, sdd 224G (OS), sde 2.7T, sdf 7.3T

**✅ Best backup target — 1.33T free on bulk-storage, 1.31T free on archive. ZFS with 1.04x dedup on bulk-storage.**

---

### LINDA (10.88.127.88) — Workstation / Source Machine

| Device/Pool | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| speed-storage | 2.4T | 1.5T | 963G | 61% | /speed-storage |
| speed-storage/nix | 1.1T | 103G | 963G | 10% | /nix |
| speed-storage/var-lib-libvirt | 1.2T | 200G | 963G | 18% | /var/lib/libvirt |
| bulk-storage/88-FS-V3 | 5.4T | 1.1T | 4.4T | 20% | /bulk-storage |
| /dev/nvme4n1p1 | 284G | 166G | 105G | 62% | /home |

**ZFS Pools:**
| Pool | Size | Alloc | Free | Cap | Dedup | Health |
|---|---|---|---|---|---|---|
| speed-storage | 4.53T | 2.73T | 1.81T | 60% | 1.00x | ONLINE |
| bulk-storage | 5.44T | 1004G | 4.46T | 18% | 1.04x | ONLINE |

**Physical Disks:** 4x NVMe (466G–1.8T), 3x SATA (932G–3.6T), 1x zvol VM disk (1.5T)

---

### gaming-host-1 (10.88.127.52) — Game Server / Backup Source

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/nvme0n1p1 | 454G | 89G | 343G | 21% | / |

**No ZFS pools.** Single NVMe root. Second NVMe (nvme1n1, 477G) present but **unmounted** — available for local backups or ZFS.

**Physical Disks:** nvme0n1 477G (OS), nvme1n1 477G (unused)

---

### alpha-one (10.88.127.108) — Desktop

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/sda2 | 212G | 114G | 88G | 57% | / |

No ZFS. Single 224G SATA disk. 88G free.

---

### alpha-three (10.88.127.107) — Desktop

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/sdb1 | 226G | 32G | 183G | 15% | / |

No ZFS. Second disk sda 2.7T **unmounted** — available for use.

---

### terminal-nx-01 (10.88.127.21) — Terminal

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/sda1 | 679G | 227G | 418G | 36% | / |

No ZFS. 418G free.

---

### remote-worker (10.88.127.50) — VM / Web Server

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/disk/by-label/nixos | 40G | 23G | 15G | 62% | / |
| vdb 300G | — | — | — | — | /home/pokej/mnt2 |
| vdc 100G | — | — | — | — | /home/pokej/mnt |

No ZFS. VM with 40G root + 400G additional block storage.

---

### remote-builder (10.88.127.51) — VM / Build Server

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/disk/by-label/nixos | 40G | 12G | 27G | 30% | / |

No ZFS. VM with 40G root only.

---

### display-1 (10.88.127.41) — Raspberry Pi Display

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/mmcblk0p2 | 118G | 11G | 102G | 10% | / |

No ZFS. 119G eMMC. 102G free.

---

### display-2 (10.88.127.42) — Raspberry Pi Display

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/mmcblk0p2 | 58G | 13G | 43G | 23% | / |

No ZFS. 58G eMMC. 43G free.

---

### print-controller (10.88.127.30) — Raspberry Pi

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/mmcblk0p2 | 30G | 5.1G | 23G | 19% | / |

No ZFS. 30G SD card. 23G free.

---

### cluster-box (10.88.127.211) — Mini Server

| Device | Size | Used | Avail | Use% | Mount |
|---|---|---|---|---|---|
| /dev/nvme0n1p3 | 121G | 70G | 45G | 61% | / |
| /dev/nvme0n1p1 | 83G | 79G | 0 | 100% | /speed-storage |

No ZFS. 238G NVMe. **⚠️ /speed-storage is 100% full.**

---

## Aggregate Summary

### Total Storage by Type

| Type | Total Size | Total Used | Total Free |
|---|---|---|---|
| **ZFS Pools** | 21.8T | 12.8T | 9.0T |
| **Block Devices (non-ZFS)** | 3.5T | 1.1T | 2.1T |
| **Grand Total** | 25.3T | 13.9T | 11.1T |

### ZFS Pool Details

| Pool | Machine | Size | Free | Dedup | Best Use |
|---|---|---|---|---|---|
| bulk-storage | local-nas | 5.45T | 1.33T | 1.04x | **Primary backup target** |
| bulk-storage | LINDA | 5.44T | 4.46T | 1.04x | Secondary/replication target |
| archive | local-nas | 2.72T | 1.31T | 1.00x | Archive/cold storage |
| speed-storage | LINDA | 4.53T | 1.81T | 1.00x | Active storage |
| external | cortex-alpha | 3.62T | 169G | 1.00x | **Nearly full — avoid** |

### Machines Needing Attention

| Machine | Issue | Severity |
|---|---|---|
| cluster-box | /speed-storage 100% full | **Critical** |
| cortex-alpha | external pool 95% full | **High** |
| gaming-host-1 | nvme1n1 (477G) unmounted — wasted | Medium |
| alpha-three | sda (2.7T) unmounted — wasted | Medium |

### Backup Target Recommendation

**local-nas `bulk-storage`** is the best candidate for Phase A backups:
- 1.33T free (sufficient for gaming-host-1's 89G + other machines)
- ZFS with dedup (1.04x) — space-efficient for similar data
- Already serves as the network's storage hub
- Has `lib/rclone-target.nix` infrastructure on LINDA for reuse

**Capacity estimate:** Could back up all 13 reachable machines' root partitions (~700G total used) with room to spare.

## Implementation Status

**Phase A backup infrastructure is complete.** The `lib/rclone-target.nix` module has been extended with:
- `mode` — `"bisync"` (default) or `"copy"` (one-way backup)
- `calendar` — systemd `OnCalendar` expression for fixed-time scheduling
- `bwlimit` — bandwidth limiting for rate control
- `preExec` — pre-transfer command (e.g. backup rotation)
- `user` — configurable service user (was hardcoded)

**Example deployment:** `snippets/gaming-host-1-daily-backup.nix`
- Daily backup at 06:00 UTC
- One-way copy to local-nas
- 14-day rotation via `preExec`
- 10 MB/s rate limit
- No systemd ties to minecraft service (independent timer/service units)

**To activate:** Add the snippet's import and config to `machines/gaming-host-1/default.nix`. Requires an rclone remote named `local-nas` in the encrypted config file.

---

## Raw Data

Individual command outputs saved in `documentation/backup-survey/`:
- `<machine>-df.txt` — `df -h` output
- `<machine>-zpool.txt` — `zpool list` output
- `<machine>-lsblk.txt` — `lsblk` output

---

*Survey conducted 2026-06-14 via SSH (port 1108, deploy user) over WireGuard.*
