# CI Generator — Dependency Reduction & Workflow Flexibility Plan

> **Created:** 2026-07-24  
> **Status:** READY FOR EXECUTION  
> **Source:** Review of ci.nix architecture and ketchup extraction readiness  
> **Prerequisite:** `ci-ketchup-parallelism-PLAN.md` (Phases 1-3 complete)  
> **Agents:** bellana-deepseek (implementation), tpol-minimax (verification)

---

## Objectives

**A. Reduce codebase dependencies** for clean ketchup extraction  
**B. Add workflow flexibility** (head-only vs every-commit, concurrency controls)

---

## Architecture Context

```
Current:
  flake.nix ──► ci.nix ──► lib/ci_library.nix
                 │              │
                 │              └── Hardcoded .#ci.ci.github-actions
                 └── self (unused)

Target:
  flake.nix ──► ci.nix ──► lib/ci_library.nix (parameterized)
                 │              │
                 │              └── workflowAttrPath (configurable)
                 └── No self dependency
```

---

## Phase 1: Dependency Reduction

**Goal:** Remove unnecessary codebase coupling to prepare for ketchup extraction.

### Step 1.1: Remove `self` from `ci.nix` Signature

**Why:** `self` is passed to `ci.nix` from `flake.nix:239` but is never referenced. This creates unnecessary coupling to the flake.

**File:** `ci.nix:3-8`

**Current:**
```nix
{ self
, lib
, pkgs
, parallelism ? { }
, ...
}:
```

**Change to:**
```nix
{ lib
, pkgs
, parallelism ? { }
, ...
}:
```

**Also update `flake.nix:239`:**
```nix
# Current:
ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; parallelism = ciParallelism; };

# Change to:
ci = import ./ci.nix { inherit lib; pkgs = nixpkgs; parallelism = ciParallelism; };
```

**bellana-deepseek prompt:**
> Edit two files to remove the unused `self` dependency:
>
> File 1: `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`
> - Remove `self` from the function parameter list (line 3)
> - Change `{ self` to `{ lib`
>
> File 2: `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix`
> - Find line 239: `ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; parallelism = ciParallelism; };`
> - Change to: `ci = import ./ci.nix { inherit lib; pkgs = nixpkgs; parallelism = ciParallelism; };`
>
> Read both files first. Make only these two changes.

**Success criteria:**
- `nix flake check` — no errors
- `nix eval --json .#ci.ci.machines.x86` — still works
- `nix run .#generate-ci-workflow > /dev/null` — still works

---

### Step 1.2: Parameterize Workflow Attribute Path in Library

**Why:** `lib/ci_library.nix:116` hardcodes `.#ci.ci.github-actions` which is Bargman-specific. For ketchup to be reusable, this must be configurable.

**File:** `lib/ci_library.nix:106-111`

**Current:**
```nix
generateWorkflowScript = pkgs.writeShellApplication {
  name = "generate-ci-workflow";
  runtimeInputs = [
    pkgs.nix
    pkgs.jq
    json2yaml
  ];
  text = ''
    set -euo pipefail

    nix eval --json .#ci.ci.github-actions | jq '{name, on, permissions, jobs}' | json2yaml
  '';
};
```

**Change to:**
```nix
generateWorkflowScript = { workflowAttrPath ? ".#ci.ci.github-actions" }:
  pkgs.writeShellApplication {
    name = "generate-ci-workflow";
    runtimeInputs = [
      pkgs.nix
      pkgs.jq
      json2yaml
    ];
    text = ''
      set -euo pipefail

      nix eval --json ${workflowAttrPath} | jq '{name, on, permissions, jobs}' | json2yaml
    '';
  };
```

**Also update `ci/generate-workflow.nix:13`:**
```nix
# Current:
generate-ci-workflow = ciLib.generateWorkflowScript;

# Change to:
generate-ci-workflow = ciLib.generateWorkflowScript { };
```

**bellana-deepseek prompt:**
> Edit two files to parameterize the workflow attribute path:
>
> File 1: `/speed-storage/bargman-tech/NixOS-Configuration/lib/ci_library.nix`
> - Find the `generateWorkflowScript` definition (around line 106)
> - Change from a direct `pkgs.writeShellApplication` to a function that takes `{ workflowAttrPath ? ".#ci.ci.github-actions" }:` and returns the script
> - The `text` block should use `${workflowAttrPath}` instead of the hardcoded path
>
> File 2: `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`
> - Find line 13: `generate-ci-workflow = ciLib.generateWorkflowScript;`
> - Change to: `generate-ci-workflow = ciLib.generateWorkflowScript { };`
>
> Read both files first. Make only these changes.

