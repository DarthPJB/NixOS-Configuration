# Grafana Dashboard Review — 2026-07-11

> **Reviewer:** mimo-v2.5-pro (via OpenCode MCP Prometheus tools)
> **Scope:** All 7 provisioned Grafana dashboards vs live Prometheus metrics
> **Prometheus instance:** `10.88.127.3:8080` (local-nas)
> **Grafana instance:** `10.88.127.3:3101` (local-nas)

---

## Executive Summary

**5 of 7 dashboards have significant issues** that cause panels to show "No data" or incorrect information. The root causes are:

1. **Port mismatch**: `noob.json` references port `3100` for node_exporter, but the fleet standardised on port `9100` (via `environments/metrics.nix`)
2. **Non-existent metrics**: `disk-health.json` uses SMART metric names that don't exist in the smartctl exporter
3. **Missing exporter**: `network-wireguard.json` relies on WireGuard-specific metrics from an exporter that isn't deployed
4. **Irrelevant services**: `service-health.json` monitors Docker, Minio, and PostgreSQL which aren't part of this NixOS fleet
5. **Stale hostnames/IPs**: `noob.json` has IP-to-hostname transformations that are incomplete or outdated

---

## Dashboard-by-Dashboard Analysis

### 1. `noob.json` — "CPU-Monitor-disk" ⚠️ CRITICAL

**UID:** `jof8tnw`
**Issues:** 3 critical, 1 moderate

| Issue | Severity | Detail |
|-------|----------|--------|
| Port 3100 → 9100 | CRITICAL | All `node_cpu_scaling_frequency_hertz`, `node_ethtool_*`, `node_disk_*`, `node_zfs_zpool_*`, `node_hwmon_power_watt`, `node_systemd_*` queries reference `:3100` but node_exporter runs on `:9100` |
| Incomplete hostname mappings | MODERATE | Transformations only map 9 IPs; fleet has 14+ active machines. Missing: `10.88.127.51` (remote-builder), `10.88.127.52` (gaming-host-1), `10.88.127.43` (arm-builder), `10.88.127.108` (alpha-one), `10.88.127.107` (alpha-three), `10.88.127.30` (print-controller) |
| `node_power_supply_energy_watthour` | LOW | May not be available on all machines (only laptops/desktops with UPS) |
| `node_ethtool_*` metrics | OK | Available — `ethtool` collector is enabled in `environments/metrics.nix` |

**Affected panels:**
- "System Statuses" (id=15) — `node_systemd_system_running` at `:3100`
- "Data Throughput" (id=11) — `node_ethtool_*` at `:3100`
- "Energy Usage" (id=12) — `node_hwmon_power_watt` at `:3100`
- "CPU - Remote Systems" (id=8) — `node_cpu_seconds_total` at `:3100`
- "CPU - ARM systems" (id=16) — `node_cpu_scaling_frequency_hertz` at `:3100`
- "CPU - LINDA" (id=4) — `node_cpu_scaling_frequency_hertz` at `:3100`
- "CPU - Local Systems" (id=6) — `node_cpu_scaling_frequency_hertz` at `:3100`
- "CPU - cortex-alpha" (id=3) — `node_cpu_scaling_frequency_hertz` at `:3100`
- "CPU - Terminal-Zero" (id=2) — `node_cpu_scaling_frequency_hertz` at `:3100`
- "CPU - terminal-nx-01" (id=5) — `node_cpu_scaling_frequency_hertz` at `:3100`
- "CPU - Data-storage" (id=1) — `node_cpu_scaling_frequency_hertz` at `:3100`
- "Disk RW Access" (id=7) — `node_zfs_zpool_dataset_reads`, `node_disk_*` at `:3100`

**Fix:** Replace all `:3100` with `:9100` in instance label references. Update hostname transformations.

---

### 2. `disk-health.json` — "Disk Health (SMART)" ⚠️ CRITICAL

**UID:** `disk-health`
**Issues:** 5 critical

