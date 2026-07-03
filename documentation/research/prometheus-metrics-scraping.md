# Prometheus Metrics Scraping — Quick Reference

> **Created:** 2026-07-03
> **Last updated:** 2026-07-03
> **Context:** arm-builder (Pi 4 aarch64) monitoring during kernel builds
> **Companion:** `prometheus-mcp-server-comparison.md` — MCP server options for agent access

## Prometheus API Endpoints

Prometheus runs on `local-nas` at `10.88.127.3:8080`.

### Query Current Values (instant)

```bash
# CPU load (1-minute average)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=node_load1{instance="10.88.127.43:9100"}' | jq '.data.result[0].value[1]'

# Memory available (bytes)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=node_memory_MemAvailable_bytes{instance="10.88.127.43:9100"}' | jq '.data.result[0].value[1]'

# Disk space available on /nix (bytes)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=node_filesystem_avail_bytes{instance="10.88.127.43:9100",mountpoint="/nix"}' | jq '.data.result[0].value[1]'

# CPU usage percentage (rate over 5m)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=100 - (avg by(instance)(rate(node_cpu_seconds_total{instance="10.88.127.43:9100",mode="idle"}[5m])) * 100)' | jq '.data.result[0].value[1]'

# Disk write throughput (bytes/sec over 1m)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=rate(node_disk_written_bytes_total{instance="10.88.127.43:9100",device="sda"}[1m])' | jq '.data.result[0].value[1]'

# NVMe utilization (0-1, 1 = saturated)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=rate(node_disk_io_time_seconds_total{instance="10.88.127.43:9100",device="sda"}[1m])' | jq '.data.result[0].value[1]'
```

### Query Range (time series)

```bash
# Load average over last hour, 30s intervals
curl -s 'http://10.88.127.3:8080/api/v1/query_range?query=node_load1{instance="10.88.127.43:9100"}&start=-1h&step=30s' | jq '.data.result[0].values[-5:]'

# Memory available over last hour
curl -s 'http://10.88.127.3:8080/api/v1/query_range?query=node_memory_MemAvailable_bytes{instance="10.88.127.43:9100"}&start=-1h&step=30s' | jq '.data.result[0].values[-5:]'
```

### SMART Metrics (NVMe via USB bridge)

```bash
# Disk temperature (Celsius)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=smartctl_temperature_celsius{instance="10.88.127.43:3107"}' | jq '.data.result[] | {device: .metric.device, temp: .value[1]}'

# SMART health status (1 = passed)
curl -s 'http://10.88.127.3:8080/api/v1/query?query=smartctl_device_smart_status{instance="10.88.127.43:3107"}' | jq '.data.result[] | {device: .metric.device, status: .value[1]}'

# Power-on hours
curl -s 'http://10.88.127.3:8080/api/v1/query?query=smartctl_power_on_hours{instance="10.88.127.43:3107"}' | jq '.data.result[] | {device: .metric.device, hours: .value[1]}'

# All SMART metrics available
curl -s 'http://10.88.127.3:8080/api/v1/query?query={instance="10.88.127.43:3107"}' | jq '.data.result[] | .metric.__name__' | sort
```

### Check Target Health

```bash
# All targets for arm-builder
curl -s 'http://10.88.127.3:8080/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.instance | contains("10.88.127.43")) | "\(.labels.instance) [\(.labels.job)] → \(.health)"'

# All targets (full fleet)
curl -s 'http://10.88.127.3:8080/api/v1/targets' | jq -r '.data.activeTargets[] | "\(.labels.instance) [\(.labels.job)] → \(.health)"'
```

### Systemd Unit Status (via node_exporter)

```bash
# Check if nix-daemon is running
curl -s 'http://10.88.127.43:9100/metrics' | grep 'node_systemd_unit_state{name="nix-daemon.service",state="active"}'

# All active systemd units
curl -s 'http://10.88.127.43:9100/metrics' | grep 'node_systemd_unit_state{state="active"}' | wc -l

# Failed units
curl -s 'http://10.88.127.43:9100/metrics' | grep 'node_systemd_unit_state{state="failed"}'
```

## Port Allocation (Standardised via `environments/metrics.nix`)

