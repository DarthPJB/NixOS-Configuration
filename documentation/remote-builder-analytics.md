# remote-builder Analytics & Access Guide

> **Created:** 2026-07-19
> **Purpose:** Reference for future analytic processes on the build infrastructure
> **Scope:** remote-builder hub, CI pipeline, build dispatch, optimization targets

## 1. Access Methods

### GitHub CLI (`gh`) — via nix-shell

**Primary method for CI analytics.** Use `nix-shell -p gh` to acquire the tool without installing.

```bash
# List recent runs
nix-shell -p gh --run 'gh run list --repo DarthPJB/NixOS-Configuration --limit 10 --json databaseId,conclusion,status,createdAt,updatedAt,displayTitle,event'

# View specific run jobs with timings
nix-shell -p gh --run 'gh run view <run-id> --repo DarthPJB/NixOS-Configuration --json jobs' | jq '.jobs[] | {name, conclusion, startedAt, completedAt}'

# Check runner status
nix-shell -p gh --run 'gh api repos/DarthPJB/NixOS-Configuration/actions/runners --jq ".runners[] | {name, status, busy, labels: [.labels[].name]}"'

# View run logs (only available after completion)
nix-shell -p gh --run 'gh run view <run-id> --repo DarthPJB/NixOS-Configuration --log' | grep -i "error\|fail"

# Trigger workflow_dispatch
nix-shell -p gh --run 'gh workflow run ci.yml --repo DarthPJB/NixOS-Configuration -f machine=remote-builder -f action=build'
```

### GitHub MCP

Available tools for CI inspection without CLI:
- `github_list_pull_requests` — PR status
- `github_get_pull_request_status` — combined commit status
- `github_list_commits` — recent commits with SHAs
- `github_list_issues` — open issues

**Limitation:** MCP does not expose workflow run details or job timings. Use `gh` CLI for that.

### SSH Access (Three-User Model)

| User | Port | Auth | Purpose | Scope |
|---|---|---|---|---|
| `build` | 22 | SSH key (secrix) | Nix remote builder (`ssh-ng`) | WireGuard `10.88.127.0/24` only |
| `deploy` | 1108 | SSH key | Remote administration, passwordless sudo | WireGuard `10.88.127.0/24` only |
| `inspect` | 1108 | SSH key | Read-only inspection, journal access | WireGuard `10.88.127.0/24` only |
| `John88` | 1108 | SSH key | Interactive access | WireGuard `10.88.127.0/24` only |

**Observation-only per PD20.** SSH is for reading logs, checking status, inspecting state. All fixes go through Nix build pipeline.

```bash
# Check nix-daemon status
ssh deploy@10.88.127.51 -p 1108 'systemctl status nix-daemon'

# Check /etc/nix/machines (builder registrations)
ssh deploy@10.88.127.51 -p 1108 'cat /etc/nix/machines'

# Check nix config
ssh deploy@10.88.127.51 -p 1108 'nix show-config | grep -E "max-jobs|distributed-builds"'

# Check secrix decrypted keys
ssh deploy@10.88.127.51 -p 1108 'ls -la /run/nix-daemon-keys/'

# Check store disk usage
ssh deploy@10.88.127.51 -p 1108 'df -h /nix'

# Check GitHub runner status
ssh deploy@10.88.127.51 -p 1108 'systemctl status github-runner-*'

# Check build dispatch logs
ssh deploy@10.88.127.51 -p 1108 'journalctl -u nix-daemon --since "1 hour ago" | grep -i "build\|dispatch\|error"'

# Read-only inspection (inspect user)
ssh inspect@10.88.127.51 -p 1108 'journalctl -u nix-daemon --since "1 hour ago"'
```

### Nix Apps (Flake)

```bash
# Validate config against golden
nix run .#check-network -- remote-builder

# Dump full config to JSON
nix run .#dump-config -- remote-builder > /tmp/remote-builder-config.json

# Deploy
nix run .#remote-builder -- switch
```

---

## 2. Machine Runtime vs Declaration

### Declaration (Source of Truth)

| File | Purpose |
|---|---|
| `machines/remote-builder/default.nix` | Machine-specific config (imports, WG routing, max-jobs) |
| `machines/remote-builder/hardware-configuration.nix` | Hardware (OpenStack VM, 300GB disk) |
| `modifier_imports/remote-builder.nix` | Builder registrations, `/etc/nix/machines` override |
| `users/build.nix` | Build user (uid 1111, port 22, WireGuard-only) |
| `users/deployment.nix` | Deploy user (uid 1110, port 1108, passwordless sudo) |
| `users/inspect.nix` | Inspect user (uid 1112, port 1108, read-only) |
| `services/github_runners.nix` | 3 runners (disgust, rat-infested, entropy-is-origin) |
| `services/github-runner-nixos-config.nix` | hate-filled runner (NixOS-Configuration CI) |
| `modules/enable-wg-topology.nix` | WireGuard from topology |
| `configuration.nix` | Fleet-wide config (GC, nix settings, kmscon) |

### Runtime State (via SSH)

