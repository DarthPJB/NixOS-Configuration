# Final Topology Rectification — Action Plan
**Created**: 2026-06-23  
**Status**: PLANNING — Deferred to post-overlord-I  
**Priority**: High — Blocker for Phase C (Library Split)  
**Primary Branch**: `jb/overlord-II` (not yet created)

## Objective

Restructure topology files into a clean `topology/` directory hierarchy that:
1. Serves as the single source of truth for all network topology data
2. Is importable by external tools (graph generators, diagram renderers)
3. Eliminates the `real-topology` naming
4. Maintains 1:1 isomorphism with current golden test output at every step

## Critical Constraint

**Golden tests are sacrosanct.** Every structural change MUST produce byte-identical golden output. If `nix run .#check-network -- <machine>` fails at any step, the structural change is wrong — revert and fix.

**Never regenerate golden files as part of this work.** Golden regeneration is ONLY for intentional configuration changes.

## Agent Delegation Pattern

### Execution Model
- **Worker Agent**: `bellana-deepseek` — Executes individual steps in serial
- **Validation Agent**: `tpol-minimax` — Validates phase completion via systematic review and nix evaluation

### Per-Phase Workflow
1. Create worktree from `jb/overlord-II`
2. `bellana-deepseek` executes steps in serial (one step completes and builds before next begins)
3. `tpol-minimax` validates phase completion:
   - Systematic review of all changes
   - Run required nix evaluations (`nix build`, `nix run .#check-network`)
   - Verify golden tests pass
4. Merge worktree into `jb/overlord-II`
5. Proceed to next phase (new worktree)

### Prompt Requirements
Each step prompt for `bellana-deepseek` must include:
- Critical requirements (golden test constraint, specific files to modify)
- Validation commands to run before marking complete
- Expected output/behavior

Each validation prompt for `tpol-minimax` must include:
- Full list of changes made in the phase
- Golden test results
- Any deviations from plan (and justification)

## Objective

Restructure topology files into a clean `topology/` directory hierarchy that:
1. Serves as the single source of truth for all network topology data
2. Is importable by external tools (graph generators, diagram renderers)
3. Eliminates the `real-topology` naming
4. Maintains 1:1 isomorphism with current golden test output at every step

## Critical Constraint

**Golden tests are sacrosanct.** Every structural change MUST produce byte-identical golden output. If `nix run .#check-network -- <machine>` fails at any step, the structural change is wrong — revert and fix.

**Never regenerate golden files as part of this work.** Golden regeneration is ONLY for intentional configuration changes.

## Architecture Clarification

**`topology/default.nix` is the topology data source**, not just a golden test generator. It:
- Imports all per-machine topology files (`topology/<machine>.nix`)
- Exposes a unified topology attrset that the library transforms
- Contains golden test generation logic (`safeOptions`, `generateGolden`) as a secondary function
- Is the single import point for external tools (graph generators, diagram renderers)

**Data flow:**
```
topology/default.nix (imports per-machine files, exposes unified attrset)
         ↓
lib/topology/*.nix (transformers: topology data → NixOS config)
         ↓
modules/core-router.nix (consumes transformed config)
```

## Current State

```
real-topology/
├── default.nix          # Golden test generator (safeOptions, generateGolden)
├── cortex-alpha.nix     # Per-machine topology (664 lines, comprehensive)
├── coverage.nix         # Coverage tracking
├── _template.nix        # Template for new machines
└── golden/              # 17 golden JSON files (sacrosanct)
    ├── cortex-alpha.json
    ├── remote-worker.json
    └── ... (15 more)

topology.nix             # Minimal WireGuard-only topology (shared data)
lib/topology/            # Transformation functions (mk*.nix, gen*.nix)
```

**Dependencies:**
- `modules/core-router.nix` → imports `real-topology/<machine>.nix`
- `flake.nix` → imports `real-topology/default.nix` for golden generation
- `flake.nix` → imports `real-topology/coverage.nix`
- `modules/enable-wg-topology.nix` → imports `topology.nix`

**Transition plan:**
- `topology.nix` → `topology/shared.nix` (as-is, then incrementally split)
- `real-topology/cortex-alpha.nix` → `topology/cortex-alpha.nix`
- `real-topology/default.nix` → `lib/golden_generator.nix`
- `real-topology/coverage.nix` → `lib/golden_coverage.nix`
- `real-topology/golden/*.json` → `goldens/*.json`
- `lib/topology/*.nix` → `lib/topology_library.nix` (consolidated for Phase C extraction)

## Target State