| Issue | Severity | Detail |
|-------|----------|--------|
| `smartctl_device_reallocated_sector_count` | CRITICAL | Does not exist. Actual metric: `smartctl_device_attribute{attribute_name="Reallocated_Sector_Ct", attribute_value_type="raw"}` |
| `smartctl_device_current_pending_sector_count` | CRITICAL | Does not exist. Actual metric: `smartctl_device_attribute{attribute_name="Current_Pending_Sector_Ct", attribute_value_type="raw"}` |
| `smartctl_device_offline_uncorrectable_sector_count` | CRITICAL | Does not exist. Actual metric: `smartctl_device_attribute{attribute_name="Offline_Uncorrectable", attribute_value_type="raw"}` |
| `smartctl_device_load_cycle_count` | CRITICAL | Does not exist. Actual metric: `smartctl_device_attribute{attribute_name="Load_Cycle_Count", attribute_value_type="raw"}` |
| `smartctl_device_start_stop_count` | CRITICAL | Does not exist. Actual metric: `smartctl_device_attribute{attribute_name="Start_Stop_Count", attribute_value_type="raw"}` |

**Verified working panels:**
- "SMART Health Status" (id=1) — `smartctl_device_smart_status` ✅
- "Disk Temperature" (id=2) — `smartctl_device_temperature` ✅ (note: has `temperature_type="current"` label)
- "Power-On Hours" (id=6) — `smartctl_device_power_on_seconds / 3600` ✅

**Fix:** Replace all `smartctl_device_*_count` metrics with `smartctl_device_attribute{attribute_name="...", attribute_value_type="raw"}` queries.

---

### 3. `network-wireguard.json` — "Network & WireGuard" ⚠️ CRITICAL

**UID:** `network-wireguard`
**Issues:** 2 critical

| Issue | Severity | Detail |
|-------|----------|--------|
| WireGuard metrics missing | CRITICAL | `wireguard_device_info`, `wireguard_device_received_bytes_total`, `wireguard_device_transmitted_bytes_total`, `wireguard_device_received_packets_total`, `wireguard_device_transmitted_packets_total`, `wireguard_device_handshakes_total` — NONE exist in Prometheus. No WireGuard exporter is deployed. |
| `node_network_up` for wireg0 | LOW | `node_network_up{device="wireg0"}` returns `0` even when WireGuard is functioning — the `up` metric reflects carrier state, not tunnel state |

**Verified working panels:**
- "Physical Interface Bandwidth" (id=5) — `node_network_receive_bytes_total`, `node_network_transmit_bytes_total` ✅
- "Interface Status" (id=6) — `node_network_up` ✅ (but wireg0 always shows DOWN due to carrier semantics)

**Fix:** Remove WireGuard-specific panels (ids 1-4) since no WireGuard exporter is deployed. Keep physical network panels (ids 5-6). Consider deploying `prometheus-wireguard-exporter` if WireGuard metrics are desired.

---

### 4. `service-health.json` — "Service Health" ⚠️ MODERATE

**UID:** `service-health`
**Issues:** 2 moderate

| Issue | Severity | Detail |
|-------|----------|--------|
| Docker panel | MODERATE | Monitors `docker.service` and `containerd.service` — this is a NixOS fleet that explicitly rejects Docker (Prime Directive 13). Panel will always show "NOT RUNNING". |
| Minio panel | MODERATE | Monitors `minio.service` — no Minio service is configured in this fleet. |
| PostgreSQL panel | LOW | Monitors `postgresql.service` — only relevant on machines running PostgreSQL (e.g., local-nas). Not fleet-wide. |

**Verified working panels:**
- "Active Services" (id=1) — `node_systemd_unit_state{name=~".*service.*", state="active"}` ✅
- "Failed Units" (id=2) — `node_systemd_unit_state{state="failed"}` ✅
- "SSH" (id=3) — `sshd.service` ✅
- "Web Server" (id=4) — `nginx.service|httpd.service` ✅
- "Prometheus" (id=8) — `prometheus.service` ✅
- "Rclone Backup Status" (id=9) — `rclone-sync-*` ✅

**Fix:** Remove Docker and Minio panels. Consider adding panels for services actually used in this fleet: `nix-daemon.service`, `wireguard-wireg0.service`, `smartd.service`, `kmscon.service`.

---

