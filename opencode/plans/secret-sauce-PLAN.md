# Secret-Sauce Boundary — Working Plan

> **Status:** ACTIVE — living working document. Updates in place as gates clear.
> **Owner:** John88 / USS-Voyager (Janeway)
> **Date:** 2026-11-12
> **Predecessor:** `mayo-split-PLAN.md` (Gates A/B/C/3b all ✅ — extraction complete).
> **Companion docs:** `documentation/LDR-001-fleet-spec-and-boundaries.md`
> (D-08…D-11), `AGENTS.md` (Architecture Boundary), demarkation rule §6 of
> the mayo-split plan.

---

## 1. Objective

With the mayo extraction complete, this phase classifies and acts on the
**remaining library code in the parent flake** (review of 2026-11-12), per the
user's three rulings:

| # | Ruling (user, 2026-11-12) |
|---|---|
| R1 | Extract `ci.nix` (+ its library) to a **new public GitHub project `nix-github-ci`**, alongside mayo/ketchup. Consumed by NixOS-Configuration **in the style of `platonic/gitlab-ci.nix`** (flake input → app re-export). `gh` assists project configuration. |
| R2 | **`genDashboard.nix` + `dashboard_templates/` extract to mayo.** |
| R3 | **Delete orphan tests and code.** |

### Demarkation consequences (forced, not chosen)

- **`nix-github-ci` is public** → nothing fleet-identifying may live in it.
  `ci.nix` names machines (`cluster-box`, `bargman-greeter-vm`,
  `remote-builder`, `LINDA` comment), carries a real VPN range (`10.88.127`),
  and fleet timeouts. The **engine moves; the fleet data stays parent-side,
  injected** — the same seam pattern proven by mayo (`topologyDir`,
  `pubKeyDir`) and golden `coverage.nix` (data-injected).
- **mayo is public** → dashboard templates must shed their fleet data
  (`workstationHosts = [ "LINDA" ]`, `cluster-box` label override,
  `remote-builder` comment, datasource uid) into parent-side injection.
  `inventory.nix` **stays parent-side** (reads `self` — barred from mayo by
  the pure-generator law; file says so itself).

---

## 2. Repository Map (after this phase)

| Repo | Location | Visibility | Contents |
|---|---|---|---|
| **mayo** | `github.com/Bargman-Tech/mayo` | public · AGPL-3.0-or-later | Ketchup layer + Mayo layer (now incl. monitoring/dashboard tooling) |
| **nix-github-ci** (NEW) | `github.com/Bargman-Tech/nix-github-ci` | public | GitHub Actions CI engine: `mkCi` + `ciLibrary` + workflow apps |
| **gaming-host-1** | `gitlab.com/mecha-team-zero/gaming-host-1` | private | child machine flake (unchanged here) |

*Ketchup remains a **layer inside mayo** (repo separation deferred per user
ruling "it can wait") — `nix-github-ci` is the third project of the family,
not a ketchup repo.*

---

## 3. Consumption contract — nix-github-ci (R1)

Mirrors the fleet-standard `platonic/gitlab-ci.nix` pattern
(`LLM-CORE/flake.nix:26` + app re-export at `:938`):

```nix
# flake.nix inputs
nix-github-ci = {
  url = "github:Bargman-Tech/nix-github-ci";
  inputs.nixpkgs.follows = "nixpkgs_stable";
};
# flake.nix outputs
ci = nix-github-ci.lib.mkCi {
  inherit self lib;
  pkgs = nixpkgs;
  parallelism = ciParallelism;
  fleet = { … };            # Secret-Sauce data (stays here)
};
apps."x86_64-linux" = {
  inherit (nix-github-ci.apps.x86_64-linux)
    generate-ci-workflow validate-ci-workflow;
};
```

### What moves vs what stays

