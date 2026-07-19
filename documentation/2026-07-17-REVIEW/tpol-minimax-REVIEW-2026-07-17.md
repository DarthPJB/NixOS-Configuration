# CI Pipeline Generator Structural Analysis

**Reviewer:** tpol-minimax  
**Date:** 2026-07-17  
**Files Analyzed:**
- `ci.nix` (lines 1-188)
- `ci/generate-workflow.nix` (lines 1-117)
- `ci/README.md`
- `.github/workflows/ci.yml`
- `lib/topology_library.nix`
- `lib/mayo_library.nix`
- `documentation/phase-c-library-split-design.md`
- `flake.nix` (lines 210-380, 580-710)
- `lib/topology/utils.nix`
- `lib/topology/mkWireguardPeers.nix`
- `lib/topology/validate.nix`
- `lib/topology/genWireguard.nix`

---

## 1. Boundary Audit: Generic vs Proprietary

### 1.1 Data Flow Overview

```
ci.nix → generate-workflow.nix → flake.nix → .github/workflows/ci.yml
              ↓
         Python/Shell scripts (json2yaml conversion)
```

### 1.2 Classification of Data Structures and Functions

#### **KETCHUP (Generic) — Extractable**

| Element | Location | Classification | Rationale |
|---------|----------|----------------|-----------|
| `ciJobs` job definitions structure | `ci.nix:29-186` | **KETCHUP** | Generic CI job patterns (validation, build matrix, security scan, deploy). No machine-specific data. |
| `x86Machines` / `armMachines` | `ci.nix:7-27` | **SECRET-SAUCE** | Contains proprietary machine names (e.g., `cortex-alpha`, `terminal-zero`, `LINDA`). Cannot be generalized. |
| `generateGitHubActions` workflow structure | `ci.nix:118-186` | **KETCHUP** | Generic GitHub Actions workflow structure (triggers, permissions, job layout). |
| `mkMatrix` helper | `ci.nix:196-205` | **KETCHUP** | Generic matrix generation for machine types. |
| `mkDeployCommand` helper | `ci.nix:207-217` | **KETCHUP** | Generic deployment command builder. |
| `json2yaml` conversion | `generate-workflow.nix:18-24` | **KETCHUP** | Standard JSON→YAML conversion. |
| `generateScript` shell script | `generate-workflow.nix:27-42` | **KETCHUP** | Generic workflow generation (nix eval → jq → yaml). |
| `validateScript` | `generate-workflow.nix:44-70` | **KETCHUP** | Generic YAML validation. |
| `ciHelpers` exports | `ci.nix:191-217` | **KETCHUP** | Helper functions are platform-generic. |
| `ci` output attribute | `ci.nix:219-240` | **MIXED** | `github-actions` is KETCHUP; `machines` is SECRET-SAUCE. |

#### **SECRET-SAUCE (Proprietary) — Cannot be Generalized**

| Element | Location | Classification | Rationale |
|---------|----------|----------------|-----------|
| Machine names | `ci.nix:7-27` | **SECRET-SAUCE** | Real hostnames: `terminal-zero`, `cortex-alpha`, `LINDA`, `gaming-host-1`, `beta-one`, etc. |
| `workflow_dispatch` inputs | `ci.nix:164-185` | **SECRET-SAUCE** | Machine choices are proprietary. |
| `mkKnownHosts` | `flake.nix:307-360` | **SECRET-SAUCE** | Reads actual public keys from `secrets/public_keys/host_keys/`. |
| `commonModules` | `flake.nix:237-268` | **SECRET-SAUCE** | Contains Bargman-specific secrix config, overlays, hardware. |
| `mkX86_64` / `mkAarch64` | `flake.nix:270-332` | **SECRET-SAUCE** | Hardware-specific modules, deployment configs. |
| `ci` wiring in flake | `flake.nix:361-362` | **SECRET-SAUCE** | `ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; };` |
| `legacyPackages.ci-info` | `flake.nix:706` | **SECRET-SAUCE** | Exposes machine lists externally. |

#### **MAYONNAISE (Shared Helpers)**

