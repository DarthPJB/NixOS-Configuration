# SYNTHESIS — CI Pipeline Generator: Ketchup Readiness & Parallelism Control

> **Commander's Synthesis**  
> **Date:** 2026-07-17  
> **Agents:** tpol-minimax (structural), tuvok-deepseek (adversarial), bellana-codex (implementation)  
> **Status:** COMPLETE

---

## Convergence: What All Three Agents Agree On

### 1. Critical Precondition: CI Golden Tests Must Exist Before Refactoring

| Agent | Finding |
|-------|---------|
| tpol-minimax | "No golden test infrastructure for CI" — readiness score 1/5 for testability |
| tuvok-deepseek | "CRITICAL: Missing golden tests for CI configuration" — #1 priority action item |
| bellana-codex | "Byte-identical output guarantee" requires diff against golden; currently no golden exists |

**Verdict:** All three independently identified the same critical gap. No CI refactoring should proceed without a golden test.

### 2. Machine List Triplication Is the Root Cause

Machine names exist in **three places** — all agents flagged this:
- `flake.nix` — `nixosConfigurations` keys
- `ci.nix:11-30` — `x86Machines`, `armMachines`
- `ci.nix:244-251` — `workflow_dispatch.inputs.machine.options`

| Agent | Finding |
|-------|---------|
| tpol-minimax | "CRITICAL VIOLATION: Machine names in 3 places" — identified as the primary barrier to ketchup extraction |
| tuvok-deepseek | "MEDIUM: Manual synchronization risk demonstrated by historical beta-one omission" (CORRECTION_PLAN) |
| bellana-codex | Decomposition table shows all three lists stay in Secret-Sauce; proposes dynamic derivation from `self.nixosConfigurations` |

**Verdict:** Fix the triplication as part of ketchup extraction. Single source of truth: derive from the flake.

### 3. Ketchup Extraction Is Feasible — Following Topology Engine Pattern

| Agent | Verdict |
|-------|---------|
| tpol-minimax | Readiness score 11/25 (44%). "Extractable but needs API redesign." Proposed complete `lib/ci_library.nix` API with job templates, builders, generators, validators, and serializers. |
| tuvok-deepseek | "Incremental extraction: extract machine lists first, verify golden, repeat for functions." Identified dependency chain breakage risk — fixed by wrapper re-exports. |
| bellana-codex | "Step 1: Create `lib/ci_library.nix` with `mkMatrix`, `mkDeployCommand`, `mkNixCommandOptions`, script generators. Step 2: Thin `ci.nix` to data-only. Step 3: Simplify `ci/generate-workflow.nix` to wiring. Step 4: Update `flake.nix`." |

**Verdict:** Pattern is proven by topology engine. The CI generator follows the same shape but has two anti-patterns to remove first: machine list triplication and dead code.

### 4. Parallelism Control Is Feasible — With Guardrails

| Agent | Verdict |
|-------|---------|
| tpol-minimax | Didn't focus on parallelism (structural review), but API design includes `nixSettings` parameterization |
| tuvok-deepseek | "CRITICAL: Runner core oversubscription. CRITICAL: parallelism × matrix thrashing." Identified 5 concrete failure modes for `--option max-jobs`. Recommends dynamic core detection and separate ARM/x86 parallelism limits. |
| bellana-codex | "formatNixOptions helper with per-machine override resolution: `perMachine.maxJobs || perSystem.maxJobs || default.maxJobs || 0`. Always prepend `--option builders ''`." Provided exact before/after YAML diff and proposed `ciParallelism` struct in `flake.nix`. |

**Verdict:** Feasible, but must be conservative. Start with `max-jobs=2` for ARM, `max-jobs=auto` for x86. Dynamic detection (`nproc`) is safer than hardcoded values. Matrix × Nix parallelism multiplicative thrashing is a real risk that needs mitigation.

### 5. Prime Directive 17 (`--option builders ''`) Is Violated

All agents confirmed: no `nix build` or `nix run` command in the generated CI workflow includes `--option builders ''`. Fix this as part of parallelism injection.

### 6. Dead Code Exists

| tpol-minimax | tuvok-deepseek | bellana-codex |
|-------------|---------------|---------------|
| `mkMatrix` (L295-303) and `mkDeployCommand` (L307-314) are defined but never called | Not explicitly flagged | Proposed moving these into `lib/ci_library.nix` as they're reusable despite being currently unused |

**Verdict:** Don't delete — repurpose. These helpers are correctly designed but need wiring into the core CI jobs.

---

## Divergence: Where Agents Disagree

### The 30-Minute Patch

**bellana-codex** proposed a quick-fix alternative: skip the ketchup library rewrite entirely and just add a `ciParallelism` attrset to `ci.nix` with `--option max-jobs` injection. This would deliver the parallelism objective immediately while deferring ketchup extraction.

**tuvok-deepseek** implicitly argues against this by flagging the YAML generation pipeline as fragile and the lack of golden tests as critical. A quick patch without golden tests is risky.

**tpol-minimax** recommends the full refactor — create the library first, then add parallelism through the clean API.

