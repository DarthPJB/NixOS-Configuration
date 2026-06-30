# Incident Report: local-nas ZFS Saturation During Concurrent Backups

**Date:** 2026-06-30
**Duration:** ~30 minutes (initial sync)
**Severity:** Medium — performance degradation, no data loss
**Status:** Resolved (backups will stagger on future runs)

## Summary

Three concurrent rclone backup services from LINDA saturated the `bulk-storage` ZFS pool on local-nas, causing 42-54% I/O wait and 197ms write latency on the weakest disk.

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 21:17:35 | bargman-tech and downloads services started |
| 21:19:37 | 88-FS-V3 service started |
| 21:20:15 | I/O wait peaked at 54%, sdc at 105% utilization |
| 21:21:21 | local-nas load average: 8.19 (4 CPUs) |
| ~22:00 | Services completed (estimated) |

## Root Cause

### ZFS Pool Configuration

**Pool:** `bulk-storage`
**Profile:** RAIDZ1 (single parity)
**Capacity:** 5.45T total, 4.18T allocated (76%), 1.27T free
**Fragmentation:** 15%

| Device | Model | Size | Type | Serial |
|--------|-------|------|------|--------|
| wwn-0x5000c500c648e7c0 | ST2000DM008-2FR102 | 1.82T | HDD (7200rpm) | ZFL2F52C |
| wwn-0x5000039bb8d15cff | ST3000DM001-1ER166 | 7.28T | HDD (7200rpm) | Z500EQ7W |
| ata-WDC_WD40EFAX-68JH4N1 | WDC WD40EFAX-68JH4N1 | 3.64T | HDD (5400rpm) | WD-WX12D80D0S3N |

**Critical issue:** Mixed disk sizes in RAIDZ1. The smallest disk (sdc, 1.82T Seagate Barracuda) becomes the write bottleneck because RAIDZ1 writes parity across all disks.

### Write Load During Incident

| Metric | Value |
|--------|-------|
| Total write bandwidth | 116 MB/s |
| Total write operations | 1015 ops/s |
| Per-disk write ops | 299-357 ops/s |
| Per-disk write bandwidth | 38.5-38.8 MB/s |

### Disk Performance During Incident

| Device | Model | Write Await | Utilization | Status |
|--------|-------|-------------|-------------|--------|
| **sdc** | **ST2000DM008-2FR102** | **196.97ms** | **105%** | 🔴 **Saturated** |
| sda | WDC WD40EFAX | 9.51ms | 9.7% | ✅ Normal |
| sdf | TOSHIBA HDWG480 | 15.06ms | 14.5% | ✅ Normal |

**sdc (Seagate Barracuda 2TB)** is the bottleneck:
- Consumer-grade drive, not designed for sustained writes
- Smallest disk in the pool (1.82T vs 3.64T and 7.28T)
- RAIDZ1 parity writes amplify the load on this disk

### ZFS Properties

| Property | Value | Notes |
|----------|-------|-------|
| compression | on | Default |
| recordsize | 128K | Default |
| sync | standard | Default |
| dedup | off | Default |
| atime | on | Default |
| logbias | latency | Default |

## Contributing Factors

1. **Concurrent writes:** Three rclone services (30MB/s each = 90MB/s total) hit the pool simultaneously
2. **Mixed disk sizes:** RAIDZ1 with 1.82T, 3.64T, 7.28T — smallest disk is the bottleneck
3. **Consumer drive:** Seagate Barracuda (ST2000DM008) not rated for sustained enterprise writes
4. **Pool capacity:** 76% full — ZFS performance degrades above 80% (approaching threshold)
5. **No SLOG/ZIL:** No dedicated write log device

## Recommendations

### Immediate
1. **Stagger backups** — already implemented (different schedules)
2. **Reduce concurrent load** — initial syncs should be sequential

### Short-term
1. **Replace sdc** — upgrade 1.82T Seagate Barracuda with matching capacity (3.64T+ WDC or Toshiba)
2. **Add SLOG device** — dedicated SSD for write log (reduces latency)
3. **Monitor pool capacity** — alert at 80% (currently 76%)

### Long-term
1. **Migrate to RAIDZ2** — better parity, more resilient
2. **Match disk sizes** — all disks should be same capacity
3. **Consider SSD tier** — for hot data (Minio buckets)

## Metrics Collected

### ZFS Pool Stats (during incident)
```
bulk-storage    4.18T  1.27T    0  1015    0  116M
  raidz1-0      4.18T  1.27T    0  1014    0  116M
    sdc             -      -    0   299    0  38.8M
    sdb             -      -    0   357    0  38.7M
    sda             -      -    0   356    0  38.7M
```

### iostat (during incident)
```
Device    r/s   rkB/s  w/s    wkB/s  aqu-sz  %util
sdc       0.00  0.00   59.00  28224  12.64   105.00
sda       0.00  0.00   53.00  10904  0.58    9.70
sdf       0.00  0.00   53.00  10904  0.94    14.50
```

### local-nas System Stats
```
Load average: 8.19, 4.10, 1.84
CPU: 6.43% user, 16.97% system, 54.24% iowait, 22.37% idle
Memory: 28.2GB used, 471MB free, 4GB buff/cache
```

## Lessons Learned

1. **RAIDZ1 with mixed sizes is a performance trap** — smallest disk becomes the bottleneck
2. **Concurrent writes amplify the problem** — 3× write load on an already stressed pool
3. **Consumer drives in NAS roles need monitoring** — Seagate Barracuda not rated for this workload
4. **ZFS I/O stats are invaluable** — `zpool iostat -v` immediately identified the bottleneck disk
