# Engineering Review: overlord-II Topology Rectification & Fleet Deployment

**Reviewer:** bellana-deepseek (opencode-go/deepseek-v4-flash)
**Date:** 2026-07-12
**Subject:** overlord-II — Topology rectification, fleet deployment, SSH revert analysis
**Type:** Read-only engineering review
**Build validated:** `nix run .#check-network -- cortex-alpha` ✅ PASS

---

## Executive Summary

overlord-II successfully moved from `real-topology/` to `topology/` + `goldens/`, updated all import paths, and deployed to 12 machines. The golden test for cortex-alpha passes. However, this review identified **3 functional issues** (broken scripts, leftover SSH multiplexing references, Prometheus retention concern) and **3 structural concerns** (format mismatch, stale comments, coverage gaps).

**Overall risk level: MODERATE** — No blocking issues for the active deployment, but technical debt has accumulated that should be addressed before the Phase C library split.

---

## 1. Regression Risk: flake.nix Changes

### 1.1 Topology Import (`topo`)

```nix
topo = import ./topology/shared.nix { inherit lib; };
```

**Verdict: ✅ PASS.** `topology/shared.nix` exists and is parseable. Contains all 22 machine entries with `wireguard` fields.

### 1.2 `topoIp` Resolution

```nix
topoIp = machineName: topo.${machineName}.wireguard;
```

**Verdict: ✅ PASS.** Every machine that uses `topoIp` in `flake.nix` has a corresponding entry in `topology/shared.nix` with a `wireguard` field. Verified all 17 active and 3 dormant configurations:
- Active: display-1, display-2, arm-builder, print-controller, terminal-zero, terminal-nx-01, cortex-alpha, local-nas, alpha-one, alpha-three, LINDA, gaming-host-1, remote-worker, remote-builder
- Dormant: alpha-two, storage-array, display-0

No `topoIp` calls for machines without topology entries (beta-one, arm-bootstrap, bargman-greeter-vm are constructed directly without topology).

### 1.3 `mkKnownHosts` Integrity

**Verdict: ✅ PASS.** The function:
- Combines active + dormant configs for key lookup
- Falls back from `secrix.hostPubKey` to file read from `secrets/public_keys/host_keys/`
- Generates hostnames from topology entries including wireguard, lan, and uplink IPs
- Skips machines without known keys
- Filters null entries correctly

No regression risk. The function correctly handles both topology-only and non-topology machines.

### 1.4 `ci.nix` Import

```nix
ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; };
```

**Verdict: ✅ PASS.** `ci.nix` exists and imports cleanly.

### 1.5 Circular Dependencies

**Verdict: ✅ PASS.** Dependency graph is linear:
```
topology/shared.nix → (pure data, no flake refs)
topology/default.nix → shared.nix + per-machine files + golden_generator.nix
flake.nix → topology/shared.nix (for topoIp, mkKnownHosts)
flake.nix → topology/default.nix (for generate-golden app)
modules/core-router.nix → topology/<hostname>.nix (per-machine)
modules/enable-wg-topology.nix → topology/shared.nix
```

No circular dependency detected.

---

## 2. Regression Risk: Golden Tests

### 2.1 cortex-alpha Golden Test

```
$ nix run .#check-network -- cortex-alpha
✓ Network config matches golden for cortex-alpha
```

**Verdict: ✅ PASS.** The golden test for cortex-alpha passes. The `dump-config` → `serialize-config.nix` pipeline produces byte-identical output to `goldens/cortex-alpha.json`.

**⚠ Warning:** The evaluation produced 24 trace warnings for obsolete option names (e.g., `services.openssh.logLevel` → `services.openssh.settings.LogLevel`, `services.prometheus.xmpp-alerts.configuration` → `services.prometheus.xmpp-alerts.settings`). These are non-blocking deprecation notices, but they indicate technical debt in configuration modules. The number of deprecation warnings is increasing with nixpkgs 25.11.

---

## 3. Regression Risk: Root `topology.nix` Removal

### 3.1 Functional Nix References

**Verdict: ✅ PASS.** Specific grep for `import ./topology.nix` and `import ../topology.nix` returned **zero results** in `.nix` files. The root `topology.nix` was successfully eliminated without breaking functional imports.

All Nix module references to `topology.nix` are file *names* (e.g., `enable-wg-topology.nix`, `core-router-topology.nix`) — these are the WIP module files and are correctly resolved.

### 3.2 Broken Scripts (Functional Issue)

**Verdict: ❌ FAIL.** Two scripts contain broken references to the old file structure:

