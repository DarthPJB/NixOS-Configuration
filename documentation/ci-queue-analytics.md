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
