# CI Pipeline Generator — Hardening, Parallelism & Ketchup Extraction Plan

> **Created:** 2026-07-17  
> **Updated:** 2026-07-25  
> **Status:** COMPLETE — All 4 phases implemented  
> **Branch:** `overlord-II`  
> **Source:** Review `documentation/2026-07-17-REVIEW/SYNTHESIS.md`  
> **Agents:** bellana-grok-code (implementation), tpol-minimax (verification), bellana-codex (fallback)

---

## Architecture Overview

This plan executes **four phases** in strict sequence. Each phase has multiple serial steps. Each phase terminates with a `tpol-minimax` verification gate. No phase proceeds until the previous phase passes verification.

```
Phase 1: YAML Pipeline Hardening
    │  (fix critical flaws found by tuvok-deepseek)
    ▼
Phase 2: Parallelism Control Injection
    │  (Objective 2: x86 parallel, ARM constrained)
    ▼
Phase 3: CI Golden Tests
    │  (precondition for safe ketchup extraction)
    ▼
Phase 4: Ketchup Library Extraction
       (Objective 1: lib/ci_library.nix)
```

---

## Phase 1: YAML Pipeline Hardening

**Goal:** Fix the three critical flaws in the YAML generation pipeline before touching anything else. Byte-identical output must be preserved.

**Files in scope:**
- `ci/generate-workflow.nix` (lines 44-72)
- `.github/workflows/ci.yml` (regeneration target)

### Step 1.1: Remove `2>/dev/null` — Preserve Error Visibility

**Why:** `2>/dev/null` on `nix eval` discards fatal evaluation errors. A broken `ci.nix` produces an empty YAML file silently, causing CI to deploy nothing.

**File:** `ci/generate-workflow.nix:44`

**Change:** In `generateScript`, change:
```nix
text = ''
  set -euo pipefail
  nix eval --json .#ci.ci.github-actions 2>/dev/null | jq 'del(.warning)' | json2yaml
'';
```
To:
```nix
text = ''
  set -euo pipefail
  nix eval --json .#ci.ci.github-actions | jq 'del(.warning)' | json2yaml
'';
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`. On line 44, remove `2>/dev/null` from the `nix eval` pipeline in the `generateScript` definition. This is in the `text` block of the `pkgs.writeShellApplication` call (around lines 38-44). The exact string to change is `nix eval --json .#ci.ci.github-actions 2>/dev/null`. Remove only the `2>/dev/null` token. Read the file first, then make the single edit. Do NOT change anything else.

**Success criteria:**
- `nix eval --json .#ci.ci.github-actions` now prints stderr to the terminal (visible errors)
- `nix run .#generate-ci-workflow > /tmp/test.yml; diff .github/workflows/ci.yml /tmp/test.yml` — byte-identical output
- `nix run .#validate-ci-workflow` — passes

---

### Step 1.2: Hardened jq Filter — Explicit Key Selection

**Why:** `jq 'del(.warning)'` is fragile. If Nix eval adds unexpected metadata fields (e.g., `trace`, `lastModified`), they survive the filter and produce invalid GitHub Actions YAML. Explicit key whitelist is safer.

**File:** `ci/generate-workflow.nix:44`

**Change:** Change `jq 'del(.warning)'` to `jq '{name, on, permissions, jobs}'`.