**Success criteria:**
- `nix run .#generate-ci-workflow > /dev/null` — still works (uses default path)
- `nix eval --expr '(import ./lib/ci_library.nix { lib = (import <nixpkgs> {}).lib; pkgs = import <nixpkgs> {}; }).generateWorkflowScript { workflowAttrPath = ".#test"; }'` — evaluates

---

### Step 1.3: Add `builders` Option to `formatNixOptions`

**Why:** Prime Directive 17 requires `--option builders ''` on all nix commands. The current `formatNixOptions` includes it, but the `builders` setting should be configurable via the `parallelism` struct.

**File:** `lib/ci_library.nix:28-42`

**Current:**
```nix
formatNixOptions = machine: system: parallelism:
  let
    settings = resolveNixSettings machine system parallelism;
    maxJobs = settings.max-jobs or null;
    cores = settings.cores or null;
    builders = settings.builders or null;
  in
  lib.concatStringsSep " " (lib.filter (s: s != "") [
    (if builders != null then "--option builders ${toString builders}" else "")
    (if maxJobs != null then "--option max-jobs ${toString maxJobs}" else "")
    (if cores != null then "--option cores ${toString cores}" else "")
  ]);
```

**Note:** This is already implemented correctly. The `builders` option is already configurable via the `parallelism` struct. No change needed — this step is already complete.

---

### Verification Gate 1: tpol-minimax

**tpol-minimax verification prompt:**
> Verify Phase 1 completion for dependency reduction at `/speed-storage/bargman-tech/NixOS-Configuration/`. Check:
>
> 1. `ci.nix` — confirm `self` is NOT in the function parameter list
> 2. `flake.nix:239` — confirm `ci` import does NOT pass `self`
> 3. `lib/ci_library.nix` — confirm `generateWorkflowScript` is a function that takes `{ workflowAttrPath ? ".#ci.ci.github-actions" }:` and returns a script
> 4. `ci/generate-workflow.nix:13` — confirm `generate-ci-workflow = ciLib.generateWorkflowScript { };`
> 5. Run: `nix flake check` — no errors
> 6. Run: `nix run .#generate-ci-workflow > /dev/null` — works
> 7. Run: `nix eval --json .#ci.ci.machines.x86` — works
>
> Report: PASS (all checks) or FAIL (specific check with details).

---

## Phase 2: Workflow Flexibility

**Goal:** Add configurable trigger options and concurrency controls to the CI workflow.

### Step 2.1: Add `concurrency` Support to `generateGitHubActions`

**Why:** GitHub Actions concurrency controls prevent redundant builds when multiple pushes happen in quick succession. This is critical for reducing queue depth (see `ci-queue-analytics.md`).

**File:** `lib/ci_library.nix:68-73`

**Current:**
```nix
generateGitHubActions =
  { name
  , on
  , jobs
  , permissions ? {
      contents = "read";
      deployments = "write";
    }
  }: {
    inherit name on permissions jobs;
  };
```

**Change to:**
```nix
generateGitHubActions =
  { name
  , on
  , jobs
  , permissions ? {
      contents = "read";
      deployments = "write";
    }
  , concurrency ? null
  }: {
    inherit name on permissions jobs;
  } // (if concurrency != null then { inherit concurrency; } else { });
```

**bellana-deepseek prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/lib/ci_library.nix`. Find the `generateGitHubActions` function definition (around line 68). Add an optional `concurrency ? null` parameter and include it in the output if not null.
>
> The function should become:
> ```nix
> generateGitHubActions =
>   { name
>   , on
>   , jobs
>   , permissions ? {
>       contents = "read";
>       deployments = "write";
>     }
>   , concurrency ? null
>   }: {
>     inherit name on permissions jobs;
>   } // (if concurrency != null then { inherit concurrency; } else { });
> ```
>
> Read the file first. Make only this change.

**Success criteria:**
- `nix eval --expr '(import ./lib/ci_library.nix { lib = (import <nixpkgs> {}).lib; pkgs = import <nixpkgs> {}; }).generateGitHubActions { name = "test"; on = {}; jobs = {}; concurrency = { group = "test"; }; }'` — includes `concurrency`

---

### Step 2.2: Add Concurrency Configuration to `ci.nix`

**Why:** The Bargman CI workflow should have concurrency controls to prevent queue buildup.

**File:** `ci.nix:218-262`

**Current:**
```nix
generateGitHubActions = ciLib.generateGitHubActions {
  name = "NixOS CI/CD";
  on = { ... };
  permissions = { ... };
  jobs = ciJobs;
};
```

**Change to:**
```nix
generateGitHubActions = ciLib.generateGitHubActions {
  name = "NixOS CI/CD";
  on = { ... };
  permissions = { ... };
  jobs = ciJobs;
  concurrency = {
    group = "\${{ github.workflow }}-\${{ github.ref }}";
    "cancel-in-progress" = true;
  };
};
```

**bellana-deepseek prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`. Find the `generateGitHubActions` call (around line 218). Add a `concurrency` parameter to the attrset:
>
> ```nix
> concurrency = {
>   group = "\${{ github.workflow }}-\${{ github.ref }}";
>   "cancel-in-progress" = true;
> };
> ```
>
> Read the file first. Make only this change.