| Element | Location | Classification | Rationale |
|---------|----------|----------------|-----------|
| `dedupPreserveOrder` | `lib/topology/utils.nix:5-21` | **MAYONNAISE** | Shared utility used by both CI and topology. |
| `safeLookup` | `lib/topology/utils.nix:24` | **MAYONNAISE** | Shared utility. |
| `isIP`, `isCIDR`, `isIPv4`, `isMAC`, `isPort` | `lib/topology/utils.nix:26-46` | **MAYONNAISE** | Network validation utilities. |

### 1.3 Proprietary Data Entry Points

The proprietary data enters the CI system at these points:

```
Point 1: ci.nix:7-27 (MACHINE_NAMES)
  └── Hardcoded machine names (x86Machines, armMachines)
  └── These names are referenced in:
      - build-x86 matrix (line 53)
      - build-arm matrix (line 83)
      - workflow_dispatch inputs (line 164-185)

Point 2: flake.nix:361-362 (CI_WIRING)
  └── ci = import ./ci.nix { inherit self lib; pkgs = nixpkgs; };
  └── Passes self (the flake) containing all proprietary data

Point 3: flake.nix:706 (CI_INFO_EXPOSURE)
  └── legacyPackages."x86_64-linux".ci-info = ci-generator.ci-info;
  └── Exposes machine lists to external consumers

Point 4: generate-workflow.nix:14 (WORKFLOW_EVALUATION)
  └── workflow = ci.ci.github-actions;
  └── Evaluates the full ci.nix with all proprietary context
```

### 1.4 Current Boundary Violations

**VIOLATION 1:** Machine names are embedded directly in `ci.nix:7-27`. If we wanted to use the CI library for another project, we'd need to edit the source file.

**VIOLATION 2:** `ci.nix` imports nothing from the flake, yet the machine names are hardcoded there. This creates a maintenance burden: adding a new machine requires editing two files (flake.nix AND ci.nix).

**VIOLATION 3:** The `workflow_dispatch` inputs in `ci.nix:164-185` duplicate the machine lists from `x86Machines` and `armMachines`. This is not DRY.

---

## 2. API Design Assessment

### 2.1 Current State (No `lib/ci_library.nix`)

Currently there is NO `lib/ci_library.nix`. The CI code lives in:
- `ci.nix` — Main CI module
- `ci/generate-workflow.nix` — Workflow generator scripts
- `flake.nix:361-362` — Wiring

### 2.2 Proposed API Design for `lib/ci_library.nix`

Based on the topology engine patterns in `lib/topology_library.nix`, I propose:

```nix
# lib/ci_library.nix
# Ketchup — The open-source CI pipeline library.
#
# Usage:
#   ketchup-ci = import ./lib/ci_library.nix { inherit lib; };
#
#   # Generate platform-specific workflow
#   ketchup-ci.generators.genGitHubActions {
#     machines.x86 = [ "machine1" "machine2" ];
#     machines.arm = [ "machine3" ];
#     jobs = ketchup-ci.jobTemplates.standardJobs;
#     triggers = ketchup-ci.triggers.standardTriggers;
#   }
#
#   # Or use job builders
#   ketchup-ci.jobBuilders.mkBuildMatrix {
#     machines = [ "machine1" "machine2" ];
#     runnerType = "self-hosted";
#   }
{ lib }:

let
  # --- Core utilities (Mayer shared) ---
  inherit (import ./topology/utils.nix { inherit lib; })
    dedupPreserveOrder
    safeLookup
    isIP
    isCIDR
    isIPv4
    isMAC
    isPort
    normalizePath
    ;

in
{
  # === JOB TEMPLATES (Generic) ===
  jobTemplates = {
    # Standard CI job set: validation, security, build, deploy
    standardJobs = import ./ci_templates/standardJobs.nix { inherit lib; };

    # Build matrix job template
    mkBuildMatrix = import ./ci_templates/mkBuildMatrix.nix { inherit lib; };

    # Security scan job template
    mkSecurityScan = import ./ci_templates/mkSecurityScan.nix { inherit lib; };
  };

  # === JOB BUILDERS (Generic) ===
  jobBuilders = {
    # Create a build matrix job
    mkBuildMatrix = {
      machines,            # List of machine names
      runnerType ? "self-hosted",  # "self-hosted", "ubuntu-latest", etc.
      needs ? [ "validation" "security" ],
      system ? "x86_64-linux"
    }: { ... };

    # Create validation job
    mkValidationJob = { runnerType ? "self-hosted" }: { ... };

    # Create security scan job
    mkSecurityJob = { ... }: { ... };

    # Create deployment job
    mkDeployJob = {
      machine,         # Single machine name (not list)
      action,         # "build", "test", "deploy"
      runnerType ? "self-hosted",
      needs ? [ "validation" "security" "build-x86" "build-arm" ]
    }: { ... };
  };

  # === WORKFLOW GENERATORS (Generic) ===
  generators = {
    # Generate GitHub Actions workflow
    genGitHubActions = {
      jobs,           # Job definitions
      triggers,       # Trigger configuration
      permissions ? { contents = "read"; deployments = "write"; },
      name ? "NixOS CI/CD"
    }: { ... };

    # Generate GitLab CI workflow
    genGitLabCI = { ... }: { ... };

    # Generate Buildkite pipeline
    genBuildkite = { ... }: { ... };
  };

  # === TRIGGER CONFIGURATIONS (Generic) ===
  triggers = {
    # Standard push/PR triggers
    standardTriggers = {
      push = {
        branches = [ "main" ];
        paths = [ "**.nix" "flake.lock" ];
      };
      pull_request = {
        branches = [ "main" ];
        paths = [ "**.nix" "flake.lock" ];
      };
    };

    # Manual dispatch trigger
    mkManualDispatch = { machines }: {
      workflow_dispatch = {
        inputs = {
          machine = {
            description = "Machine to deploy";
            required = true;
            type = "choice";
            options = machines;
          };
          action = {
            description = "Deployment action";
            required = true;
            type = "choice";
            options = [ "build" "test" "deploy" ];
            default = "build";
          };
        };
      };
    };
  };

  # === VALIDATORS (Generic) ===
  validators = {
    # Validate workflow structure
    validateWorkflow = workflow: {
      valid = bool;
      errors = [ string ];
      warnings = [ string ];
    };

    # Check machine list validity
    validateMachineList = machines: { ... };
  };

  # === SERIALIZERS (Generic) ===
  serializers = {
    # Nix attrset to YAML
    toYAML = obj: { ... };

    # Nix attrset to JSON
    toJSON = obj: { ... };
  };

  # === UTILITIES (Generic) ===
  utils = {
    inherit dedupPreserveOrder safeLookup isIP isCIDR isIPv4 isMAC isPort normalizePath;

    # Generate matrix include entries with system types
    mkMatrixInclude = {
      machines,
      systemByMachine ? (machine: if builtins.elem machine armMachines then "aarch64-linux" else "x86_64-linux")
    }: [ ... ];

    # Build deployment command
    mkDeployCommand = machine: action: string;
  };
}
```

### 2.3 How Secret-Sauce Data Would Be Injected

The key insight from the topology engine is that **data enters through parameters, not imports**:

```nix
# Secret-Sauce (in flake.nix):
let
  # Import ketchup library
  ketchup-ci = import ./lib/ci_library.nix { inherit lib; };

  # Inject proprietary machine lists
  machineLists = {
    x86 = [ "terminal-zero" "cortex-alpha" "LINDA" ... ];
    arm = [ "display-1" "beta-one" ... ];
    all = x86 ++ arm;
  };

  # Build workflow using generic generators + proprietary data
  workflow = ketchup-ci.generators.genGitHubActions {
    jobs = [
      ketchup-ci.jobBuilders.mkValidationJob { runnerType = "self-hosted"; }
      ketchup-ci.jobBuilders.mkBuildMatrix { machines = machineLists.x86; }
      ketchup-ci.jobBuilders.mkBuildMatrix { machines = machineLists.arm; system = "aarch64-linux"; }
      ketchup-ci.jobBuilders.mkDeployJob { machine = machineLists.all; }
    ];
    triggers = ketchup-ci.triggers.standardTriggers // {
      workflow_dispatch = ketchup-ci.triggers.mkManualDispatch { machines = machineLists.all; };
    };
  };
in
{
  # Expose as CI output
  ci = workflow;
}
```

