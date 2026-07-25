# bellana-codex REVIEW — CI Pipeline Generator: Implementation Feasibility

> **Agent:** bellana-codex
> **Role:** Fast execution specialist — assess concrete implementation cost
> **Date:** 2026-07-17
> **Constraint:** READ-ONLY. No code changes. No file writes. Inspect only.

## Mission

Conduct an **implementation feasibility analysis**. Your focus is on the concrete code changes needed, their complexity, and the exact refactoring cost — not abstract architecture.

## Files to Inspect

Read every line of these:
1. `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`
2. `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`
3. `/speed-storage/bargman-tech/NixOS-Configuration/.github/workflows/ci.yml`
4. `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix` (full file — all 710 lines)
5. `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology/utils.nix` (reference: how utilities are structured)
6. `/speed-storage/bargman-tech/NixOS-Configuration/ci/IMPLEMENTATION_GUIDE.md` (reference: past refactoring patterns)

## Analysis Framework

### 1. Monolith Decomposition: What Moves Where?

Trace every function, constant, and data structure in `ci.nix`. For each, determine its home after ketchup extraction:

| Item | Current Location | Ketchup Home (`lib/ci_library.nix`) | Secret-Sauce Home (`ci.nix`) | Reason |
|------|-----------------|--------------------------------------|------------------------------|--------|
| `x86Machines` list | ci.nix L11-22 | ❌ | ✅ | Bargman machine names |
| `armMachines` list | ci.nix L24-30 | ❌ | ✅ | Bargman machine names |
| `ciJobs.validation` | ci.nix L36-59 | ❌ (partial) | ✅ (data) | Job structure generic, steps/repo specific |
| `ciJobs.build-x86` | ci.nix L63-87 | ❌ (partial) | ✅ (data) | Matrix pattern generic, machine names specific |
| `mkMatrix` helper | ci.nix L295-303 | ✅ | ❌ | Pure function, no proprietary data |
| `mkDeployCommand` helper | ci.nix L307-314 | ✅ | ❌ | Generic command builder |
| `generateGitHubActions` | ci.nix L223-273 | ✅ | ❌ | Pure: attrset → attrset |
| `generateScript` | generate-workflow.nix L31-45 | ✅ | ❌ | Generic Nix → YAML pipeline |
| `validateScript` | generate-workflow.nix L49-82 | ✅ | ❌ | Generic CI file validation |
| `json2yaml` | generate-workflow.nix L19-28 | ✅ | ❌ | Generic serialization |

Be exhaustive — list every item.

### 2. Exact Refactoring Steps (Pseudocode)

Write the step-by-step code changes as if you were implementing them. For each step, state:

```
Step N: [Description]
  Files changed: [path]
  Lines affected: [range]
  Complexity: [Trivial | Simple | Moderate | Complex]
  Risk of breaking CI output: [None | Low | Medium | High]
  Test: [How to verify this step didn't break anything]
```

Include the *exact* new file contents for `lib/ci_library.nix` at a structural level (function signatures, not full implementations).

### 3. Byte-Identical Output Guarantee

The golden rule: after refactoring, `nix run .#generate-ci-workflow` MUST produce byte-identical YAML.

- What is the minimal change that achieves this?
- What Nix language features could accidentally change output (attrset ordering, string interpolation, default values)?
- How do you verify? (Write the exact diff command.)
- Are there any non-deterministic elements in the current pipeline that could mask a regression?

### 4. Parallelism Injection: Concrete Implementation

For the `--option max-jobs N` injection:

- Where exactly in the data flow does the nix settings struct get added?
- What Nix function transforms job steps to inject `--option` flags?
- How do you handle the `builders ''` requirement (Prime Directive 17)?
- What's the minimal change to `ci.nix` to support this?
- What's the minimal change to `flake.nix`?
- Show the EXACT before/after YAML diff for a build step.

Consider the per-machine override scenario:
```nix
nixSettings = {
  default = { max-jobs = "auto"; cores = "0"; };
  perSystem = {
    aarch64-linux = { max-jobs = "2"; cores = "2"; };
  };
  perMachine = {
    "cortex-alpha" = { max-jobs = "24"; };
  };
};
```
How would resolution work? Write the merge/override logic.

### 5. File Impact Summary

Count every file that needs to change:
- New files to create
- Existing files to modify
- Files that can be deleted
- Documentation to update

For each, estimate lines added/removed.

### 6. Complexity & Risk Assessment

- What is the single most complex change in this refactoring?
- What is the single riskiest change?
- If you had to implement this in 30 minutes, what corners would you cut?
- If you had unlimited time, what would you do differently?

## Output

Write your report to `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-17-REVIEW/bellana-codex-REVIEW-2026-07-17.md`.

Format: structured markdown with exact code snippets, file paths, and line numbers. Be concrete — no hand-waving. This report should be detailed enough that a junior engineer could implement the refactoring from it alone.
