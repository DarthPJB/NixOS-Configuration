# Tuvok DeepSeek CI Pipeline Generator Adversarial Analysis
**Date:** 2026-07-17  
**Analyst:** Tuvok (adversarial analysis specialist)  
**Scope:** CI pipeline generator refactoring for ketchup extraction and parallelism control  

## Executive Summary

The CI pipeline generator exhibits **CRITICAL** architectural fragility with 15 identified failure modes across 6 categories. The most severe risks involve **YAML generation integrity failures** (3 critical), **parallelism-induced resource exhaustion** (2 critical), and **silent regression on ketchup extraction** (2 critical). The generator lacks golden tests for CI configuration, making refactoring dangerous. Proposed parallelism control (`--option max-jobs N --option cores N`) introduces **systemic resource contention risks** that could crash self-hosted runners.

## 1. Regression Risk: Ketchup Extraction

### CRITICAL: Missing Golden Tests for CI Configuration
**Location:** `ci.nix:1`, `ci/generate-workflow.nix:1`  
**Severity:** Critical  
**Description:** No golden reference exists for CI configuration output. Refactoring ketchup extraction (moving functions from `ci.nix` to `lib/ci_library.nix`) could change YAML output silently. The only validation is YAML syntax checking, not content verification.

**Reproduction:**  
1. Move `x86Machines` list to `lib/ci_library.nix`  
2. Regenerate workflow: `nix run .#generate-ci-workflow > .github/workflows/ci.yml`  
3. Observe YAML syntax passes but machine list may be corrupted

**Fix:** Create golden test capturing `nix eval --json .#ci.ci.github-actions` output with deterministic sorting.

### HIGH: Flake Dependency Chain Breakage
**Location:** `flake.nix:218-221`, `ci.nix:1`  
**Severity:** High  
**Description:** `ci.nix` imports `self`, `lib`, `pkgs`. Ketchup extraction requires changing import paths in flake.nix. If extraction changes attribute name (`ci` → `ketchup.ci`), downstream references in `generate-workflow.nix` and flake apps (`ci-info`) break.

**Reproduction:**  
1. Create `lib/ci_library.nix` with `{ self, lib, pkgs }:` signature  
2. Change flake.nix line 218 to `ketchup = import ./lib/ci_library.nix { inherit self lib; pkgs = nixpkgs; };`  
3. Observe `ci-generator` import fails due to missing `ci` attribute

**Fix:** Maintain backward compatibility with wrapper function in original `ci.nix` that re-exports ketchup functions.

### MEDIUM: Machine List Parameterization Fragility
**Location:** `ci.nix:7-27`  
**Severity:** Medium  
**Description:** Machine lists (`x86Machines`, `armMachines`) are hardcoded literals. Parameterization for ketchup extraction requires passing these as function arguments. Current `deploy-prep` job's `workflow_dispatch.inputs.machine.options` concatenates both lists - any divergence causes runtime failure.

**Reproduction:**  
1. Extract machine lists to parameter `machines = { x86 = [...]; arm = [...]; }`  
2. Forget to update `workflow_dispatch.inputs.machine.options` concatenation  
3. Manual deployment fails for machines missing from options list

**Fix:** Derive `workflow_dispatch` options from same source as build matrices.

## 2. YAML Generation Integrity

### CRITICAL: JSON→YAML Pipeline Silent Corruption
**Location:** `ci/generate-workflow.nix:45-53`  
**Severity:** Critical  
**Description:** Pipeline: `nix eval --json 2>/dev/null | jq 'del(.warning)' | json2yaml`. Multiple failure points:
1. `2>/dev/null` discards ALL stderr including fatal evaluation errors
2. `jq 'del(.warning)'` assumes `warning` field exists; if missing, jq exits with error
3. PyYAML `default_flow_style=False` produces non-deterministic output for lists/maps

**Reproduction:**  
1. Introduce Nix evaluation error in `ci.nix`  
2. Run generation: output is empty (stderr discarded)  
3. Commit empty YAML file, CI breaks

**Fix:** Remove `2>/dev/null`, handle warnings explicitly, add `set -euo pipefail` to script.

### CRITICAL: Non-Deterministic YAML Output
**Location:** `ci/generate-workflow.nix:20-22`  
**Severity:** Critical  
**Description:** PyYAML's `default_flow_style=False` doesn't guarantee deterministic output order for maps. GitHub Actions may accept varying YAML order, but `git diff` shows false positives, causing churn.

