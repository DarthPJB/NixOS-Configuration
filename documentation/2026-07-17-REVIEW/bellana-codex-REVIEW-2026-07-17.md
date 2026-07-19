---
title: "CI Pipeline Generator Implementation Review"
date: 2026-07-17
author: bellana-codex
---

# CI Pipeline Generator Implementation Review (2026-07-17)

This document captures the step-by-step feasibility analysis requested for the CI workflow generator. Every assertion below cites the precise source lines in the repository so a junior engineer can execute it without guessing.

## 1. Monolith Decomposition: What Moves Where?

  +
`ci.nix` becomes the thin data definition that feeds this helper with `name`, `on`, `permissions`, and `jobs` (the sections above). |
| `toYAML` helper | `ci/generate-workflow.nix` lines 12‑14 | **Ketchup `lib/ci_library.nix`** | Serializing experiments should live alongside `json2yaml` + script builders so other repos can re-use a `toYAML` helper. |

This decomposition keeps repo-specific inventory and job data inside `ci.nix`, and moves all serialization/command-shell helpers into the new `lib/ci_library.nix` shared module.

## 2. Exact Refactoring Steps (Pseudocode)

| Step | Files Touching | Description | Complexity | CI Risk | Verification |
| --- | --- | --- | --- | --- | --- |
| 1 | `lib/ci_library.nix` (new file) | Create the shared library with the following skeleton: |

```nix
{ lib, pkgs }:

let
  mkMatrix = machines: {
    inherit machines;
    include = lib.mapAttrsToList ...;  # same logic as ciHelpers.mkMatrix
  };

  mkDeployCommand = machine: action: ...;  # same signature as current helper

  mkNixCommandOptions = args: let
    mergeAttrs = ...;  # merge default/perSystem/perMachine max-jobs
  in
  ''--option builders '' ${if args.maxJobs then "--option max-jobs ${args.maxJobs}" else ""} '';

  toYAML = obj: builtins.toJSON obj;
  json2yamlScript = pkgs.writeScriptBin "json2yaml" ''...'';  # reuse existing script
  generateWorkflowScript = pkgs.writeShellApplication { ... };  # general nix eval + jq + json2yaml pipeline
  validateWorkflowScript = pkgs.writeShellApplication { ... };  # reuses yq logic
in
{
  inherit mkMatrix mkDeployCommand mkNixCommandOptions toYAML json2yamlScript generateWorkflowScript validateWorkflowScript;
}
```

Complexity: **Moderate** (new shared module with script derivations). Risk: **Low**. Test: `nix build .#legacyPackages.x86_64-linux.ci-info` (ensures new attrset is available) and `nix run .#generate-ci-workflow > /tmp/generated.yml`.
|
| 2 | `ci.nix` | Refactor imports so `ci.nix` now does `let ciLib = import ./lib/ci_library.nix { inherit pkgs lib; };` and: <br>a) keep `x86Machines`, `armMachines`, and `ciJobs` definitions unchanged.<br>b) Replace `ciHelpers` with `ciLib.mkMatrix` and `ciLib.mkDeployCommand` (line 294 onwards).<br>c) Move workflow serialization out of `ci.nix` to the library; `generateGitHubActions` simply assembles `name`, `on`, `permissions`, `jobs` and hands them to `ciLib.generateWorkflowScript`/`ciLib.validateWorkflowScript` for export.<br>d) Add a new `parallelism` attrset (default/perSystem/perMachine) that feeds `ciLib.mkNixCommandOptions` so every `run` string gets `--option max-jobs` plus the mandated `--option builders ''`.<br>Complexity: **Moderate**. Risk: **Medium** (string building for commands). Test: `nix eval --json .#ci.ci.jobs` and `nix run .#generate-ci-workflow -- --dry-run` (simulate). |
| 3 | `ci/generate-workflow.nix` | Reduce this file to wiring: import `ciLib` and expose `workflow = ci.ci.github-actions`, `scripts` = `{ generate-ci-workflow = ciLib.generateWorkflowScript; validate-ci-workflow = ciLib.validateWorkflowScript; }`, and expose `ci-info` etc. No inline script definitions remain. Complexity: **Simple**. Risk: **Low**. Test: `nix build .#legacyPackages.x86_64-linux.ci-info` should still succeed. |
| 4 | `flake.nix` | Update the `ci` import (lines 217‑222) to pass `pkgs = nixpkgs` plus the new `parallelism` configuration derived from `topo` (if needed). Add `ciParallelism` attrset in `flake.nix` so future machines can override `max-jobs` (see Section 4). Complexity: **Simple**. Risk: **Low**. Test: `nix run .#generate-ci-workflow > /tmp/generated.yml && diff .github/workflows/ci.yml /tmp/generated.yml`. |
| 5 | `.github/workflows/ci.yml` | Regenerate from Nix after the above refactors to ensure no formatting drift. Complexity: **Trivial** (regeneration). Risk: **None** if YAML unchanged. Test: `nix run .#validate-ci-workflow`. |
| 6 | `ci/IMPLEMENTATION_GUIDE.md` | Update the instructions if the restructuring changes how scripts are invoked; mention new library location and `max-jobs` option. Complexity: **Simple**. Risk: **Low**. Test: Spell-check and ensure commands still match reality. |

