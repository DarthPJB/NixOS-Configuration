# CI Queue Analytics — Raw Data

> **Dumped:** 2026-07-19
> **Source:** GitHub Actions API via `gh`

## Run Summary

| Run ID | Event | Created | Status | Conclusion |
|---|---|---|---|---|
| 29659723643 | PR | 2026-07-18 20:27 | queued | - |
| 29659721965 | push | 2026-07-18 20:26 | queued | - |
| 29657279469 | PR | 2026-07-18 19:10 | queued | - |
| 29657278101 | push | 2026-07-18 19:10 | queued | - |
| 29643063903 | PR | 2026-07-18 11:43 | completed | failure |
| 29643062888 | push | 2026-07-18 11:43 | completed | failure |
| 29604686045 | PR | 2026-07-17 18:40 | completed | failure |
| 29604684524 | push | 2026-07-17 18:40 | completed | failure |
| 29589954761 | PR | 2026-07-17 14:55 | completed | failure |
| 29589950753 | push | 2026-07-17 14:54 | completed | failure |
| 29589813677 | PR | 2026-07-17 14:52 | completed | failure |
| 29589808861 | push | 2026-07-17 14:52 | completed | failure |
| 29589325455 | PR | 2026-07-17 14:45 | completed | failure |
| 29574947676 | PR | 2026-07-17 10:52 | completed | failure |
| 29567428463 | PR | 2026-07-17 08:43 | completed | failure |
| 29545388691 | PR | 2026-07-17 00:39 | completed | failure |
| 29544867741 | PR | 2026-07-17 00:28 | completed | failure |
| 29544331951 | PR | 2026-07-17 00:16 | completed | failure |
| 29544093011 | PR | 2026-07-17 00:11 | completed | failure |
| 29534268620 | PR | 2026-07-16 20:59 | completed | failure |

## Job Timings (Completed Runs)

### Run 29643062888 (2026-07-18 11:43, push)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 11:43:54 | 11:44:39 | 45s | ✅ |
| Validation & Linting | 11:43:54 | 13:28:34 | **1h 44m 40s** | ❌ |

### Run 29604686045 (2026-07-17 18:40, PR)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 18:40:27 | 18:41:16 | 49s | ✅ |
| Validation & Linting | 00:55:22 | 00:56:54 | **1m 32s** | ❌ |
| Queue wait (Validation) | 18:41:16 | 00:55:22 | **6h 14m** | - |

### Run 29589950753 (2026-07-17 14:54, push)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 14:55:02 | 14:55:53 | 51s | ✅ |
| Validation & Linting | 15:28:29 | 15:28:48 | 19s | ❌ |
| Queue wait (Validation) | 14:55:53 | 15:28:29 | **32m 36s** | - |

### Run 29589808861 (2026-07-17 14:52, push)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 14:52:54 | 14:53:47 | 53s | ✅ |
| Validation & Linting | 15:24:14 | 15:24:34 | 20s | ❌ |
| Queue wait (Validation) | 14:53:47 | 15:24:14 | **30m 27s** | - |

### Run 29567428463 (2026-07-17 08:43, PR)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 08:43:53 | 08:44:45 | 52s | ✅ |
| Validation & Linting | 08:43:52 | 08:50:17 | **6m 25s** | ❌ |

### Run 29545388691 (2026-07-17 00:39, PR)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 00:39:48 | 00:40:38 | 50s | ✅ |
| Validation & Linting | 00:40:52 | 02:46:33 | **2h 5m 41s** | ❌ |
| Queue wait (Validation) | 00:40:38 | 00:40:52 | 14s | - |

### Run 29544867741 (2026-07-17 00:28, PR)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 00:28:16 | 00:29:00 | 44s | ✅ |
| Validation & Linting | 00:28:38 | 00:40:50 | **12m 12s** | ❌ |
| Queue wait (Validation) | 00:29:00 | 00:28:38 | - | - |

### Run 29544331951 (2026-07-17 00:16, PR)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 00:16:47 | 00:17:37 | 50s | ✅ |
| Validation & Linting | 00:28:17 | 00:28:36 | 19s | ❌ |
| Queue wait (Validation) | 00:17:37 | 00:28:17 | **10m 40s** | - |