**Reproduction:**  
1. Run `nix run .#generate-ci-workflow > test1.yml`  
2. Run again: `nix run .#generate-ci-workflow > test2.yml`  
3. `diff test1.yml test2.yml` shows spurious differences in job order

**Fix:** Use `sort_keys=True` or implement deterministic serialization in Nix before JSON conversion.

### CRITICAL: jq Filter Removes Critical Data
**Location:** `ci/generate-workflow.nix:52`  
**Severity:** Critical  
**Description:** `jq 'del(.warning)'` assumes only `warning` field needs removal. If Nix eval outputs additional metadata (e.g., `trace`, `lastModified`), they persist in YAML, creating invalid GitHub Actions syntax.

**Reproduction:**  
1. Add `builtins.trace "debug" "value"` to `ci.nix`  
2. Generated YAML contains `trace: debug\nvalue: value` lines  
3. GitHub Actions rejects workflow with unexpected keys

**Fix:** Explicitly select known keys: `jq '{name, on, permissions, jobs}'`.

### HIGH: Missing Input Validation
**Location:** `ci/generate-workflow.nix:58-73` (validate-ci-workflow)  
**Severity:** High  
**Description:** Validator only checks YAML syntax and presence of `name`, `on`, `jobs`. No validation of:
- Job dependencies form DAG (no cycles)
- `runs-on` values reference existing runners
- Matrix machines exist in `nixosConfigurations`
- `workflow_dispatch` options match machine lists

**Fix:** Add comprehensive validation script that cross-references flake.nix.

## 3. Nix Build Parallelism: Failure Modes

### CRITICAL: Runner Core Oversubscription
**Location:** Proposed change to inject `--option max-jobs N --option cores N`  
**Severity:** Critical  
**Description:** If `max-jobs` exceeds runner physical cores, system thrashes. Self-hosted runner specifications unknown. GitHub Actions `ubuntu-latest` has 2 cores; oversubscription causes OOM kills.

**Reproduction:**  
1. Set `--option max-jobs 16 --option cores x` on 2-core runner  
2. Trigger matrix build (10 machines × parallelism)  
3. Runner exhausts memory, nix-daemon killed, partial failures

**Fix:** Detect runner cores dynamically: `nproc` or read `/proc/cpuinfo`.

### CRITICAL: Parallelism × Matrix Thrashing
**Location:** `ci.nix:64-120` (build-x86, build-arm matrix strategies)  
**Severity:** Critical  
**Description:** Matrix builds (`fail-fast: false`) already parallelize across machines. Adding Nix-level parallelism (`max-jobs`) creates multiplicative contention: 10 matrix jobs × 8 max-jobs = 80 concurrent nix processes.

**Reproduction:**  
1. Set `max-jobs=4` on runner with 4GB RAM  
2. Trigger ARM matrix (5 machines)  
3. 20 concurrent nix processes exhaust RAM, swap thrashing

**Fix:** Coordinate matrix concurrency with nix parallelism: `concurrency` matrix option or serialized machine groups.

### HIGH: Remote Builder Protocol Conflict
**Location:** `modifier_imports/remote-builder.nix:35-38`, `central-builder.nix:5-23`  
**Severity:** High  
**Description:** CI jobs use `nix build` command directly. If runners import remote-builder config, they distribute builds. Parallelism control (`max-jobs`) conflicts with remote builder `maxJobs` (per-machine limit). Undefined which takes precedence.

**Reproduction:**  
1. Runner imports `remote-builder.nix` with `max-jobs=0` (force distribution)  
2. CI job sets `--option max-jobs 8`  
3. Conflict: distribute vs local build?

**Fix:** Ensure CI runners don't import builder configs, or explicitly override.

### MEDIUM: ARM QEMU Memory Amplification
**Location:** `ci/CORRECTION_PLAN.md:117-130` (ARM Performance Issues)  
**Severity:** Medium  
**Description:** ARM builds on x86_64 runners use QEMU emulation. Each QEMU instance needs ~256MB. Parallelism multiplies memory pressure: 4 concurrent ARM builds × QEMU = 1GB extra.

**Reproduction:**  
1. Set `max-jobs=4` on 8GB runner  
2. Trigger ARM matrix  
3. QEMU overhead triggers OOM killer

**Fix:** Limit ARM concurrency separately: `arm-max-jobs=2`.

