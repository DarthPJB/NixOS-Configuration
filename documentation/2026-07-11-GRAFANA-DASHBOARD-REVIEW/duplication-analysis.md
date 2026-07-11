# Grafana Dashboard Duplication & Coverage Analysis

**Date:** 2026-07-11
**Analyst:** Agent (Research Only - No Modifications)
**Dashboards Reviewed:** 9

---

## Executive Summary

The 9 Grafana dashboards contain significant duplication, naming inconsistencies, hard-coded machine references, and substantial missing coverage. Most critically, hundreds of available Prometheus metrics are not visualized in any dashboard, while several panels duplicate the same data with different query functions.

---

## 1. DASHBOARD INVENTORY

| Dashboard | Title | UID | Tags |
|-----------|-------|-----|------|
| fleet-cpu-disk.json | Fleet CPU & Disk Monitor | `fleet-cpu-disk` | cpu, disk, fleet |
| disk-health.json | Disk Health (SMART) | `disk-health` | smart, disk, health |
| disk-usage.json | Disk-usage | `e5efb550-495f-46cb-8193-9be2759685a4` | _(none)_ |
| failstate-overview.json | Failstate-Overview | `joctmbb` | _(none)_ |
| fleet-deployment.json | Fleet Deployment Status | `fleet-deployment` | fleet, deployment |
| network-wireguard.json | Network | `network-wireguard` | network |
| service-health.json | Service Health | `service-health` | systemd, services |
| storage-io.json | Storage I/O | `storage-io` | storage, io, disk |
| zfs-health.json | ZFS Pool Health | `zfs-health` | zfs, storage |

---

## 2. EXACT METRIC DUPLICATION

### 2.1 ZFS Dataset Reads

**Metric:** `node_zfs_zpool_dataset_reads`

Appears in **4 panels across 3 dashboards** with different query functions:

| Dashboard | Panel | Query Function |
|-----------|-------|----------------|
| fleet-cpu-disk.json | "Disk RW Access" (ID 7) | `idelta(node_zfs_zpool_dataset_reads[$__interval])` |
| disk-usage.json | "ZFS" (ID 1) | `idelta(node_zfs_zpool_dataset_reads{instance="10.88.127.88:9100"}[5m])` (DUPLICATE QUERY) |
| storage-io.json | _(not used)_ | _(referenced in analysis only)_ |
| zfs-health.json | "Dataset Read/Write Ops" (ID 3) | `rate(node_zfs_zpool_dataset_reads[5m])` |

**Issue:** The `disk-usage.json` panel has **identical queries in both targets A and B** - lines 377 and 393 both use `idelta(node_zfs_zpool_dataset_reads{instance="10.88.127.88:9100"}[5m])`.

### 2.2 Disk Read/Write Bytes

**Metrics:** `node_disk_read_bytes_total`, `node_disk_written_bytes_total`

| Dashboard | Panel | Visualization |
|-----------|-------|---------------|
| failstate-overview.json | "Disk Read" heatmap (ID 2) | `idelta(node_disk_read_bytes_total[5m]) > 0` |
| failstate-overview.json | "Disk Read" heatmap (ID 3) | `idelta(node_disk_written_bytes_total[5m]) > 0` **← MISLABELED** |
| fleet-cpu-disk.json | "Disk RW Access" (ID 7) | `idelta(node_disk_read_bytes_total[$__interval])` |
| storage-io.json | "Disk Read/Write Bandwidth" (ID 1) | `rate(node_disk_read_bytes_total[5m])` |

### 2.3 Failed Systemd Services

**Metric:** `node_systemd_unit_state{state="failed"}`

| Dashboard | Panel | Notes |
|-----------|-------|-------|
| service-health.json | "Failed Units" (ID 2) | Full fleet view |
| failstate-overview.json | "Failed State Services" (ID 1) | Has hardcoded filter excluding `acme-finished-johnbargman.net.target` |

---

## 3. INCORRECT/MISLABELED PANELS

### 3.1 failstate-overview.json - Panel ID 3

**Title:** "Disk Read"
**Actual Content:** `idelta(node_disk_written_bytes_total[5m])` (writes, not reads)

**Recommendation:** Rename to "Disk Write" or fix the query.

### 3.2 disk-usage.json - Panel ID 1

**Title:** "ZFS"
**Problem:** Both targets A and B use the **identical query**:
```nix
idelta(node_zfs_zpool_dataset_reads{instance="10.88.127.88:9100"}[5m])
```

This panel appears to be non-functional or copy-paste error.

---

## 4. HARD-CODED MACHINE REFERENCES

These dashboards contain hardcoded IP addresses that create maintenance burden:

### fleet-cpu-disk.json
- `10.88.127.88:9100` (LINDA) - appears 7+ times
- `10.88.127.1:9100` (cortex-alpha) - appears 4+ times
- `10.88.127.20:9100` (terminal-zero) - appears 2 times
- `10.88.127.21:9100` (terminal NX-01) - appears 2 times
- `10.88.127.3:9100` (data-storage) - appears 2 times
- `10.88.127.50:9100` (remote-worker) - appears 1 time
- `10.88.127.51:9100` (remote-builder) - appears 1 time
- `10.88.127.41:9100` (Display-1) - appears 1 time
- `10.88.127.42:9100` (Display-2) - appears 1 time
- `10.88.127.30:9100` - appears 1 time (unclear machine name)

### disk-usage.json
- `10.88.127.88:9100` (LINDA) - used for memory panels

### failstate-overview.json
- Multiple IP-to-name mappings in renameByRegex transformations

---

## 5. NAMING & STRUCTURAL INCONSISTENCIES

### 5.1 UIDs
| Dashboard | UID | Status |
|-----------|-----|--------|
| fleet-cpu-disk | `fleet-cpu-disk` | ✅ Human-readable |
| disk-health | `disk-health` | ✅ Human-readable |
| fleet-deployment | `fleet-deployment` | ✅ Human-readable |
| network-wireguard | `network-wireguard` | ✅ Human-readable |
| service-health | `service-health` | ✅ Human-readable |
| storage-io | `storage-io` | ✅ Human-readable |
| zfs-health | `zfs-health` | ✅ Human-readable |
| failstate-overview | `joctmbb` | ❌ Random UUID |
| disk-usage | `e5efb550-495f-46cb-8193-9be2759685a4` | ❌ Random UUID |

### 5.2 Tags
| Dashboard | Tags | Notes |
|-----------|------|-------|
| fleet-cpu-disk | cpu, disk, fleet | ✅ |
| disk-health | smart, disk, health | ✅ |
| fleet-deployment | fleet, deployment | ✅ |
| network-wireguard | network | ✅ |
| service-health | systemd, services | ✅ |
| storage-io | storage, io, disk | ⚠️ Redundant "disk" |
| zfs-health | zfs, storage | ⚠️ "storage" overlaps |
| failstate-overview | _(none)_ | ❌ Missing tags |
| disk-usage | _(none)_ | ❌ Missing tags |

### 5.3 Schema Versions
| Dashboard | Schema Version |
|-----------|----------------|
| fleet-cpu-disk | 42 |
| disk-health | 42 |
| disk-usage | 41 |
| failstate-overview | 42 |
| fleet-deployment | 42 |
| network-wireguard | 42 |
| service-health | 42 |
| storage-io | 42 |
| zfs-health | 42 |

`disk-usage.json` is on schema version 41, others on 42.

---

## 6. MISSING COVERAGE - METRICS NOT IN ANY DASHBOARD

### 6.1 NVIDIA GPU Metrics (80+ available, 1 used)

**Dashboard Coverage:** Only `nvidia_smi_power_draw_watts` in fleet-cpu-disk.json

**Available but NOT used:**
```
nvidia_smi_utilization_gpu_ratio      # GPU utilization - ONLY used in disk-usage.json
nvidia_smi_utilization_memory_ratio   # VRAM utilization
nvidia_smi_temperature_gpu            # GPU temperature
nvidia_smi_clocks_current_graphics_clock_hz
nvidia_smi_clocks_current_memory_clock_hz
nvidia_smi_clocks_current_sm_clock_hz
nvidia_smi_memory_total_bytes
nvidia_smi_memory_used_bytes
nvidia_smi_memory_free_bytes
nvidia_smi_power_limit_watts
nvidia_smi_enforced_power_limit_watts
nvidia_smi_fan_speed_ratio
nvidia_smi_pstate
nvidia_smi_display_active
nvidia_smi_pcie_link_gen_current
nvidia_smi_pcie_link_width_current
```

### 6.2 ZFS/ARC Metrics (200+ available, 5 used)

**Dashboard Coverage:** Only pool-level metrics in zfs-health.json

**Available but NOT used:**

**Pool metrics:**
```
zfs_pool_health                     # Pool health status (not "state")
zfs_pool_allocated_bytes
zfs_pool_freeing_bytes
zfs_pool_leaked_bytes
zfs_pool_readonly
```

**ARC metrics (all 100+ node_zfs_arc_* metrics):**
```
node_zfs_arc_size                   # Current ARC size
node_zfs_arc_hits                    # ARC hits
node_zfs_arc_misses                  # ARC misses
node_zfs_arc_l2_size                 # L2 ARC size
node_zfs_arc_l2_hits                 # L2 ARC hits
node_zfs_arc_l2_misses               # L2 ARC misses
node_zfs_arc_memory_all_bytes
node_zfs_arc_memory_available_bytes
node_zfs_arc_compressed_size
node_zfs_arc_uncompressed_size
node_zfs_arc_metadata_size
```