#### `scripts/topology-report.sh` (BROKEN)

```
Line 21:  HAS_TOPOLOGY=$(nix eval --json "import ./topology.nix {} | ...")
Line 30:  if [ -f "real-topology/golden/$machine.json" ]; then
Line 65:  HAS_TOPOLOGY=$(nix eval --json "import ./topology.nix | ...")
Line 66:  HAS_GOLDEN=$([ -f "real-topology/golden/$machine.json" ] && ...)
```

- `./topology.nix` no longer exists — it was moved to `topology/shared.nix`
- `real-topology/golden/` no longer exists — goldens moved to `goldens/`
- **Result:** This script will fail on lines 21 and 65 with `error: file 'topology.nix' not found`
- **Impact:** The coverage report cannot be generated. This is a monitoring/observability gap.

#### `scripts/validate-new-architecture.sh` (BROKEN)

```
Line 9:  GOLDEN_FILE="$REPO_DIR/real-topology/golden/cortex-alpha.json"
```

- `real-topology/golden/cortex-alpha.json` no longer exists
- **Result:** Script will fail with file not found
- **Impact:** Legacy test harness is non-functional

**Recommendation:** Fix both scripts to reference `topology/shared.nix` and `goldens/` respectively.

---

## 4. Regression Risk: SSH Multiplexing Revert

### 4.1 Leftover `ssh-mux` References in Nix Code

**Verdict: ⚠ WARNING — 2 instances found in `machines/LINDA/default.nix`**

#### Instance 1: SSH ControlPath (Line 50)
```nix
programs.ssh.extraConfig = ''
  Host hyperhyper
    ControlMaster auto
    ControlPath /run/ssh-mux/%r@%h:%p
    ControlPersist 600
'';
```

#### Instance 2: tmpfiles Rule (Line 255)
```nix
systemd.tmpfiles.rules = [
  ...
  "d /run/ssh-mux 0755 John88 users"
];
```

**Analysis:** These references are NOT from the reverted overlord-II `mkMultiplexConfig` implementation — they are pre-existing LINDA-specific SSH configuration for a host named "hyperhyper". However:
- They use the same `/run/ssh-mux` path that the reverted plan specified
- They create the `/run/ssh-mux` directory via tmpfiles
- The `ControlMaster auto` / `ControlPath` / `ControlPersist 600` pattern IS an SSH multiplexing configuration

**Risk:** LOW. This is a functional SSH multiplexing setup that happens to use the same path pattern as the reverted plan. It is operational and predates overlord-II. Not a regression from the revert. However, it's an untracked SSH multiplexing deployment that exists outside the topology framework.

### 4.2 No `mkMultiplexConfig` or `matchBlocks` References

**Verdict: ✅ PASS.** Grep for `mkMultiplexConfig` and `matchBlocks` in `.nix` files returned zero results. The revert was clean in terms of Nix code. Documentation files still reference these terms for historical context (which is appropriate).

---

## 5. MaxSessions Revert

### 5.1 sshd.nix

**Verdict: ✅ PASS.** `environments/sshd.nix` line 28:
```nix
MaxSessions = 2;
```

Correctly reverted from 20 back to 2. No leftover references to `MaxSessions = 20` found anywhere in the codebase.

---

## 6. Unintended Consequences: `topology/default.nix`

### 6.1 Merge Logic Analysis

```nix
# topology/default.nix lines 12-25
machineFiles = {
  cortex-alpha = import ./cortex-alpha.nix { inherit lib self; };
};

topology = shared // lib.mapAttrs
  (name: machineCfg:
    let
      sharedCfg = shared.${name} or { };
    in
    sharedCfg // machineCfg
  )
  machineFiles;
```

**Verdict: ✅ PASS.** The merge logic is correct:

1. `shared` = all 22 entries from `shared.nix` (cortex-alpha, local-nas, alpha-one, etc.)
2. `lib.mapAttrs` iterates only over keys in `machineFiles` (only `cortex-alpha`)
3. For cortex-alpha: merges `shared.cortex-alpha` with `cortex-alpha.nix` (per-machine takes precedence via `//`)
4. `shared // mergedCortexAlpha` — replaces the shared cortex-alpha entry with the merged version
5. All other machines remain untouched from `shared`

**No evaluation error risk for machines without per-machine files.** The `mapAttrs` function only touches keys present in `machineFiles`.

### 6.2 `generateGolden` Delegation

```nix
generateGolden = machineName:
  let
    generator = import ../lib/golden_generator.nix { inherit lib self; };
  in
  generator.generateGolden machineName;
```

