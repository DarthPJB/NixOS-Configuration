# Overlord-II — Consolidated Execution Plan

> **Created:** 2026-07-11
> **Status:** ACTIVE
> **Branch:** `overlord-II`
> **Base commit:** `db90b5d` (golden: regenerate 10 active machine configs to match v1.9 fleet state)

## Context

Overlord-II is the second major development phase following the overlord-I deployment
baseline. The branch has accumulated 14 commits since the overlord-I merge, including:

- **Golden regeneration** — 10 active machines regenerated to v1.9 fleet state
- **Deployment exporter redesign** — Fixed infinite recursion, added system closure tracking
- **Grafana dashboards** — Major overhaul (panels, SMART metrics, provisioning)
- **GitHub runner module** — Phase 1 override deployed, Phase 2 custom module planned
- **Smart/WG fixes** — Pi hosts smartd disabled, topology validate updated for WG-only hosts
- **GC change** — 30-day retention with 50GB cap

### Known Issues (Pre-existing)

**5 machines with nixpkgs fail2ban eval bug** — Golden regeneration skipped:
- `arm-builder`, `beta-one`, `display-1`, `display-2`, `print-controller`
- These are ARM/legacy machines with small golden files (3-6KB)
- Root cause: nixpkgs fail2ban module eval failure on certain architectures
- **Not blocking** — these machines are not primary deployment targets

---

## Phase 0: Pre-flight Verification

**Goal:** Establish that the current branch is deployable and all golden tests pass
for the 10 active x86_64 machines.

**Worktree:** N/A (read-only operations)
**Agent:** `bellana-deepseek`

### Steps

1. **Verify flake evaluation**
   ```bash
   nix eval --json --impure --expr 'let flake = builtins.getFlake (builtins.toString ./.); in builtins.attrNames flake.nixosConfigurations' | jq .
   ```

2. **Run golden validation for 10 active machines**
   ```bash
   for m in cortex-alpha LINDA gaming-host-1 remote-worker remote-builder local-nas alpha-one alpha-three terminal-zero terminal-nx-01; do
     echo "=== $m ===" && nix run .#check-network -- "$m" 2>&1 | tail -3
   done
   ```

3. **Document baseline state**
   - Record pass/fail for each machine
   - Any failures must be investigated before proceeding

**Exit criteria:** All 10 active x86_64 machines pass golden tests.
**Validation Agent:** `tpol-minimax` — Verify baseline results.

---

## Phase 1: Topology Rectification — Directory Structure

**Goal:** Create the new `topology/`, `goldens/`, and `lib/` directory structure
without breaking any existing imports.

**Worktree:** `topology-rectification-phase-1` (from `overlord-II`)
**Agent:** `bellana-deepseek`
**Depends on:** Phase 0

### Steps

1. **Create new directories**
   ```bash
   mkdir -p topology/ topology/external/ goldens/
   ```

2. **Copy per-machine topology files**
   ```bash
   for m in cortex-alpha LINDA gaming-host-1 remote-worker remote-builder local-nas alpha-one alpha-three terminal-zero terminal-nx-01; do
     cp real-topology/$m.nix topology/$m.nix
   done
   ```

3. **Create `topology/default.nix`** — Imports all per-machine files, exposes unified attrset

4. **Move `topology.nix` → `topology/shared.nix`** (as-is, no content changes)

5. **Copy golden generator**
   ```bash
   cp real-topology/default.nix lib/golden_generator.nix
   cp real-topology/coverage.nix lib/golden_coverage.nix
   ```

6. **Copy golden files**
   ```bash
   cp real-topology/golden/*.json goldens/
   ```

**Exit criteria:**
- All files exist in new locations
- Golden tests still pass (old paths still active)
- `nix run .#check-network -- cortex-alpha` passes

**Validation Agent:** `tpol-minimax` — Verify directory structure and golden tests.

---

## Phase 2: Topology Rectification — Update Imports

**Goal:** Point all consumers at the new `topology/` paths. One machine at a time.

**Worktree:** `topology-rectification-phase-2` (from `overlord-II`)
**Agent:** `bellana-deepseek`
**Depends on:** Phase 1

### Steps

1. **Update `topology/default.nix`** — Make self-contained (imports from `topology/` not `real-topology/`)

2. **Update `modules/core-router.nix`** — Point at `topology/<machine>.nix`
   ```nix
   # Before:
   topology = import ../real-topology/${config.networking.hostName}.nix { inherit lib self; };
   # After:
   topology = import ../topology/${config.networking.hostName}.nix { inherit lib self; };
   ```

3. **Update `flake.nix`** — Point golden generator at `topology/default.nix`
   ```nix
   # Before:
   topology = import ./real-topology/default.nix { inherit lib; self = flake; };
   # After:
   topology = import ./topology/default.nix { inherit lib; self = flake; };
   ```