### 2.4 Multi-Platform Support

The API should support multiple CI platforms through a common interface:

```nix
# Platform-agnostic workflow definition
workflowSpec = {
  jobs = [
    { type = "validation"; runner = "self-hosted"; }
    { type = "build-matrix"; machines = [...]; runner = "self-hosted"; needs = ["validation"]; }
    { type = "security-scan"; runner = "ubuntu-latest"; }
    { type = "deploy"; machine = "${inputs.machine}"; action = "${inputs.action}"; }
  ];
  triggers = { push = {...}; pull_request = {...}; workflow_dispatch = {...}; };
};

# Generate for different platforms
githubWorkflow = ketchup-ci.generators.genGitHubActions workflowSpec;
gitlabCI = ketchup-ci.generators.genGitLabCI workflowSpec;
buildkite = ketchup-ci.generators.genBuildkite workflowSpec;
```

### 2.5 Comparison with Topology Engine Pattern

| Aspect | Topology Engine | CI Library (Proposed) |
|--------|-----------------|----------------------|
| Entry point | `lib/topology_library.nix` | `lib/ci_library.nix` (MISSING) |
| Data entry | Parameters to `mkWireguardPeers` | Parameters to generators |
| Generic part | Transformers, generators | Job templates, generators |
| Proprietary part | `topology/*.nix` | `ci.nix` machine lists |
| Validation | `lib/topology/validate.nix` | `ci/validators.nix` (MISSING) |
| Dual pattern support | WIP + Production | Single pattern (needs redesign) |

**Key Lesson from Topology:** The topology engine supports BOTH patterns (WIP with `{ warnings, errors, machines }` return AND production with direct NixOS config return). The CI library should similarly support incremental adoption.

---

## 3. Duplication & Complexity Analysis

### 3.1 Duplication Between `ci.nix` and `ci/generate-workflow.nix`

**OVERLAP ANALYSIS:**

| Element | `ci.nix` | `generate-workflow.nix` | Duplicated? |
|---------|----------|------------------------|-------------|
| `x86Machines` list | Lines 7-20 | Imported via `ci` | ✅ YES |
| `armMachines` list | Lines 22-27 | Imported via `ci` | ✅ YES |
| `ciJobs` | Lines 29-186 | Imported via `ci.ci.jobs` | ✅ YES |
| `generateGitHubActions` | Lines 118-186 | Imported via `ci.ci.github-actions` | ✅ YES |
| `ciHelpers.mkMatrix` | Lines 196-205 | NOT exported | ❌ No |
| `ciHelpers.mkDeployCommand` | Lines 207-217 | NOT exported | ❌ No |

**ASSESSMENT:** There is significant duplication of structure. `generate-workflow.nix` imports `ci.nix` entirely and re-exports most of it unchanged. This adds a layer of indirection without adding value.

**RECOMMENDATION:** Consolidate into a single file (`ci.nix`) with the generator scripts as separate entries in the flake outputs.

### 3.2 Duplication with `flake.nix`

| Element | `flake.nix` | `ci.nix` | Issue |
|---------|-------------|----------|-------|
| Machine definitions | `nixosConfigurations` keys | `x86Machines`, `armMachines` | ❌ **MAJOR** — Not DRY |
| Machine lists | Derived from `nixosConfigurations` | Hardcoded separately | ❌ **MAJOR** — Two sources of truth |
| `workflow_dispatch` options | N/A | Duplicates `x86Machines ++ armMachines` | ❌ **MODERATE** — Triple listing |

**MAJOR ISSUE:** Machine names appear in THREE places:
1. `flake.nix:418-628` — `nixosConfigurations` keys
2. `ci.nix:7-27` — `x86Machines` and `armMachines`
3. `ci.nix:164-185` — `workflow_dispatch.inputs.machine.options`

When adding a new machine, ALL THREE must be updated.