**Verdict: ❌ FORMAT MISMATCH — Confirmed via diff.**

The `generate-golden` app calls `topology.generateGolden` → `lib/golden_generator.nix`, which produces a flat option-value structure. However, the golden files in `goldens/` were ALL generated with `dump-config` (which uses `lib/serialize-config.nix` — a different, more comprehensive serializer). These two serializers produce **drastically different output**.

**Evidence from direct comparison:**

`diff` between `dump-config` and `generate-golden` output for cortex-alpha reveals:

1. **Size difference**: `dump-config` produces ~3,800 lines of comprehensive configuration; `generate-golden` produces ~600 lines (only the options in `safeOptions`)
2. **Missing sections in generate-golden**: Entire `boot.loader.*`, `networking.interfaces.*`, `networking.wireguard.*`, `services.nginx.*`, `security.acme.*` sections present in dump-config are either absent or radically different in generate-golden
3. **Path representation difference**: Store paths are rendered differently:
   - `dump-config`: `"kernel.poweroff_cmd": "<store>/d0y2...systemd-258.7/sbin/poweroff"`
   - `generate-golden`: `"kernel.poweroff_cmd": "/nix/store/d0y2...systemd-258.7/sbin/poweroff"`
4. **Depth**: dump-config produces deeply nested JSON; generate-golden produces a flat key-value map

**The `generate-golden` app is currently dangerous.** If someone runs:
```bash
nix run .#generate-golden -- cortex-alpha > goldens/cortex-alpha.json
```
They would **irrevocably truncate the golden file** from ~3,800 lines to ~600 lines, corrupting the golden test. The `check-network` app correctly uses `dump-config` for comparison, which is why golden tests still pass — but `generate-golden` is a trap.

**Recommendation (HIGH PRIORITY):** Either:
1. **Update `generate-golden`** to use `lib/serialize-config.nix` (making it consistent with `dump-config`)
2. **Or remove `generate-golden` entirely** — it's fully redundant with `dump-config` and actively dangerous

---

## 7. Additional Findings

### 7.1 Prometheus Retention Set to Unlimited

**Verdict: ⚠ CONCERN.** `services/prometheus.nix` line 30:
```nix
retentionTime = "0d";
```

This disables Prometheus data retention, meaning **data accumulates indefinitely**. Without a retention policy, disk usage grows monotonically until the storage volume is full. This is the Prometheus default, but the task description flagged it as a concern.

- `retentionTime = "0d"` means "never delete data based on age"
- `retentionSize` is not set (defaults to 0, meaning unlimited)
- Combined effect: **truly unlimited retention**

**Risk:** Gradual disk exhaustion on the monitoring host (`local-nas`, `10.88.127.3`). Over months of operation, this will consume significant storage. Particularly impactful with 17 machines sending node exporter data at 30s scrape intervals, plus ZFS, NVIDIA GPU, smartctl, and other exporters.

**Recommendation:** Set a concrete retention policy:
```nix
retentionTime = "90d";   # or "180d" for longer history
retentionSize = "50GB";  # cap total storage
```

### 7.2 Stale `real-topology/` Comments

**Verdict: ⚠ COSMETIC.** Three files contain stale `real-topology/` references in comments:

| File | Line | Content | Impact |
|------|------|---------|--------|
| `lib/golden_generator.nix` | 1 | `# real-topology/default.nix` | LOW — comment only |
| `topology/cortex-alpha.nix` | 1 | `# real-topology/cortex-alpha.nix` | LOW — comment only |
| `tests/test-new-architecture.nix` | 52 | `# Import safeOptions from real-topology/default.nix` | LOW — comment only |

These are non-functional but should be cleaned before the Phase C library split to avoid confusion.

### 7.3 `golden_coverage.nix` Exclusion List Opaque

**Verdict: ⚠ CODE SMELL.** `lib/golden_coverage.nix` line 6 excludes these machines from coverage:
```nix
nixosMachines = builtins.attrNames (builtins.removeAttrs self.nixosConfigurations [
  "beta-one" "display-0" "display-1" "display-2" "print-controller"
  "bargman-greeter-vm" "arm-bootstrap"
]);
```

Notable: `display-1`, `display-2`, and `print-controller` ARE in `topology/shared.nix` and HAVE golden files in `goldens/`. The exclusion reasons are unclear — these machines appear fully capable of coverage. Only `beta-one`, `bargman-greeter-vm`, and `arm-bootstrap` are genuinely special (VM, ARM bootstrap). The exclusion list conflates multiple categories.