**Success criteria:**
- `nix run .#generate-ci-workflow > /tmp/ci.yml` — includes `concurrency` block
- `nix run .#validate-ci-workflow` — passes

---

### Step 2.3: Add Trigger Strategy Options to `ci.nix`

**Why:** Different workflows need different trigger strategies. The current config triggers on all pushes. Options include:
- **Head-only:** Only build main branch pushes (reduces queue depth)
- **Every-commit:** Build all pushes (current behavior)
- **PR-only:** Only build PRs (minimal CI)

**File:** `ci.nix:220-251`

**Current:**
```nix
on = {
  push = {
    paths = [
      "**.nix"
      "flake.lock"
      ".github/workflows/**"
    ];
  };
  pull_request = {
    branches = [ "main" ];
    paths = [
      "**.nix"
      "flake.lock"
    ];
  };
  workflow_dispatch = { ... };
};
```

**Change to (head-only strategy):**
```nix
on = {
  push = {
    branches = [ "main" ];  # Only build main branch head
    paths = [
      "**.nix"
      "flake.lock"
      ".github/workflows/**"
    ];
  };
  pull_request = {
    branches = [ "main" ];
    paths = [
      "**.nix"
      "flake.lock"
    ];
  };
  workflow_dispatch = { ... };
};
```

**Alternative (every-commit strategy):**
```nix
on = {
  push = {
    # No branches filter = all pushes trigger
    paths = [
      "**.nix"
      "flake.lock"
      ".github/workflows/**"
    ];
  };
  pull_request = {
    branches = [ "main" ];
    paths = [
      "**.nix"
      "flake.lock"
    ];
  };
  workflow_dispatch = { ... };
};
```

**bellana-deepseek prompt:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`. Find the `on` block in the `generateGitHubActions` call (around line 220). Add a `branches` filter to the `push` trigger:
>
> ```nix
> push = {
>   branches = [ "main" ];
>   paths = [
>     "**.nix"
>     "flake.lock"
>     ".github/workflows/**"
>   ];
> };
> ```
>
> This changes the workflow from "every push" to "head-only" (only main branch pushes trigger builds). PRs still trigger on all branches.
>
> Read the file first. Make only this change.

**Success criteria:**
- `nix run .#generate-ci-workflow > /tmp/ci.yml` — includes `branches: [main]` under `push`
- `nix run .#validate-ci-workflow` — passes

---

### Step 2.4: Parameterize Trigger Strategy (Optional Enhancement)

**Why:** Make trigger strategy configurable without editing `ci.nix` directly.

**File:** `ci.nix` — function parameters

**Add parameter:**
```nix
{ lib
, pkgs
, parallelism ? { }
, triggerStrategy ? "head-only"  # "head-only", "every-commit", "pr-only"
, ...
}:
```

**Then use in `on` block:**
```nix
on = {
  push = if triggerStrategy == "head-only" then {
    branches = [ "main" ];
    paths = [ "**.nix" "flake.lock" ".github/workflows/**" ];
  } else if triggerStrategy == "every-commit" then {
    paths = [ "**.nix" "flake.lock" ".github/workflows/**" ];
  } else {
    # pr-only: no push trigger
  };
  pull_request = {
    branches = [ "main" ];
    paths = [ "**.nix" "flake.lock" ];
  };
  workflow_dispatch = { ... };
};
```

**And update `flake.nix:239`:**
```nix
ci = import ./ci.nix {
  inherit lib;
  pkgs = nixpkgs;
  parallelism = ciParallelism;
  triggerStrategy = "head-only";  # Configurable
};
```

**bellana-deepseek prompt:**
> Edit three files to add trigger strategy parameterization:
>
> File 1: `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`
> - Add `triggerStrategy ? "head-only"` to function parameters
> - Update the `on.push` block to use conditional logic based on `triggerStrategy`
>
> File 2: `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix`
> - Update the `ci` import to pass `triggerStrategy = "head-only";`
>
> File 3: `/speed-storage/bargman-tech/NixOS-Configuration/lib/ci_library.nix`
> - No changes needed — the `on` block is passed through from ci.nix
>
> Read all files first. Make the changes.

**Success criteria:**
- `nix run .#generate-ci-workflow > /tmp/ci.yml` — includes `branches: [main]` under `push`
- `nix eval --json .#ci.ci.github-actions` — includes trigger config
- `nix run .#validate-ci-workflow` — passes

---