```
topology/                    # Topology input data ONLY
├── default.nix              # Entry point: imports all machines, exposes unified topology attrset
├── shared.nix               # Shared topology data (replaces topology.nix, incrementally split)
├── cortex-alpha.nix         # Nix-managed machine topology
├── remote-worker.nix        # Nix-managed machine topology
├── external/                # Real systems NOT managed by Nix
│   ├── access-point.nix     # e.g., 10.88.127.2 AP
│   └── dlyonpc.nix          # e.g., WireGuard peer, not Nix-managed
└── ...

goldens/                     # Golden test data files ONLY
└── *.json                   # Golden test files

lib/
├── golden_generator.nix     # Golden test generator (moved from real-topology/default.nix)
├── golden_coverage.nix      # Coverage tracking (moved from real-topology/coverage.nix)
├── topology_library.nix     # Library functions that consume topology data
│                            # (consolidated from lib/topology/*.nix, ready for Phase C extraction)
└── topology/                # Current transformer/generator files (to be consolidated)
    ├── mk*.nix              # Transformers (topology data → settings)
    ├── gen*.nix             # Generators (settings → NixOS config)
    ├── validate.nix         # Validation
    └── utils.nix            # Shared utilities
```

**Data categories:**
- `topology/<machine>.nix` — Nix-managed systems (cortex-alpha, remote-worker, etc.)
- `topology/external/<name>.nix` — Real systems not managed by Nix (APs, external PCs, WireGuard-only peers)
- `topology/shared.nix` — Shared topology data (subnet definitions, common config)

**Library consolidation (Phase C preparation):**
- `lib/topology_library.nix` — Entry point that re-exports all transformers and generators
- Individual `lib/topology/*.nix` files remain for now, consolidated later

**NEVER AGAIN:**
- No `real-topology/` directory
- No ambiguity about what is data vs test infrastructure vs library

**After completion:**
- `topology/` contains all topology input data (managed + external + shared)
- `goldens/` contains only golden JSON files
- `lib/` contains golden generator, coverage, and topology library functions
- `topology.nix` at root removed entirely
- `real-topology/` removed entirely
- All golden tests pass unchanged

## Phases

### Phase 1: Preparation — Verify Golden Baseline
**Goal**: Establish that all golden tests pass before any changes.
**Worktree**: N/A (read-only operations)
**Agent**: `bellana-deepseek`

**Steps:**
1. Run full golden validation for all 17 machines
2. Document any pre-existing failures (separate from this work)
3. Record baseline state

**Validation:**
```bash
for m in cortex-alpha remote-worker remote-builder LINDA local-nas alpha-one alpha-two alpha-three terminal-zero terminal-nx-01 display-0 display-1 display-2 gaming-host-1 print-controller storage-array beta-one; do
  nix run .#check-network -- "$m" 2>&1 | tail -1
done
```

**Exit criteria:** All machines pass (or pre-existing failures documented).
**Validation Agent**: `tpol-minimax` — Verify baseline results

---

### Phase 2: Create `topology/`, `goldens/`, and Directory Structure
**Goal**: Create the new directories with proper separation of concerns.
**Worktree**: `topology-rectification-phase-2` (from `jb/overlord-II`)
**Agent**: `bellana-deepseek`

**Steps:**
1. `mkdir topology/ topology/external/ goldens/`
2. Copy `real-topology/cortex-alpha.nix` → `topology/cortex-alpha.nix`
3. Create `topology/default.nix` that imports per-machine files
4. Move `topology.nix` → `topology/shared.nix` (as-is)
5. Copy `real-topology/default.nix` → `lib/golden_generator.nix`
6. Copy `real-topology/coverage.nix` → `lib/golden_coverage.nix`
7. Copy `real-topology/golden/*.json` → `goldens/`

**NOT copied:**
- `_template.nix` — Development aid, stays in `real-topology/` for now

**Validation:**
```bash
# Verify files exist
ls topology/*.nix topology/external/ lib/golden_*.nix goldens/*.json

# Run golden tests (should still pass — nothing imports new paths yet)
nix run .#check-network -- cortex-alpha
```

**Exit criteria:** Files created, golden tests pass (old paths still active).
**Validation Agent**: `tpol-minimax` — Verify directory structure and golden tests

---

### Phase 3: Update `topology/default.nix` Imports
**Goal**: Make `topology/default.nix` self-contained (imports from `topology/` not `real-topology/`).
**Worktree**: `topology-rectification-phase-3` (from `jb/overlord-II`)
**Agent**: `bellana-deepseek`

**Steps:**
1. Update `topology/default.nix` to import from `../lib/topology/utils.nix` (path unchanged)
2. Verify `generateGolden` function works with new path