4. **Update `flake.nix`** — Point golden paths at `goldens/`
   ```nix
   # Before:
   if diff -u "${self}/real-topology/golden/$MACHINE.json" /tmp/current-network.json
   # After:
   if diff -u "${self}/goldens/$MACHINE.json" /tmp/current-network.json
   ```

5. **Update `modules/enable-wg-topology.nix`** — Point at `topology/shared.nix`
   ```nix
   # Before:
   topology = import ../topology.nix { inherit lib; };
   # After:
   topology = import ../topology/shared.nix { inherit lib; };
   ```

6. **Validate each change** — Run `nix run .#check-network -- cortex-alpha` after each update

**Exit criteria:** All golden tests pass with new import paths.
**Validation Agent:** `tpol-minimax` — Verify all golden tests pass.

---

## Phase 3: Topology Rectification — Cleanup

**Goal:** Remove `real-topology/` directory and root `topology.nix`.

**Worktree:** `topology-rectification-phase-3` (from `overlord-II`)
**Agent:** `bellana-deepseek`
**Depends on:** Phase 2

### Steps

1. **Verify no remaining references**
   ```bash
   grep -r "real-topology" . --include="*.nix" --include="*.md" | grep -v documentation/
   ```

2. **Remove `topology.nix` root file**

3. **Remove `real-topology/` directory**
   ```bash
   rm -rf real-topology/
   ```

4. **Run full golden validation**
   ```bash
   for m in cortex-alpha LINDA gaming-host-1 remote-worker remote-builder local-nas alpha-one alpha-three terminal-zero terminal-nx-01; do
     nix run .#check-network -- "$m" 2>&1 | tail -1
   done
   ```

**Exit criteria:** `real-topology/` gone, all golden tests pass.
**Validation Agent:** `tpol-minimax` — Verify cleanup and golden tests.

---

## Phase 4: GitHub Runner Custom Module

**Goal:** Build a custom `github-runner` module that separates identity from config,
preventing runner registration destruction on nix rebuild.

**Worktree:** `github-runner-module` (from `overlord-II`)
**Agent:** `bellana-deepseek`
**Depends on:** None (independent of topology work)

### Steps

1. **Create `modules/github-runner/` directory structure**
   ```
   modules/github-runner/
     default.nix        # Module entry point
     options.nix        # Option declarations
     service.nix        # Service configuration
     scripts/
       unconfigure.sh   # Non-destructive unconfigure
       configure.sh     # Registration logic
       setup-workdir.sh # Work directory setup
   ```

2. **Implement options.nix** — Module option declarations
   - `preserveRegistration` option (default: true)
   - `forceReRegister` option
   - Custom unconfigure script option

3. **Implement service.nix** — Service configuration with non-destructive ExecStartPre

4. **Implement scripts** — Copy-paste from nixpkgs with destructive behavior removed

5. **Test on LINDA** — Deploy to gaming-host-1 first (non-critical)

6. **Validate** — Verify runner survives nix rebuild + reboot

**Exit criteria:** GitHub runner survives config changes without re-registration.
**Validation Agent:** `tpol-minimax` — Verify runner registration persistence.

---

## Phase 5: SSH Multiplexing via Topology

**Goal:** Generate `programs.ssh.matchBlocks` from topology for fleet-wide SSH
connection multiplexing.

**Worktree:** `ssh-multiplex` (from `overlord-II`)
**Agent:** `bellana-deepseek`
**Depends on:** Phase 3 (topology must be in new location)

### Steps

1. **Implement `mkMultiplexConfig` in `flake.nix`**
   - Mirror `mkKnownHosts` pattern
   - Generate `programs.ssh.matchBlocks` from topology

2. **Add socket directory to `commonModules`**
   ```nix
   systemd.tmpfiles.rules = [
     "d /run/user/%i/ssh-mux 0700 %u users -"
   ];
   ```

3. **Add `MaxSessions = 20` to `environments/sshd.nix`**

4. **Enable `deploy` user `linger`**
   ```nix
   users.users.deploy.linger = true;
   ```

5. **Smoke test on cortex-alpha**
   ```bash
   ssh -O check deploy@10.88.127.1
   ```

6. **Fleet-wide deployment**

7. **Benchmark**
   ```bash
   time ssh deploy@10.88.127.1 true
   ```

**Exit criteria:** SSH multiplexing operational, benchmark shows improvement.
**Validation Agent:** `tpol-minimax` — Verify multiplexing works.

---

## Phase 6: LLM-CORE Re-enable

**Goal:** Re-enable the LLM-CORE input and opencode-fleet module on LINDA and
remote-worker.

**Worktree:** `llm-core-enable` (from `overlord-II`)
**Agent:** `bellana-deepseek`
**Depends on:** None (independent)

### Steps

1. **Uncomment LLM-CORE in `flake.nix`**
   - Input declaration
   - `globalArgs` inheritance
   - LINDA module import
   - remote-worker module import

2. **Run `nix flake lock --update-input LLM-CORE`**

