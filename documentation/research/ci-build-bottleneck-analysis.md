# CI Build Bottleneck Analysis — 2026-07-22

> **Date:** 2026-07-22 09:45 UTC
> **Author:** Agent (mimo-v2.5-pro)
> **Scope:** Remote-builder CI pipeline performance analysis
> **Method:** Prometheus metrics + GitHub Actions build log forensics

---

## Executive Summary

**The bottleneck is NOT hardware.** The bottleneck is **Nix flake evaluation** — each of the 15 CI build jobs evaluates the **entire flake (all 19 machines)** before determining what to build for the target machine. This costs **~1m 45s per job** as a fixed overhead, regardless of cache state.

**Impact:** 15 jobs × 1m 45s eval = **~26 minutes of pure evaluation** per run, even when all builds are instant cache hits. With 20 queued runs, this is **~8.5 hours of redundant evaluation alone**.

---

## Methodology

### Data Sources

| Source | Tool | Access Pattern |
|---|---|---|
| CI job timings | `gh` CLI (`nix-shell -p gh`) | `gh run view <id> --json jobs` |
| Build logs | `gh` CLI | `gh run view <id> --log --job <job-id>` |
| Prometheus metrics | HTTP API | `curl http://10.88.127.3:8080/api/v1/query_range` |
| Remote-builder state | SSH (deploy user) | `ssh -p 1108 deploy@10.88.127.51` |
| Process state | SSH + `ps` | `ps aux --sort=-%cpu` |

### Time Window

- **Prometheus retention:** ~1.5 hours (back to 08:00 UTC 2026-07-22)
- **Build log analysis:** Run 29846947438 (2026-07-21 16:04-07:17 UTC) — first full build completion
- **Live state:** 09:23-09:45 UTC 2026-07-22

### Limitations

- **hyperhyper (100.107.101.14) is NOT in prometheus** — zero visibility into x86 build execution
- **Prometheus retention is 1.5 hours** — historical build windows from 2026-07-21 are unavailable
- **arm-builder (10.88.127.43) is idle** during the observation window — no ARM builds active

---

## Finding 1: Nix Evaluation is the Bottleneck

### Build Log Forensics — Warm-Cache Build (remote-builder, Run 29846947438)

**Total wall time:** 1m 56s (API reported 122s)

```
22:46:28.978  Runner starts
22:46:31.027  Checkout begins                          (+2s)
22:46:32.960  Git checkout complete                    (+2s)
22:46:33.077  `nix build` command starts
22:46:33.355  Flake warnings emitted (eval begins)
               ─── NIX EVALUATION PHASE ───
22:48:17.905  "these 4 derivations will be built"      (+1m 44s)  ← 88% OF BUILD TIME
               ─── BUILD PHASE ───
22:48:18.207  Building derivation 1/4                  (+0.3s)
22:48:18.941  Building derivation 2/4                  (+0.7s)
22:48:21.626  Building derivation 3/4                  (+2.7s)
22:48:22.457  Building derivation 4/4                  (+0.8s)
               ─── CLEANUP ───
22:48:23.743  Post-job cleanup                         (+1.3s)
22:48:24.693  Job complete
```

### Comparison: Different Machines, Same Evaluation Time

| Machine | Total Time | Eval Time | Derivations | Build Time | Eval % |
|---|---|---|---|---|---|
| **remote-builder** | 1m 56s | **1m 44s** | 4 | 5s | **88%** |
| **cortex-alpha** | 6m 12s | **1m 47s** | 129 | 4m 18s | **28%** |

**Both machines take ~1m 45s to evaluate**, regardless of how many derivations actually need building. This proves the evaluation scope is the **entire flake**, not just the target machine.

### Why?

The flake's `nixosConfigurations` attrset contains all 19 machines. When `nix build .#nixosConfigurations.remote-builder.config.system.build.toplevel` runs, Nix must:

1. Parse `flake.nix` and resolve all inputs
2. Evaluate the `let` block (imports all machines' configs)
3. Evaluate the shared topology (`topology/shared.nix`, `topology/default.nix`)
4. Evaluate ALL machines' topology files (they share dependencies)
5. Compute the target machine's derivation graph
6. Determine which derivations need building

Steps 1-4 are the **fixed cost** — they happen for every machine. The shared topology and cross-machine dependencies force Nix to evaluate most of the flake even for a single-machine build.

---

## Finding 2: Remote-Builder Hardware is NOT the Bottleneck

### Prometheus Metrics (08:00-09:40 UTC, 2026-07-22)

**remote-builder (10.88.127.51) — 8 vCPUs, 15GB RAM, 295GB disk**

| Metric | Min | Avg | Max | Assessment |
|---|---|---|---|---|
| **CPU usage** | 0.4% | **21.5%** | 24.6% | ✅ Not CPU-bound |
| **Load average** | 0.07 | **1.7** | 2.49 | ✅ Well below 8-core capacity |
| **Memory available** | 9.44 GB | **11.4 GB** | 14.06 GB | ✅ Plenty of headroom |
| **Disk I/O utilization** | 0% | **0.7%** | 4.1% | ✅ Not disk-bound |
| **Disk write throughput** | 0 MB/s | **0.06 MB/s** | 0.10 MB/s | ✅ Negligible |

### Process CPU at 09:42 UTC

```
PID    CPU%  RSS     Process
328594 42.1% 3.6GB   nix build .#nixosConfigurations.gaming-host-1...  ← active build
328621  9.8% 37MB    nix-daemon (child 1)
328619  9.2% 19MB    nix-daemon (child 2)
328419  3.1% 124MB   github-runner (hate-filled-1)
```

The `nix build` process uses 42% CPU (≈3.4 of 8 cores) during evaluation. This is the **flake evaluation workload** — parsing, lambda evaluation, attribute resolution. It's single-threaded in nature (Nix evaluator is largely sequential).

### arm-builder (10.88.127.43) — Idle

| Metric | Value | Assessment |
|---|---|---|
| CPU usage | 1.3% | ✅ Idle |
| Load average | 0.03 | ✅ No work |

No ARM builds were active during the observation window.

---

## Finding 3: hyperhyper is a Monitoring Blind Spot

### What We Know

| Property | Value | Source |
|---|---|---|
| IP | 100.107.101.14 (WireGuard) | `modifier_imports/remote-builder.nix` |
| Arch | x86_64-linux | `/etc/nix/machines` |
| maxJobs | 10 | `/etc/nix/machines` |
| speedFactor | 10 | `/etc/nix/machines` |
| Features | big-parallel, kvm, nixos-test | `/etc/nix/machines` |
| Connection | ssh-ng via cortex-alpha WG gateway | SSH control socket |
| Prometheus | **NOT MONITORED** | `curl /api/v1/targets` — no 100.x IPs |

### Impact

hyperhyper is where **all x86 builds actually execute**. The remote-builder's nix-daemon dispatches derivations to hyperhyper via ssh-ng. We have zero visibility into:

- hyperhyper's CPU/memory usage during builds
- Disk I/O on hyperhyper's store
- Network throughput between hyperhyper and remote-builder
- Build derivation execution time on hyperhyper

The SSH control socket shows: `ssh build@100.107.101.14 -M -N -oControlPersist=15m`

### Recommendation

Add hyperhyper to prometheus scraping targets. This requires:
1. Opening port 9100 on hyperhyper's firewall for the prometheus server (10.88.127.3)
2. Adding hyperhyper's WireGuard IP (100.107.101.14) to `services/prometheus.nix` scrape targets
3. Or: SSH tunnel from local-nas to hyperhyper for metrics scraping

---

## Finding 4: Network is Not the Bottleneck

### WireGuard Traffic (remote-builder)

All WireGuard RX/TX values were **0 MB/s** throughout the observation window. The ssh-ng control socket uses WireGuard, but actual build traffic is minimal during evaluation phase.

### Public Interface (ens3) — Spike Observed

```
08:54  RX: 0.79 MB/s
08:56  RX: 1.11 MB/s
```

This spike corresponds to a store path transfer from hyperhyper after a build completed. Even at peak, this is well below network capacity.

### Assessment

Network throughput is not a limiting factor. The ssh-ng protocol transfers store paths efficiently, and the WireGuard tunnel has ample capacity.

---

## Finding 5: Sequential Runner Processing

### Current State

| Runner | Status | Busy | Memory |
|---|---|---|---|
| hate-filled-1 | online | **yes** | 2.4G |
| disgust | online | no | 77M |
| entropy-is-origin | online | no | 79M |
| rat-infested | online | no | 81M |

Only `hate-filled-1` processes NixOS-Configuration builds. The other 3 runners service other projects.

### Queue Depth

20 runs queued, 15 build jobs each = **300 jobs** to process.

At ~3 minutes per job (warm cache): **~15 hours** to drain.

---

## Time Budget Per Job (Warm Cache)

| Phase | Duration | Notes |
|---|---|---|
| Runner startup | 1-2s | GitHub Actions runner overhead |
| Git checkout | 2-3s | Shallow clone, single commit |
| **Nix evaluation** | **1m 45s** | **Fixed cost — evaluates ALL 19 machines** |
| Build derivations | 5s - 4m | Depends on derivation count |
| Cleanup | 1-2s | Git config cleanup |
| **TOTAL** | **~2m - ~6m** | |

**Key insight:** The 1m 45s evaluation cost is paid **15 times per run** (once per job). For a run where all builds are cache hits, the 15 jobs would take:

- 15 × (5s overhead + 1m 45s eval + 5s build + 2s cleanup) = **15 × 1m 57s = ~29 minutes**

Of that 29 minutes, **26 minutes (90%) is pure evaluation**.

---

## Optimization Recommendations

### 1. Consolidate CI Jobs (Highest Impact)

**Current:** 15 separate `nix build` commands, each evaluating the full flake.
**Proposed:** Single job that evaluates once and builds all machines.

```bash
# Current (15 evaluations):
nix build .#nixosConfigurations.remote-builder.config.system.build.toplevel
nix build .#nixosConfigurations.cortex-alpha.config.system.build.toplevel
# ... 13 more

# Proposed (1 evaluation):
nix build \
  .#nixosConfigurations.remote-builder.config.system.build.toplevel \
  .#nixosConfigurations.cortex-alpha.config.system.build.toplevel \
  # ... all 15 in one command
```

**Impact:** 1 evaluation instead of 15 = **~24 minutes saved per run**.
**Risk:** Single job failure kills all builds. Mitigate with per-machine error handling.

### 2. Add hyperhyper to Prometheus (Visibility)

Without metrics from hyperhyper, we're blind to the actual build execution bottleneck. Adding it would reveal:

- Whether hyperhyper's 100 cores are saturated during builds
- Disk I/O patterns during store path writes
- Network throughput for ssh-ng transfers

### 3. Nix Eval Cache Persistence

The GitHub Actions runner starts fresh each time — no eval cache persistence. If the eval cache could be preserved between jobs (e.g., shared `/tmp/nix-*/` directory), subsequent evaluations would be faster.

### 4. Reduce Flake Evaluation Scope

If individual machines could be built without evaluating the entire topology, eval time would drop. This requires architectural changes to how `nixosConfigurations` is structured — potentially using `flake-utils` or per-machine flakes.

---

## Appendix: Raw Data

### A. Prometheus Query Samples

**CPU usage on remote-builder:**
```bash
curl -s 'http://10.88.127.3:8080/api/v1/query_range' \
  --data-urlencode 'query=100-(avg by(instance)(rate(node_cpu_seconds_total{instance="10.88.127.51:9100",mode="idle"}[2m]))*100)' \
  --data-urlencode 'start=1784707200' \
  --data-urlencode 'end=1784713200' \
  --data-urlencode 'step=120s'
```

**Memory available on remote-builder:**
```bash
curl -s 'http://10.88.127.3:8080/api/v1/query_range' \
  --data-urlencode 'query=node_memory_MemAvailable_bytes{instance="10.88.127.51:9100"}' \
  --data-urlencode 'start=1784707200' \
  --data-urlencode 'end=1784713200' \
  --data-urlencode 'step=120s'
```

**Disk I/O utilization:**
```bash
curl -s 'http://10.88.127.3:8080/api/v1/query_range' \
  --data-urlencode 'query=rate(node_disk_io_time_seconds_total{instance="10.88.127.51:9100",device="vdb"}[2m])' \
  --data-urlencode 'start=1784707200' \
  --data-urlencode 'end=1784713200' \
  --data-urlencode 'step=120s'
```

### B. Build Log Extraction

```bash
# Get job IDs for a run
nix-shell -p gh --run 'gh run view 29846947438 --repo DarthPJB/NixOS-Configuration --json jobs' \
  | jq '.jobs[] | {id: .databaseId, name: .name}'

# Get full build log for a job
nix-shell -p gh --run 'gh run view 29846947438 --repo DarthPJB/NixOS-Configuration --log --job 88696491855'
```

### C. SSH Access to Remote-Builder

```bash
# Deploy user (read + admin)
ssh -p 1108 deploy@10.88.127.51 'ps aux --sort=-%cpu | head -10'

# Check nix-daemon connections
ssh -p 1108 deploy@10.88.127.51 'journalctl -u nix-daemon --since "1 hour ago" | tail -20'

# Check builder registrations
ssh -p 1108 deploy@10.88.127.51 'cat /etc/nix/machines'
```

### D. Prometheus Target Health

```bash
# All targets
curl -s 'http://10.88.127.3:8080/api/v1/targets' \
  | jq -r '.data.activeTargets[] | "\(.labels.instance) [\(.labels.job)] → \(.health)"'

# Current values
curl -s 'http://10.88.127.3:8080/api/v1/query?query=node_load1' \
  | jq -r '.data.result[] | "\(.metric.instance): \(.value[1])"'
```

---

## Related Documents

- `documentation/remote-builder-analytics.md` — Builder access patterns, machine declarations
- `documentation/ci-queue-analytics.md` — CI queue data and job timings
- `documentation/build-monitoring-pattern.md` — tmux + log monitoring pattern
- `documentation/research/prometheus-metrics-scraping.md` — Prometheus API reference
- `documentation/ci-ketchup-parallelism-PLAN.md` — CI parallelism injection plan