**Validation:**
```bash
# Test golden generation from new path
nix eval --json --impure --expr '
  let
    flake = builtins.getFlake (builtins.toString ./.);
    lib = (import <nixpkgs> {}).lib;
    topology = import ./topology/default.nix { inherit lib; self = flake; };
  in
  topology.generateGolden "cortex-alpha"
' 2>/dev/null | jq -S . > /tmp/test-golden.json

# Compare with existing golden
diff real-topology/golden/cortex-alpha.json /tmp/test-golden.json
```

**Exit criteria:** `topology/default.nix` produces identical golden output.
**Validation Agent**: `tpol-minimax` — Verify golden output matches

---

### Phase 4: Update `modules/core-router.nix`
**Goal**: Point `core-router.nix` at `topology/<machine>.nix` instead of `real-topology/<machine>.nix`.
**Worktree**: `topology-rectification-phase-4` (from `jb/overlord-II`)
**Agent**: `bellana-deepseek`

**Steps:**
1. Change import path in `core-router.nix`:
   ```nix
   # Before:
   topology = import ../real-topology/${config.networking.hostName}.nix { inherit lib self; };
   # After:
   topology = import ../topology/${config.networking.hostName}.nix { inherit lib self; };
   ```
2. Run golden test for cortex-alpha

**Validation:**
```bash
nix run .#check-network -- cortex-alpha
```

**Exit criteria:** cortex-alpha golden passes with new import path.
**Validation Agent**: `tpol-minimax` — Verify golden test passes

---

### Phase 5: Update `flake.nix` References
**Goal**: Point flake at `topology/` for golden generation and coverage.
**Worktree**: `topology-rectification-phase-5` (from `jb/overlord-II`)
**Agent**: `bellana-deepseek`

**Steps:**
1. Update `generate-golden` app:
   ```nix
   # Before:
   topology = import ./real-topology/default.nix { inherit lib; self = flake; };
   # After:
   topology = import ./topology/default.nix { inherit lib; self = flake; };
   ```
2. Update `check-network` app (golden path):
   ```nix
   # Before:
   if diff -u "${self}/real-topology/golden/$MACHINE.json" /tmp/current-network.json
   # After:
   if diff -u "${self}/topology/golden/$MACHINE.json" /tmp/current-network.json
   ```
3. Update `coverage` reference if applicable

**Validation:**
```bash
nix run .#check-network -- cortex-alpha
nix run .#check-network -- remote-worker
nix run .#check-network -- remote-builder
```

**Exit criteria:** All golden tests pass with flake pointing at `topology/`.
**Validation Agent**: `tpol-minimax` — Verify all golden tests pass

---

### Phase 6: Remove `topology.nix` Root File
**Goal**: Remove `topology.nix` entirely; `topology/shared.nix` replaces it.
**Worktree**: `topology-rectification-phase-6` (from `jb/overlord-II`)
**Agent**: `bellana-deepseek`

**Steps:**
1. Update `modules/enable-wg-topology.nix`:
   ```nix
   # Before:
   topology = import ../topology.nix { inherit lib; };
   # After:
   topology = import ../topology/shared.nix { inherit lib; };
   ```
2. Delete `topology.nix`

**Validation:**
```bash
# Test WireGuard client machines
nix run .#check-network -- LINDA
nix run .#check-network -- remote-worker
nix run .#check-network -- remote-builder
```

**Exit criteria:** WireGuard client golden tests pass.
**Validation Agent**: `tpol-minimax` — Verify WireGuard client golden tests pass

---

### Phase 7: Remove `real-topology/` Directory
**Goal**: Eliminate `real-topology/` entirely.
**Worktree**: `topology-rectification-phase-7` (from `jb/overlord-II`)
**Agent**: `bellana-deepseek`

**Steps:**
1. Verify NO remaining references to `real-topology`:
   ```bash
   grep -r "real-topology" . --include="*.nix" --include="*.md"
   ```
2. Remove `real-topology/` directory entirely
3. Run full golden validation for all 17 machines

**Validation:**
```bash
for m in cortex-alpha remote-worker remote-builder LINDA local-nas alpha-one alpha-two alpha-three terminal-zero terminal-nx-01 display-0 display-1 display-2 gaming-host-1 print-controller storage-array beta-one; do
  nix run .#check-network -- "$m" 2>&1 | tail -1
done
```

**Exit criteria:** `real-topology/` gone forever, all golden tests pass.
**Validation Agent**: `tpol-minimax` — Verify `real-topology/` removed and all golden tests pass

---

### Phase 8: Update Documentation
**Goal**: Update all documentation references to reflect new structure.
**Worktree**: `topology-rectification-phase-8` (from `jb/overlord-II`)
**Agent**: `bellana-deepseek`