**LESSON FROM TOPOLOGY:** The topology engine uses `topology/shared.nix` as a single source of truth, and transformers read from it. The CI system should similarly derive machine lists from a single source.

### 3.3 JSON → YAML Pipeline Complexity

**Current Pipeline:**
```
ci.nix (Nix attrset)
    ↓
nix eval --json (JSON)
    ↓
jq 'del(.warning)' (JSON filtering)
    ↓
json2yaml Python script (YAML)
    ↓
.github/workflows/ci.yml (file)
```

**COMPLEXITY ASSESSMENT:**

| Layer | File | Purpose | Complexity |
|-------|------|---------|------------|
| 1 | `ci.nix` | Job definitions | LOW — declarative Nix |
| 2 | `nix eval --json` | Nix→JSON conversion | LOW — built-in |
| 3 | `jq 'del(.warning)'` | Remove nix warnings | LOW — simple filter |
| 4 | `json2yaml` (Python) | JSON→YAML conversion | MEDIUM — external dep |
| 5 | `validateScript` (yq) | YAML validation | MEDIUM — external dep |

**ISSUE:** The Python/Shell layer adds complexity without clear benefit. Nix can output YAML directly using `builtins.toJSON` and string manipulation, or we could use a Nix-native YAML library.

**REFERENCE:** The topology engine uses `lib/serialize-config.nix` for golden test serialization. A similar approach could work for CI.

### 3.4 Dead or Redundant Functions

| Function | Location | Status | Notes |
|----------|----------|--------|-------|
| `ciHelpers.mkMatrix` | `ci.nix:196-205` | **UNUSED** | Not called anywhere |
| `ciHelpers.mkDeployCommand` | `ci.nix:207-217` | **UNUSED** | Not called anywhere |
| `ci.ci` output | `ci.nix:219-240` | **MIXED** | `ciHelpers` unused; `machines` and `jobs` are used |
| `generateScript` | `generate-workflow.nix:27-42` | **USED** | Called via `nix run .#generate-ci-workflow` |
| `validateScript` | `generate-workflow.nix:44-70` | **USED** | Called via `nix run .#validate-ci-workflow` |
| `json2yaml` | `generate-workflow.nix:18-24` | **USED** | Used by generateScript |

**DEAD CODE:**
- `mkMatrix` — Defined but never used
- `mkDeployCommand` — Defined but never used

### 3.5 Overcomplicated Patterns

**PATTERN 1: Nested Attrset for Simple Values**

`ci.nix:29-186` wraps everything in `ciJobs = { ... }` then wraps again in `generateGitHubActions = { jobs = ciJobs; ... }`. This nested indirection adds cognitive load without benefit.

**BETTER DESIGN:**
```nix
# Simple flat structure
githubActions = {
  name = "NixOS CI/CD";
  on = { ... };
  jobs = {
    validation = { ... };
    build-x86 = { ... };
    # ...
  };
};
```

**PATTERN 2: Dual Export Structure**

`ci.nix` exports both `ci = { ... }` and `ciHelpers = { ... }`. The helpers should be internal only.

**PATTERN 3: Inconsistent Helper Location**

`ciHelpers` is exported from `ci.nix` but the actual scripts (`generateScript`, `validateScript`) are defined in `generate-workflow.nix`. This split makes it hard to understand where things are.

---

## 4. Ketchup Readiness Score

### 4.1 Data Separation: 2/5

| Criterion | Score | Evidence |
|-----------|-------|----------|
| Proprietary data isolated | 2 | Machine names hardcoded in `ci.nix` |
| Clear boundary | 2 | No library file exists; boundary unclear |
| Injectable parameters | 2 | No parameterization — everything is hardcoded |
| DRY source of truth | 1 | Machine names in 3 places |

**Issues:**
- Machine names (`x86Machines`, `armMachines`) are hardcoded in `ci.nix`
- `workflow_dispatch` options duplicate machine lists
- No way to inject different machine lists without modifying source

### 4.2 API Cleanliness: 2/5

