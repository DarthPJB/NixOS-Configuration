# Overlord-II — Consolidated Execution Plan (Archived)

> **Created:** 2026-07-11
> **Archived:** 2026-07-20
> **Branch:** `overlord-II`
> **Note:** Topology phases (0-3) are superseded by the `planar-topology` branch.
>       This file preserves the non-topology execution history.

## Context

Overlord-II is the second major development phase following the overlord-I deployment
baseline. The branch accumulated 14 commits including golden regeneration, deployment
exporter redesign, Grafana dashboards, GitHub runner module, Smart/WG fixes, and GC
retention changes.

### Known Issues (Pre-existing)

**5 machines with nixpkgs fail2ban eval bug** — Golden regeneration skipped:
- `arm-builder`, `beta-one`, `display-1`, `display-2`, `print-controller`
- Root cause: nixpkgs fail2ban module eval failure on certain architectures
- **Not blocking** — not primary deployment targets

---

## Phase 4: GitHub Runner Custom Module

**Goal:** Build a custom `github-runner` module that separates identity from config,
preventing runner registration destruction on nix rebuild.

### Steps

1. Create `modules/github-runner/` directory structure (default.nix, options.nix,
   service.nix, scripts/)
2. Implement options.nix — `preserveRegistration`, `forceReRegister`, custom
   unconfigure script option
3. Implement service.nix — Service configuration with non-destructive ExecStartPre
4. Implement scripts — Copy-paste from nixpkgs with destructive behavior removed
5. Test on gaming-host-1 first (non-critical)
6. Validate — Verify runner survives nix rebuild + reboot

**Exit criteria:** GitHub runner survives config changes without re-registration.

---

## Phase 6: LLM-CORE Re-enable

**Goal:** Re-enable the LLM-CORE input and opencode-fleet module on LINDA and
remote-worker.

### Steps

1. Uncomment LLM-CORE in `flake.nix` (input, globalArgs, LINDA + remote-worker imports)
2. `nix flake lock --update-input LLM-CORE`
3. Test evaluation
4. Deploy to LINDA first, then remote-worker

**Exit criteria:** LLM-CORE operational on both machines.

---

## Phase 7: Documentation Update

**Goal:** Update all documentation to reflect new structure and overlord-II changes.

### Steps

1. Update `AGENTS.md` — Architecture section, file references, active files list
2. Update `documentation/file_structure.md` — New directory layout
3. Update `documentation/code_structure.md` — Topology references
4. Update `documentation/core-router-usage.md` — New paths
5. Remove stale references to `real-topology/`
6. Update `documentation/roadmap-snapshot.md` — Mark overlord-II items complete

**Exit criteria:** No stale references in documentation.

---

## Progress Tracking

> **Last validated:** 2026-07-17

| Phase | Status | Notes |
|-------|--------|-------|
| 4: GitHub Runner | ✅ Done | Custom override deployed, hate-filled on remote-builder |
| 6: LLM-CORE | ✅ Done | Enabled in flake inputs, opencode-fleet active on LINDA |
| 7: Documentation | ✅ Done | |

### remote-builder Hub

| Phase | Status | Notes |
|-------|--------|-------|
| 1: Clean up modifier_imports | ✅ Done | |
| 2: Attach 300G disk + store migration | ✅ Done | |
| 3: Configure hub (max-jobs=0) | ✅ Done | |
| 3b: Route to hyperhyper | ✅ Done | CI can contact hyperhyper |
| 3c: Move hate-filled runner + netrc | ✅ Done | Committed `d723f05` |
| 4: Cache strategy | ✅ Done | remote-builder IS the cache, GC disabled |
| 5: Verify and deploy | ⬜ Pending | End-to-end validation |