**Recommendation:** Either add golden coverage for `display-1`, `display-2`, and `print-controller`, or document why they're excluded.

### 7.4 WIP Architecture Status

The WIP `core-router-topology.nix` is confirmed **not wired** into cortex-alpha per `AGENTS.md`. The production `core-router.nix` remains active for cortex-alpha. This is intentional and correct per Phase B sequencing. The WIP `core-router-topology.nix` will be integrated in a future step and MUST pass golden validation at that time.

---

## 8. Findings Summary

| # | Category | Finding | Severity | Status |
|---|----------|---------|----------|--------|
| 1 | flake.nix | Topology import & mkKnownHosts | ✅ PASS | No issues |
| 2 | Golden test | cortex-alpha passes | ✅ PASS | Byte-identical |
| 3a | topology.nix removal | Nix imports clean | ✅ PASS | No leftover refs |
| **3b** | **topology.nix removal** | **scripts/topology-report.sh BROKEN** | **❌ FAIL** | **References old paths** |
| **3c** | **topology.nix removal** | **scripts/validate-new-architecture.sh BROKEN** | **❌ FAIL** | **References old paths** |
| 4a | SSH revert | LINDA has ssh-mux refs | ⚠ WARNING | Pre-existing, not a regression |
| 4b | SSH revert | No mkMultiplexConfig/matchBlocks | ✅ PASS | Clean revert |
| 5 | MaxSessions | Set to 2 in sshd.nix | ✅ PASS | Correctly reverted |
| 6a | topology/default.nix | Merge logic correct | ✅ PASS | No eval errors for partial coverage |
| **6b** | **topology/default.nix** | **generate-golden corrupts goldens** | **❌ FAIL** | **Different format; would truncate 3800→600 lines** |
| **7a** | **Prometheus** | **retentionTime = "0d"** | **⚠ CONCERN** | **Unlimited retention risks disk fill** |
| 7b | Stale comments | real-topology/ in comments | ⚠ COSMETIC | 3 files, comment-only |
| 7c | Coverage | Exclusion list opaque | ⚠ CODE SMELL | display-1/2/print excluded |

---

## 9. Recommendations

### Immediate (Before Phase C Library Split)

1. **Fix `scripts/topology-report.sh`** — Update `./topology.nix` → `./topology/shared.nix` and `real-topology/golden/` → `goldens/`
2. **Fix `scripts/validate-new-architecture.sh`** — Update `real-topology/golden/` → `goldens/`
3. **Fix or remove `generate-golden` (HIGH PRIORITY)** — It produces fundamentally different (truncated) output compared to `dump-config`. If used to regenerate a golden file, it would silently corrupt the golden. Either align it with `lib/serialize-config.nix` or remove the app entirely.
4. **Set Prometheus retention** — Replace `retentionTime = "0d"` with a concrete value (e.g., `"90d"`)

### Before Deployment

5. **Clean stale comments** — Update `# real-topology/` in `lib/golden_generator.nix`, `topology/cortex-alpha.nix`, `tests/test-new-architecture.nix`
6. **Document golden coverage exclusions** — Add rationale comments to `lib/golden_coverage.nix` explaining why display-1, display-2, print-controller are excluded

### Non-Blocking

7. **Review LINDA SSH multiplexing** — The `ControlPath /run/ssh-mux/...` configuration in `machines/LINDA/default.nix` is pre-existing and functional, but should be tracked if a fleet-wide SSH multiplexing solution is later implemented via `extraConfig`
8. **Address deprecation warnings** — 24 obsolete option warnings during `check-network` indicate growing NixOS 25.11 deprecation debt

---

## 10. Verification Record

```
$ nix run .#check-network -- cortex-alpha
✓ Network config matches golden for cortex-alpha

$ grep -r "topology\\.nix" --include="*.nix" | grep -v "enable-wg-topology" | grep -v "core-router-topology"
# (only matched enable-wg-topology.nix and core-router-topology.nix — these are filenames, not imports of root topology.nix)

$ grep -rn "mkMultiplexConfig\|matchBlocks\|ssh-mux" --include="*.nix"
machines/LINDA/default.nix:50:  ControlPath /run/ssh-mux/%r@%h:%p
machines/LINDA/default.nix:255: "d /run/ssh-mux 0755 John88 users"

$ grep -n "MaxSessions" environments/sshd.nix
28:        MaxSessions = 2;
```

---

*Report generated by bellana-deepseek (opencode-go/deepseek-v4-flash). Read-only review — no code changes were made.*
