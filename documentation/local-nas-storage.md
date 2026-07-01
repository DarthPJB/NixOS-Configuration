# local-nas — Storage Server

**Host:** local-nas (10.88.127.3)
**Role:** Central storage hub, Minio S3, Prometheus, Grafana, PostgreSQL, Gitolite
**OS:** NixOS on Crucial BX500 223.6GB SSD

## Disk Inventory

| Device | Model | Type | Capacity | Interface | Age | Pool | Role |
|--------|-------|------|----------|-----------|-----|------|------|
| sda | WDC WD40EFAX-68JH4N1 | **CMR** (WD Red) | 3.64T | SATA 6Gb/s | 1.6yr (13,991h) | bulk-storage | RAIDZ1 member |
| sdb | ST3000DM001-1ER166 | **CMR** (Seagate Barracuda) | 7.28T | SATA 6Gb/s | 3.3yr (28,930h) | bulk-storage | RAIDZ1 member |
| sdc | ST2000DM008-2FR102 | **SMR** (Seagate BarraCuda) | 1.82T | SATA 6Gb/s | 3.4yr (29,901h) | bulk-storage | RAIDZ1 member |
| sdd | CT240BX500SSD1 | **SSD** (Crucial BX500) | 223.6G | SATA 6Gb/s | — | — | **OS disk** (/, swap, /boot) |
| sde | ST3000DM001-1ER166 | **CMR** (Seagate Barracuda) | 7.28T | SATA 6Gb/s | — | archive | Mirror member |
| sdf | TOSHIBA HDWG480 | **CMR** (Toshiba Enterprise) | 7.28T | SATA 6Gb/s | 1.6yr (14,209h) | bulk-storage | RAIDZ1 member |

## ZFS Pool Configuration

### bulk-storage (Primary Data Pool)

| Property | Value |
|----------|-------|
| Profile | RAIDZ1 (single parity) |
| Capacity | 5.45T total, 4.18T allocated (76%), 1.27T free |
| Fragmentation | 15% |
| Compression | on (default) |
| Recordsize | 128K (default) |
| Dedup | off |
| Sync | standard |
| Autoreplace | off |

**Devices:**
- raidz1-0: sda (3.64T) + sdb (7.28T) + sdc (1.82T) + sdf (7.28T)
- **No SLOG/ZIL device**
- **No L2ARC cache device**

**⚠️ Issues:**
- Mixed disk sizes (1.82T to 7.28T)
- sdc is **SMR** (Shingled Magnetic Recording) — write performance bottleneck
- No dedicated SLOG device
- Single parity (RAIDZ1) — one disk failure = degraded, two = total loss

### archive (Backup/Archive Pool)

| Property | Value |
|----------|-------|
| Profile | Mirror (2-way) |
| Capacity | 2.72T total, 1.41T allocated (51%), 1.31T free |

**Devices:**
- mirror-0: sde (7.28T) + sdb (7.28T) — *Wait, sdb is in both pools? This needs verification.*

## Disk Health (SMART)

| Device | Reallocated | Pending | Offline | Load Cycles | Temp | Status |
|--------|-------------|---------|---------|-------------|------|--------|
| sda | 0 | 0 | 0 | 2,681 | 36°C | ✅ Healthy |
| sdb | 0 | 0 | 0 | 99,459 | 30°C | ✅ Healthy |
| sdc | 0 | 0 | 0 | 122,838 | 47°C | ⚠️ High load cycles, SMR |
| sdf | 0 | 0 | 0 | 3,458 | 46°C | ✅ Healthy |

## Running Services

| Service | Description |
|---------|-------------|
| minio | Minio Object Storage (S3-compatible) |
| nginx | Nginx Web Server |
| grafana | Grafana Service Daemon |
| prometheus | Prometheus Server |
| prometheus-zfs-exporter | ZFS metrics |
| prometheus-postgres-exporter | PostgreSQL metrics |
| prometheus-node-exporter | System metrics |
| postgresql | PostgreSQL Server |
| gitolite | Git hosting |

## Minio Buckets

| Bucket | Size | Source | Mode |
|--------|------|--------|------|
| obsidian-v3 | 806M | LINDA, terminal-zero | bisync (60s) |
| minecraft-backups | 33.6G | gaming-host-1 | copy (daily 06:00) |
| fs-v3-88 | — | LINDA | copy (every 2h) |
| bargman-tech | — | LINDA | copy (every hour) |
| downloads | — | LINDA | copy (daily 05:00) |

## Mount Points

| Mount | Source | Size | Used | Purpose |
|-------|--------|------|------|---------|
| `/` | sdd1 (ext4) | 212G | 20G (10%) | OS root |
| `/boot` | sdd3 (vfat) | 487M | 39M | Boot partition |
| swap | sdd2 | 7.5G | — | Swap |
| `/bulk-storage` | bulk-storage (ZFS) | 1.9T | 1.2T (60%) | Primary data |
| `/archive` | archive (ZFS) | 2.5T | 1.3T (50%) | Archive data |

## Bind Mounts

| Source | Destination |
|--------|-------------|
| `/archive/general` | `/bulk-storage/NAS-ARCHIVE/ARCHIVE` |
| `/archive/astral` | `/bulk-storage/NAS-ARCHIVE/remote.worker/Astralship Master Archive/ARCHIVE` |
| `/archive/personal` | `/bulk-storage/NAS-ARCHIVE/remote.worker/88/88-FS-V2/ARCHIVE` |

## ZFS Automation

| Timer | Frequency | Purpose |
|-------|-----------|---------|
| `zfs-snapshot-frequent.timer` | Every 15min | Frequent snapshots |
| `zfs-snapshot-hourly.timer` | Hourly | Hourly snapshots |
| `zfs-snapshot-daily.timer` | Daily | Daily snapshots |
| `zfs-snapshot-weekly.timer` | Weekly | Weekly snapshots |
| `zfs-snapshot-monthly.timer` | Monthly | Monthly snapshots |
| `zfs-scrub.timer` | Monthly | Data integrity check |
| `zpool-trim.timer` | Weekly | ZFS pool trim |
| `fstrim.timer` | Weekly | Filesystem trim |

All configured via `services.zfs` in NixOS config. Snapshots go back to July 2025.

## SMART Monitoring

Fleet-wide SMART disk monitoring deployed via `modules/smart-monitoring.nix`.

| Component | Purpose | Port |
|-----------|---------|------|
| `services.smartd` | Local disk health alerts (wall messages) | — |
| `services.prometheus.exporters.smartctl` | Prometheus metrics for SMART data | 3102 |

**Prometheus scrape:** `smartctl` job, 60s interval, 14 machines on WireGuard.

**Metrics available:**
- `smartctl_device_smart_status` — Overall health (PASSED/FAILED)
- `smartctl_device_temperature_celsius` — Disk temperature
- `smartctl_device_power_on_seconds` — Power-on hours
- `smartctl_device_reallocated_sector_count` — Reallocated sectors
- `smartctl_device_current_pending_sector_count` — Pending sectors
- `smartctl_device_load_cycle_count` — Load cycles

**Configuration:** Imported fleet-wide via `configuration.nix`.

## Action Plan

### Immediate (After Syncs Complete)
1. Replace sdc (SMR) with CMR drive
2. Install smartmontools for monitoring

### Short-term (This Month)
1. Migrate bulk-storage to RAIDZ2
2. Add SLOG device (new SSD)
3. Match disk sizes in pool
4. Enable autoreplace

### Long-term (This Quarter)
1. Add L2ARC cache device
2. Implement ZFS snapshot automation
3. Monitor pool capacity (alert at 80%)
