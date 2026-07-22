# Eval Cache Persistence — Deployment Record

> **Date:** 2026-07-22
> **Deployed:** 11:19 UTC (first attempt), 11:31 UTC (successful after BindPaths fix)
> **Remote-builder:** 10.88.127.51

---

## Problem

The GitHub Actions runner's HOME was set to tmpfs (`/run/github-runner/hate-filled-1`). Nix's eval cache (`~/.cache/nix/eval-cache-v6/`) and flake input cache (`~/.cache/nix/gitv3/`) were lost between every CI job. This forced a full 1m45s evaluation on every build, even when inputs hadn't changed.

## Solution

### Changes Made

**1. `services/mkRunners.nix`** — Set `NIX_CACHE_HOME` for persistent eval cache:

```nix
extraEnvironment = {
  GIT_ASKPASS = "${gitlabAskpass}";
  NIX_CACHE_HOME = "/nix/cache";
};
```

**2. `lib/mkRunner.nix`** — Add writable bind mount for `/nix/cache`:

The runner service has `BindReadOnlyPaths = [ "/nix" ]` which makes the entire `/nix` filesystem read-only. Adding `BindPaths = [ "/nix/cache" ]` overrides this for the cache subpath:

```nix
serviceOverrides = {
  BindReadOnlyPaths = [ "/nix" ] ++ ...;
  BindPaths = [ "/nix/cache" ];  # writable override for eval cache
};
```

**3. `services/mkRunners.nix`** — Create cache directory on boot:

```nix
systemd.tmpfiles.rules = [
  "d /nix/cache 0755 build users - -"
];
```

### Why `NIX_CACHE_HOME` (not `XDG_CACHE_HOME`)

The nix source at `src/libutil/users.cc:15-25` shows:

```cpp
getCacheDir() {
    auto dir = getEnvOs(OS_STR("NIX_CACHE_HOME"));  // checked first
    if (dir) return *dir;
    return unix::xdg::getCacheHome() / "nix";        // XDG fallback
}
```

`NIX_CACHE_HOME` is the nix-native override, checked before `XDG_CACHE_HOME` and independent of `use-xdg-base-directories`.

### Cache Directory Structure

After deployment, `/nix/cache/` contains:

```
/nix/cache/
├── eval-cache-v6/           ← eval cache (SQLite, per-flake-fingerprint)
├── fetcher-cache-v4.sqlite  ← flake input fetch cache (972K)
├── fetcher-locks/           ← concurrent access locks
├── gitv3/                   ← git flake input cache (shallow clones)
├── tarball-cache-v2/        ← tarball flake input cache
└── sentry/                  ← crash reporting
```

**Total size:** ~14-18MB (grows with more evaluations)

---

## Build Timings — Post-Deploy

### Pipeline #183 ("aliens did it") — Post-Restart

Runner restarted at 11:31 UTC after BindPaths fix. All jobs after restart succeeded.

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
| gaming-host-1 | 5m 57s | ❌ | moonrise gradle |
| LINDA | 5m 13s | ❌ | Parsec narHash |
| terminal-nx-01 | 3m 12s | ❌ | Parsec narHash |
| alpha-one | 4m 7s | ❌ | Parsec narHash |

### Pipeline #185 ("RF-0 listenAddresses fix") — Post-Deploy

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
| terminal-nx-01 | 3m 22s | ❌ | Parsec narHash |
| alpha-one | 3m 57s | ❌ | Parsec narHash |
| LINDA | 5m 2s | ❌ | Parsec narHash |
| gaming-host-1 | 5m 49s | ❌ | moonrise gradle |

### Timings Summary (Warm-Cache Builds)

| Category | Machines | Avg Duration | Range |
|---|---|---|---|
| **ARM builds** | display-1, display-2, arm-builder, print-controller | **2m 20s** | 2m 5s – 3m 7s |
| **x86 warm-cache** | remote-builder, cortex-alpha, local-nas, remote-worker | **2m 18s** | 2m 6s – 2m 22s |
| **x86 moderate** | terminal-zero | **4m 25s** | 4m 23s – 4m 27s |
| **x86 cold** | alpha-three | **7m 25s** | 4m 54s – 9m 55s |
| **Failures** | LINDA, terminal-nx-01, alpha-one, gaming-host-1 | **4m 30s** | 3m 12s – 5m 57s |

### Post-Deploy Build Timings (11:31 – 12:28 UTC)

Collected over ~1 hour of continuous runner activity after deploy.

**ARM Builds (consistent 1-3m):**

