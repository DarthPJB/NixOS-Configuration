# CI Build Metrics

**Repository:** DarthPJB/NixOS-Configuration
**Runner:** remote-builder (10.88.127.51) — 8 vCPU Intel Xeon Skylake, 15GB RAM, 295GB disk
**Runner Instances:** hate-filled-1, hate-filled-2 (self-hosted, NixOS)
**First Pipeline:** 2026-04-15 (run #1)
**Data Collected:** 2026-08-03

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total Pipelines | 255 |
| Successful | 25 |
| Failed | 203 |
| Cancelled | 21 |
| In Progress | 2 |
| Queued | 2 |
| Success Rate | 9.8% |
| Date Range | 2026-04-15 → 2026-08-03 (111 days) |

---

## Timeline

### Phase 1: Initial CI Setup (2026-04-15 → 2026-04-22)
- Runs #1–#5: Early pushes to `jb/ai/overlord-8` and `main`
- All failures — CI configuration not yet functional
- Duration: seconds to minutes (fast failures)

### Phase 2: Overlord-I Development (2026-06-23 → 2026-07-05)
- Runs #29–#77: Active development on `jb/overlord-I` branch
- Mix of failures and first successes
- **First success:** Run #77 (2026-07-05, push to main, 8m 29s)
- Runner registration issues discovered (nixpkgs module bug)

### Phase 3: Overlord-II Topology Work (2026-07-11 → 2026-08-03)
- Runs #78–#255: Massive topology overhaul on `overlord-II` and `overlord-ii-planar-topology`
- High failure rate due to active development
- Eval cache persistence fix deployed 2026-07-22
- **25 successful runs** in this phase

---

## Successful Run Details

### Run #255 (2026-08-03, PR `overlord-ii-planar-topology`)
**Total Duration:** 2h 54m 39s
| Job | Runner | Duration |
|-----|--------|----------|
| Validation & Linting | hate-filled-1 | 8m 7s |
| Security Scan | GitHub Actions | 56s |
| Build ARM cross (beta-one) | hate-filled-1 | 1m 42s |
| Build ARM cross (arm-builder) | hate-filled-1 | 1m 48s |
| Build ARM native (display-1) | hate-filled-2 | 2m 36s |
| Build ARM native (display-2) | hate-filled-1 | 2m 26s |
| Build ARM native (print-controller) | hate-filled-1 | 2m 7s |
| Build x86 (cortex-alpha) | hate-filled-1 | 16m 15s |
| Build x86 (terminal-nx-01) | hate-filled-2 | 28m 34s |
| Build x86 (terminal-zero) | hate-filled-2 | 23m 4s |
| Build x86 (alpha-three) | hate-filled-2 | 29m 35s |
| Build x86 (alpha-one) | hate-filled-2 | 40m 5s |
| Build x86 (gaming-host-1) | hate-filled-1 | 30m 31s |
| Build x86 (local-nas) | hate-filled-1 | 25m 54s |
| Build x86 (remote-worker) | hate-filled-1 | 29m 39s |
| Build x86 (LINDA) | hate-filled-2 | 42m 15s |
| Build x86 (remote-builder) | hate-filled-1 | 38m 39s |

### Run #254 (2026-08-02, PR `overlord-ii-planar-topology`)
**Total Duration:** 2h 40m 16s
| Job | Runner | Duration |
|-----|--------|----------|
| Validation & Linting | hate-filled-2 | 7m 29s |
| Security Scan | GitHub Actions | 50s |
| Build ARM cross (arm-builder) | hate-filled-1 | 1m 47s |
| Build ARM cross (beta-one) | hate-filled-2 | 1m 32s |
| Build ARM native (display-1) | hate-filled-2 | 2m 16s |
| Build ARM native (display-2) | hate-filled-1 | 2m 25s |
| Build ARM native (print-controller) | hate-filled-2 | 2m 4s |
| Build x86 (terminal-zero) | hate-filled-2 | 35m 52s |
| Build x86 (remote-builder) | hate-filled-2 | 12m 27s |
| Build x86 (cortex-alpha) | hate-filled-2 | 11m 3s |
| Build x86 (gaming-host-1) | hate-filled-2 | 35m 1s |
| Build x86 (alpha-three) | hate-filled-1 | 24m 51s |
| Build x86 (alpha-one) | hate-filled-1 | 40m 35s |
| Build x86 (local-nas) | hate-filled-1 | 19m 58s |
| Build x86 (remote-worker) | hate-filled-1 | 28m 17s |
| Build x86 (LINDA) | hate-filled-2 | 43m 51s |
| Build x86 (terminal-nx-01) | hate-filled-1 | 34m 38s |

### Run #253 (2026-08-01, PR `overlord-ii-planar-topology`)
**Total Duration:** 4h 35m 53s
| Job | Runner | Duration |
|-----|--------|----------|
| Validation & Linting | hate-filled-1 | 7m 1s |
| Security Scan | GitHub Actions | 53s |
| Build ARM cross (beta-one) | hate-filled-1 | 1m 26s |
| Build ARM cross (arm-builder) | hate-filled-2 | 1m 39s |
| Build ARM native (display-1) | hate-filled-2 | 2m 27s |
| Build ARM native (display-2) | hate-filled-1 | 2m 15s |
| Build ARM native (print-controller) | hate-filled-2 | 1m 58s |
| Build x86 (cortex-alpha) | hate-filled-2 | 15m 47s |
| Build x86 (local-nas) | hate-filled-2 | 21m 3s |
| Build x86 (alpha-three) | hate-filled-1 | 31m 6s |
| Build x86 (alpha-one) | hate-filled-1 | 33m 44s |
| Build x86 (terminal-nx-01) | hate-filled-2 | 30m 32s |
| Build x86 (remote-builder) | hate-filled-2 | 32m 29s |
| Build x86 (LINDA) | hate-filled-1 | 58m 50s |
| Build x86 (gaming-host-1) | hate-filled-1 | 12m 18s |
| Build x86 (terminal-zero) | hate-filled-2 | 26m 5s |
| Build x86 (remote-worker) | hate-filled-1 | 32m 11s |

---

## Per-Machine Build Time Averages (Post-Eval-Cache Fix, Runs #247–#255)

### x86_64 Machines

| Machine | Min | Max | Avg | Notes |
|---------|-----|-----|-----|-------|
| cortex-alpha | 10m 50s | 27m 44s | ~16m | Router config, moderate complexity |
| local-nas | 14m 3s | 43m 45s | ~22m | Storage services |
| terminal-nx-01 | 12m 27s | 34m 38s | ~25m | Terminal config |
| terminal-zero | 15m 12s | 35m 52s | ~27m | Terminal config |
| alpha-one | 25m 2s | 58m 35s | ~38m | Full desktop environment |
| alpha-three | 11m 17s | 31m 6s | ~22m | Test machine |
| LINDA | 12m 18s | 58m 50s | ~35m | Threadripper, complex config |
| gaming-host-1 | 12m 31s | 35m 1s | ~25m | Gaming services |
| remote-worker | 12m 27s | 32m 17s | ~25m | Web services |
| remote-builder | 7m 59s | 38m 39s | ~20m | Hub machine, minimal local config |

### ARM Machines

| Machine | Architecture | Min | Max | Avg |
|---------|-------------|-----|-----|-----|
| beta-one | armv7l (cross) | 46s | 1m 54s | ~1m 20s |
| arm-builder | aarch64 (cross) | 1m 26s | 1m 55s | ~1m 45s |
| display-1 | aarch64 (native) | 2m 16s | 2m 42s | ~2m 30s |
| display-2 | aarch64 (native) | 2m 15s | 2m 42s | ~2m 30s |
| print-controller | aarch64 (native) | 1m 58s | 2m 18s | ~2m 10s |

---

## Key Events Timeline

| Date | Event | Impact |
|------|-------|--------|
| 2026-04-15 | First CI pipeline (#1) | All runs failing |
| 2026-06-23 | Runner online, active development begins | Runs #29+ |
| 2026-07-05 | First successful run (#77) | 8m 29s, push to main |
| 2026-07-09 | Runner registration destroyed by reboot | LINDA down, investigation begins |
| 2026-07-10 | Registration hack deployed (ExecStartPre override) | Runner restored |
| 2026-07-11–07-13 | First batch of successful PR runs (#78–#85) | 9m–52m per run |
| 2026-07-14–07-21 | Massive failure storm (overlord-II topology work) | 80+ consecutive failures |
| 2026-07-22 | Eval cache persistence fix deployed | Backlog drained in 1 hour |
| 2026-07-22–08-03 | Stable successful runs (#247–#255) | 2h 40m – 4h 36m per run |

---

## Eval Cache Impact (2026-07-22 Fix)

### Before Fix
- Every job: 1m 45s evaluation (cold cache)
- 15 jobs per run × 1m 45s = ~26 minutes wasted per run
- Queue backlog: 20 runs, ~15+ hours to clear

### After Fix
- Warm-cache evaluation: <5s
- Queue drained: 9 runs in first hour
- Per-machine build times reduced by ~1m 40s each

### Cache Growth
| Time (UTC) | Cache Size |
|------------|------------|
| 11:31 | 0 (fresh) |
| 11:38 | 2 databases |
| 12:00 | 14 MB |
| 13:00 | 34 MB |

---

## Build Time Distribution (Successful Runs)

### Total Run Duration (all jobs)

| Percentile | Duration |
|------------|----------|
| Fastest | 8m 29s (run #77, early/simple) |
| P25 | ~1h 30m |
| P50 (Median) | ~2h 45m |
| P75 | ~3h 30m |
| P95 | ~4h 36m |
| Slowest | ~5h 15m (cold cache, complex changes) |

---

## Runner Infrastructure

### Hardware
- **Machine:** remote-builder (VPS)
- **CPU:** 8 vCPU Intel Xeon Skylake
- **RAM:** 15 GB
- **Disk:** 295 GB (NVMe)
- **Network:** WireGuard VPN (10.88.127.0/24)

### Runner Configuration
- **Instances:** 2 (hate-filled-1, hate-filled-2)
- **User:** build (UID 1111)
- **Store:** Shared /nix/store with host
- **Eval Cache:** /nix/cache (persistent, bind-mounted writable)
- **HOME:** /run/github-runner/hate-filled-N (tmpfs, ephemeral)

### Build Distribution
- **x86_64 builds:** Dispatched to hyperhyper (100.107.101.14) via ssh-ng
- **aarch64 builds:** Dispatched to arm-builder (10.88.127.43) via ssh-ng
- **Runner itself:** Never builds locally (max-jobs=0)

---

## Resource Utilization (Prometheus Metrics)

**Source:** Prometheus node_exporter on `10.88.127.51:9100`
**Query Window:** Successful runs since eval-cache fix (2026-07-31 → 2026-08-03)

### Hardware Baseline

| Resource | Total | Available | Notes |
|----------|-------|-----------|-------|
| CPU | 8 vCPU Intel Xeon Skylake | — | Shared with host services |
| RAM | 16.8 GB | ~6.4 GB idle (38%) | Runner + nix-daemon + host |
| Disk (/nix) | 295 GB | ~93 GB free (31%) | Store + eval cache |
| Disk (/) | ~25 GB | ~22 GB free | Root filesystem |
| Network | WireGuard VPN | — | Builds dispatched via ssh-ng |

### CPU Usage During Builds (Run #255, 2026-08-03)

| Phase | CPU Usage | Load (1m) | Notes |
|-------|-----------|-----------|-------|
| Idle (between jobs) | 0.2–0.3% | 0.0 | Minimal host activity |
| Validation & Linting | 36% | 7.43 | Highest single-job CPU spike |
| ARM builds (cross) | 1–2% | 0.1–0.8 | Minimal local work (dispatched) |
| ARM builds (native) | 8–16% | 0.3–1.6 | Evaluation + dispatch overhead |
| x86 builds (warm cache) | 1–16% | 0.1–1.6 | Evaluation only, builds on hyperhyper |
| x86 builds (cold cache) | 24–38% | 2.8–7.9 | Full evaluation + path copying |
| Peak observed | 38.3% | 7.43 | During validation step |

### Memory Usage Pattern (Run #255, 2026-08-03)

| Phase | Memory Used | Available | Notes |
|-------|-------------|-----------|-------|
| Idle baseline | 6.4 GB (38%) | 10.4 GB | Host + nix-daemon |
| Validation start | 15.1 GB (90%) | 1.7 GB | Nix evaluation spike |
| Post-validation | 6.4 GB (38%) | 10.4 GB | Released after eval |
| Build dispatch | 10–12 GB (60–71%) | 4.8–6.8 GB | SSH connections + path copying |
| Peak observed | 15.8 GB (94%) | 1.0 GB | During nix flake check |
| Min available | 1.0 GB | — | Near-OOM during validation |

**Critical finding:** Validation (`nix flake check`) is the most memory-intensive operation, consuming up to 94% of available RAM. Build dispatch is CPU-bound, not memory-bound.

### Disk I/O (Run #255, 2026-08-03)

| Phase | Disk Util (vda) | Notes |
|-------|-----------------|-------|
| Idle | 0.03–0.04% | Minimal |
| Validation | 0.08–0.10% | Eval cache reads/writes |
| Build dispatch | 0.04–0.09% | Path copies to remote builders |
| Peak observed | 0.44% | Brief spike during path copy |

**Finding:** Disk I/O is not a bottleneck. The remote-builder's primary role is coordination, not building.

### Network (Run #255, 2026-08-03)

| Phase | Receive Rate | Notes |
|-------|-------------|-------|
| Idle | 0.003 MB/s | Background traffic |
| Build dispatch | 0.006–0.015 MB/s | SSH-ng path transfers |
| Peak observed | 0.015 MB/s | During x86 build dispatch |

**Finding:** Network is not a bottleneck. Builds are dispatched to remote builders; the runner only coordinates.

### Filesystem Growth

| Date | /nix Available | Change | Notes |
|------|---------------|--------|-------|
| 2026-07-31 00:00 | 99.1 GB | — | Baseline |
| 2026-07-31 12:00 | 94.2 GB | -4.9 GB | Builds accumulating store paths |
| 2026-08-01 00:00 | 93.2 GB | -1.0 GB | Continued growth |
| 2026-08-02 00:00 | 93.1 GB | -0.1 GB | Stable |
| 2026-08-03 18:00 | 92.1 GB | -1.0 GB | Run #255 in progress |

**Rate:** ~0.5–5 GB per successful run (store paths from hyperhyper copied back). At current rate, disk will reach `min-free` (10 GB) threshold in ~20 runs without GC.

### Resource Bottleneck Analysis

| Resource | Utilization | Bottleneck? | Notes |
|----------|-------------|-------------|-------|
| CPU | Peak 38%, avg 5–15% | **No** | Validation is CPU-heavy but brief |
| Memory | Peak 94%, avg 38% | **YES** | Validation near-OOM; 16GB is tight |
| Disk I/O | Peak 0.44% | **No** | Coordination role, not building |
| Network | Peak 0.015 MB/s | **No** | Minimal transfer volume |
| Disk Space | 68% used, growing | **Monitor** | ~20 runs until min-free threshold |

**Primary constraint:** Memory during `nix flake check`. The 8 vCPU / 16 GB VM is CPU-adequate but memory-tight for full flake evaluation. The runner itself is not the bottleneck — it dispatches builds to hyperhyper (100+ cores, 1TB RAM).

### Comparison: Runner vs. Build Machines

| Metric | remote-builder (runner) | hyperhyper (builder) | arm-builder |
|--------|------------------------|---------------------|-------------|
| Role | Coordinator + GitHub runner | x86_64 build execution | aarch64 build execution |
| CPU | 8 vCPU Skylake | 100+ cores | RPi 4 (4 cores) |
| RAM | 16 GB | 1 TB | 4 GB |
| Build role | Evaluation + dispatch | Actual derivation builds | ARM builds |
| Max-jobs | 0 (never builds locally) | 10 | 3 |

---

## Failure Analysis

### Top Failure Categories (estimated from run patterns)

| Category | Approximate % | Period |
|----------|--------------|--------|
| Nix evaluation errors | 40% | Throughout |
| Topology/config syntax errors | 25% | overlord-II work |
| Runner registration loss | 10% | 2026-07-09–07-10 |
| OOM kills | 5% | Early runner config |
| Flaky/network errors | 10% | Throughout |
| Cancelled (superseded) | 10% | Active development |

---

## Raw Data

Full run-level data: `runs-timeline.json`
Job-level data for successful runs: `successful-run-jobs.json`

---

*Last updated: 2026-08-03*
*Sources:*
- *GitHub Actions API (`gh api repos/DarthPJB/NixOS-Configuration/actions/runs`)*
- *Prometheus node_exporter (`10.88.127.51:9100`) — CPU, memory, disk, network metrics*
- *Draft blogs: `personal-website-blog/draft-blogs/2026-07-22-ci-eval-cache-persistence.md`*
