# CI Evaluation Optimization Research — 2026-07-22

> **Date:** 2026-07-22 10:15 UTC
> **Author:** Agent (mimo-v2.5-pro)
> **Scope:** Nix evaluation optimization, hyperhyper metrics exposure, CI job consolidation trade-offs

---

## 1. Nix Evaluation Optimization Options

### Current Configuration (remote-builder)

| Setting | Value | Source |
|---|---|---|
| `eval-cores` | 0 (all cores) | determinate-nixd default |
| `eval-cache` | true | determinate-nixd default |
| `eval-profiler` | disabled | determinate-nixd default |
| `eval-attrset-update-layer-rhs-threshold` | 16 | determinate-nixd default |
| `cores` | 0 (all cores) | `machines/remote-builder/default.nix` |
| `max-jobs` | 0 (dispatch to remote) | `machines/remote-builder/default.nix` |
| Nix version | Determinate Nix 3.21.7 (nix 2.34.8) | `determinate-nixd --version` |
| Stack limit | 64M | `determinate-flake/modules/nixos.nix` |

### What's Already Optimized

1. **`eval-cores = 0`** — The determinate nix fork supports parallel evaluation. Already set to use all available cores (8 on remote-builder).

2. **`eval-cache = true`** — Nix caches evaluation results between runs. However, the GitHub Actions runner starts fresh each time — no eval cache persistence between jobs.

3. **`LimitSTACK = 64M`** — The determinate nixosModule increases the stack limit for nix-daemon, preventing stack overflow during deep evaluation.

4. **`powerManagement.cpuFreqGovernor = "performance"`** — hyperhyper runs in performance mode.

### Available Tuning Options

#### A. Eval Profiler (Diagnostics)

The determinate nix fork includes a stack sampling profiler:

```bash
# Generate flamegraph profile of evaluation
nix build --option eval-profiler flamegraph \
          --option eval-profile-file /tmp/eval-profile \
          .#nixosConfigurations.remote-builder.config.system.build.toplevel
```

**Use case:** Identify which Nix expressions consume the most eval time. The output is in folded format, compatible with `flamegraph.pl`.

**Recommendation:** Run this on the remote-builder during a CI build to profile the actual evaluation. This will reveal whether the bottleneck is:
- Topology evaluation (`topology/shared.nix`, `topology/default.nix`)
- Module system evaluation (NixOS module merging)
- Flake input resolution
- Attribute set operations

#### B. eval-attrset-update-layer-rhs-threshold

This determinate-specific setting controls the threshold for switching to a faster attribute set update algorithm. The default is `16`.

- **Lower values** (e.g., 8): Switch to the faster algorithm sooner — beneficial when many small attrsets are merged
- **Higher values** (e.g., 32): Use the standard algorithm longer — beneficial when attrsets are large

**Recommendation:** Profile first, then tune. The optimal value depends on the flake's attrset patterns.

#### C. Eval Cache Persistence

The eval cache is stored per-user in `~/.cache/nix/eval-cache-v1`. On the GitHub Actions runner, this is ephemeral — lost between jobs.

**Options:**
1. **Shared eval cache directory:** Mount a persistent volume at the eval cache path
2. **Nix store cache:** Use `--eval-store` to point to a persistent store
3. **Runner-level caching:** GitHub Actions cache for `~/.cache/nix/`

**Impact:** If the eval cache is warm, subsequent evaluations of the same flake (same inputs) should be near-instant. This would reduce the 1m45s eval time to seconds.

#### D. Flake Structure Optimization

The current flake evaluates ALL 19 machines even when building one. This is because:

1. `topology/shared.nix` defines data used by all machines
2. `topology/default.nix` imports all machine topology files
3. The `let` block in `flake.nix` evaluates all `nixosConfigurations`

**Possible approaches:**
1. **Per-machine flake outputs:** Use `flake-utils` or custom logic to only evaluate the requested machine
2. **Lazy topology:** Make topology evaluation lazy — only resolve what the target machine needs
3. **Separate flake for CI:** A CI-specific flake that imports only the machines being built