**Commander's call:** The 30-minute patch is the right tactical approach for **parallelism control** (Objective 2). The full ketchup extraction (Objective 1) is a separate, larger undertaking that needs golden tests first. Do them in sequence: patch parallelism now, ketchup library afterward.

### YAML Generation Pipeline

**tuvok-deepseek** identified three critical flaws in the JSON→YAML pipeline:
1. `2>/dev/null` discards fatal errors
2. `jq 'del(.warning)'` is fragile
3. PyYAML non-deterministic output

**bellana-codex** is confident byte-identical output is achievable by keeping the `ci.ci.github-actions` attrset unchanged.

**tpol-minimax** suggests Nix-native YAML generation to eliminate the Python dependency.

**Commander's call:** tuvok's concerns are valid but bellana-codex's fix is correct. The `2>/dev/null` is dangerous and should be removed. The jq filter should be changed to `jq '{name, on, jobs, permissions}'` to explicitly select known keys. PyYAML non-determinism is mitigated by using `sort_keys=True`. These are one-line fixes that should be included in the parallelism patch.

---

## Recommended Action Plan

### Phase 1: Immediate (Parallelism + Hardening) — 30 minutes

This delivers **Objective 2** (parallelism control) and addresses the critical YAML pipeline flaws tuvok identified.

1. **Fix YAML generation pipeline** (`ci/generate-workflow.nix:44-52`)
   - Remove `2>/dev/null`
   - Change jq filter: `jq '{name, on, permissions, jobs}'` (explicit key selection)
   - Update `PyYAML` call: `yaml.dump(data, default_flow_style=False, sort_keys=True)`

2. **Add `ciParallelism` struct to `flake.nix`**
   ```nix
   ciParallelism = {
     default = { max-jobs = "auto"; cores = "0"; };
     perSystem = {
       aarch64-linux = { max-jobs = "2"; cores = "2"; };
     };
   };
   ```

3. **Inject `--option` flags into build steps** in `ci.nix`
   - Add `formatNixOptions` helper (always includes `--option builders ''`)
   - Update build-x86 step: `nix build --option builders '' --option max-jobs auto ...`
   - Update build-arm step: `nix build --option builders '' --option max-jobs 2 --option cores 2 ...`
   - Update deploy-prep step: inherit system-appropriate settings

4. **Regenerate and validate**
   - `nix run .#generate-ci-workflow > .github/workflows/ci.yml`
   - `nix run .#validate-ci-workflow`
   - Manual diff review of generated YAML

### Phase 2: Ketchup Extraction (Future) — 2 hours

This delivers **Objective 1** (ketchup readiness). Blocked on Phase 1 completion.

1. **Create CI golden test** — `goldens/ci.json`
2. **Create `lib/ci_library.nix`** — following bellana-codex's pseudocode
3. **Thin `ci.nix`** to data-only, importing from library
4. **Simplify `ci/generate-workflow.nix`** to pure wiring
5. **Fix machine list triplication** — derive from `self.nixosConfigurations`
6. **Add `check-ci` app** — `nix run .#check-ci` validates against golden

### Risk Matrix

| Risk | Phase | Severity | Mitigation |
|------|-------|----------|------------|
| YAML output changes from refactor | 1, 2 | Critical | Byte-identical diff verification at every step |
| Runner OOM from parallelism | 1 | High | Start conservative (ARM max-jobs=2), monitor |
| Matrix × Nix parallelism thrashing | 1 | Medium | Acceptable on 48c LINDA; constrain on limited runners |
| Dependency chain breakage | 2 | High | Wrapper re-exports in ci.nix during transition |
| Drift between machine lists | 2 | Medium | Phase 2 derives from single source |

---

## Summary Table

| Question | Answer |
|----------|--------|
| **Ketchup readiness score** | 11/25 (44%) — structural patterns are right, data separation is wrong |
| **Can we extract to ketchup?** | Yes, following the proven topology engine pattern. Create `lib/ci_library.nix`, thin `ci.nix` to data-only. |
| **Can we implement parallelism control?** | Yes. Add `ciParallelism` struct in flake, inject `--option max-jobs N --option builders ''` per job. |
| **What must happen first?** | Fix YAML pipeline (remove `2>/dev/null`, explicit jq filter, sort_keys). Then inject parallelism. Then golden test. Then ketchup extraction. |
| **Biggest risk?** | No golden tests. Any refactoring is blind without them. |
| **Quickest win?** | 30-minute patch: fix YAML pipeline + inject parallelism options. Delivers Objective 2 immediately. |

---

## Review Artifacts

| File | Agent | Lines | Focus |
|------|-------|-------|-------|
| `tpol-minimax-REVIEW-2026-07-17.md` | tpol-minimax | 837 | Structural analysis, API design, topology lessons, readiness scoring |
| `tuvok-deepseek-REVIEW-2026-07-17.md` | tuvok-deepseek | 314 | 15 failure modes, adversarial probing, historical regression analysis |
| `bellana-codex-REVIEW-2026-07-17.md` | bellana-codex | 141 | Step-by-step implementation, byte-identical guarantee, exact YAML diffs |
| `2026-07-17-REVIEW.md` | Commander | — | Scope document and agent prompts |
| `SYNTHESIS.md` | Commander | — | This document |

All files in `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-17-REVIEW/`.