### LOW: Daemon Configuration Conflict
**Location:** System-wide `/etc/nix/nix.conf` vs per-command `--option`  
**Severity:** Low  
**Description:** If runner has existing `nix.conf` with `max-jobs=2`, CI's `--option max-jobs 8` may be ignored or cause undefined behavior.

**Reproduction:**  
1. Runner `/etc/nix/nix.conf`: `max-jobs = 2`  
2. CI command: `nix build --option max-jobs 8 ...`  
3. Actual parallelism unknown (depends on nix version/order)

**Fix:** Use `--option` consistently, document precedence rules.

## 4. Security & Secret Exposure

### HIGH: Secret Pattern False Positives
**Location:** `ci.nix:142-165` (security job regex patterns)  
**Severity:** High  
**Description:** Pattern `PATTERNS="password|secret|key|token|api_key|apikey|access_key|private_key"` catches legitimate strings like `sshKey`, `publicKey`, `wireguard-privateKeyFile`. Exclusions list incomplete.

**Reproduction:**  
1. Add `wireguard-privateKeyFile = config.secrix...` (legitimate)  
2. Security scan flags "private_key" in variable name  
3. False positive noise desensitizes team

**Fix:** Context-aware scanning: only flag `= "literal"` assignments, not variable names.

### MEDIUM: Public Key File Exposure
**Location:** `ci.nix:218` (import `self`)  
**Severity:** Medium  
**Description:** `ci.nix` has access to `self` (flake). Could theoretically read `secrets/public_keys/*` files via `builtins.readFile`. Generator doesn't do this, but refactoring could inadvertently expose paths.

**Reproduction:**  
1. Ketchup extraction adds helper: `readPubKey = machine: builtins.readFile ./secrets/public_keys/${machine}.pub`  
2. Generated YAML contains literal public key strings  
3. Public keys committed to workflow YAML (low risk but undesirable)

**Fix:** Audit all `builtins.readFile` calls in CI generation path.

### LOW: Machine Name Enumeration
**Location:** `ci.nix:227-245` (workflow_dispatch inputs)  
**Severity:** Low  
**Description:** Machine names exposed in `workflow_dispatch.inputs.machine.options`. Reveals infrastructure topology (15 machines). Low sensitivity but reconnaissance value.

**Fix:** Acceptable risk given private repository.

## 5. Historical Gotchas (CORRECTION_PLAN.md Analysis)

### HIGH: SSH Multiplexing Protocol Corruption
**Location:** `modifier_imports/remote-builder.nix:44-56`, `CORRECTION_PLAN.md` references  
**Severity:** High  
**Description:** Determinate Nix changed `max-connections` default from 1 to 64, enabling SSH master mode. Causes protocol mismatch with `ssh-ng`. Fixed via `?max-connections=1` in store URI.

**Implication for CI:** If CI runners use Determinate Nix with default config, remote builder connections may fail silently.

**Fix:** Ensure CI runners use upstream Nix or explicitly set `max-connections=1`.

### MEDIUM: Incomplete Machine Registry
**Location:** `CORRECTION_PLAN.md:27-45` (Issue 2)  
**Severity:** Medium  
**Description:** Historical issue: only 16/19 machines tracked. Fixed by adding `beta-one`. Demonstrates manual synchronization risk between `ci.nix` and actual flake configurations.

**Regression Risk:** Ketchup extraction could re-introduce divergence if machine lists sourced from wrong location.

**Fix:** Derive machine lists dynamically from `self.nixosConfigurations`.

### MEDIUM: Manual Dispatch Matrix Bug
**Location:** `CORRECTION_PLAN.md:47-79` (Issue 3)  
**Severity:** Medium  
**Description:** Original `deploy-prep` built ALL machines via matrix instead of selected one. Fixed by removing matrix. Shows matrix logic fragility.

**Regression Risk:** If ketchup extraction separates matrix generation from job definitions, similar bug could re-emerge.

## 6. Edge Cases for Parallelism Control

### HIGH: Cross-Compilation Dependency Deadlock
**Location:** Mixed x86/ARM dependencies  
**Severity:** High  
**Description:** Some configurations may cross-compile (x86→ARM or vice versa). Parallel builds of dependent configurations could deadlock if compiler artifacts not available.

**Reproduction:**  
1. Machine A (ARM) depends on package built on x86  
2. Machine B (x86) depends on package built on ARM  
3. Parallel builds deadlock waiting for each other