| Artifact | Destination | Notes |
|---|---|---|
| `lib/ci_library.nix` | nix-github-ci `lib/ci_library.nix` | already generic; header relabelled (drops stale "Ketchup" label per 2026-11-11 delineation) |
| `ci.nix` | nix-github-ci `lib/mk-ci.nix` (`lib.mkCi`) | **parameterized** — see fleet knobs below; output shape `{ ci = { github-actions; github-actions-filtered; machines; jobs; } }` **unchanged** |
| `ci/generate-workflow.nix` | **deleted** (parent) | scripts come from `nix-github-ci.apps`; workflow/ci-info read from `.#ci` |
| `ciParallelism` + fleet knobs | **stays parent** (`flake.nix` let) | Secret-Sauce |
| `check-ci` app + `goldens/ci.json` | **stays parent** | golden tooling |
| `ci-info` app | **stays parent** | reads `.#ci.ci.machines` |

### Fleet knobs (parent → `mkCi` `fleet` arg)

| Knob | Current value in `ci.nix` | Why fleet |
|---|---|---|
| `exclusions` | `[ "cluster-box" "bargman-greeter-vm" ]` | machine names |
| `profileTarget` | `"remote-builder"` (eval-profiler step; `null` ⇒ step omitted) | machine name |
| `x86TimeoutMinutes` | `720` (LINDA cold-cache comment stays parent-side) | fleet tuning |
| `ipScanExcludes` | `[ "10.88.127" ]` (appended before the generic `127.0.0.1` / `documentation` excludes → byte-identical grep chain) | real VPN range |

Everything else (job structure, gitleaks/secret patterns, workflow name
`NixOS CI/CD`, triggers, deploy-prep, matrix builders) is generic and moves.

### New repo skeleton

```
nix-github-ci/
  flake.nix        # inputs: nixpkgs only; outputs: lib.{mkCi,ciLibrary},
                   #   apps.{generate-ci-workflow,validate-ci-workflow},
                   #   checks.{formatting,deadnix}
  lib/ci_library.nix
  lib/mk-ci.nix
  README.md        # usage (gitlab-ci-style), fleet-knob table
  LICENSE          # AGPL-3.0-or-later — mirrors mayo (flagged for user override)
```

---

## 4. Dashboard extraction to mayo (R2)

| Item | From | To |
|---|---|---|
| `genDashboard.nix` | `lib/topology/` | mayo `lib/mayo/monitoring/genDashboard.nix` (**Mayo layer** — "other library assets", not topology) |
| `dashboard_templates/` (10 files) | `lib/topology/` | mayo `lib/mayo/monitoring/dashboard_templates/` |
| `inventory.nix` | stays | parent `lib/monitoring/` (reads `self`; fleet data source) |

### Injection seams (fleet data leaves mayo)