### Verification Gate 2: tpol-minimax

**tpol-minimax verification prompt:**
> Verify Phase 2 completion for workflow flexibility at `/speed-storage/bargman-tech/NixOS-Configuration/`. Check:
>
> 1. `lib/ci_library.nix` — confirm `generateGitHubActions` accepts optional `concurrency ? null` parameter
> 2. `ci.nix` — confirm `concurrency` block is included in `generateGitHubActions` call
> 3. `ci.nix` — confirm `on.push` includes `branches = [ "main" ]` (head-only strategy)
> 4. Run: `nix run .#generate-ci-workflow > /tmp/ci.yml` — confirm output includes:
>    - `concurrency` block with `group` and `cancel-in-progress`
>    - `push.branches: [main]`
> 5. Run: `nix run .#validate-ci-workflow` — passes
> 6. Run: `nix flake check` — no errors
>
> Report: PASS (all checks) or FAIL (specific check with details).

---

## Phase 3: Golden Test Update

**Goal:** Update the CI golden test to reflect the new workflow configuration.

### Step 3.1: Regenerate CI Golden File

**Why:** The golden file must reflect the new concurrency and trigger configuration.

**Command:**
```bash
nix eval --json .#ci.ci.github-actions | jq -S . > goldens/ci.json
```

**bellana-deepseek prompt:**
> Execute the following command at `/speed-storage/bargman-tech/NixOS-Configuration/`:
> ```
> nix eval --json .#ci.ci.github-actions | jq -S . > goldens/ci.json
> ```
> Verify the file was updated: `wc -l goldens/ci.json`. Report the line count.

**Success criteria:**
- `goldens/ci.json` is updated with new configuration
- `nix run .#check-ci` — passes

---

### Step 3.2: Regenerate GitHub Actions Workflow

**Why:** The workflow YAML must reflect the new configuration.

**Command:**
```bash
nix run .#generate-ci-workflow > .github/workflows/ci.yml
```

**bellana-deepseek prompt:**
> Execute the following command at `/speed-storage/bargman-tech/NixOS-Configuration/`:
> ```
> nix run .#generate-ci-workflow > .github/workflows/ci.yml
> ```
> Verify the file was updated: `wc -l .github/workflows/ci.yml`. Report the line count.

**Success criteria:**
- `.github/workflows/ci.yml` is updated
- `nix run .#validate-ci-workflow` — passes

---

### Verification Gate 3: tpol-minimax

**tpol-minimax verification prompt:**
> Verify Phase 3 completion for golden test update at `/speed-storage/bargman-tech/NixOS-Configuration/`. Check:
>
> 1. `goldens/ci.json` — exists, is valid JSON, includes `concurrency` block and `push.branches`
> 2. `.github/workflows/ci.yml` — exists, includes `concurrency` block and `push.branches`
> 3. Run: `nix run .#check-ci` — passes
> 4. Run: `nix run .#validate-ci-workflow` — passes
>
> Report: PASS (all checks) or FAIL (specific check with details).

---

## Summary

| Phase | Goal | Key Changes |
|---|---|---|
| **Phase 1** | Dependency reduction | Remove `self` from ci.nix, parameterize workflow path |
| **Phase 2** | Workflow flexibility | Add concurrency controls, head-only triggers |
| **Phase 3** | Golden test update | Regenerate golden and workflow YAML |

### Expected Outcomes

**Before:**
- `ci.nix` depends on `self` (unused)
- `lib/ci_library.nix` hardcodes workflow path
- No concurrency controls (queue buildup)
- All pushes trigger builds (resource waste)

**After:**
- `ci.nix` has minimal dependencies (`lib`, `pkgs`, `parallelism`)
- `lib/ci_library.nix` is parameterized for reuse
- Concurrency controls prevent queue buildup
- Head-only triggers reduce redundant builds

### Files Modified

| File | Changes |
|---|---|
| `ci.nix` | Remove `self`, add `concurrency`, add `branches` filter |
| `lib/ci_library.nix` | Parameterize `generateWorkflowScript` |
| `ci/generate-workflow.nix` | Update `generateWorkflowScript` call |
| `flake.nix` | Update `ci` import (remove `self`) |
| `goldens/ci.json` | Regenerate |
| `.github/workflows/ci.yml` | Regenerate |

---

## Execution Order

1. **Phase 1** — Dependency reduction (Steps 1.1, 1.2)
2. **Phase 2** — Workflow flexibility (Steps 2.1, 2.2, 2.3)
3. **Phase 3** — Golden test update (Steps 3.1, 3.2)

Each phase ends with a verification gate. No phase proceeds until the previous phase passes verification.

---

**Status:** READY FOR EXECUTION  
**Estimated Time:** 1-2 hours  
**Risk:** LOW (incremental improvements, golden test safety net)