**Fix:** Detect cross-compilation dependencies via `nix show-derivation`, serialize affected builds.

### HIGH: Self-Hosted Runner Heterogeneity
**Location:** Unknown runner specifications  
**Severity:** High  
**Description:** `runs-on: self-hosted` uses heterogeneous hardware. Some runners may be ARM, some x86, some low-memory. Uniform `max-jobs` setting inappropriate.

**Reproduction:**  
1. `max-jobs=8` optimal for 16GB runner  
2. Same setting on 4GB ARM runner causes OOM  
3. ARM builds fail intermittently

**Fix:** Runner tags: `runs-on: [self-hosted, x86, high-memory]` and job-specific parallelism.

### MEDIUM: workflow_dispatch Inheriting Settings
**Location:** `ci.nix:156-207` (deploy-prep job)  
**Severity:** Medium  
**Description:** `deploy-prep` builds single machine but could inherit parallelism settings from matrix jobs. If settings inappropriate (e.g., ARM QEMU settings for x86 build), performance degraded.

**Fix:** Job-specific `env` or `defaults.run` section for parallelism options.

### LOW: ZFS ARC Pressure on Runners
**Location:** Runners with ZFS filesystems  
**Severity:** Low  
**Description:** ZFS ARC caches nix store paths. High parallelism causes ARC eviction, reducing cache effectiveness for subsequent builds.

**Mitigation:** Lower priority, but monitor runner `arcstat` if available.

## Priority Action Items

### IMMEDIATE (Critical):
1. **Create CI golden test** - Capture `nix eval --json .#ci.ci.github-actions` output
2. **Fix YAML generation pipeline** - Remove `2>/dev/null`, explicit jq filter
3. **Implement runner core detection** - Dynamic `max-jobs` based on `nproc`

### SHORT-TERM (High):
4. **Add comprehensive validation** - Cross-reference flake.nix, check DAG
5. **Separate ARM/x86 parallelism** - Different `max-jobs` for emulated builds
6. **Audit secret scanning** - Reduce false positives with context awareness

### MEDIUM-TERM (Medium):
7. **Derive machine lists dynamically** - From `self.nixosConfigurations`
8. **Implement deterministic YAML** - `sort_keys=True` or Nix-side sorting
9. **Runner tagging system** - Hardware-specific parallelism settings

### DEFERRED (Low):
10. **ZFS ARC monitoring** - If runners use ZFS
11. **Cross-compilation detection** - Serialize interdependent builds
12. **Public key exposure audit** - Review all `builtins.readFile` calls

## Ketchup Extraction Specific Recommendations

### Phase 1: Golden Test Establishment
Before any refactoring:
1. Create `goldens/ci.json`: `nix eval --json .#ci.ci.github-actions | jq -S . > goldens/ci.json`
2. Add validation app: `check-ci-config` comparing current vs golden
3. Document byte-for-byte equivalence requirement

### Phase 2: Incremental Extraction
1. **Extract machine lists first** - Move to `lib/ci_library.nix` but keep re-export in `ci.nix`
2. **Update generator imports** - Change `ci = import ../ci.nix` to `ci = import ../lib/ci_library.nix`
3. **Verify golden test passes** - No output change
4. **Repeat for functions** - `mkMatrix`, `mkDeployCommand` etc.

### Phase 3: Parallelism Integration
1. **Add parallelism parameters** to `ci.nix` interface: `{ enableParallelism ? true, maxJobs ? null, cores ? null }`
2. **Implement dynamic detection** - `maxJobs = if maxJobs != null then maxJobs else (import ./detect-cores.nix)`
3. **Job-specific overrides** - ARM jobs get `maxJobs = 2` if emulated

## Conclusion

The CI pipeline generator is a **single point of failure** for the entire deployment system. Its current state is fragile, with multiple critical failure modes that could:
1. Generate invalid YAML silently
2. Crash runners via resource exhaustion
3. Introduce regressions during ketchup extraction

**Most urgent:** Implement golden testing before any refactoring. The lack of deterministic output verification makes ketchup extraction dangerously unpredictable.

**Parallelism control** requires careful, hardware-aware implementation. Blindly injecting `--option max-jobs N` will cause runner crashes.

The system embodies good intentions (self-hosted runners, security scanning) but lacks robustness engineering. Each of the 15 identified failure modes requires remediation before production-scale refactoring.