1. **`datasource`** — `genDashboard { lib } { inventory, datasource }`
   (required arg; parent passes `{ type = "prometheus"; uid = "prometheus01"; }`
   — provisioned by parent's `services/prometheus.nix`).
2. **`cpu-frequency` fleet bits** — `workstationHosts` + `labelOverrides`
   move into parent `inventory.nix` (the data bag dashboards already read);
   template reads `inventory.workstationHosts or [ ]` /
   `inventory.labelOverrides or { }`.
3. **Comments** — machine-naming comments in templates neutralised
   (`fleet-cpu-disk.nix` "remote-builder" fold note; stale
   `lib/topology/inventory.nix` path references).

### mayo-side wiring

- `mayo_library.nix` gains `monitoring = { genDashboard = …; dashboards = …; }`
  (api-freeze: consumers reach it only through the Mayo API).
- `anti-vendor.sh` forbidden list += `genDashboard.nix` + the 10 template
  basenames (mayo-owned from now on).
- layer-boundary: monitoring code imports neither Ketchup nor inventory
  (data arrives as args — already true).

### Parent-side wiring

```nix
inventory       = (import ../lib/monitoring/inventory.nix { inherit lib; }) { inherit self registry; };  # unchanged + 2 new fields
genDashboard    = (import mayoLib.monitoring.genDashboard { inherit lib; })
                   { inherit inventory; datasource = { type = "prometheus"; uid = "prometheus01"; }; };
generatedDashboards = import mayoLib.monitoring.dashboards { dash = genDashboard; };
```

`lib/topology/` is **emptied and removed** (last of its contents).

---

## 5. Orphan prune (R3)

| Delete | Evidence |
|---|---|
| `tests/topology/mkRegistry.nix` | orphaned (wired to nothing); mayo-split plan line 362 offer accepted |
| `tests/topology/genNginx.nix` | same |
| `tests/topology-validation.nix` | same |
| `tests/test-hub-of-hubs.nix` | zero references repo-wide |
| `scripts/validate-topology.sh` | **broken** — checks 8 files that no longer exist (`lib/topology/mkRegistry.nix`, `mk*Settings.nix`, …); zero references |
| `.github/workflows/ci.yml.example` | stale generated artifact (old branch list, pre-extraction machine list); regenerable; zero references |

**Kept:** `tests/helpers.nix` (imported by greeter + minecraft tests),
`tests/{bargman-greeter-login,minecraft-server}/` (live checks),
`scripts/{compare-configs.sh,llm-bench.sh}` (live apps).

---

## 6. Execution order & gates

```
Phase C  orphan prune                ──▶  GATE C: fmt + deadnix + flake check green; sweep unaffected
Phase B1 mayo: dashboards in         ──▶  (push mayo — parent locks only pushed revs)
Phase B2 parent: rewire + relock     ──▶  GATE B: dashboard JSON deep-equal (before/after);
                                          sweep 20/20; structure checks green
Phase A1 create + push nix-github-ci ──▶  (repo public on GitHub)
Phase A2 parent: consume + delete    ──▶  GATE A: `check-ci` byte-identical (goldens/ci.json unchanged);
                                          generated ci.yml unchanged; sweep 20/20; structure checks
Docs                                ──▶  AGENTS / development-guide / monitoring-automation / LDR-001 D-12
Final                               ──▶  full sweep + nix flake check + report
```

**Order rationale:** C is independent and shrinks the tree first; B reuses the
proven mayo injection pattern; A is the largest rewiring and lands last with
the strictest golden (`ci.json` byte-identical).

### Hard rules (carry over)

1. Goldens are sacrosanct — a diff is an extraction bug. No regeneration
   authorised or needed by this plan.
2. Per-input flake updates only (new input `nix-github-ci`; `mayo` relock).
3. Mayo/nix-github-ci changes are **pushed before** the parent relocks —
   `git+https` inputs resolve only pushed revs.
4. No `secrets/` content in any new repo (D-08). nix-github-ci carries no
   fleet data at all.
5. `nixpkgs-fmt` / deadnix clean on every touched file; formatter config
   untouched.
6. No child (gaming-host-1) changes required — it consumes neither CI nor
   dashboards.

---

## 7. Decision log

| Date | Decision |
|---|---|
| 2026-11-12 | R1: extract CI to new public `github.com/Bargman-Tech/nix-github-ci`; consumed flake-input-style like `platonic/gitlab-ci.nix`; `gh` for repo config (user) |
| 2026-11-12 | R2: `genDashboard` + `dashboard_templates` → mayo; `inventory.nix` stays parent (reads `self`) (user + pure-generator law) |
| 2026-11-12 | R3: delete orphan tests + broken code — 4 test files, `validate-topology.sh`, `ci.yml.example` (user; list from 2026-11-12 review) |
| 2026-11-12 | ci.nix fleet data (exclusions, profile target, timeouts, IP excludes) stays parent-side as `fleet = { … }` — forced by public-repo demarkation (plan, pending user glance) |
| 2026-11-12 | Dashboard layer = **Mayo** (other library assets), not Ketchup (plan) |
| 2026-11-12 | nix-github-ci license = AGPL-3.0-or-later, mirroring mayo (plan — **flagged: override welcome**) |