### Run 29544093011 (2026-07-17 00:11, PR)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 00:11:45 | 00:12:35 | 50s | ❌ |
| Validation & Linting | 00:27:52 | 00:28:15 | 23s | ❌ |
| Queue wait (Validation) | 00:12:35 | 00:27:52 | **15m 17s** | - |

### Run 29534268620 (2026-07-16 20:59, PR)
| Job | Started | Completed | Duration | Result |
|---|---|---|---|---|
| Security Scan | 20:59:07 | 20:59:56 | 49s | ❌ |
| Validation & Linting | 00:27:18 | 00:27:49 | 31s | ❌ |
| Queue wait (Validation) | 20:59:56 | 00:27:18 | **3h 27m** | - |

## Key Observations

### Validation Duration (actual execution, excluding queue wait)

| Run | Date | Duration | Error |
|---|---|---|---|
| 29567428463 | 07-17 08:43 | 6m 25s | voyagerOnly option |
| 29545388691 | 07-17 00:39 | 2h 5m 41s | ? |
| 29544867741 | 07-17 00:28 | 12m 12s | ? |
| 29544331951 | 07-17 00:16 | 19s | ? |
| 29544093011 | 07-17 00:11 | 23s | ? |
| 29534268620 | 07-16 20:59 | 31s | ? |
| 29589950753 | 07-17 14:54 | 19s | voyagerOnly option |
| 29589808861 | 07-17 14:52 | 20s | ? |
| 29643062888 | 07-18 11:43 | **1h 44m 40s** | OOM (doCheck=true) |

### Queue Wait Times

| Run | Date | Queue Wait |
|---|---|---|
| 29604686045 | 07-17 18:40 | **6h 14m** |
| 29534268620 | 07-16 20:59 | **3h 27m** |
| 29589950753 | 07-17 14:54 | 32m |
| 29589808861 | 07-17 14:52 | 30m |
| 29544093011 | 07-17 00:11 | 15m |
| 29544331951 | 07-17 00:16 | 10m |

### Build Jobs

No completed run has reached the build phase — all failed at Validation & Linting. Build job timing data is not yet available.

---

## Build Phase Data — Run 29657278101 (FIRST RUN TO REACH BUILDS)

**Run:** "unqueue hyperhyper jobs and implement custom nix fork"
**Created:** 2026-07-18 19:10
**Status:** In progress (alpha-three building)

### Validation & Linting
- Started: 00:11:49
- Completed: 00:20:03
- **Duration: 8m 14s** ✅

### Build Job Timings (sequential, single runner)

| Job | Started | Completed | Duration | Result | Notes |
|---|---|---|---|---|---|
| gaming-host-1 | 00:32:10 | 00:48:11 | 16m 1s | ❌ | wine build |
| display-1 | 03:11:29 | 03:27:30 | 16m 1s | ✅ | ARM, cold cache |
| arm-builder | 03:27:31 | 04:58:10 | 1h 30m 39s | ✅ | ARM, cold cache |
| LINDA | 04:58:12 | 05:04:25 | 6m 13s | ❌ | |
| cortex-alpha | 05:11:10 | 05:41:11 | 30m 1s | ✅ | Cold cache |
| remote-builder | 07:21:42 | 07:24:23 | **2m 41s** | ✅ | Warm cache |
| terminal-zero | 07:24:24 | 07:28:37 | 4m 13s | ❌ | |
| local-nas | 07:32:27 | 07:36:12 | **3m 45s** | ✅ | Warm cache |
| terminal-nx-01 | 07:36:14 | 07:39:04 | 2m 50s | ❌ | |
| remote-worker | 07:44:01 | 07:45:58 | **1m 57s** | ✅ | Warm cache |
| alpha-one | 07:49:01 | 07:52:34 | 3m 33s | ❌ | |
| alpha-three | 07:52:35 | in_progress | - | 🔄 | |

### Key Observations

**Build times confirm the caching model:**

| Phase | Machines | Duration | Explanation |
|---|---|---|---|
| Cold cache | cortex-alpha, arm-builder, display-1 | 16m - 1h30m | First builds, store empty |
| Warm cache | remote-builder, remote-worker, local-nas | **1m57s - 3m45s** | Store populated, cache hits |