3. **Test evaluation**
   ```bash
   nix eval --json --impure --expr 'let flake = builtins.getFlake (builtins.toString ./.); in flake.nixosConfigurations.LINDA.config.system.build.toplevel.drvPath' 2>&1 | head -5
   ```

4. **Deploy to LINDA first** (primary target)

5. **Deploy to remote-worker**

**Exit criteria:** LLM-CORE operational on both machines.
**Validation Agent:** `tpol-minimax` — Verify LLM-CORE integration.

---

## Phase 7: Documentation Update

**Goal:** Update all documentation to reflect new topology structure and overlord-II
changes.

**Worktree:** `overlord-II-docs` (from `overlord-II`)
**Agent:** `bellana-deepseek`
**Depends on:** Phases 1-6

### Steps

1. **Update `AGENTS.md`** — Architecture section, file references, active files list

2. **Update `documentation/file_structure.md`** — New directory layout

3. **Update `documentation/code_structure.md`** — Topology references

4. **Update `documentation/topology-migration-guide.md`** — New paths

5. **Update `documentation/core-router-usage.md`** — New paths

6. **Remove stale references**
   ```bash
   grep -r "real-topology" documentation/ AGENTS.md README.md
   ```

7. **Update roadmap-snapshot.md** — Mark overlord-II items complete

**Exit criteria:** No stale references to `real-topology/` in docs.
**Validation Agent:** `tpol-minimax` — Verify documentation accuracy.

---

## Execution Order

```
Phase 0 (Pre-flight)
    ↓
Phase 1 (Directory Structure) ──────────────────────────┐
    ↓                                                    │
Phase 2 (Update Imports)                                │
    ↓                                                    │
Phase 3 (Cleanup)                                       │
    ↓                                                    │
Phase 5 (SSH Multiplexing)                              │
    ↓                                                    │
Phase 7 (Documentation)                                 │
                                                        │
Phase 4 (GitHub Runner) ────────────────────────────────┤
                                                        │
Phase 6 (LLM-CORE) ────────────────────────────────────┘
```

**Critical path:** Phases 0 → 1 → 2 → 3 → 5 → 7
**Parallel tracks:** Phase 4 and Phase 6 can run independently

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Golden test fails after path change | Revert immediately; investigate import resolution |
| Circular imports in `topology/default.nix` | Keep per-machine files independent; default.nix only imports |
| `enable-wg-topology.nix` breaks | Test WireGuard client machines explicitly in Phase 2 |
| Stale references to `real-topology` | Full grep sweep before deletion in Phase 3 |
| LLM-CORE breaks evaluation | Test in isolation before deploying |
| GitHub runner loses registration | Test on non-critical machine first |

---

## Progress Tracking

> **Last validated:** 2026-07-17 — code inspection, not documentation trust

| Phase | Status | Notes |
|-------|--------|-------|
| 0: Pre-flight | ✅ Done | |
| 1: Directory Structure | ✅ Done | `topology/`, `goldens/` created |
| 2: Update Imports | ✅ Done | All consumers point at new paths |
| 3: Cleanup | ✅ Done | `real-topology/` removed |
| 4: GitHub Runner | ✅ Done | Custom override deployed, hate-filled on remote-builder |
| 5: SSH Multiplexing | ✅ Done | `ssh-multiplex.nix` module using `extraConfig` (not `matchBlocks`) |
| 6: LLM-CORE | ✅ Done | Enabled in flake inputs, `opencode-fleet` active on LINDA |
| 7: Documentation | ✅ Done | |

### Phase B: Transformer Architecture

> **Plan:** `documentation/phase-b-completion-plan.md`

| Step | Status | Notes |
|------|--------|-------|
| 1-3: Core-router wiring + validation | ✅ Done | `core-router-topology.nix` wired into cortex-alpha |
| 4: genBackup.nix | ✅ Done | Generator exists at `lib/topology/genBackup.nix` |
| 5: Backup topology in cortex-alpha.nix | ❌ Not done | No `backup` section in `topology/cortex-alpha.nix` |
| 6: Wire backup into core-router-topology.nix | ❌ Not done | No `mkBackupSettings`/`genBackup` calls in module |
| 7: Final validation | ⬜ Pending | Depends on Steps 5-6 |

### remote-builder Hub

> **Plan:** `documentation/plans/remote-builder-hub-2026-07-15.md`

| Phase | Status | Notes |
|-------|--------|-------|
| 1: Clean up modifier_imports | ✅ Done | |
| 2: Attach 300G disk + store migration | ✅ Done | |
| 3: Configure hub (max-jobs=0) | ✅ Done | |
| 3b: Route to hyperhyper | ✅ Done | CI can contact hyperhyper |
| 3c: Move hate-filled runner + netrc | ✅ Done | Committed `d723f05` |
| 4: Cache contribution | ⬜ Pending | Post-build hook → cache.platonic.systems |
| 5: Verify and deploy | ⬜ Pending | End-to-end validation |