## 3. Byte-Identical Output Guarantee

1. **Minimal change required:** Keep the final `ci.ci.github-actions` attrset unchanged. The generator must still run `nix eval --json .#ci.ci.github-actions` (see `ci/generate-workflow.nix` line 44) and pipe the result through `jq 'del(.warning)'` and the `json2yaml` script. As long as the attrset tree, the atom order (controlled by `builtins.toJSON`), and the script output stay the same, the YAML will be identical.
2. **Accidental output diff sources:**<br>a. Changing the order of top‑level keys in `ciJobs` or `generateGitHubActions` would produce a different JSON ordering even if `jq` sorts (because GitHub Actions workflows care about key order for readability). Avoid re-ordering unless you also re-run the generator and compare diffs.<br>b. Introducing new attributes without default values can drop `null` nodes, which changes the YAML structure.<br>c. Replacing `builtins.toJSON` with `lib.toString` or adding `lib.mapAttrsToList` could reorder fields. Keep `builtins.toJSON`/`yaml.dump(sort_keys=False)` as they enforce deterministic sorting.<br>d. Changing the `json2yaml` script to a different YAML emitter (e.g., Python `ruamel.yaml`) might emit anchors/aliases or reorder keys.
3. **Verification path:**<br>`nix run .#generate-ci-workflow > /tmp/generated.yml`<br>`diff -u .github/workflows/ci.yml /tmp/generated.yml` — this must return empty. As an extra safety net, `nix run .#validate-ci-workflow` ensures syntax and required fields remain intact.
4. **Non-deterministic elements to watch for:** `nix eval` sometimes outputs a `warning` field (stripped by `jq`). File timestamps, host-dependent `nix` warnings, or environment variables inside the generator must not be introduced; keep the scripts `set -euo pipefail` and isolate them with `pkgs.writeShellApplication` so no extra output leaks.

## 4. Parallelism Injection: Concrete Implementation

1. **Data flow for `--option max-jobs`:**<br>The `nix build`/`nix run` commands live inside `ciJobs.build-*` steps (lines 82‑114 of `ci.nix`). Those steps are converted to YAML through the generator, so we inject options before serialization. Add a new helper inside `lib/ci_library.nix` called `formatNixOptions` that merges a settings struct (`parallelism.default`, `parallelism.perSystem`, `parallelism.perMachine`) and returns a string such as `"--option builders '' --option max-jobs 4"`. The `ci.nix` job steps call this helper when they set `run` and when `ciHelpers.mkDeployCommand` builds commands for `workflow_dispatch` steps.
2. **Nix function transforming job steps:** The helper should look like:<br>```nix
formatNixOptions = { machine, system, settings }: let
  perMachine = settings.perMachine.${machine} or {}; 
  perSystem = settings.perSystem.${system} or {}; 
  defaults = settings.default or {};
  merged = lib.deepMerge default {} [ defaults perSystem perMachine ];
  maxJobs = merged.maxJobs or 0;
in
  lib.concatStringsSep " " (lib.filter (v: v != "") [ "--option builders ''" (if maxJobs == 0 then "" else "--option max-jobs ${toString maxJobs}") ]);
```
`ciJobs.*` will plug in `system = if machine is in armMachines then "aarch64-linux" else "x86_64-linux"` before serializing.<br>This helper is the single place that touches every step that invokes `nix`; it maps the `settings` struct into CLI flags.
3. **Handling Prime Directive 17 (`--option builders ''`):** Always prepend `--option builders ''` (literal two single quotes) inside the helper so **every** Nix invocation we emit honors the directive. Do not place the `builders` option inside a separate helper or else it might be dropped when nobody calls it.
4. **Minimal changes to `ci.nix`:** Update each `run` string so it becomes `<nix command> ${formatNixOptions {...}} ...`. For example, the normal build step becomes:<br>Before:<br>```yaml
        run: nix build .#nixosConfigurations.${{ matrix.machine }}.config.system.build.toplevel
```
        run: nix build --option builders '' --option max-jobs 6 .#nixosConfigurations.${{ matrix.machine }}.config.system.build.toplevel