**remote-builder built in 2m41s** — the same machine that took 30+ minutes in earlier runs. The store now has cached derivations.

**Queue gaps are significant:**
- gaming-host-1 finished 00:48, display-1 started 03:11 → **2h23m gap** (other runs' jobs interleaved)
- cortex-alpha finished 05:41, remote-builder started 07:21 → **1h40m gap**

These gaps are NOT build time — they're runner queue contention from multiple queued runs.

### Runner Behavior

- **Single runner** (`hate-filled`) processes jobs sequentially
- **Queue wait** varies from 10 minutes to 6+ hours depending on runner availability
- **Validation duration** varies wildly: 19s (cache hit) to 2h+ (cache miss + build from source)

---

## Update — 2026-07-22 (Post-Eval-Cache Deploy)

> **Deployed:** 2026-07-22 11:31 UTC
> **Change:** `NIX_CACHE_HOME=/nix/cache` + `BindPaths = [ "/nix/cache" ]`
> **Effect:** Eval cache and flake input cache now persistent across jobs

### Pipeline #183 Timings (Post-Deploy)

| Job | Duration | Result | Notes |
|---|---|---|---|
| display-1 (ARM) | 2m 41s | ✅ | |
| arm-builder (ARM) | 2m 5s | ✅ | |
| display-2 (ARM) | 2m 36s | ✅ | |
| print-controller (ARM) | 2m 14s | ✅ | |
| local-nas | 2m 19s | ✅ | Warm cache |
| remote-builder | 2m 18s | ✅ | Warm cache |
| cortex-alpha | 2m 17s | ✅ | Warm cache |
| remote-worker | 2m 15s | ✅ | Warm cache |
| terminal-zero | 4m 23s | ✅ | |
| alpha-three | 9m 55s | ✅ | Cold cache |

### Pipeline #185 Timings (Post-Deploy)

| Job | Duration | Result | Notes |
|---|---|---|---|
| arm-builder (ARM) | 2m 5s | ✅ | |
| cortex-alpha | 2m 6s | ✅ | Warm cache |
| local-nas | 2m 19s | ✅ | Warm cache |
| remote-builder | 2m 22s | ✅ | Warm cache |
| remote-worker | 2m 22s | ✅ | Warm cache |
| display-1 (ARM) | 3m 7s | ✅ | |
| terminal-zero | 4m 27s | ✅ | |
| alpha-three | 4m 54s | ✅ | |

### Queue Drain Summary

| Time (UTC) | Queue Depth | Runs/Hour | Notes |
|---|---|---|---|
| 11:19 | 20+ | — | Pre-deploy, all jobs failing |
| 11:31 | 20+ | — | BindPaths fix deployed |
| 12:00 | 11 | ~9 | Rapid drain |
| 12:28 | 2 | ~9 | Nearly clear |
| 13:00 | 3 | ~2 | New pushes arriving |
| 14:00 | 3 | ~2 | Normal operating depth |

**Backlog drained from 20+ to 3 in ~2.5 hours.** Now operating at steady state.

### Eval Cache Status

```
/nix/cache/ — 14-18MB total
├── eval-cache-v6/           — 3 SQLite databases
├── fetcher-cache-v4.sqlite  — 972K
├── gitv3/                   — 3 shallow clones cached
└── tarball-cache-v2/        — tarball cache populated
```

**Expected improvement:** Next run with identical inputs should see eval drop from ~1m45s to <10s.

> **Dumped:** 2026-07-22 09:25 UTC
> **Source:** GitHub Actions API via `gh`, SSH deploy@remote-builder

### Run Summary (2026-07-21 to 2026-07-22)

| Run ID | Event | Created | Status | Conclusion | Title |
|---|---|---|---|---|---|
| 29870490686 | PR | 2026-07-21 21:34 | queued | - | Draft: Meta Commit II - far too large. |
| 29870488133 | push | 2026-07-21 21:34 | queued | - | owo |
| 29865476321 | PR | 2026-07-21 20:22 | queued | - | Draft: Meta Commit II - far too large. |
| 29865473568 | push | 2026-07-21 20:22 | queued | - | fix: remove duplicate opencode from code.nix |
| 29859144229 | push | 2026-07-21 18:53 | completed | **failure** | feat(planar-topology): RF-2 — Tailscale ACL drift validator |
| 29857931561 | push | 2026-07-21 18:36 | queued | - | feat(planar-topology): RF-1 — populate routes, wireguard, firewall |
| 29857547965 | push | 2026-07-21 18:31 | queued | - | fix(planar-topology): RF-0 listenAddresses fix + golden regen |
| 29857024461 | PR | 2026-07-21 18:23 | queued | - | Draft: Meta Commit II - far too large. |
| 29857022296 | push | 2026-07-21 18:23 | queued | - | aliens did it |
| 29856643728 | push | 2026-07-21 18:18 | queued | - | fix(planar-topology): RF-0 — clean up JSON data quality |
| 29849006987 | push | 2026-07-21 16:31 | queued | - | merge(overlord-II): crush removal, deprecation fixes |
| 29848705228 | push | 2026-07-21 16:27 | queued | - | Fix all 14 deadnix findings in pre-existing non-topology files |
| 29846947438 | push | 2026-07-21 16:04 | completed | **failure** | fix(checks): flatten network-config into per-machine checks |
| 29844859390 | PR | 2026-07-21 15:37 | queued | - | Draft: Meta Commit II - far too large. |
| 29844853633 | push | 2026-07-21 15:37 | queued | - | fix: deprecated wireless.userControlled.enable |
| 29844726872 | push | 2026-07-21 15:36 | completed | **failure** | merge(overlord-II): absorb flakehub token + system deprecation fix |
| 29843497487 | PR | 2026-07-21 15:20 | queued | - | Draft: Meta Commit II - far too large. |
| 29843492935 | push | 2026-07-21 15:20 | queued | - | fix: replace all deprecated system attr with stdenv.hostPlatform |
| 29842696784 | push | 2026-07-21 15:10 | completed | **failure** | fix(flake): add allowUnfree to pkgs_llm — crush is unfree |
| 29842586756 | PR | 2026-07-21 15:09 | queued | - | Draft: Meta Commit II - far too large. |

**Key pattern:** 12 of 20 runs are still queued. Only 4 completed (all failures). Massive queue backlog.

### Completed Run Timings

#### Run 29842696784 (2026-07-21 15:10, push — fix: add allowUnfree)

| Job | Duration | Result | Notes |
|---|---|---|---|
| Security Scan | 53s | ✅ | |
| Validation & Linting | **7m 31s** | ❌ | Queue wait: 25m 10s |

#### Run 29844726872 (2026-07-21 15:36, push — merge overlord-II)

| Job | Duration | Result | Notes |
|---|---|---|---|
| Security Scan | 46s | ✅ | |
| Validation & Linting | **7m 14s** | ❌ | Queue wait: 17m 46s |

#### Run 29859144229 (2026-07-21 18:53, push — planar-topology RF-2)

| Job | Duration | Result | Notes |
|---|---|---|---|
| Security Scan | 48s | ✅ | |
| Validation & Linting | **20s** | ❌ | Queue wait: **10h 24m** (18:54 → 05:18) |

**Queue wait of 10h24m is the worst observed.** Validation itself was instant (20s) — likely a quick eval error.

#### Run 29846947438 (2026-07-21 16:04, push — FIRST RUN TO COMPLETE ALL BUILDS)

**Title:** "fix(checks): flatten network-config into per-machine checks"
**Total wall time:** 16:04 → 07:17 = **15h 13m**

| Job | Started | Duration | Result | Notes |
|---|---|---|---|---|
| Security Scan | 16:04:35 | 45s | ✅ | |
| Validation & Linting | 16:18:19 | **12m 23s** | ✅ | Queue wait: 13m |
| Build x86 (cortex-alpha) | 16:55:10 | **6m 12s** | ✅ | Warm cache |
| Build x86 (alpha-three) | 17:05:17 | **4h 53m 12s** | ✅ | Cold cache, massive rebuild |
| Build ARM (display-1) | 16:46:30 | 4m 17s | ✅ | |
| Build x86 (terminal-zero) | 22:07:08 | 4m 36s | ✅ | |
| Build x86 (terminal-nx-01) | 22:11:46 | 2m 58s | ❌ | **Parsec narHash mismatch** |
| Build x86 (remote-worker) | 22:57:08 | 2m 8s | ✅ | |
| Build x86 (remote-builder) | 22:46:26 | 2m 2s | ✅ | Warm cache |
| Build ARM (arm-builder) | 22:44:28 | 1m 57s | ✅ | |
| Build x86 (alpha-one) | 22:38:51 | 3m 32s | ❌ | **Parsec narHash mismatch** |
| Build x86 (local-nas) | 22:59:17 | 2m 6s | ✅ | |
| Build x86 (LINDA) | 23:12:22 | 4m 22s | ❌ | **Parsec narHash mismatch** |
| Build x86 (gaming-host-1) | 23:01:25 | 7m 43s | ❌ | **moonrise gradle build failure** |
| Build ARM (display-2) | 03:01:49 | 2m 41s | ✅ | |
| Build ARM (print-controller) | 05:24:01 | 2m 11s | ✅ | |
| Build ARM (beta-one) | 07:16:16 | 51s | ✅ | |

### Failure Analysis

**Three distinct failure modes observed:**

1. **Parsec narHash mismatch** (terminal-nx-01, alpha-one, LINDA)
   - Error: `mismatch in field 'narHash' of input 'https://builds.parsecgaming.com/channel/release/appdata/linux/latest'`
   - Expected: `sha256-HQhIa2A5e21sjVSZEk5OsPt5C6RDBxqi7NpiNP0JZIM=`
   - Got: `sha256-MaBaAcuriCHa1NEfGsGLQS3cNgA2+CtBaIW850f3Wm8=`
   - **Root cause:** Parsec upstream released a new version. The flake.lock pins the old hash.
   - **Fix:** `nix flake update parsec` or remove parsec from affected machines.

2. **Moonrise/Gradle build failure** (gaming-host-1)
   - Error: `builder failed with exit code 1` on `moonrise-0.1.0-beta.15-gradle-deps.drv`
   - Transitive failure: moonrise → squaremap → mc-server-final → mc-curseforge → system-units → etc → toplevel
   - **Root cause:** Minecraft mod dependency (moonrise) gradle build fails on hyperhyper.
   - **Fix:** Investigate gradle build environment on hyperhyper, or pin moonrise to working version.

3. **Validation failures** (29842696784, 29844726872)
   - Quick failures (7m) — likely eval errors in the config.

### Remote Builder State (2026-07-22 09:23 UTC)

| Metric | Value | Notes |
|---|---|---|
| **Uptime** | 240 days 10h | Stable |
| **Load** | 1.43 / 1.66 / 1.63 | Moderate |
| **Memory** | 1.9G used / 15G total | Healthy (13G available) |
| **Disk (/nix)** | 112G used / 295G total (40%) | Healthy |
| **nix-daemon** | active | |
| **max-jobs** | 0 | Dispatches to remote builders |
| **distributed-builds** | true | |

### Runner Status (2026-07-22 09:23 UTC)

| Runner | Status | Busy | Memory | Notes |
|---|---|---|---|---|
| hate-filled | offline | no | - | Base runner, not active |
| hate-filled-1 | **online** | **yes** | 2.4G | **Currently building LINDA** |
| hate-filled-2 | offline | no | - | |
| hate-filled-3 | offline | no | - | |
| hate-filled-4 | offline | no | - | |
| hate-filled-5 | offline | no | - | |
| disgust | online | no | 77M | Idle |
| entropy-is-origin | online | no | 79M | Idle |
| rat-infested | online | no | 81M | Idle |

**Active build at 09:23:**
```
nix build --option max-jobs auto --option cores 0 .#nixosConfigurations.LINDA.config.system.build.toplevel
```

**Builder registrations (unchanged):**

| Builder | IP | Arch | maxJobs | speedFactor | Connection |
|---|---|---|---|---|---|
| hyperhyper | 100.107.101.14 | x86_64-linux | 10 | 10 | ssh-ng via cortex-alpha WG |
| arm-builder | 10.88.127.43 | aarch64-linux | 3 | 5 | ssh-ng direct |

### Build Performance Summary (Run 29846947438)

| Category | Machines | Avg Duration | Notes |
|---|---|---|---|
| **Warm cache (x86)** | remote-builder, remote-worker, local-nas | **2m 5s** | Store populated from prior runs |
| **Cold cache (x86)** | cortex-alpha | 6m 12s | First build with new inputs |
| **Cold cache (x86, heavy)** | alpha-three | **4h 53m** | Massive derivation rebuild |
| **ARM (warm)** | arm-builder, beta-one | **1m 24s** | ARM builds fast when cached |
| **ARM (cold)** | display-1, display-2, print-controller | **3m 3s** | ARM cold cache moderate |
| **Failed (Parsec)** | terminal-nx-01, alpha-one, LINDA | 3m 34s avg | narHash mismatch, not build failure |
| **Failed (gradle)** | gaming-host-1 | 7m 43s | moonrise dependency chain |

### Queue Depth Crisis

**Current state:** 12 runs queued, only 1 runner processing jobs.

| Metric | Value |
|---|---|
| Queued runs | 12 |
| Active runners | 1 (hate-filled-1) |
| Idle runners | 3 (disgust, entropy-is-origin, rat-infested) |
| Estimated queue drain time | **12+ hours** at current rate |

**Root cause:** Only `hate-filled-1` is picking up build jobs. The other 3 online runners (disgust, entropy-is-origin, rat-infested) appear idle — they may not have the `self-hosted` label or may not match the job's `runs-on` selector.

**Recommendation:** Investigate why 3 idle runners are not consuming queued jobs. This is the primary CI bottleneck — not build time, but runner utilization.

### nix-daemon Activity Pattern

Connections from `build` user arriving every 3-5 minutes — these are ssh-ng handshake pings from the CI runner checking builder availability:

```
09:23:19 accepted connection from pid 326227, user build (trusted)
09:20:10 accepted connection from pid 325788, user build (trusted)
09:14:58 accepted connection from pid 325426, user build (trusted)
09:10:16 accepted connection from pid 323242, user build (trusted)
09:07:07 accepted connection from pid 322899, user build (trusted)
```

Also periodic warnings: `Could not chdir to home directory /tmp/nix-builder-1111: No such file or directory`
— Harmless but indicates the build user's home directory doesn't exist. Could be fixed by adding `home = "/tmp/nix-builder-1111";` to the build user config.

### Timeline: Last 24 Hours

```
2026-07-21
  15:10  Run 29842696784 (push) — Validation fails (7m31s)
  15:36  Run 29844726872 (push) — Validation fails (7m14s)
  15:37  Runs 29844853633, 29844859390 — queued
  15:20  Runs 29843492935, 29843497487 — queued
  15:09  Run 29842586756 — queued
  16:04  Run 29846947438 (push) — STARTS (first to reach builds)
         16:05  Security ✅
         16:18  Validation ✅ (12m23s)
         16:46  ARM builds start
         16:55  x86 builds start
         22:07  terminal-zero ✅ (4m36s)
         22:11  terminal-nx-01 ❌ (Parsec hash)
         22:38  alpha-one ❌ (Parsec hash)
         22:44  arm-builder ✅ (1m57s)
         22:46  remote-builder ✅ (2m02s)
         22:57  remote-worker ✅ (2m08s)
         22:59  local-nas ✅ (2m06s)
         23:01  gaming-host-1 ❌ (moonrise gradle)
         23:12  LINDA ❌ (Parsec hash)
  16:27  Run 29848705228 — queued
  16:31  Run 29849006987 — queued
  18:18  Run 29856643728 — queued
  18:23  Runs 29857022296, 29857024461 — queued
  18:31  Run 29857547965 — queued
  18:36  Run 29857931561 — queued
  18:53  Run 29859144229 (push) — starts
         18:54  Security ✅
         ...  10h 24m queue wait ...
  20:22  Runs 29865473568, 29865476321 — queued
  21:34  Runs 29870488133, 29870490686 — queued

2026-07-22
  03:01  Run 29846947438 — display-2 ✅ (2m41s)
  05:18  Run 29859144229 — Validation fails (20s, after 10h queue wait)
  05:24  Run 29846947438 — print-controller ✅ (2m11s)
  07:16  Run 29846947438 — beta-one ✅ (51s)
  07:17  Run 29846947438 — COMPLETED (15h 13m total)
  09:23  hate-filled-1 building LINDA (from queued run)
```