### 5. `zfs-health.json` — "ZFS Pool Health" ✅ MOSTLY OK

**UID:** `zfs-health`
**Issues:** 1 minor

| Issue | Severity | Detail |
|-------|----------|--------|
| `node_zfs_zpool_state` filter | LOW | Panel queries `node_zfs_zpool_state{state="online"}` — this works but only shows pools in ONLINE state. Consider showing all states for completeness. |

**Verified working metrics:**
- `zfs_pool_free_bytes` ✅
- `zfs_pool_size_bytes` ✅
- `zfs_pool_fragmentation_ratio` ✅
- `zfs_pool_allocated_bytes` ✅
- `zfs_pool_deduplication_ratio` ✅
- `node_zfs_zpool_dataset_reads` ✅
- `node_zfs_zpool_dataset_nread` ✅
- `node_zfs_zpool_dataset_writes` ✅
- `node_zfs_zpool_dataset_nwritten` ✅
- `node_zfs_zpool_state` ✅

**Status:** No changes required. Dashboard is functional.

---

### 6. `storage-io.json` — "Storage I/O" ✅ OK

**UID:** `storage-io`
**Issues:** None

**All metrics verified:**
- `node_disk_read_bytes_total` ✅
- `node_disk_written_bytes_total` ✅
- `node_disk_reads_completed_total` ✅
- `node_disk_writes_completed_total` ✅
- `node_disk_read_time_seconds_total` ✅
- `node_disk_write_time_seconds_total` ✅
- `node_disk_io_time_weighted_seconds_total` ✅
- `node_disk_io_time_seconds_total` ✅
- `node_filesystem_avail_bytes` ✅
- `node_filesystem_size_bytes` ✅

**Status:** No changes required. Dashboard is functional.

---

### 7. `fleet-deployment.json` — "Fleet Deployment Status" ✅ OK

**UID:** `fleet-deployment`
**Issues:** None (dashboard queries are correct; some targets are down due to offline machines)

**All metrics verified:**
- `nixos_generation_match` ✅
- `nixos_version_info` ✅
- `nixos_flake_info` ✅
- `nixos_generation_number` ✅
- `nixos_uptime_seconds` ✅
- `nixos_activation_timestamp_seconds` ✅
- `nixos_kernel_version_info` ✅

**Status:** No changes required. Dashboard is functional. Some targets are down because those machines are offline (display-0, display-2, alpha-two, etc.) — this is expected behaviour.

---

## Target Health Summary (from live Prometheus)

### Node Exporter (job: `node`, port 9100)
| Instance | Status |
|----------|--------|
| 10.88.127.1 (cortex-alpha) | ❌ DOWN |
| 10.88.127.3 (local-nas) | ✅ UP |
| 10.88.127.20 (terminal-zero) | ❌ DOWN |
| 10.88.127.21 (terminal-nx-01) | ❌ DOWN |
| 10.88.127.30 (print-controller) | ❌ DOWN |
| 10.88.127.41 (display-1) | ❌ DOWN |
| 10.88.127.42 (display-2) | ❌ DOWN |
| 10.88.127.43 (arm-builder) | ✅ UP |
| 10.88.127.50 (remote-worker) | ❌ DOWN |
| 10.88.127.51 (remote-builder) | ❌ DOWN |
| 10.88.127.52 (gaming-host-1) | ✅ UP |
| 10.88.127.88 (LINDA) | ✅ UP |
| 10.88.127.107 (alpha-three) | ❌ DOWN |
| 10.88.127.108 (alpha-one) | ❌ DOWN |

### SMART Exporter (job: `smartctl`, port 3107)
| Instance | Status |
|----------|--------|
| 10.88.127.1 (cortex-alpha) | ✅ UP |
| 10.88.127.3 (local-nas) | ❌ DOWN |
| 10.88.127.20 (terminal-zero) | ✅ UP |
| 10.88.127.21 (terminal-nx-01) | ✅ UP |
| 10.88.127.30 (print-controller) | ❌ DOWN |
| 10.88.127.41 (display-1) | ❌ DOWN |
| 10.88.127.42 (display-2) | ❌ DOWN |
| 10.88.127.43 (arm-builder) | ✅ UP |
| 10.88.127.50 (remote-worker) | ❌ DOWN (connection refused) |
| 10.88.127.51 (remote-builder) | ❌ DOWN (connection refused) |
| 10.88.127.52 (gaming-host-1) | ✅ UP |
| 10.88.127.88 (LINDA) | ✅ UP |
| 10.88.127.107 (alpha-three) | ❌ DOWN |
| 10.88.127.108 (alpha-one) | ❌ DOWN |

