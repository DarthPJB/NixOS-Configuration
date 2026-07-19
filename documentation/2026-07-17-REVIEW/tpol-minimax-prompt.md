# tpol-minimax REVIEW — CI Pipeline Generator: Structural Analysis

> **Agent:** tpol-minimax
> **Role:** Research prep, synthesis — structural architecture review
> **Date:** 2026-07-17
> **Constraint:** READ-ONLY. No code changes. No file writes. Inspect only.

## Mission

Conduct a **structural analysis** of the CI pipeline generator at `/speed-storage/bargman-tech/NixOS-Configuration/`. Your focus is on architecture, boundaries, API design, and ketchup extractability.

## Files to Inspect

Read every line of these files:
1. `/speed-storage/bargman-tech/NixOS-Configuration/ci.nix`
2. `/speed-storage/bargman-tech/NixOS-Configuration/ci/generate-workflow.nix`
3. `/speed-storage/bargman-tech/NixOS-Configuration/ci/README.md`
4. `/speed-storage/bargman-tech/NixOS-Configuration/.github/workflows/ci.yml`
5. `/speed-storage/bargman-tech/NixOS-Configuration/lib/topology_library.nix` (reference: how ketchup was extracted for topology)
6. `/speed-storage/bargman-tech/NixOS-Configuration/lib/mayo_library.nix` (reference: mayo pattern)
7. `/speed-storage/bargman-tech/NixOS-Configuration/documentation/phase-c-library-split-design.md` (reference: split philosophy)
8. `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix` (lines 210-380 — CI wiring section)

## Analysis Framework

### 1. Boundary Audit: What is Generic vs Proprietary?

For each file and each significant data structure/function in the CI system, classify as:

| Classification | Definition |
|---------------|------------|
| **Ketchup (generic)** | No Bargman-specific data; purely functional; would work in any NixOS repo |
| **Mayo (shared helper)** | Utility that both ketchup and secret-sauce need |
| **Secret-Sauce (proprietary)** | Contains machine names, IPs, branch names, runner labels, repo details |

Trace the data flow: `ci.nix` → `generate-workflow.nix` → `flake.nix` → output YAML. At which points does proprietary data enter?

### 2. API Design Assessment

If we were to create `lib/ci_library.nix` (ketchup), what should its API look like? Consider:
- What functions should it export?
- What parameters do they need?
- How would Secret-Sauce data be injected?
- Can the generation pipeline be parameterized to support multiple CI platforms (GitHub Actions, GitLab CI, Buildkite)?

Compare against the topology engine's successful pattern:
```nix
# Topology pattern (proven):
ketchup = import ./lib/topology_library.nix { inherit lib; };
topology = import ./topology/default.nix;  # proprietary data
ketchup.transformers.mkWireguardPeers topology self;  # generic + data
```

Can the CI generator follow the same shape?

### 3. Duplication & Complexity

- Are there duplicated patterns between `ci.nix` and `ci/generate-workflow.nix`?
- Does the CI system duplicate concepts already present in `flake.nix` (e.g., machine lists)?
- Is the JSON → YAML pipeline overcomplicated? Could it be simplified?
- Are there dead or redundant helper functions?

### 4. Ketchup Readiness Score

Rate the CI generator on each dimension (1-5):

| Dimension | What to assess |
|-----------|---------------|
| **Data separation** | How cleanly can data be separated from logic? |
| **API cleanliness** | How well can the logic be wrapped in a clean function API? |
| **Platform agnosticism** | How GitHub-Actions-specific is the output format? |
| **Testability** | Can the ketchup functions be tested independently? |
| **Migration cost** | How many files/imports need to change? |

### 5. Topology Engine Lessons

The topology engine went through the same extraction. What lessons apply?
- What mistakes were made during topology extraction that CI should avoid?
- What worked well?
- Are there WIP/legacy patterns in topology that CI should learn from?

## Output

Write your report to `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-17-REVIEW/tpol-minimax-REVIEW-2026-07-17.md`.

Format: structured markdown with sections matching the analysis framework above. Include code snippets, file references, and line numbers. Be verbose — this is a reference document.