| Port | Service | Source |
|------|---------|--------|
| 9100 | node_exporter | `environments/metrics.nix` (all machines) |
| 3107 | smartctl_exporter | `environments/metrics.nix` (all machines) |
| 3111 | nixos-deployment_exporter | `configuration.nix` (fleet machines) |
| 8080 | prometheus | `services/prometheus.nix` (local-nas) |
| 3101 | grafana | `services/prometheus.nix` (local-nas) |

## Key Metrics for Build Monitoring

### During kernel build (`linux-rpi` on arm-builder):

| Metric | Expected | Warning | Critical |
|--------|----------|---------|----------|
| `node_load1` | 3.0–4.0 | > 5.0 | > 7.0 |
| `node_memory_MemAvailable_bytes` | > 500MB | < 300MB | < 100MB |
| `node_filesystem_avail_bytes{mountpoint="/nix"}` | > 100GB | < 50GB | < 10GB |
| `rate(node_disk_written_bytes_total{device="sda"}[1m])` | 10–100 MB/s | sustained > 200 MB/s | N/A |
| `rate(node_disk_io_time_seconds_total{device="sda"}[1m])` | 0.2–0.6 | > 0.9 for 5min | > 0.95 for 10min |
| `smartctl_temperature_celsius` | 40–60°C | > 70°C | > 80°C |

### NVMe disconnect warning signs:
1. NVMe utilization > 0.9 sustained for > 5 minutes → USB disconnect risk
2. Memory available drops below 300MB → swap kicks in, adds I/O to NVMe
3. SMART temperature > 70°C → thermal throttling in enclosure

## MCP Server Access (for Agents)

For programmatic Prometheus access by agents (not curl), see `prometheus-mcp-server-comparison.md`.

**Recommended:** `prometheus/prometheus-mcp` (official, Go) — 30+ tools, single binary,
token-efficient (TOON encoding), embedded Prometheus docs, trivially packaged for NixOS.

**Deployment path:**
1. Package as Nix derivation (`buildGoModule`)
2. Run as systemd service on local-nas alongside Prometheus
3. Expose via WireGuard on stdio or HTTP transport
4. Agents connect to `http://10.88.127.3:<mcp-port>` or use stdio over SSH

**Key MCP tools for build monitoring:**
- `query` — instant PromQL queries (equivalent to curl `/api/v1/query`)
- `range_query` — time series data (equivalent to curl `/api/v1/query_range`)
- `list_targets` — scrape target health
- `series` — discover available metric series
- `label_values` — enumerate label values (e.g., all instances)
- `tsdb_stats` — storage engine statistics

## Architecture

```
arm-builder (10.88.127.43)              local-nas (10.88.127.3)
┌─────────────────────────┐             ┌──────────────────────────┐
│ node_exporter    :9100  │────WG──────→│ prometheus        :8080  │
│ smartctl_exporter :3107 │             │   scrapes every 30s      │
│ smartd (disabled)       │             │ grafana           :3101  │
│ nix-daemon               │             │ [future: MCP server]     │
│ NVMe: /dev/sda → /nix   │             └──────────────────────────┘
└─────────────────────────┘
```

## Verified Baseline (2026-07-03 20:24 UTC, idle)

| Metric | Value |
|--------|-------|
| Load | 0 |
| Memory available | 3.4 GB |
| /nix available | ~194 GB |
| Node exporter | up ✅ |
| Smartctl exporter | up ✅ |

## Notes

- `smartd` is disabled on arm-builder — it can't detect SMART through the USB-NVMe
  bridge. The `smartctl_exporter` handles USB devices directly via `smartctl -d sat`.
- Port 9100 was standardised from the previous 3100 — all machines now use 9100.
- The `environments/metrics.nix` module uses `lib.mkDefault` for all values, so
  individual machines can override ports or collectors if needed.
- The smartctl_exporter on arm-builder reports SMART via USB-SAT bridge — temperature,
  power-on hours, and health status are available even though `smartd` can't detect the
  device.

## Related Documents

- `prometheus-mcp-server-comparison.md` — MCP server options for agent access
- `environments/metrics.nix` — shared exporter module
- `services/prometheus.nix` — prometheus + grafana config (on local-nas)
- `documentation/plans/arm-builder-usb-nvme-reliability-2026-07-03.md`
- `documentation/research/rpi4-usb-nvme-kernel-tuning.md`
- `documentation/research/rpi4-usb-nvme-firmware-research.md`