### ZFS Exporter (job: `zfs`, port 3102/9134)
| Instance | Status |
|----------|--------|
| 10.88.127.1 (cortex-alpha) | ✅ UP |
| 10.88.127.3 (local-nas) | ✅ UP |
| 10.88.127.51 (remote-builder) | ❌ DOWN |
| 10.88.127.88 (LINDA) | ✅ UP |

### NVIDIA Exporter (job: `nvidia`, port 3103)
| Instance | Status |
|----------|--------|
| 10.88.127.21 (terminal-nx-01) | ✅ UP |
| 10.88.127.88 (LINDA) | ✅ UP |
| 10.88.127.107 (alpha-three) | ❌ DOWN |
| 10.88.127.108 (alpha-one) | ✅ UP |

### Deployment Exporter (job: `nixos-deployment`, port 3111)
| Instance | Status |
|----------|--------|
| 10.88.127.1 (cortex-alpha) | ✅ UP |
| 10.88.127.3 (local-nas) | ✅ UP |
| 10.88.127.20 (terminal-zero) | ✅ UP |
| 10.88.127.21 (terminal-nx-01) | ✅ UP |
| 10.88.127.50 (remote-worker) | ✅ UP |
| 10.88.127.52 (gaming-host-1) | ✅ UP |
| 10.88.127.88 (LINDA) | ✅ UP |
| 10.88.127.108 (alpha-one) | ✅ UP |
| Others | ❌ DOWN |

---

## Port Allocation Reference

| Port | Service | Source |
|------|---------|--------|
| 9100 | node_exporter | `environments/metrics.nix` (all machines) |
| 3102 | zfs_exporter | Per-machine config |
| 3103 | nvidia_exporter | Per-machine config (GPU machines) |
| 3104 | klipper_exporter | `server_services/klipper.nix` (print-controller) |
| 3105 | nginx_exporter | Per-machine config (remote-worker) |
| 3106 | nextcloud_exporter | Per-machine config (remote-worker) |
| 3107 | smartctl_exporter | `environments/metrics.nix` (all machines) |
| 3110 | postgres_exporter | Per-machine config (local-nas) |
| 3111 | nixos-deployment_exporter | `configuration.nix` (all machines) |
| 8080 | prometheus | `services/prometheus.nix` (local-nas) |
| 3101 | grafana | `services/prometheus.nix` (local-nas) |

---

## Recommended Fixes (Priority Order)

### P0 — Fix immediately (dashboards completely broken)

1. **`noob.json`**: Replace all `:3100` with `:9100` in instance label references
2. **`disk-health.json`**: Replace `smartctl_device_*_count` metrics with `smartctl_device_attribute{attribute_name="...", attribute_value_type="raw"}` queries
3. **`network-wireguard.json`**: Remove WireGuard exporter panels (ids 1-4), keep physical network panels

### P1 — Fix soon (dashboards show misleading data)

4. **`service-health.json`**: Remove Docker and Minio panels
5. **`noob.json`**: Update hostname transformations to include all active fleet machines

### P2 — Nice to have

6. **`service-health.json`**: Add panels for actual fleet services (nix-daemon, wireguard, smartd)
7. **`network-wireguard.json`**: Consider deploying `prometheus-wireguard-exporter` if WG metrics are desired
8. **`zfs-health.json`**: Show all pool states, not just ONLINE

---

## Files

- Dashboard directory: `services/graphana_dashboards/`
- Prometheus config: `services/prometheus.nix`
- Metrics environment: `environments/metrics.nix`
- SMART monitoring: `modules/smart-monitoring.nix`
- Deployment exporter: `modules/nixos-deployment-exporter.nix`
- Topology: `topology.nix`