**Dataset metrics:**
```
zfs_dataset_used_bytes
zfs_dataset_logical_used_bytes
zfs_dataset_quota_bytes
zfs_dataset_referenced_bytes
zfs_dataset_available_bytes
zfs_dataset_written_bytes
```

### 6.3 Memory Metrics (50+ available, 2 used)

**Dashboard Coverage:** Only `node_memory_MemTotal_bytes` and `node_memory_Active_bytes` for LINDA in disk-usage.json

**Available but NOT used:**
```
node_memory_MemFree_bytes
node_memory_MemAvailable_bytes
node_memory_Cached_bytes
node_memory_Buffers_bytes
node_memory_Inactive_bytes
node_memory_Active_anon_bytes
node_memory_Active_file_bytes
node_memory_AnonPages_bytes
node_memory_Shmem_bytes
node_memory_Slab_bytes
node_memory_SReclaimable_bytes
node_memory_SUnreclaim_bytes
node_memory_KernelStack_bytes
node_memory_VmallocUsed_bytes
node_memory_PageTables_bytes
node_memory_Dirty_bytes
node_memory_Writeback_bytes
node_memory_SwapTotal_bytes
node_memory_SwapFree_bytes
node_memory_SwapCached_bytes
node_load1
node_load5
node_load15
```

### 6.4 SMART/NVMe Metrics (20+ available, 8 used)

**Dashboard Coverage:** 8 attributes in disk-health.json

**Available but NOT used:**
```
smartctl_device_critical_warning      # NVMe critical warning
smartctl_device_available_spare       # NVMe spare capacity
smartctl_device_available_spare_threshold
smartctl_device_percentage_used       # NVMe TBW percentage
smartctl_device_media_errors          # Media errors
smartctl_device_num_err_log_entries   # Error log entries
smartctl_device_bytes_read            # Bytes read (lifetime)
smartctl_device_bytes_written         # Bytes written (lifetime)
smartctl_device_error_log_count
smartctl_device_power_cycle_count
smartctl_device_rotation_rate          # HDD rotation rate
```

### 6.5 System Metrics (50+ available, limited use)

**Available but NOT used:**
```
node_cpu_seconds_total               # CPU time by mode (user, system, idle, etc.)
node_load1, node_load5, node_load15  # System load - NO DASHBOARD
node_procs_running
node_procs_blocked
node_entropy_available_bits
node_forks_total
node_context_switches_total
node_intr_total
node_vmstat_pgfault
node_vmstat_pgmajfault
node_boot_time_seconds
node_time_seconds
```

### 6.6 Network Metrics (50+ available, 4 used)

**Dashboard Coverage:** Basic network stats in network-wireguard.json

**Available but NOT used:**
```
node_network_speed_bytes             # Interface speed
node_network_advertised_speed_bytes
node_network_supported_speed_bytes
node_network_mtu_bytes
node_network_carrier_changes_total
node_network_carrier_up_changes_total
node_network_carrier_down_changes_total
node_udp_queues                       # UDP queue depths
node_netstat_Tcp_CurrEstab            # Established TCP connections
node_netstat_TcpExt_TCPRetransSegs    # TCP retransmissions
node_netstat_TcpExt_SyncookiesRecv
node_netstat_TcpExt_SyncookiesSent
node_netstat_TcpExt_TCPTimeouts
node_nf_conntrack_entries             # Conntrack entries
node_nf_conntrack_entries_limit
```

---

## 7. DEAD PANELS

### 7.1 disk-usage.json - "ZFS" Panel (ID 1)

Both targets A and B execute the identical query:
```promql
idelta(node_zfs_zpool_dataset_reads{instance="10.88.127.88:9100"}[5m])
```

This appears to be a copy-paste error. Panel likely shows no useful data.

### 7.2 Hardcoded Instance References to Potentially Non-Existent Machines

The following IPs are hardcoded but may not exist in the fleet:

| IP | Referenced In |
|----|---------------|
| 10.88.127.30:9100 | fleet-cpu-disk.json (CPU - ARM systems) |
| 10.88.127.41:9100 | fleet-cpu-disk.json (Display-1) |
| 10.88.127.42:9100 | fleet-cpu-disk.json (Display-2) |

---

## 8. CONSOLIDATION RECOMMENDATIONS

### 8.1 Consolidate ZFS Metrics

**Current:** ZFS I/O metrics scattered across:
- `fleet-cpu-disk.json` (Disk RW Access - ZFS reads)
- `zfs-health.json` (Dataset Read/Write Ops)
- `disk-usage.json` (ZFS panel - broken)

**Recommendation:** Remove ZFS I/O from fleet-cpu-disk and disk-usage. Keep all ZFS pool/dataset I/O in zfs-health.json.

### 8.2 Consolidate Systemd Service Monitoring