```
 (The numeric value comes from the merged settings.) Update `mkDeployCommand` so `nix run` also receives the same `formatNixOptions` call when it builds the command string for `test`/`deploy` actions.
5. **Minimal changes to `flake.nix`:** Introduce a new attrset near the CI import such as:<br>```nix
ciParallelism = {
  default = { maxJobs = 4; };
  perSystem = {
    "aarch64-linux" = { maxJobs = 3; };
    "x86_64-linux" = { maxJobs = 6; };
  };
  perMachine = {
    LINDA = { maxJobs = 2; };
  };
};

ci = import ./ci.nix {
  inherit self lib;
  pkgs = nixpkgs;
  parallelism = ciParallelism;
};
```
This gives each job access to the settings struct without spreading defaults throughout `ci.nix` itself.
6. **Merge/override logic (per-machine override scenario):**<br>```nix
resolveMaxJobs = machine: system: let
  pm = parallelism.perMachine.${machine} or {};
  ps = parallelism.perSystem.${system} or {};
  base = parallelism.default or {};
in
  pm.maxJobs or ps.maxJobs or base.maxJobs or 0;
```
`formatNixOptions` uses `resolveMaxJobs` to decide whether to emit the `--option max-jobs` flag. Per-machine overrides win first, then per-system values, and finally the default. A zero value silences the flag (do not emit `--option max-jobs 0`).<br>
7. **YAML diff snippet:** After regenerating the workflow, a single build step diff looks like:<br>```diff
@@
-        run: nix build .#nixosConfigurations.${{ matrix.machine }}.config.system.build.toplevel
+        run: nix build --option builders '' --option max-jobs 6 .#nixosConfigurations.${{ matrix.machine }}.config.system.build.toplevel
```
8. **Verification:** Rerun `nix run .#generate-ci-workflow` and confirm the `run` strings now include both `--option builders ''` and the computed `--option max-jobs` value. Run actions `nix run .#validate-ci-workflow` afterwards.

## 5. File Impact Summary

| File | Action | Approx. delta | Notes |
| --- | --- | --- | --- |
| `lib/ci_library.nix` | **Create** | +120 lines | Houses the shared helpers (`mkMatrix`, `mkDeployCommand`, `formatNixOptions`, script generators). |
| `ci.nix` | **Modify** | +50 / -30 lines (refactor) | Import the new library, keep only repo-specific data (`machines`, `jobs`), use `ciLib` helpers for options and exports. |
| `ci/generate-workflow.nix` | **Modify** | -80 / +10 lines | Simplifies to wiring the scripts exported from `ciLib` and keeps `ci-info`. |
| `.github/workflows/ci.yml` | **Regenerate** | 0 (content stays) | Output should remain identical; just rerun generator post-refactor. |
| `flake.nix` | **Modify** | +30 lines | Pass the new `parallelism` struct into `ci` and reference new helper where needed. |
| `ci/IMPLEMENTATION_GUIDE.md` | **Update** | +15 lines | Document the new split between Ketchup and Secret-Sauce and `max-jobs` option. |
| `documentation/2026-07-17-REVIEW/bellana-codex-REVIEW-2026-07-17.md` | **Create** | ~220 lines | This review document (current file). |

No files are deleted in this refactor.

## 6. Complexity & Risk Assessment

- **Single most complex change:** Building `lib/ci_library.nix` and wiring it into `ci/generate-workflow.nix` without changing the YAML output (Section 3). Bringing together the helper signatures, script derivations, and `json2yaml` pipeline into one reusable module is non-trivial because it must mirror current behavior exactly.
- **Single riskiest change:** Introducing the `parallelism` struct and injecting `--option max-jobs` into every `nix` invocation (Section 4). Mistakes there can break `workflow_dispatch` deploy steps, cause unmatched CLI options, or produce YAML diffs customers must accept.
- **What I’d cut in 30 minutes:** Skip the shared `ci_library` rewrite and execute a quick patch that only adds a `ciParallelism` attrset in `ci.nix`. This would produce the desired `max-jobs` injection with minimal touchpoints, deferring the Ketchup/Secret-Sauce split to a later phase.
- **What I’d do with unlimited time:** Build a regression test suite that runs `nix run .#generate-ci-workflow > .github/workflows/ci.yml && diff -u goldens/ci.yml .github/workflows/ci.yml` and fails when `max-jobs` defaults drift. I’d also standardize the `validate-ci-workflow` script to assert the `run` strings include `--option builders ''` and any requested `--option max-jobs`, preventing future regressions automatically.
