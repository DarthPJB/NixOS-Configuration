# tuvok-deepseek REVIEW — CI Pipeline Generator: Adversarial Analysis

> **Agent:** tuvok-deepseek
> **Role:** Logical analysis, adversarial probing — find what breaks
> **Date:** 2026-07-17
> **Constraint:** READ-ONLY. No code changes. No file writes. Inspect only.

## Mission

Conduct an **adversarial analysis** of the CI pipeline generator. Your job is to find edge cases, failure modes, security risks, and everything that could go wrong — especially under refactoring for ketchup extraction and parallelism control.

## Files to Inspect

Read every line of these:
1. `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`
2. `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`
3. `/speed-storage/bargman-tech/NixOS-Configuration/.github/workflows/ci.yml` (the generated output)
4. `/speed-storage/bargman-tech/NixOS-Configuration/.github/workflows/ci.yml.example` (legacy reference)
5. `/speed-storage/bargman-tech/NixOS-Configuration/.github/workflows/ci.json` (legacy reference)
6. `/speed-storage/bargman-tech/NixOS-Configuration/ci/CORRECTION_PLAN.md` (historical audit — what broke before?)
7. `/speed-storage/bargman-tech/NixOS-Configuration/ci/IMPLEMENTATION_GUIDE.md`
8. `/speed-storage/bargman-tech/NixOS-Configuration/modifier_imports/remote-builder.nix` (distributed build infra)
9. `/speed-storage/bargman-tech/NixOS-Configuration/modifier_imports/central-builder.nix`

## Analysis Framework

### 1. Regression Risk: What Could a Refactor Break?

Walk through the exact changes needed for ketchup extraction:
- Changing import paths in `flake.nix`
- Extracting functions from `ci.nix` into `lib/ci_library.nix`
- Adding parameterisation for machine lists

For each change, answer:
- What downstream systems depend on the current structure?
- Could the generated `ci.yml` diverge (even by a single byte)?
- What golden tests or validation exist? Are they sufficient?

### 2. YAML Generation Integrity

The current pipeline is: `nix eval --json → jq del(.warning) → PyYAML → stdout`. Probe:
- Are there any Nix attrset values that could produce invalid YAML?
- Can PyYAML's `default_flow_style=False` ever produce ambiguous output?
- What happens if `jq` filters something critical? Why is `.warning` being deleted?
- Is the `set -euo pipefail` in `generateScript` sufficient? What edge cases escape it?
- Could the YAML output change non-deterministically between Nix evaluations?

### 3. Nix Build Parallelism: Failure Modes

The proposed change injects `--option max-jobs N --option cores N` into `nix build` commands. Find the cracks:

- What happens if `max-jobs` exceeds available cores on the self-hosted runner?
- What happens if `--option builders ''` (Prime Directive 17) interacts badly with `max-jobs`?
- Can a machine-specific override break when the machine list changes?
- What happens if the Nix daemon on the runner is already configured with different `max-jobs`?
- Does GitHub Actions' own parallelism (matrix strategy) interact with Nix-level parallelism — could we get N×M build parallelism thrashing memory?
- Are there any system-specific gotchas (RPi aarch64 OOM at low `max-jobs`, ZFS ARC pressure, etc.)?

### 4. Security & Secret Exposure

- Does the CI generator ever touch secrets? Where?
- Could a refactoring accidentally expose secret paths or machine names in generated output?
- The `security` job scans for hardcoded IPs (`10.88.127` range). Could a ketchup refactor change what gets scanned?
- Are there any `builtins.readFile` calls in the CI module that might leak file contents into generated YAML?

### 5. Historical Gotchas

Review `CORRECTION_PLAN.md` and `IMPLEMENTATION_GUIDE.md`. What broke in the past?
- Which past CI bugs would a refactor risk reintroducing?
- Were any past fixes fragile — relying on exact file structure that a refactor would disturb?
- Are there undocumented assumptions (e.g., about runner availability, VPN connectivity) embedded in the CI config?

### 6. Edge Cases for Parallelism

- Machine added to x86 list but has ARM-only deps → cross-compilation triggered → `max-jobs auto` explodes?
- Machine removed from CI but still referenced in `workflow_dispatch.inputs.machine.options`
- `build-x86` and `build-arm` both set `runs-on: self-hosted` — do they contend for the same runner?
- The `deploy-prep` job also runs `nix build` for the selected machine — should it inherit the same nix settings?

## Output

Write your report to `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-17-REVIEW/tuvok-deepseek-REVIEW-2026-07-17.md`.

Format: structured markdown. Prioritise severity — flag critical issues first. For each finding, state: **Severity** (Critical/High/Medium/Low), **Location** (file:line), **Description**, **Reproduction steps**, **Fix recommendation**.