**Files to update:**
- `AGENTS.md` — Update architecture section, file references
- `documentation/file_structure.md` — Update directory layout
- `documentation/code_structure.md` — Update topology references
- `documentation/topology-migration-guide.md` — Update paths
- `documentation/core-router-usage.md` — Update paths
- `documentation/topology-generator-issues.md` — Update paths
- `README.md` — Update any topology references

**Validation:**
```bash
grep -r "real-topology" documentation/ AGENTS.md README.md
# Should return nothing
```

**Exit criteria:** No remaining references to `real-topology` in docs.
**Validation Agent**: `tpol-minimax` — Verify no stale references remain

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Golden test fails after path change | Revert immediately; investigate import resolution |
| Circular imports in `topology/default.nix` | Keep per-machine files independent; default.nix only imports, doesn't compose |
| `enable-wg-topology.nix` breaks | Test WireGuard client machines explicitly in Phase 6 |
| Stale references to `real-topology` | Full grep sweep before deletion in Phase 7 |

## Open Questions

None — all design decisions resolved.

## WIP Generators — Implementation Status

The topology library has two layers: **transformers** (topology data → settings) and **generators** (settings → NixOS config). Some are production-ready, others are WIP.

### Design Intent

The transformer-generator separation serves three purposes:

1. **Cross-machine reference** — After transformers compute settings for ALL machines, any machine can reference any other machine's computed data (e.g., `topology.cortex-alpha.wireguard.interface.ipv4` instead of hardcoded `"10.88.127.1"`)

2. **Recursion avoidance** — Generators consume data built by transformers, never by themselves. Clean DAG: topology → transformers → settings → generators → NixOS config

3. **Library extraction** — Settings format becomes the API contract for Phase C split. The `lib/topology_library.nix` entry point exposes transformers + generators as a clean interface.

### Critical Testing Requirement

**Existing WIP transformers are mostly untested.** Before any transformer can be trusted, it MUST be validated against golden tests:
- Run transformer → generate NixOS config → compare against golden
- If output diverges, the transformer is wrong (never the golden)
- Incremental validation: one machine at a time, one transformer at a time

### Production Transformers (used by `core-router.nix`)
| File | Purpose | Status |
|------|---------|--------|
| `mkWireguardPeers.nix` | WireGuard peer transformation | ✅ Production |
| `mkTailscaleConfig.nix` | Tailscale configuration | ✅ Production |
| `mkDhcpDns.nix` | DHCP/DNS configuration | ✅ Production |
| `mkNginxProxies.nix` | Nginx proxy configuration | ✅ Production |
| `mkForwarding.nix` | nftables forwarding rules | ✅ Production |
| `mkMonitoringSettings.nix` | Prometheus exporter config | ✅ Production |
| `validate.nix` | Topology validation | ✅ Production |
| `utils.nix` | Shared utilities | ✅ Production |

### WIP Transformers (for new architecture)
| File | Purpose | Status |
|------|---------|--------|
| `mkWireguardSettings.nix` | WireGuard transformer | ✅ Written |
| `mkNginxSettings.nix` | Nginx transformer | ✅ Written |
| `mkFirewallSettings.nix` | Firewall transformer | ✅ Written |
| `mkDnsSettings.nix` | DNS/DHCP transformer | ✅ Written |
| `mkMonitoringSettings.nix` | Monitoring transformer | ✅ Shared with production |

### WIP Generators (for new architecture)
| File | Purpose | Status |
|------|---------|--------|
| `genWireguard.nix` | WireGuard generator | ✅ Written |
| `genNginx.nix` | Nginx generator | ✅ Written |
| `genFirewall.nix` | Firewall generator | ✅ Written |
| `genDns.nix` | DNS/DHCP generator | ✅ Written |

### Not Yet Implemented
| File | Purpose | Status |
|------|---------|--------|
| `genMonitoring.nix` | Monitoring generator | ❌ Not implemented |
| `genTailscale.nix` | Tailscale generator | ❌ Not implemented |
| `genForwarding.nix` | Forwarding generator | ❌ Not implemented |

**Note:** The WIP generators exist but are NOT validated against golden tests. They must produce identical output to the production transformers before they can be used.

## Progress Tracking

| Phase | Status | Golden Tests | Notes |
|-------|--------|--------------|-------|
| 1: Baseline | ⬜ Pending | — | |
| 2: Create directories | ⬜ Pending | — | topology/, topology/external/, goldens/ |
| 3: Update default.nix | ⬜ Pending | — | |
| 4: Update core-router | ⬜ Pending | cortex-alpha | |
| 5: Update flake.nix | ⬜ Pending | All | golden generator → lib/ |
| 6: Remove topology.nix | ⬜ Pending | WireGuard clients | → topology/shared.nix |
| 7: Remove real-topology | ⬜ Pending | All | real-topology/ gone forever |
| 8: Update docs | ⬜ Pending | — | |