```nix
nix eval --json .#ci.ci.github-actions | jq '{name, on, permissions, jobs}' | json2yaml
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`. On the same line edited in Step 1.1 (the `nix eval` pipeline inside `generateScript`'s `text` block), change `jq 'del(.warning)'` to `jq '{name, on, permissions, jobs}'`. This explicitly selects only the known GitHub Actions workflow keys instead of deleting unknown fields. Read the file first. Make only this single change.

**Success criteria:**
- Unexpected Nix metadata fields are stripped from output
- `nix run .#generate-ci-workflow > /tmp/test.yml; diff .github/workflows/ci.yml /tmp/test.yml` — byte-identical
- `nix run .#validate-ci-workflow` — passes

---

### Step 1.3: Deterministic YAML Output — `sort_keys=True`

**Why:** `yaml.dump(data, default_flow_style=False)` produces output where key ordering is not guaranteed across Python versions. This causes spurious `git diff` churn on regeneration.

**File:** `ci/generate-workflow.nix:19-28` (`json2yaml` script)

**Change:** Add `sort_keys=True` to the `yaml.dump()` call:
```python
print(yaml.dump(data, default_flow_style=False, sort_keys=True))
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`. In the `json2yaml` script definition (lines 19-28, the `pkgs.writeScriptBin "json2yaml"` block), change the `yaml.dump` call from `yaml.dump(data, default_flow_style=False, sort_keys=False)` to `yaml.dump(data, default_flow_style=False, sort_keys=True)`. Note: the current line may just be `yaml.dump(data, default_flow_style=False)` — add the `sort_keys=True` parameter. Read the file first to see the exact current state.

**Success criteria:**
- Regenerated YAML is deterministic — running the generator twice produces identical output
- `nix run .#generate-ci-workflow > /tmp/test1.yml && nix run .#generate-ci-workflow > /tmp/test2.yml && diff /tmp/test1.yml /tmp/test2.yml` — empty diff
- `nix run .#validate-ci-workflow` — passes

---

### Verification Gate 1: tpol-minimax

**tpol-minimax verification prompt:**
> Verify Phase 1 completion for the CI pipeline hardening at `/speed-storage/bargman-tech/NixOS-Configuration/`. Check these files:
> 1. `ci/generate-workflow.nix` — confirm: (a) `2>/dev/null` is removed from the nix eval pipeline, (b) `jq` filter uses explicit key selection `{name, on, permissions, jobs}`, (c) `yaml.dump()` includes `sort_keys=True`
> 2. `.github/workflows/ci.yml` — confirm the generated workflow is valid YAML with all required fields
> 3. Run: `nix run .#validate-ci-workflow` — confirm it passes
> 4. Run: generate the workflow twice and diff to confirm deterministic output
> Report: PASS (all checks) or FAIL (specific failure with file:line). If FAIL, the previous step must be re-executed.

---

## Phase 2: Parallelism Control Injection

**Goal:** Inject `--option max-jobs N --option cores N --option builders ''` into CI build steps. x86_64 builds get `auto`/`0`, aarch64 builds get `2`/`2`.

**Files in scope:**
- `ci.nix` (build step definitions, add `formatNixOptions` helper)
- `flake.nix` (add `ciParallelism` struct)
- `.github/workflows/ci.yml` (regeneration)

### Step 2.1: Add `ciParallelism` Struct to `flake.nix`

**Why:** Centralize parallelism tuning in the flake so it can be overridden per-system and per-machine without editing `ci.nix`.

**File:** `flake.nix` — near the CI import block (line ~217)

**Change:** Add a new `ciParallelism` attrset:
```nix
# Parallelism control for CI build jobs
# Can be overridden per-system and per-machine
ciParallelism = {
  default = {
    max-jobs = "auto";
    cores = "0";
  };
  perSystem = {
    aarch64-linux = {
      max-jobs = "2";
      cores = "2";
    };
  };
  # perMachine overrides — uncomment and tune as needed:
  # perMachine = {
  #   LINDA = { max-jobs = "24"; };
  # };
};
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix`. Add a new `ciParallelism` attrset to the `let` block near the existing CI import declarations (around line 217, near where `ci = import ./ci.nix` is defined). The content should be:
> ```nix
> ciParallelism = {
>   default = { max-jobs = "auto"; cores = "0"; };
>   perSystem = {
>     aarch64-linux = { max-jobs = "2"; cores = "2"; };
>   };
> };
> ```
> Place it right before the `ci = import ./ci.nix` line. Read the file first to find the exact insertion point. Do NOT change anything else.

**Success criteria:**
- `nix eval --json --expr '(builtins.getFlake ".").ciParallelism'` returns the struct
- `nix flake check` — no warnings from this change

---

### Step 2.2: Add `formatNixOptions` Helper to `ci.nix`

**Why:** Single function that transforms parallelism settings into `--option` CLI flags. Every build step calls this so `--option builders ''` is never missed (Prime Directive 17).

**File:** `ci.nix` — in the `let` block, before `ciJobs`

**Change:** Add the helper:
```nix
# Resolve parallelism settings: perMachine > perSystem > default
resolveNixSettings = machine: system: parallelism:
  let
    pm = parallelism.perMachine or {};
    ps = parallelism.perSystem or {};
    base = parallelism.default or {};
    merged = base // (ps.${system} or {}) // (pm.${machine} or {});
  in merged;

# Format nix settings as --option flags for CLI
formatNixOptions = machine: system: parallelism:
  let
    settings = resolveNixSettings machine system parallelism;
    maxJobs = settings.max-jobs or null;
    cores = settings.cores or null;
  in
    lib.concatStringsSep " " (lib.filter (s: s != "") [
      "--option builders ''"
      (if maxJobs != null then "--option max-jobs ${toString maxJobs}" else "")
      (if cores != null then "--option cores ${toString cores}" else "")
    ]);
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`. In the `let` block (after the `armMachines` list, before the `ciJobs` definition), add two helper functions: `resolveNixSettings` and `formatNixOptions`. Read the file first. Insert the functions between the `armMachines` list (ending around line 30) and the `ciJobs` definition (starting around line 33). The functions should be:
> ```nix
> resolveNixSettings = machine: system: parallelism:
>   let
>     pm = parallelism.perMachine or {};
>     ps = parallelism.perSystem or {};
>     base = parallelism.default or {};
>     merged = base // (ps.${system} or {}) // (pm.${machine} or {});
>   in merged;
> 
> formatNixOptions = machine: system: parallelism:
>   let
>     settings = resolveNixSettings machine system parallelism;
>     maxJobs = settings.max-jobs or null;
>     cores = settings.cores or null;
>   in
>     lib.concatStringsSep " " (lib.filter (s: s != "") [
>       "--option builders ''"
>       (if maxJobs != null then "--option max-jobs ${toString maxJobs}" else "")
>       (if cores != null then "--option cores ${toString cores}" else "")
>     ]);
> ```
> Add a comment above them: `# Nix parallelism settings — per-machine > per-system > default`. Do NOT change anything else.

**Success criteria:**
- `ci.nix` evaluates without errors
- `nix eval --json .#ci.ci.machines.x86` still works (no regression)

---

### Step 2.3: Pass `ciParallelism` into `ci.nix` from `flake.nix`

**Why:** The helpers need access to the parallelism settings. Wire them through the import.

**File:** `flake.nix:218`

**Change:** Update the `ci` import to pass `parallelism`:
```nix
ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; parallelism = ciParallelism; };
```

**Also:** Update `ci.nix`'s function signature to accept `parallelism`:
```nix
# ci.nix line 1-7
{ self
, lib
, pkgs
, parallelism ? {}  # <-- new parameter
, ...
}:
```

**bellana-grok-code prompt:**
> Two-file edit.
> 
> File 1: `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix`. On the line where `ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; };` (around line 218), add `parallelism = ciParallelism;` to the attrset. The line becomes: `ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; parallelism = ciParallelism; };`
> 
> File 2: `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`. In the function parameter list at the top (lines 3-7), add `, parallelism ? {}` as a new parameter. Place it after `pkgs` and before the ellipsis. Read both files first.
> 
> Make both edits. Do NOT change anything else.

**Success criteria:**
- `nix flake check` — evaluates without error
- `nix eval --json .#ci.ci.machines.x86` — still works

---

### Step 2.4: Inject `--option` Flags into `build-x86` and `build-arm` Steps

**Why:** Apply parallelism settings to the actual CI build commands.

**File:** `ci.nix` — `build-x86` steps (L82-84) and `build-arm` steps (L110-112)

**Change:** Update the `run` lines in both build jobs to use `formatNixOptions`. Note: GitHub Actions matrix variables (`${{ matrix.machine }}`) must be escaped correctly in the Nix string.

For `build-x86`:
```nix
run = "nix build ${
  builtins.replaceStrings ["'"] ["'\\''"] (  # escape for shell
    formatNixOptions "${{ matrix.machine }}" "x86_64-linux" parallelism
  )
} .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel";
```

**Simpler approach:** Since we can't call Nix functions at GitHub Actions runtime, pre-compute the options per system and bake them into the `run` string:

```nix
# Pre-compute options for each system in ci.nix:
x86NixOptions = formatNixOptions "x86-default" "x86_64-linux" parallelism;
armNixOptions = formatNixOptions "arm-default" "aarch64-linux" parallelism;
```

Then in build-x86:
```nix
run = "nix build ${x86NixOptions} .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel";
```

And in build-arm:
```nix
run = "nix build ${armNixOptions} .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel";
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`. This is a multi-part change:
> 
> 1. In the `let` block, right after the `formatNixOptions` function added in Step 2.2, add two pre-computed option strings:
> ```nix
> x86NixOptions = formatNixOptions "x86-default" "x86_64-linux" parallelism;
> armNixOptions = formatNixOptions "arm-default" "aarch64-linux" parallelism;
> ```
> 
> 2. In `ciJobs.build-x86.steps`, find the step with `name = "Build configuration"` (around lines 82-84). Change the `run` line from:
> ```
> run = "nix build .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel";
> ```
> to:
> ```
> run = "nix build ${x86NixOptions} .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel";
> ```
> Note: the `${{ matrix.machine }}` must remain a shell-escaped GitHub Actions variable — the `${x86NixOptions}` is the only Nix interpolation.
> 
> 3. In `ciJobs.build-arm.steps`, find the same step (around lines 110-112). Change the `run` line identically but use `${armNixOptions}` instead of `${x86NixOptions}`.
> 
> Read the file carefully first. Make only these three changes.

**Success criteria:**
- Generated YAML contains `--option builders '' --option max-jobs auto --option cores 0` in build-x86 steps
- Generated YAML contains `--option builders '' --option max-jobs 2 --option cores 2` in build-arm steps
- Regenerate: `nix run .#generate-ci-workflow > .github/workflows/ci.yml`
- `nix run .#validate-ci-workflow` — passes

---

### Step 2.5: Inject `--option` Flags into `deploy-prep` Step

**Why:** The deploy-prep job also runs `nix build` (for the selected machine) and `nix run` (for test/deploy). It needs appropriate parallelism settings based on the selected machine's system type.

**File:** `ci.nix` — `deploy-prep` steps (L195-207)

**Change:** The deploy step builds a single machine selected via `${{ github.event.inputs.machine }}`. We can't pre-compute per-machine options at Nix eval time because the machine is chosen at runtime. Two approaches:

**Approach A (recommended):** Use a shell-level fallback in the run command:
```nix
run = ''
  MACHINE="${{ github.event.inputs.machine }}"
  # ARM machines get constrained parallelism
  case "$MACHINE" in
    arm-builder|display-1|display-2|print-controller|beta-one)
      NIX_OPTS="${armNixOptions}"
      ;;
    *)
      NIX_OPTS="${x86NixOptions}"
      ;;
  esac
  nix build $NIX_OPTS .#nixosConfigurations.$MACHINE.config.system.build.toplevel
'';
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`. In `ciJobs.deploy-prep.steps`, find the "Build configuration" step (around line 195). Change the `run` line from a simple nix build to a case-statement approach. Read the file first to see the exact current content.
> 
> Change from:
> ```
> run = "nix build .#nixosConfigurations.\${{ github.event.inputs.machine }}.config.system.build.toplevel";
> ```
> To:
> ```
> run = ''
>   MACHINE="${{ github.event.inputs.machine }}"
>   ARM_MACHINES="arm-builder display-1 display-2 print-controller beta-one"
>   if echo "$ARM_MACHINES" | grep -qw "$MACHINE"; then
>     NIX_OPTS="${armNixOptions}"
>   else
>     NIX_OPTS="${x86NixOptions}"
>   fi
>   nix build $NIX_OPTS .#nixosConfigurations.$MACHINE.config.system.build.toplevel
> '';
> ```
> 
> Also update the "Test deployment" step (around line 200) and "Deploy to machine" step (around line 205) to prefix with `$NIX_OPTS` similarly. Read the current content of those steps and adapt.
> 
> Note: the Nix interpolation `${armNixOptions}` and `${x86NixOptions}` are evaluated at Nix eval time (they're pre-computed strings). The shell variables `$MACHINE` and `$NIX_OPTS` are evaluated at GitHub Actions runtime. Do not confuse them.

**Success criteria:**
- Generated YAML for deploy-prep includes platform detection and appropriate `--option` flags
- Regenerate: `nix run .#generate-ci-workflow > .github/workflows/ci.yml`
- `nix run .#validate-ci-workflow` — passes

---

### Verification Gate 2: tpol-minimax

**tpol-minimax verification prompt:**
> Verify Phase 2 completion for parallelism control injection at `/speed-storage/bargman-tech/NixOS-Configuration/`. Check:
> 1. `flake.nix` — confirm `ciParallelism` struct exists with `default`, `perSystem.aarch64-linux` entries. Confirm `ci` import passes `parallelism = ciParallelism`.
> 2. `ci.nix` — confirm: (a) `resolveNixSettings` and `formatNixOptions` helpers exist, (b) `parallelism ? {}` is in function params, (c) `x86NixOptions` and `armNixOptions` pre-computed, (d) build-x86 `run` line includes `${x86NixOptions}`, (e) build-arm `run` line includes `${armNixOptions}`, (f) deploy-prep uses case-statement approach
> 3. Regenerate: `nix run .#generate-ci-workflow > /tmp/ci.yml` and inspect the output. Confirm:
>    - build-x86 steps contain `--option builders ''` and `--option max-jobs auto`
>    - build-arm steps contain `--option builders ''` and `--option max-jobs 2` and `--option cores 2`
>    - deploy-prep step contains the ARM detection case statement
> 4. Run `nix run .#validate-ci-workflow` — must pass
> 5. Run `nix flake check` — no new errors
> Report: PASS (all checks) or FAIL (specific failure with file:line). If FAIL, the failing step must be re-executed.

---

## Phase 3: CI Golden Tests

**Goal:** Establish golden test infrastructure for the CI configuration so ketchup extraction (Phase 4) has a safety net. This follows the topology engine's `goldens/*.json` pattern.

**Files in scope:**
- `goldens/ci.json` (new — golden reference)
- `flake.nix` (new `check-ci` app)
- New shell script for CI golden validation

### Step 3.1: Generate Initial CI Golden File

**Why:** Capture the current correct CI config output as the canonical reference.

**Command:**
```bash
nix eval --json .#ci.ci.github-actions | jq -S . > /speed-storage/bargman-tech/NixOS-Configuration/goldens/ci.json
```

**bellana-grok-code prompt:**
> Execute the following command at `/speed-storage/bargman-tech/NixOS-Configuration/`:
> ```
> nix eval --json .#ci.ci.github-actions 2>/dev/null | jq -S . > goldens/ci.json
> ```
> Verify the file was created: `wc -l goldens/ci.json`. Report the line count. If the command fails, report the exact error.

**Success criteria:**
- `goldens/ci.json` exists and is valid JSON
- File is non-empty (expected ~200-500 lines)

---

### Step 3.2: Add `check-ci` Validation App to `flake.nix`

**Why:** Following the `check-network` pattern for topology, provide a `check-ci` app that validates the current CI config against the golden file.

**File:** `flake.nix` — in the `apps."x86_64-linux"` block

**Change:** Add a new app entry:
```nix
check-ci = {
  type = "app";
  meta.description = "Check CI config against golden file";
  program = lib.getExe (nixpkgs.writeShellApplication {
    name = "check-ci";
    runtimeInputs = [ nixpkgs.jq ];
    text = ''
      echo "Checking CI configuration against golden..."
      nix eval --json .#ci.ci.github-actions | jq -S . > /tmp/current-ci.json
      if diff -u "${self}/goldens/ci.json" /tmp/current-ci.json; then
        echo "CI config matches golden"
      else
        echo "CI configuration has changed from golden!"
        echo "If intentional, update with:"
        echo "  nix eval --json .#ci.ci.github-actions | jq -S . > goldens/ci.json"
        exit 1
      fi
    '';
  });
};
```

**bellana-grok-code prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix`. In the `apps."x86_64-linux"` block (the large attrset after `formatter`, around line 225), add a new `check-ci` app entry. Place it near the existing `check-network` app for consistency. Read the file first to find the exact location and understand the app structure pattern.
> 
> Add:
> ```nix
> check-ci = {
>   type = "app";
>   meta.description = "Check CI config against golden file";
>   program = lib.getExe (nixpkgs.writeShellApplication {
>     name = "check-ci";
>     runtimeInputs = [ nixpkgs.jq ];
>     text = ''
>       echo "Checking CI configuration against golden..."
>       ${lib.getExe' nixpkgs.nix "nix"} eval --json .#ci.ci.github-actions | ${lib.getExe nixpkgs.jq} -S . > /tmp/current-ci.json
>       if ${lib.getExe' nixpkgs.diffutils "diff"} -u "${self}/goldens/ci.json" /tmp/current-ci.json; then
>         ${lib.getExe' nixpkgs.coreutils "echo"} "CI config matches golden"
>       else
>         ${lib.getExe' nixpkgs.coreutils "echo"} "CI configuration has changed from golden!"
>         ${lib.getExe' nixpkgs.coreutils "echo"} "If intentional, update with:"
>         ${lib.getExe' nixpkgs.coreutils "echo"} "  nix eval --json .#ci.ci.github-actions | jq -S . > goldens/ci.json"
>         exit 1
>       fi
>     '';
>   });
> };
> ```
> Note: Follow Prime Directive 18 (use `writeShellApplication`, not `writeShellScript`) and Prime Directive 19 (use `lib.getExe` / `lib.getExe'` for ALL tool invocations). The `runtimeInputs` must include `nixpkgs.nix`, `nixpkgs.jq`, `nixpkgs.diffutils`, and `nixpkgs.coreutils`.

**Success criteria:**
- `nix run .#check-ci` — passes (output: "CI config matches golden")
- Modify `ci.nix` temporarily to change a job name, run `nix run .#check-ci` — fails with diff output

---

### Step 3.3: Commit Golden File

**Why:** The golden file must be tracked in git to serve as the canonical reference.

**Command:**
```bash
git add goldens/ci.json
git commit -m "ci: add golden test for CI workflow configuration"
```

**bellana-grok-code prompt:**
> Stage and commit the new golden file at `/speed-storage/bargman-tech/NixOS-Configuration/`. Run:
> ```
> git add goldens/ci.json
> git commit -m "ci: add golden test for CI workflow configuration"
> ```
> Verify with `git log --oneline -1` that the commit was created. Report the commit hash.

**Success criteria:**
- `goldens/ci.json` is tracked in git
- Commit message is concise and descriptive

---

### Verification Gate 3: tpol-minimax

**tpol-minimax verification prompt:**
> Verify Phase 3 completion for CI golden tests at `/speed-storage/bargman-tech/NixOS-Configuration/`. Check:
> 1. `goldens/ci.json` exists, is valid JSON (`jq . goldens/ci.json > /dev/null`), is tracked in git
> 2. `flake.nix` contains `check-ci` app in `apps."x86_64-linux"`
> 3. Run `nix run .#check-ci` — must pass (CI config matches golden)
> 4. Verify the app uses `writeShellApplication` (Prime Directive 18) and `lib.getExe` (Prime Directive 19)
> 5. Confirm the app's text block does not contain bare command names (all must use `lib.getExe` or `lib.getExe'`)
> Report: PASS (all checks) or FAIL (specific failure with file:line). If FAIL, the failing step must be re-executed.

---

## Phase 4: Ketchup Library Extraction

**Goal:** Create `lib/ci_library.nix` as the ketchup entry point, thin `ci.nix` to data-only, simplify `ci/generate-workflow.nix` to wiring. Preserve byte-identical YAML output (verified by golden test from Phase 3).

**Files in scope:**
- `lib/ci_library.nix` (NEW — ketchup entry point)
- `ci.nix` (MODIFY — thin to data-only)
- `ci/generate-workflow.nix` (MODIFY — simplify to wiring)
- `flake.nix` (MODIFY — update imports)
- `goldens/ci.json` (VALIDATE — must not change)

### Step 4.1: Create `lib/ci_library.nix` — Ketchup Entry Point

**Why:** Following `lib/topology_library.nix` pattern, provide a clean API for CI pipeline generation. All generic logic lives here.

**File:** `lib/ci_library.nix` (NEW)

**Content structure:**
```nix
# lib/ci_library.nix
# Ketchup — The open-source CI pipeline library.
#
# Exports all CI pipeline generators, validators, and serializers
# as a clean API. This is the boundary between the generic CI engine
# (Ketchup) and the proprietary machine configs (Secret-Sauce).
#
# Usage:
#   ketchup-ci = import ./lib/ci_library.nix { inherit lib pkgs; };
#   ketchup-ci.mkMatrixJob { machines = [...]; system = "x86_64-linux"; }
#   ketchup-ci.formatNixOptions machine system parallelism
#   ketchup-ci.generateGitHubActions { name, on, jobs, permissions }
{ lib, pkgs }:

let
  # --- Job builders (generic) ---

  # Build a matrix job for a list of machines
  mkMatrixJob = {
    name,
    machines,
    system ? "x86_64-linux",
    nixOptions ? "",
    needs ? [ ],
    runs-on ? "self-hosted",
    fail-fast ? false,
  }: {
    inherit name needs runs-on;
    strategy = {
      inherit fail-fast;
      matrix.machine = machines;
    };
    steps = [
      { name = "Checkout"; uses = "actions/checkout@v4"; }
      { name = "Build configuration"; run = "nix build ${nixOptions} .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel"; }
    ];
  };

  # --- Nix settings helpers (generic) ---

  resolveNixSettings = machine: system: parallelism:
    let
      pm = parallelism.perMachine or {};
      ps = parallelism.perSystem or {};
      base = parallelism.default or {};
      merged = base // (ps.${system} or {}) // (pm.${machine} or {});
    in merged;

  formatNixOptions = machine: system: parallelism:
    let
      settings = resolveNixSettings machine system parallelism;
      maxJobs = settings.max-jobs or null;
      cores = settings.cores or null;
    in
      lib.concatStringsSep " " (lib.filter (s: s != "") [
        "--option builders ''"
        (if maxJobs != null then "--option max-jobs ${toString maxJobs}" else "")
        (if cores != null then "--option cores ${toString cores}" else "")
      ]);

  # --- Workflow generator (generic) ---

  generateGitHubActions = { name, on, jobs, permissions ? { contents = "read"; deployments = "write"; } }: {
    inherit name on permissions jobs;
  };

  # --- Serialization pipeline (generic) ---

  json2yaml = pkgs.writeScriptBin "json2yaml" ''
    #!${pkgs.python3}/bin/python3
    import sys
    import json
    sys.path.append("${pkgs.python3Packages.pyyaml}/${pkgs.python3.sitePackages}")
    import yaml
    data = json.load(sys.stdin)
    print(yaml.dump(data, default_flow_style=False, sort_keys=True))
  '';

  generateWorkflowScript = pkgs.writeShellApplication {
    name = "generate-ci-workflow";
    runtimeInputs = [ pkgs.nix pkgs.jq json2yaml ];
    text = ''
      set -euo pipefail
      nix eval --json .#ci.ci.github-actions | jq '{name, on, permissions, jobs}' | json2yaml
    '';
  };

  validateWorkflowScript = pkgs.writeShellApplication {
    name = "validate-ci-workflow";
    runtimeInputs = [ pkgs.yq ];
    text = ''
      set -euo pipefail
      echo "Validating GitHub Actions workflow..."
      if [ ! -f .github/workflows/ci.yml ]; then
        echo "Workflow file not found. Run: nix run .#generate-ci-workflow > .github/workflows/ci.yml"
        exit 1
      fi
      ${lib.getExe pkgs.yq} -e . .github/workflows/ci.yml > /dev/null
      echo "YAML syntax valid"
      if ${lib.getExe pkgs.yq} -e '.name' .github/workflows/ci.yml > /dev/null && \
         ${lib.getExe pkgs.yq} -e '.on' .github/workflows/ci.yml > /dev/null && \
         ${lib.getExe pkgs.yq} -e '.jobs' .github/workflows/ci.yml > /dev/null; then
        echo "Required fields present"
      else
        echo "Missing required fields"
        exit 1
      fi
      echo "Workflow validation complete!"
    '';
  };

in
{
  # Job builders
  inherit mkMatrixJob;

  # Nix settings
  inherit resolveNixSettings formatNixOptions;

  # Workflow generation
  inherit generateGitHubActions;

  # Serialization
  inherit json2yaml generateWorkflowScript validateWorkflowScript;
}
```

**bellana-grok-code prompt:**
> Create a new file at `/speed-storage/bargman-tech/NixOS-Configuration/lib/ci_library.nix`. This is the Ketchup entry point for the CI pipeline generator. The content should follow this structure (adapting existing code from `ci.nix` and `ci/generate-workflow.nix`):
> 
> ```nix
> { lib, pkgs }:
> 
> let
>   mkMatrixJob = {
>     name, machines, system ? "x86_64-linux", nixOptions ? "",
>     needs ? [ ], runs-on ? "self-hosted", fail-fast ? false,
>   }: {
>     inherit name needs runs-on;
>     strategy = { inherit fail-fast; matrix.machine = machines; };
>     steps = [
>       { name = "Checkout"; uses = "actions/checkout@v4"; }
>       { name = "Build configuration"; run = "nix build ${nixOptions} .#nixosConfigurations.\${{ matrix.machine }}.config.system.build.toplevel"; }
>     ];
>   };
>   
>   resolveNixSettings = machine: system: parallelism:
>     let pm = parallelism.perMachine or {}; ps = parallelism.perSystem or {}; base = parallelism.default or {};
>     in base // (ps.${system} or {}) // (pm.${machine} or {});
>   
>   formatNixOptions = machine: system: parallelism:
>     let settings = resolveNixSettings machine system parallelism;
>         maxJobs = settings.max-jobs or null; cores = settings.cores or null;
>     in lib.concatStringsSep " " (lib.filter (s: s != "") [
>       "--option builders ''"
>       (if maxJobs != null then "--option max-jobs ${toString maxJobs}" else "")
>       (if cores != null then "--option cores ${toString cores}" else "")
>     ]);
>   
>   generateGitHubActions = { name, on, jobs, permissions ? { contents = "read"; deployments = "write"; } }: { inherit name on permissions jobs; };
> 
>   json2yaml = pkgs.writeScriptBin "json2yaml" ''
>     #!${pkgs.python3}/bin/python3
>     import sys, json
>     sys.path.append("${pkgs.python3Packages.pyyaml}/${pkgs.python3.sitePackages}")
>     import yaml
>     data = json.load(sys.stdin)
>     print(yaml.dump(data, default_flow_style=False, sort_keys=True))
>   '';
> 
>   generateWorkflowScript = pkgs.writeShellApplication {
>     name = "generate-ci-workflow";
>     runtimeInputs = [ pkgs.nix pkgs.jq json2yaml ];
>     text = ''set -euo pipefail
>       nix eval --json .#ci.ci.github-actions | jq '{name, on, permissions, jobs}' | json2yaml'';
>   };
> 
>   validateWorkflowScript = pkgs.writeShellApplication {
>     name = "validate-ci-workflow";
>     runtimeInputs = [ pkgs.yq ];
>     text = ''[validation logic from ci/generate-workflow.nix, adapted with lib.getExe]'';
>   };
> in
> {
>   inherit mkMatrixJob resolveNixSettings formatNixOptions generateGitHubActions;
>   inherit json2yaml generateWorkflowScript validateWorkflowScript;
> }
> ```
> 
> For the `validateWorkflowScript`, adapt the existing validation logic from `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix` lines 48-82, converting all bare command names to `lib.getExe` / `lib.getExe'` (Prime Directive 19). The `text` block must use `${lib.getExe pkgs.yq}` instead of bare `yq`.
> 
> Read `ci/generate-workflow.nix` first for exact validation logic. Read `lib/topology_library.nix` for the ketchup entry point pattern. Create the file with the header comment documenting it as the Ketchup CI library entry point.

**Success criteria:**
- `lib/ci_library.nix` exists and evaluates: `nix eval --expr '(import ./lib/ci_library.nix { lib = (import <nixpkgs> {}).lib; pkgs = import <nixpkgs> {}; }).formatNixOptions'` — succeeds
- All exported functions are callable

---

### Step 4.2: Thin `ci.nix` to Data-Only — Import from Ketchup Library

**Why:** `ci.nix` becomes Secret-Sauce: it only defines Bargman-specific machine lists, job data, and triggers. All generic logic is imported from `lib/ci_library.nix`.

**File:** `ci.nix`

**Change:** Replace inline helper functions with ketchup imports. The file becomes:

```nix
{ self, lib, pkgs, parallelism ? {}, ... }:

let
  ciLib = import ./lib/ci_library.nix { inherit lib pkgs; };

  # Secret-Sauce: Bargman-specific machine lists
  x86Machines = [ "terminal-zero" ... ];  # unchanged
  armMachines = [ "arm-builder" ... ];    # unchanged

  # Pre-compute nix options per system
  x86NixOptions = ciLib.formatNixOptions "x86" "x86_64-linux" parallelism;
  armNixOptions = ciLib.formatNixOptions "arm" "aarch64-linux" parallelism;

  # Secret-Sauce: Job definitions (data only)
  ciJobs = {
    validation = { ... };  # unchanged
    build-x86 = ciLib.mkMatrixJob {
      name = "Build x86_64 Configurations";
      machines = x86Machines;
      system = "x86_64-linux";
      nixOptions = x86NixOptions;
      needs = [ "validation" "security" ];
    };
    build-arm = ciLib.mkMatrixJob {
      name = "Build ARM Configurations";
      machines = armMachines;
      system = "aarch64-linux";
      nixOptions = armNixOptions;
      needs = [ "validation" "security" ];
    };
    security = { ... };   # unchanged
    deploy-prep = { ... }; # unchanged
  };

  # Workflow struct using ketchup generator
  githubWorkflow = ciLib.generateGitHubActions {
    name = "NixOS CI/CD";
    on = { /* triggers - unchanged */ };
    jobs = ciJobs;
  };
in
{
  ci = {
    github-actions = githubWorkflow;
    machines = { x86 = x86Machines; arm = armMachines; all = x86Machines ++ armMachines; };
    jobs = ciJobs;
  };
}
```

**bellana-grok-code prompt:**
> Refactor `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix` to import from the new ketchup library `lib/ci_library.nix` instead of defining helpers inline. Read the current file first.
> 
> Changes:
> 1. Add `ciLib = import ./lib/ci_library.nix { inherit lib pkgs; };` at the top of the `let` block
> 2. Replace the inline `resolveNixSettings` and `formatNixOptions` functions (added in Phase 2) with calls to `ciLib.resolveNixSettings` and `ciLib.formatNixOptions`
> 3. Replace `x86NixOptions` and `armNixOptions` to use `ciLib.formatNixOptions`
> 4. Replace the `build-x86` and `build-arm` job definitions to use `ciLib.mkMatrixJob` — only pass the Bargman-specific data (machine names, job names, needs). The generic step structure comes from the library.
> 5. Replace inline `generateGitHubActions` with `ciLib.generateGitHubActions`
> 6. Remove the now-superseded inline helper functions from the `let` block
> 7. Remove the `ciHelpers` export (it was dead code anyway)
> 
> CRITICAL: The final `ci.ci.github-actions` attrset MUST produce byte-identical YAML output. Do NOT change the shape of the data — only change how it's constructed. After your refactor, verify with:
> ```
> nix run .#generate-ci-workflow > /tmp/new.yml
> diff .github/workflows/ci.yml /tmp/new.yml
> ```
> If diff is non-empty, your refactor changed the output — fix it before declaring completion.

**Success criteria:**
- `nix run .#generate-ci-workflow > /tmp/new.yml && diff .github/workflows/ci.yml /tmp/new.yml` — empty (byte-identical)
- `nix run .#check-ci` — passes (golden test)
- `nix run .#validate-ci-workflow` — passes

---

### Step 4.3: Simplify `ci/generate-workflow.nix` to Pure Wiring

**Why:** After ketchup extraction, this file becomes thin wiring — it imports the ketchup library and re-exports the scripts and info. All the logic (json2yaml, generateScript, validateScript) has moved to `lib/ci_library.nix`.

**File:** `ci/generate-workflow.nix`

**Change:** Remove all inline script definitions. Import from ketchup instead.

**bellana-grok-code prompt:**
> Simplify `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`. Read the file first.
> 
> After ketchup extraction, the `json2yaml`, `generateScript`, and `validateScript` definitions have moved to `lib/ci_library.nix`. This file now just imports and re-exports them.
> 
> Change the file to:
> ```nix
> { self, lib, pkgs, ... }:
> 
> let
>   ciLib = import ../lib/ci_library.nix { inherit lib pkgs; };
>   ci = import ../ci.nix { inherit self lib pkgs; };
> in
> {
>   scripts = {
>     generate-ci-workflow = ciLib.generateWorkflowScript;
>     validate-ci-workflow = ciLib.validateWorkflowScript;
>   };
>   workflow = ci.ci.github-actions;
>   ci-info = {
>     x86-machines = ci.ci.machines.x86;
>     arm-machines = ci.ci.machines.arm;
>     all-machines = ci.ci.machines.all;
>     job-count = builtins.length ci.ci.machines.all;
>   };
> }
> ```
> 
> Delete the inline `toYAML`, `workflow`, `json2yaml`, `generateScript`, and `validateScript` definitions — they're now in the library.
> 
> CRITICAL: `nix run .#generate-ci-workflow` must still work and produce identical output.

**Success criteria:**
- `nix run .#generate-ci-workflow > /tmp/new.yml && diff .github/workflows/ci.yml /tmp/new.yml` — empty (byte-identical)
- `nix run .#validate-ci-workflow` — passes
- `nix run .#check-ci` — passes (golden test)
- `nix run .#ci` — CI info app still works

---

### Step 4.4: Update `flake.nix` CI Wiring

**Why:** The CI apps in the flake need to reference the ketchup library's scripts now.

**File:** `flake.nix` — CI app definitions (lines 337-372)

**Change:** The app programs should already reference `ci-generator.scripts.generate-ci-workflow` and `ci-generator.scripts.validate-ci-workflow`. If `ci/generate-workflow.nix` still exports the same `scripts` attrset, this should work unchanged. Verify.

**bellana-grok-code prompt:**
> Inspect `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix` lines 337-372 (the `generate-ci-workflow`, `validate-ci-workflow`, and `ci` app definitions). Confirm they reference `ci-generator.scripts.generate-ci-workflow`, `ci-generator.scripts.validate-ci-workflow`, and `ci.ci.machines` / `ci.ci.jobs` respectively.
> 
> If they already use these paths, no changes needed — the refactored `ci/generate-workflow.nix` exports the same attrset shape. Run `nix run .#generate-ci-workflow > /dev/null` and `nix run .#ci` to verify. Report whether any changes were needed.

**Success criteria:**
- All CI apps work: `generate-ci-workflow`, `validate-ci-workflow`, `ci`
- `nix run .#check-ci` — passes

---

### Step 4.5: Final Regeneration and Validation

**Why:** Commit the regenerated CI workflow and verify everything is clean.

**Commands:**
```bash
nix run .#generate-ci-workflow > .github/workflows/ci.yml
nix run .#validate-ci-workflow
nix run .#check-ci
nix flake check
```

**bellana-grok-code prompt:**
> Execute the final validation sequence at `/speed-storage/bargman-tech/NixOS-Configuration/`:
> 1. `nix run .#generate-ci-workflow > .github/workflows/ci.yml`
> 2. `nix run .#validate-ci-workflow`
> 3. `nix run .#check-ci`
> 4. `nix flake check`
> 
> If all pass, stage and commit all changed files:
> ```
> git add lib/ci_library.nix ci.nix ci/generate-workflow.nix flake.nix goldens/ci.json .github/workflows/ci.yml documentation/2026-07-17-REVIEW/
> git commit -m "ci: extract ketchup library, inject parallelism control, add golden tests"
> ```
> 
> Report results of all checks and the commit hash.

**Success criteria:**
- All checks pass
- All files committed
- `git status` is clean (no uncommitted changes)

---

### Verification Gate 4: tpol-minimax (Final)

**tpol-minimax verification prompt:**
> Perform the FINAL verification of all four phases at `/speed-storage/bargman-tech/NixOS-Configuration/`. Check:
> 
> **Ketchup library:**
> 1. `lib/ci_library.nix` exists, evaluates, exports `mkMatrixJob`, `resolveNixSettings`, `formatNixOptions`, `generateGitHubActions`, `generateWorkflowScript`, `validateWorkflowScript`, `json2yaml`
> 2. Library header comment documents it as the Ketchup CI library entry point
> 
> **Secret-Sauce data:**
> 3. `ci.nix` imports `lib/ci_library.nix`, defines only Bargman-specific data (machine names, triggers)
> 4. `ci/generate-workflow.nix` is thin wiring — no inline script definitions
> 
> **Golden test:**
> 5. `goldens/ci.json` exists and is tracked
> 6. `nix run .#check-ci` — PASSES
> 
> **Parallelism:**
> 7. Generated `ci.yml` build-x86 steps contain `--option builders '' --option max-jobs auto --option cores 0`
> 8. Generated `ci.yml` build-arm steps contain `--option builders '' --option max-jobs 2 --option cores 2`
> 9. Generated `ci.yml` deploy-prep step contains ARM detection logic
> 
> **Integrity:**
> 10. Regenerate workflow: `nix run .#generate-ci-workflow > /tmp/final.yml`
> 11. `diff .github/workflows/ci.yml /tmp/final.yml` — must be EMPTY (byte-identical)
> 12. `nix run .#validate-ci-workflow` — PASSES
> 13. `nix flake check` — no new errors
> 14. Run workflow generation twice: `nix run .#generate-ci-workflow > /tmp/a.yml && nix run .#generate-ci-workflow > /tmp/b.yml && diff /tmp/a.yml /tmp/b.yml` — EMPTY (deterministic)
> 
> **Prime Directive compliance:**
> 15. `lib/ci_library.nix` — `validateWorkflowScript` uses `writeShellApplication` (PD18) and `lib.getExe` / `lib.getExe'` (PD19)
> 16. `flake.nix` — `check-ci` app uses `writeShellApplication` (PD18) and `lib.getExe` (PD19)
> 17. All `nix build` commands in generated workflow include `--option builders ''` (PD17)
> 
> Report: PASS (all 17 checks) or FAIL (specific check number with details).