**Risk:** These approaches add complexity and may break the shared topology pattern.

### Hardware Optimization

| Machine | CPUs | Current Load | Potential |
|---|---|---|---|
| remote-builder | 8 vCPUs | ~20% (1.6 cores) | Already has headroom |
| hyperhyper | 50+ cores | Unknown (no metrics) | Already at `max-jobs=50` |

The remote-builder is not CPU-bound during evaluation. The bottleneck is the Nix evaluator's inherent sequentiality, not available compute.

---

## 2. Hyperhyper Metrics Exposure

### Finding: Metrics NOT Accessible Over WireGuard

**Probe results:**

| Target | IP | Port | Result |
|---|---|---|---|
| hyperhyper (WireGuard) | 100.107.101.14 | 9100 | Connection refused/timeout |
| hyperhyper (internal) | 10.75.79.7 | 9100 | Connection refused/timeout |

### Root Cause

The `_base.nix` in `infrastructure-2` configures exporters to listen on `config.physical.networks.internal.address`:

```nix
# services/prometheus/exporters/_base.nix
services.prometheus.exporters.${n} = mkIf (config ? physical.networks.internal) {
  enable = true;
  listenAddress = config.physical.networks.internal.address;  # 10.75.79.7
  openFirewall = true;
};
```

This is the **physical rack network** (10.75.79.x), not the Tailscale/WireGuard network (100.x). The prometheus server on `acropolis` scrapes it directly because it's on the same rack network.

**Our machines access hyperhyper via WireGuard (100.107.101.14)**, which is a different network interface. The exporter doesn't listen there.

### Options

1. **Upstream fix (recommended):** Add Tailscale IP to exporter listen addresses
   ```nix
   # In _base.nix or hyperhyper-specific override:
   services.prometheus.exporters.node.listenAddress = mkIf (config ? physical.networks.private) 
     config.physical.networks.private.address;  # 100.107.101.14
   ```
   This would make metrics accessible over Tailscale to all machines in the mesh.

2. **SSH tunnel:** Proxy metrics through an SSH tunnel from remote-builder to hyperhyper
   ```bash
   ssh -L 9100:10.75.79.7:9100 build@100.107.101.14
   curl http://localhost:9100/metrics
   ```
   This works but is manual and not suitable for continuous scraping.

3. **Prometheus federation:** Have acropolis federate hyperhyper metrics to our local-nas prometheus
   ```nix
   # On local-nas prometheus:
   scrape_configs = [{
     job_name = "hyperhyper-federation";
     honor_labels = true;
     metrics_path = "/federate";
     params.match = ['{instance="10.75.79.7:9100"}'];
     static_configs = [{ targets = ["prometheus.platonic.systems:8080"]; }];
   }];
   ```
   This requires acropolis prometheus to be accessible over Tailscale.

4. **Separate work item:** Submit upstream issue for Tailscale-exposed metrics.

### Impact

Without hyperhyper metrics, we're blind to:
- CPU/memory usage during x86 builds (the actual compute bottleneck)
- Disk I/O patterns on the ZFS store
- Network throughput for ssh-ng store transfers
- Whether hyperhyper's 50+ cores are saturated or idle

---

## 3. CI Job Consolidation Trade-off

### The Proposal

Consolidate 15 separate `nix build` jobs into fewer jobs (e.g., 3-5 jobs grouping machines by type).

### User's Concern

> "I'm concerned it might hide the clear 'success' 'fail' indicators of separate jobs, which is a far more important factor currently."

### Analysis