| Check | Command | Expected |
|---|---|---|
| max-jobs | `nix show-config \| grep max-jobs` | `0` |
| distributed-builds | `nix show-config \| grep distributed` | `true` |
| /etc/nix/machines | `cat /etc/nix/machines` | hyperhyper + arm-builder entries |
| secrix keys | `ls /run/nix-daemon-keys/` | hyperhyper, personal-builder |
| WireGuard | `wg show wireg0` | Peer: cortex-alpha, allowedIPs include 100.107.101.14 |
| Store disk | `df -h /nix` | ~300GB ext4 |
| Runners | `systemctl status github-runner-*` | 4 active |
| nix-daemon | `systemctl status nix-daemon` | active |

---

## 3. Build Dispatch Chain

```
GitHub Push/PR
    │
    ▼
GitHub Actions Workflow (.github/workflows/ci.yml)
    │
    ├── Security Scan ──────────────────── ubuntu-latest (GitHub-hosted)
    │
    ├── Validation & Linting ───────────── self-hosted (hate-filled on remote-builder)
    │   ├── nix fmt -- --check .
    │   ├── nix flake check
    │   └── deadnix
    │
    ├── Build x86_64 (matrix, max-parallel: 10)
    │   └── self-hosted → nix-daemon (max-jobs=0) → hyperhyper (ssh-ng)
    │
    └── Build ARM (matrix, max-parallel: 2)
        └── self-hosted → nix-daemon (max-jobs=0) → arm-builder (ssh-ng)
```

### Builder Details

| Builder | IP | Arch | maxJobs | speedFactor | Features | Connection |
|---|---|---|---|---|---|---|
| hyperhyper | 100.107.101.14 | x86_64-linux | 10 | 10 | big-parallel, kvm, nixos-test | ssh-ng via cortex-alpha WG gateway |
| arm-builder | 10.88.127.43 | aarch64-linux | 3 | 5 | big-parallel | ssh-ng direct |

### SSH Multiplexing Exclusions

Builder hosts are excluded from SSH multiplexing to prevent ControlMaster corruption of the ssh-ng protocol handshake. Both `sshMultiplex.exclusions` and explicit `Host build@*` blocks are configured.

---

## 4. CI Pipeline Timings (Historical)

### Run 29643062888 (2026-07-18, push)

| Job | Duration | Result |
|---|---|---|
| Security Scan | 45s | ✅ |
| Validation & Linting | 1h 44m | ❌ (OOM on nix test suite) |

### Run 29567428463 (2026-07-17, PR)

| Job | Duration | Result |
|---|---|---|
| Security Scan | 52s | ✅ |
| Validation & Linting | 6m 25s | ❌ (voyagerOnly option) |

### Run 29659721965 (2026-07-18, push — CURRENT)

| Job | Status | Notes |
|---|---|---|
| Validation & Linting | ✅ completed | Passed |
| Security Scan | ✅ completed | Passed |
| Build ARM (5 jobs) | ⏳ queued | Waiting for self-hosted runner |
| Build x86 (10 jobs) | ⏳ queued | Waiting for self-hosted runner |

**Key observation:** Validation passes. Build jobs are queued because the self-hosted runner (`hate-filled`) is processing one job at a time. The runner is `busy: true`.

---

## 5. Build Patterns

### Local Build (this machine, x86_64, `--option builders ''`)

| Machine | Status | Notes |
|---|---|---|
| remote-builder | ✅ | |
| LINDA | ✅ | |
| alpha-one | ✅ | |
| alpha-three | ✅ | |
| local-nas | ✅ | |
| remote-worker | ✅ | |
| terminal-nx-01 | ✅ | |
| cortex-alpha | ✅ | |
| terminal-zero | ✅ | |
| gaming-host-1 | ❌ timeout | wine build exceeds 10min limit |

### ARM Machines (cannot build locally on x86_64)

| Machine | Arch | Builder |
|---|---|---|
| arm-builder | aarch64 | arm-builder (self) |
| display-1 | aarch64 | arm-builder |
| display-2 | aarch64 | arm-builder |
| print-controller | aarch64 | arm-builder |
| beta-one | armv7l | arm-builder |

---

## 6. Build Performance Analysis

### How Nix Caching Works (Correct Mental Model)

A derivation's hash is based on its **direct inputs** — source, dependencies, build script. If an input changes, only derivations that transitively depend on it get new hashes. All other derivations are cache hits.

```
LLM-CORE changes
  → opencode-fleet module changes (depends on LLM-CORE)
  → machines importing opencode-fleet get new closures
  → machines NOT importing opencode-fleet: unchanged, cache hit

x11, wine, systemd, kernel: unchanged regardless of LLM-CORE
  → store cache hit, instant
```

This means builds SHOULD get faster over time as the store accumulates cached derivations. Only the changed parts rebuild.

### Observed Performance

| Run | Date | Validation Duration | Notes |
|---|---|---|---|
| 29567428463 | 2026-07-17 08:43 | 6m 25s | First run, voyagerOnly error |
| 29643062888 | 2026-07-18 11:43 | 1h 44m | OOM on nix test suite (doCheck=true) |
| 29659721965 | 2026-07-18 20:26 | **7m 5s** | doCheck=false applied, cache warm |