| Criterion | Score | Evidence |
|-----------|-------|----------|
| Clear entry point | 1 | No `lib/ci_library.nix` exists |
| Consistent function signatures | 2 | Mixed patterns (some take params, some don't) |
| Well-defined exports | 2 | `ci` and `ciHelpers` but helpers are unused |
| Documentation | 2 | `ci/README.md` exists but incomplete |

**Issues:**
- No library file = no clean API
- `mkMatrix` and `mkDeployCommand` are dead code
- No validation API
- Inconsistent: some exports are used, some aren't

### 4.3 Platform Agnosticism: 2/5

| Criterion | Score | Evidence |
|-----------|-------|----------|
| Platform-independent core | 2 | Jobs are somewhat generic, but hardcoded to GHA |
| Multiple platform support | 1 | Only GitHub Actions supported |
| Platform abstraction layer | 1 | No abstraction — GHA is baked in |

**Issues:**
- `generateGitHubActions` function name suggests single-platform
- No abstraction for other CI systems (GitLab CI, Buildkite)
- `runs-on`, `uses`, `actions/checkout@v4` are GHA-specific
- Would need complete rewrite to support another platform

### 4.4 Testability: 2/5

| Criterion | Score | Evidence |
|-----------|-------|----------|
| Unit testable components | 2 | Job definitions are pure Nix, testable |
| Integration testable | 2 | `validateScript` exists but basic |
| Golden tests | 1 | No golden test infrastructure for CI |
| Isolated from flake | 1 | Depends on `self` (flake) |

**Issues:**
- No unit tests for job generators
- No golden test for generated YAML (unlike topology with `goldens/*.json`)
- `ci.nix` imports `self` making it flake-dependent
- Cannot test in isolation

### 4.5 Migration Cost: 3/5

| Criterion | Score | Evidence |
|-----------|-------|----------|
| Minimal file changes | 3 | Only 2 files to move, but structure needs redesign |
| Backward compatible | 3 | Can wrap old API in new library |
| Low risk refactor | 3 | Changes are additive, not destructive |
| Clear migration path | 2 | No documented migration plan |

**Issues:**
- Would need to redesign API (breaking change)
- Machine list duplication must be fixed first
- No golden test infrastructure to verify migration
- `flake.nix` wiring would need updates

### 4.6 Summary Scorecard

| Dimension | Score | Max | Issues |
|-----------|-------|-----|--------|
| Data Separation | 2 | 5 | Machine names hardcoded, 3 sources of truth |
| API Cleanliness | 2 | 5 | No library, dead code, inconsistent exports |
| Platform Agnosticism | 2 | 5 | Single platform, no abstraction |
| Testability | 2 | 5 | No unit tests, no golden tests, flake-dependent |
| Migration Cost | 3 | 5 | Moderate refactor needed, additive changes possible |
| **TOTAL** | **11** | **25** | **44%** |

---

## 5. Topology Engine Lessons

### 5.1 What Worked Well in Topology

**LESSON 1: Clear Library Entry Point**

The `lib/topology_library.nix` provides a clean, documented API:
```nix
{ lib }:
{
  transformers = { mkWireguardSettings, mkDnsSettings, ... };
  generators = { genWireguard, genDns, genFirewall, genNginx };
  utils = { safeLookup, dedupPreserveOrder, ... };
  validate = { validateTopology, validateCrossReferences };
  serializeConfig = { serializeConfig };
}
```

**BENEFIT:** Consumers know exactly where to look for functionality.

**LESSON 2: Dual Pattern Support (WIP + Production)**

The topology engine supports two patterns:
1. **WIP Pattern:** Transformers return `{ machines, warnings, errors }`
2. **Production Pattern:** Transformers return direct NixOS config

This allows incremental migration without breaking existing code.

**LESSON 3: Mayo Layer for Shared Utilities**

`lib/mayo_library.nix` exports utilities used by both Ketchup and Secret-Sauce:
```nix
inherit (utils) dedupPreserveOrder safeLookup isIP isCIDR isIPv4 isMAC isPort normalizePath;
mkKnownHosts = import ./mkKnownHosts.nix;
networkInterfaces = import ./network-interfaces.nix;
```

**BENEFIT:** Reduces duplication, provides clear "what's shared" documentation.

**LESSON 4: Validation Infrastructure**

`lib/topology/validate.nix` provides comprehensive validation:
- `validateTopology` — Structure validation
- `validateCrossReferences` — Cross-reference validation

Returns `{ valid, errors, warnings }` for consistent error handling.

**LESSON 5: Golden Tests for Integrity**

The `goldens/*.json` files capture deterministic output for validation:
```bash
nix run .#check-network -- cortex-alpha
```

**BENEFIT:** Detects unintended changes, blocks deployment on mismatch.

### 5.2 Mistakes to Avoid in CI Extraction

**MISTAKE 1: Not Starting with Single Source of Truth**

The CI system has machine names in 3 places. The topology engine initially had the same problem with `topology/shared.nix` and per-machine files.

**FIX FOR CI:** Create a single machine registry (in `topology/shared.nix` or a new `ci/nodes.nix`) and derive all lists from it.

**MISTAKE 2: Adding API Without Validation**

The topology engine has `validate.nix` from the start. The CI library should have validators from day one.

**FIX FOR CI:** Add `lib/ci/validate.nix` immediately:
```nix
# Validate workflow structure
validateWorkflow = workflow: {
  valid = allJobsHaveNames workflow.jobs && allJobsHaveRunsOn workflow.jobs;
  errors = [ ... ];
  warnings = [ ... ];
};

# Validate machine list consistency
validateMachineLists = x86Machines: armMachines: {
  valid = noDuplicates x86Machines armMachines;
  errors = if hasOverlap then [ "Machine in both x86 and arm lists" ] else [ ];
};
```

**MISTAKE 3: Dead Code from Day One**

`mkMatrix` and `mkDeployCommand` were defined but never used. This clutter makes the API harder to understand.

**FIX FOR CI:** Don't add functions until they're needed. Follow YAGNI.

**MISTAKE 4: No Golden Test Infrastructure**

The CI system has no equivalent to `goldens/*.json`. When the CI config changes, there's no automated way to detect drift.

**FIX FOR CI:** Add `ci/goldens/workflow.json`:
```bash
# Generate golden
nix eval --json .#ci.ci.github-actions | jq -S . > ci/goldens/workflow.json

# Validate against golden
nix eval --json .#ci.ci.github-actions | jq -S . | diff - ci/goldens/workflow.json
```

### 5.3 Patterns to Copy from Topology

**PATTERN 1: Transformer → Generator Separation**

Topology has:
- **Transformer:** Takes raw data → produces settings
- **Generator:** Takes settings + hostname → produces NixOS config

CI should have:
- **Job Builder:** Takes machine list + config → produces job definition
- **Workflow Generator:** Takes jobs + triggers → produces workflow

**PATTERN 2: Curried Functions for Reuse**

Topology uses currying:
```nix
# lib/topology/mkWireguardPeers.nix
{ lib }:

topology:   # First arg: topology data

self:       # Second arg: flake reference (for secrets)
```

CI could use:
```nix
# lib/ci/builders.nix
{ lib }:

machineList:    # First arg: list of machines

{
  runnerType ? "self-hosted",  # Partial application
  system ? "x86_64-linux"
}:  # Returns job config
```

**PATTERN 3: Clear Error Messages**

Topology fails with helpful messages:
```nix
throw "WireGuard peer '${peerName}' not found in lan.hosts. Valid hosts: ${...}"
```

CI should similarly fail helpfully:
```nix
throw "Machine '${machine}' not found in registry. Valid machines: ${...}"
```

**PATTERN 4: Documentation at Point of Use**

Every topology file has docstrings:
```nix
/*
  Purpose: Transform topology wireguard config into NixOS wireguard interface config

  Inputs:
  - topology.wireguard.peers: list of peer names
  - topology.lan.hosts: host definitions with IPs and other attributes
  ...
*/
```

CI files should have similar docstrings.

### 5.4 WIP/Legacy Patterns to Avoid

**LEGACY PATTERN 1: Dual Import Paths**

Topology has both:
- Direct imports: `import ./topology/mkWireguardPeers.nix`
- Library imports: `ketchup.transformers.mkWireguardPeers`

This dual path creates confusion about which to use.

**AVOID IN CI:** Pick one pattern and stick to it. Use the library entry point consistently.

**LEGACY PATTERN 2: Inconsistent Transformer Returns**

Some topology transformers return `{ warnings, errors, machines }` (WIP pattern), others return direct NixOS config (production pattern).

**AVOID IN CI:** Be explicit about which pattern each function uses. Document the return type.

**LEGACY PATTERN 3: validateCrossReferences Added Later**

Cross-reference validation was added after initial implementation. This meant fixing issues that could have been caught earlier.

**AVOID IN CI:** Add validation from the start.

---

## 6. Recommendations Summary

### 6.1 Immediate Actions (Before Extraction)

1. **Fix machine list duplication** — Create single source of truth for machine names
2. **Remove dead code** — Delete `mkMatrix` and `mkDeployCommand`
3. **Add CI golden tests** — Create `ci/goldens/workflow.json`
4. **Add validation** — Create `lib/ci/validate.nix`

### 6.2 Create `lib/ci_library.nix`

Structure:
```
lib/
  ci/
    library.nix        # Entry point
    job_templates/
      validation.nix  # Standard validation job
      build_matrix.nix # Build matrix job
      security.nix     # Security scan job
      deploy.nix       # Deployment job
    generators/
      github_actions.nix
      gitlab_ci.nix    # Future
      buildkite.nix    # Future
    validate.nix       # Validation functions
    utils.nix          # Shared utilities
```

### 6.3 API Design Principles

1. **Data through parameters** — Machine lists, job configs passed as arguments
2. **Platform abstraction** — Core logic platform-independent
3. **Validation from day one** — Schema validation for all inputs
4. **Clear error messages** — Fail helpfully with valid options listed
5. **Golden tests** — Capture deterministic output for integrity checks

### 6.4 Migration Path

1. Create `lib/ci_library.nix` with current `ci.nix` functionality
2. Add validation and golden tests
3. Update `flake.nix` to use new library
4. Keep `ci.nix` as thin wrapper for backward compatibility
5. Eventually deprecate `ci.nix`

---

## Appendix A: Current File Map

```
ci.nix
├── x86Machines (SECRET-SAUCE)
├── armMachines (SECRET-SAUCE)
├── ciJobs (KETCHUP)
│   ├── validation (KETCHUP)
│   ├── build-x86 (MIXED - machine list is SECRET-SAUCE)
│   ├── build-arm (MIXED - machine list is SECRET-SAUCE)
│   ├── security (KETCHUP)
│   └── deploy-prep (MIXED - machine list is SECRET-SAUCE)
├── generateGitHubActions (KETCHUP)
├── ciHelpers (KETCHUP)
│   ├── mkMatrix (DEAD CODE)
│   └── mkDeployCommand (DEAD CODE)
└── ci output (MIXED)

ci/generate-workflow.nix
├── Imports ci.nix
├── json2yaml (KETCHUP)
├── generateScript (KETCHUP)
└── validateScript (KETCHUP)

flake.nix
├── ci = import ./ci.nix (SECRET-SAUCE wiring)
├── ci-generator = import ./ci/generate-workflow.nix (SECRET-SAUCE wiring)
├── legacyPackages.ci-info (SECRET-SAUCE exposure)
└── Apps: generate-ci-workflow, validate-ci-workflow, ci (SECRET-SAUCE)
```

## Appendix B: Missing Infrastructure

| Component | Status | Location | Notes |
|-----------|--------|----------|-------|
| Library entry point | **MISSING** | N/A | Need to create `lib/ci_library.nix` |
| Validation | **PARTIAL** | `ci/generate-workflow.nix:validateScript` | Only YAML syntax, no schema validation |
| Golden tests | **MISSING** | N/A | Need `ci/goldens/workflow.json` |
| Machine registry | **DUPLICATED** | `ci.nix`, `flake.nix` | 3 sources of truth |
| Mayo layer | **MISSING** | N/A | No shared utilities between Ketchup/Secret-Sauce CI |
| Multi-platform support | **MISSING** | N/A | Only GitHub Actions |

---

**END OF REPORT**