| Factor | Separate Jobs (Current) | Consolidated Jobs |
|---|---|---|
| **Per-machine success/fail** | ✅ Clear per-machine status | ❌ Single job status |
| **Evaluation cost** | 15 × 1m45s = **26m** | 3 × 1m45s = **5m15s** |
| **Build isolation** | ✅ One machine's failure doesn't block others | ❌ One failure may block the group |
| **Queue depth** | 15 jobs per run | 3 jobs per run |
| **Runner utilization** | 1 job at a time | 1 job at a time |
| **Debugging** | ✅ Clear which machine failed | ⚠️ Need to check logs |

### Recommendation: Keep Separate Jobs, Optimize Evaluation

The user's priority is correct — per-machine success/fail visibility is more valuable than the 20-minute evaluation savings. Instead, optimize the evaluation itself:

1. **Profile the evaluation** (flamegraph) to find specific bottlenecks
2. **Enable eval cache persistence** between jobs (GitHub Actions cache)
3. **Tune `eval-attrset-update-layer-rhs-threshold`** based on profiling data
4. **Add hyperhyper metrics** to understand the full build pipeline

### Alternative: Hybrid Approach

If evaluation time becomes critical, a middle ground:

```yaml
# Group by evaluation scope, not by machine
jobs:
  eval-and-build-x86:
    strategy:
      matrix:
        group: [alpha, beta, gamma]  # 3 groups of 3-5 machines
    steps:
      - run: nix build .#nixosConfigurations.${{ matrix.group[0] }}... .#nixosConfigurations.${{ matrix.group[4] }}...
```

Each group builds 3-5 machines in one `nix build` command (one evaluation), but groups are separate jobs. This gives:
- 3 evaluations instead of 15 (saves ~20 minutes)
- Clear group-level success/fail
- Per-machine visibility within groups (build log shows each machine)

---

## 4. Recommendations Summary

| Priority | Action | Impact | Effort |
|---|---|---|---|
| **HIGH** | Profile evaluation with `eval-profiler flamegraph` | Identify specific bottlenecks | Low |
| **HIGH** | Add hyperhyper to our prometheus (upstream fix) | Full pipeline visibility | Medium |
| **MEDIUM** | Enable eval cache persistence (GitHub Actions cache) | Potentially instant re-evals | Medium |
| **MEDIUM** | Tune `eval-attrset-update-layer-rhs-threshold` | Marginal eval speedup | Low |
| **LOW** | Consider hybrid job grouping | Save ~20m per run | High |

---

## 5. Appendix: Prometheus Probe Commands

### Probing hyperhyper (attempted, failed)

```bash
# Via WireGuard (from remote-builder)
ssh -p 1108 deploy@10.88.127.51 'curl -s --connect-timeout 3 http://100.107.101.14:9100/metrics | head -5'

# Via internal network (from remote-builder)
ssh -p 1108 deploy@10.88.127.51 'curl -s --connect-timeout 3 http://10.75.79.7:9100/metrics | head -5'
```

Both returned HTTP 000 (connection refused/timeout).

### Checking hyperhyper's exporter config

```bash
# Read the base exporter config
cat /speed-storage/repo/platonic.systems/infrastructure-2/services/prometheus/exporters/_base.nix
```

Exporters listen on `config.physical.networks.internal.address` (10.75.79.7) — not accessible from WireGuard.

### Nix eval profiling (to run when no build is active)

```bash
# On remote-builder, when no CI job is running:
cd /tmp && git clone --depth 1 https://github.com/DarthPJB/NixOS-Configuration
cd NixOS-Configuration
nix build --option eval-profiler flamegraph \
          --option eval-profile-file /tmp/eval-profile \
          --option builders "" \
          .#nixosConfigurations.remote-builder.config.system.build.toplevel
# Output: /tmp/eval-profile (folded format for flamegraph.pl)
```

---

## Related Documents

- `documentation/research/ci-build-bottleneck-analysis.md` — Full bottleneck analysis with prometheus data
- `documentation/research/prometheus-metrics-scraping.md` — Prometheus API reference
- `documentation/remote-builder-analytics.md` — Builder access patterns
- `documentation/ci-queue-analytics.md` — CI queue data and job timings