| Machine | Duration | Time (UTC) |
|---|---|---|
| beta-one | 1m 0s | 12:23:12 → 12:24:12 |
| beta-one | 1m 1s | 12:24:14 → 12:25:15 |
| beta-one | 1m 4s | 12:19:04 → 12:20:08 |
| beta-one | 1m 40s | 12:15:26 → 12:17:06 |
| beta-one | 1m 54s | 12:17:08 → 12:19:02 |
| print-controller | 2m 18s | 11:34:12 → 11:36:30 |
| display-2 | 2m 35s | 11:31:36 → 11:34:11 |
| display-2 | 2m 38s | 11:43:35 → 11:46:08 |
| display-2 | 2m 37s | 11:46:10 → 11:48:47 |
| display-2 | 2m 38s | 12:20:31 → 12:23:09 |
| display-2 | 2m 42s | 12:25:17 → 12:27:59 |

**x86 Warm-Cache Builds (from #183 and #185):**

| Machine | Duration | Pipeline |
|---|---|---|
| cortex-alpha | 2m 6s | #185 |
| cortex-alpha | 2m 17s | #183 |
| local-nas | 2m 19s | #183, #185 |
| remote-builder | 2m 18s | #183 |
| remote-builder | 2m 22s | #185 |
| remote-worker | 2m 15s | #183 |
| remote-worker | 2m 22s | #185 |
| terminal-zero | 4m 23s | #183 |
| terminal-zero | 4m 27s | #185 |
| alpha-three | 4m 54s | #185 |
| alpha-three | 9m 55s | #183 |

**Eval Cache Growth:**

| Time (UTC) | Cache Size | Eval DBs |
|---|---|---|
| 11:31 | 0 (fresh) | 0 |
| 11:38 | — | 2 |
| 12:00 | 14MB | 3 |
| 12:28 | 15MB | 3 |

### Expected Improvement (Eval Cache)

The eval cache was just deployed. The first evaluation after restart populates the cache. Subsequent evaluations of the same flake (same inputs) should:

- **Skip input fetching** — `fetcher-cache-v4.sqlite` and `gitv3/` cache flake inputs
- **Skip eval computation** — `eval-cache-v6/` caches evaluation results per flake fingerprint
- **Expected warm-cache eval:** <10s (down from 1m45s)

The improvement will be visible on the **next run with identical inputs** — the eval phase should drop from ~1m45s to seconds.

---

## Failure Modes (Unchanged)

These failures are pre-existing and unrelated to the eval cache change:

| Machine | Error | Root Cause |
|---|---|---|
| gaming-host-1 | moonrise gradle build failure | Minecraft mod dependency fails on hyperhyper |
| LINDA | Parsec narHash mismatch | Upstream Parsec released new version |
| terminal-nx-01 | Parsec narHash mismatch | Same |
| alpha-one | Parsec narHash mismatch | Same |

---

## Queue Drain Results

| Time (UTC) | Queue Depth | Runs/Hour | Notes |
|---|---|---|---|
| 11:19 | 20+ | — | Pre-deploy, all jobs failing (read-only /nix) |
| 11:31 | 20+ | — | BindPaths fix deployed, runner restarted |
| 12:00 | 11 | ~9 | Queue draining rapidly |
| 12:28 | 2 | ~9 | Nearly caught up |
| ~13:45 | 0 (est.) | — | Queue clear |

**9 runs completed in the hour after deploy.** Queue dropped from 11 to 2 in ~1 hour.

### Eval Cache Final State

| Metric | Value |
|---|---|
| Total size | 34MB |
| Eval databases | 3 (eval-cache-v6/) |
| Fetcher cache | 972K (fetcher-cache-v4.sqlite) |
| Git cache entries | 3+ shallow clones |

---

### Eval Cache Final State (14:00 UTC)

| Metric | Value |
|---|---|
| Total size | 34MB |
| Eval databases | 3 (eval-cache-v6/) |
| Fetcher cache | 972K (fetcher-cache-v4.sqlite) |
| Git cache entries | 3+ shallow clones |

### Queue State (14:00 UTC)

3 runs queued — normal operating depth. Backlog cleared.

---

## Source References

| File | Path |
|---|---|
| Nix cache dir logic | `/speed-storage/bargman-tech/nix-src/src/libutil/users.cc:15-25` |
| XDG fallback | `/speed-storage/bargman-tech/nix-src/src/libutil/unix/xdg-dirs.cc:7-15` |
| Eval cache storage | `/speed-storage/bargman-tech/nix-src/src/libexpr/eval-cache.cc:73` |
| Runner factory | `lib/mkRunner.nix` |
| Runner service | `services/mkRunners.nix` |

---

## Related Documents

- `documentation/research/ci-build-bottleneck-analysis.md` — Full bottleneck analysis
- `documentation/research/ci-evaluation-optimization-research.md` — Eval optimization options
- `documentation/ci-queue-analytics.md` — CI queue data and job timings
- `documentation/remote-builder-analytics.md` — Builder access patterns