**Current:** Failed services in both:
- `service-health.json` (Failed Units panel)
- `failstate-overview.json` (Failed State Services panel with hardcoded exclusion filter)

**Recommendation:** Keep failed service monitoring in service-health.json. Remove or make the exclusion filter configurable in failstate-overview.json.

### 8.3 Create Dedicated Memory Dashboard

**Current:** Memory monitoring only in disk-usage.json for single machine (LINDA)

**Recommendation:** Create fleet-wide memory dashboard using:
- `node_memory_MemAvailable_bytes` / `node_memory_MemTotal_bytes`
- `node_load1`, `node_load5`, `node_load15`
- `node_vmstat_pgfault`, `node_vmstat_pgmajfault`

### 8.4 Create GPU Dashboard

**Current:** NVIDIA GPU only has power monitoring

**Recommendation:** Create GPU dashboard with:
- `nvidia_smi_utilization_gpu_ratio`
- `nvidia_smi_utilization_memory_ratio`
- `nvidia_smi_temperature_gpu`
- `nvidia_smi_clocks_current_graphics_clock_hz`
- `nvidia_smi_clocks_current_memory_clock_hz`

### 8.5 Create ARC Dashboard

**Current:** No ARC monitoring

**Recommendation:** Create ZFS ARC dashboard with:
- `node_zfs_arc_size` / `node_zfs_arc_c_max` (ARC usage %)
- `node_zfs_arc_hits`, `node_zfs_arc_misses` (hit ratio)
- `node_zfs_arc_l2_size`, `node_zfs_arc_l2_hits`, `node_zfs_arc_l2_misses`

---

## 9. METRIC NAMESPACE INCONSISTENCY

### ZFS Metric Prefix Mismatch

| Metric Pattern | Used In | Notes |
|----------------|---------|-------|
| `node_zfs_*` | fleet-cpu-disk, storage-io, zfs-health | Node exporter ZFS metrics |
| `zfs_pool_*` | zfs-health | ZFS exporter metrics (different source) |
| `zfs_dataset_*` | zfs-health | ZFS exporter metrics (different source) |

**Issue:** zfs-health.json mixes two metric sources:
- Node exporter: `node_zfs_zpool_dataset_reads`
- ZFS exporter: `zfs_pool_size_bytes`, `zfs_pool_free_bytes`

This indicates different exporters and potential data inconsistency.

---

## 10. FILES REQUIRING ATTENTION

| Priority | File | Issue |
|----------|------|-------|
| CRITICAL | disk-usage.json | Duplicate ZFS queries (broken panel) |
| CRITICAL | disk-usage.json | Mislabeled - shows GPU, Memory, ZFS but named "Disk-usage" |
| HIGH | failstate-overview.json | Panel ID 3 mislabeled "Disk Read" but shows writes |
| HIGH | fleet-cpu-disk.json | 20+ hardcoded IP addresses |
| HIGH | disk-usage.json | Hardcoded LINDA-only memory monitoring |
| MEDIUM | All dashboards | No template variables for machine selection |
| MEDIUM | zfs-health.json | Mixed ZFS exporter and node_exporter metrics |
| LOW | failstate-overview.json | Missing tags |
| LOW | disk-usage.json | Missing tags, schema v41 vs v42 |

---

## APPENDIX A: PROMETHEUS METRICS SUMMARY

| Category | Available | Dashboard Coverage | % Used |
|----------|-----------|-------------------|--------|
| node_exporter | 400+ | ~50 metrics | ~12% |
| nvidia_smi | 80+ | 2 metrics | ~2.5% |
| ZFS (pool/dataset) | 30+ | 8 metrics | ~27% |
| ZFS ARC | 200+ | 0 metrics | 0% |
| SMART | 20+ | 8 metrics | ~40% |
| nixos_* | 10 | 8 metrics | ~80% |

---

## APPENDIX B: DASHBOARD SCOPE MATRIX

| Scope | fleet-cpu-disk | disk-health | disk-usage | failstate-overview | fleet-deployment | network-wireguard | service-health | storage-io | zfs-health |
|-------|---------------|-------------|------------|-------------------|-----------------|------------------|----------------|------------|------------|
| CPU | ✓ | | | | | | | | |
| Disk I/O | ✓ | | | ✓ | | | | ✓ | |
| Disk Health | | ✓ | | | | | | | |
| Disk Usage | | | ✓ | | | | | ✓ | |
| ZFS Pool | | | | | | | | | ✓ |
| ZFS ARC | | | | | | | | | |
| Network | ✓ | | | | | ✓ | | | |
| Services | | | | ✓ | | | ✓ | | |
| Deployment | | | | | ✓ | | | | |
| GPU | | | ✓ | | | | | | |
| Memory | | | ✓ | | | | | | |
| Energy | ✓ | | | | | | | | |

---

_Report generated for research purposes. No files were modified._