**Validation & Linting dropped from 1h44m to 7m** after the `doCheck=false` fix. The nix package no longer builds from source during `nix flake check`.

### Build Queue Bottleneck

The 15 build jobs (10 x86 + 5 ARM) are all queued behind a single `hate-filled` runner. Each job runs sequentially. This is the primary CI bottleneck — not build time, but queue depth.

**Current state (run 29659721965):**
- Validation: ✅ completed (7m)
- Security: ✅ completed (50s)
- Build jobs: 15 queued, waiting for runner

### Why Builds Are Fast When They Run

When a build job actually runs `nix build .#nixosConfigurations.X.config.system.build.toplevel`:
1. Nix evaluates the derivation — if the eval cache is warm, this is instant
2. Nix checks if the output path is already in the store — if yes, done
3. If not, nix builds only the MISSING derivations — unchanged ones are cache hits
4. The runner dispatches to hyperhyper/arm-builder via ssh-ng — builders have their own stores

For a machine whose inputs haven't changed since the last run, the build should be nearly instant (store cache hit). The only slow builds are for machines whose dependencies actually changed.

---

## 7. Optimization Targets

### Target 1: Build Queue Depth (PRIMARY BOTTLENECK)

**Current:** 15 build jobs queued behind a single runner, processed sequentially
**Impact:** Even if each build takes 1 minute, 15 jobs = 15 minutes minimum
**Opportunity:**
- Register additional self-hosted runners on remote-builder (it has capacity)
- Or: restructure CI to build all machines in a single job (avoids runner startup overhead per job)
- Or: use a build matrix with multiple runners

### Target 2: Validation Duration

**Current:** 7m (down from 1h44m after doCheck=false fix)
**Bottleneck:** `nix flake check` evaluates all 15+ machine configurations
**Opportunity:**
- Split checks into per-machine jobs (parallel)
- Skip VM tests in CI (run separately on schedule)
- The eval cache should make this faster on subsequent runs with same inputs

### Target 3: Nix Package Pre-build

**Current:** Forked nix builds from source on first run after input change
**Bottleneck:** One-time cost per input change (~10-15min)
**Opportunity:**
- Pre-build the forked nix on hyperhyper and push to fleet cache (Phase 4 of hub plan)
- Subsequent runs with same inputs will be instant (store cache hit)

### Target 4: wine Build for gaming-host-1

**Current:** Times out locally (>10min single derivation)
**Bottleneck:** Massive C++ compilation
**Opportunity:**
- Always build gaming-host-1 via hyperhyper (100+ cores)
- Or: pre-cache wine in the fleet binary cache
- Under investigation — may just need more time

### Target 5: SSH Connection Overhead

**Current:** Each nix-daemon ssh-ng connection opens a new TCP session (multiplexing excluded for builders)
**Bottleneck:** Connection setup time per derivation dispatch
**Opportunity:**
- The `?max-connections=1` on arm-builder limits concurrency (intentional for RPi)
- hyperhyper has no connection limit (Determinate Nix default of 64) — verify this is working
- Waiting for ARM builds with patched daemon to test higher max-jobs

---

## 8. Expected Behavior (Correct Model)

When flake inputs change, only derivations that transitively depend on the changed input are invalidated. All other derivations are cache hits.

```
Run 1 (LLM-CORE changes):
  - machines importing opencode-fleet: rebuild (~5min each)
  - machines NOT importing opencode-fleet: instant (cache hit)
  - x11, wine, systemd, kernel: instant (cache hit)

Run 2 (same inputs):
  - ALL machines: instant (store cache hit)
  - Validation: fast (eval cache warm)

Run 3 (nix input changes):
  - ALL machines: rebuild (nix package changed, all closures depend on it)
  - This is a one-time cost

Run 4 (same inputs):
  - ALL machines: instant (store cache hit)
```

The trend should show diminishing build times as the store accumulates cached derivations. The only slow runs are when inputs actually change.

---

## 9. Key Files Reference

| File | Path |
|---|---|
| CI workflow | `.github/workflows/ci.yml` |
| CI generator | `ci.nix`, `ci/generate-workflow.nix` |
| CI library | `lib/ci_library.nix` |
| Builder config | `modifier_imports/remote-builder.nix` |
| Machine config | `machines/remote-builder/default.nix` |
| Hardware config | `machines/remote-builder/hardware-configuration.nix` |
| Build user | `users/build.nix` |
| Deploy user | `users/deployment.nix` |
| Inspect user | `users/inspect.nix` |
| SSH multiplex | `modules/ssh-multiplex.nix` |
| WireGuard topology | `modules/enable-wg-topology.nix` |
| Topology data | `topology/shared.nix` |
| Golden test | `goldens/remote-builder.json` |
| Hub plan | `documentation/plans/remote-builder-hub-2026-07-15.md` |
| Deployment status | `documentation/overlord-II-deployment-status.md` |
| Operational patterns | `/speed-storage/opencode/llm/shared/operational_patterns.md` |
