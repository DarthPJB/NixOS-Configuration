# LDR-001 — Fleet Spec, Tracks & Architecture Boundaries

**Type:** Living Decision Record (one living document — corrections in place, never forked)
**Version:** 1.3
**Date:** 2026-10-05
**Author:** USS-Voyager (Captain), for user QA review
**Status:** **D-01 … D-07 ALL RESOLVED** (user rulings 2026-10-05). Target
architecture captured (§4 — enterprise orchestration design). Non-blocking
design questions remain (Q-01…Q-04).

Registers: **R\*** = resolved fact · **F\*** = finding/fault · **D-\*** = decision · **R-F\*** = remediation action

---

## 1. Overall Spec (what we are building)

Synthesized from `AGENTS.md`, shared operational notes (`NIX_FLEET_ENGINEERING_PRINCIPLES.md`,
`infrastructure-2-evaluation-model.md`, `common-infra-strategies.md`,
`strategic_planning_prompt.md`, `promptdeploy-analysis-2026-06-26.md`) and active
documentation. **R-01 … R-09** are statements the documentation must reflect.

| ID | Spec statement | Source |
|---|---|---|
| R-01 | Professional "netrunner infrastructure", not a hobby project. Bargman-Tech production is **siloed in closed infrastructure**; GitHub is for public-facing projects only. | AGENTS.md Build Philosophy |
| R-02 | **Correctness over speed.** A four-hour evaluation is acceptable if it guarantees correctness. Golden tests are ground truth; deployments block on golden mismatch. | AGENTS.md |
| R-03 | **Closed-system builds**: self-hosted runners only. In-house binary cache (`cache.johnbargman.net`) is operational. Approved third parties: FlakeHub (inputs), `install.determinate.systems`, `cache.nixos.org`. No other intermediary without explicit user authority. | AGENTS.md (updated 2026-10-05) |
| R-04 | **Flake-only doctrine** on Determinate Nix: no home-manager, no flake-parts, no flake-utils; never edit `/nix/store`; **Flake Schemas on every flake output** (stated mandatory in shared principles — see F-22 gap). | NIX_FLEET_ENGINEERING_PRINCIPLES.md |
| R-05 | **Two-layer topology architecture**: `topology/<machine>.json` → pure `gen*` generators (via `mktopology`) → topology-derived config; user Nix overlays via module merge; golden = merged truth. | AGENTS.md boundary, topology-principle.md |
| R-06 | **Secrets via secrix**: age-encrypted at rest in-tree, decrypted to `/run` tmpfs on authorized hosts only; declare once, consume via `decrypted.path`; both user + host recipients required. | operations-runbooks.md, common-infra-strategies.md |
| R-07 | **Deployment product**: fleet exported via `github:Bargman-Tech/nixinate`; OpenCode-only support. Pipeline: build → test → validate → deploy. | promptdeploy-analysis, infrastructure-2-evaluation-model |
| R-08 | **Modularisation exists along ownership boundaries** — three tiers are already in the tree (see §4). Monolith is the default; extraction requires a stated boundary. | flake.nix cluster-box/denton-glasses/LLM-CORE blocks |
| R-09 | Documentation describes **current state**; plans live in separate docs (`opencode/plans/`); archived material must not read as active guidance. | strategic_planning_prompt.md:49-53 (enforced this revision) |
| R-10 | **Standard deployment doctrine (user, 2026-10-05):** this repo deploys **all** systems, automatically, eventually. Every system's flake input is **registered in this `flake.nix`** — mandatory. This repo defines the actual state of the machine; **an unregistered configuration is never switched.** Source may live elsewhere; deployment authority does not. | User ruling 2026-10-05 |
| R-11 | **Enterprise orchestration target (user, 2026-10-05):** break out of the mono-repo into a clearly defined machine-orchestration design — toolkit repos (`lib`, `LLM-CORE`, `github-ci`) + clean per-machine config repos (own goldens, own `topology.json`, own llm-fleet JSONs, exported via **custom flake schema**) + this repo as **parent orchestrator** (register → validate → deploy). The parent validates *its own evaluation* against the consumed machine's schema-exported JSON — **without violating the flake boundary**. Service definitions port out slowly over time. | User spec 2026-10-05 |

**F-20 (spec gap):** the grand-vision vocabulary (netrunner, fabrication forge,
siloed/proprietary split) exists only in repo docs, not in the shared notes.
**F-21: RESOLVED (2026-10-05)** — the monolith-vs-modular tension is resolved by
R-10/R-11: the monolith becomes the **orchestrator** (deployment authority,
registration, validation); source splits into enterprise repos. "Monolithic
codebases embraced" holds for the orchestration layer.
**F-22: RESOLVED BY DESIGN (2026-10-05)** — the Flake Schemas doctrine now has
its purpose: custom flake schemas are the **contract mechanism** by which machine
repos export their truth (goldens, topology, llm-fleet JSON) across the flake
boundary for parent-side validation. Implementation follows in the `lib` toolkit.
**F-23 (contradiction):** shared principles say "never `nix flake update`" while
`operations-runbooks.md` and `gitea-customization-options.md` show `nix flake update` commands.

---

## 2. Workflow Tracks — Completed & Underway

### 2.1 COMPLETED (validated against goldens / live)

| Track | Outcome | Evidence |
|---|---|---|
| **overlord-II planar topology** | Two-layer JSON→generator architecture live fleetwide; `topology-derive.nix` archived; B1–B5 closed (B5 backup validated on 4 machines) | AGENTS.md Current Issues 2026-10-05; `lib/topology/mktopology.nix` |
| **Fabrication Forge / Gitea unification** | Gitea canonical forge: multi-domain + reverse-proxy auth → LDAP/form auth; fleet PostgreSQL; `fabrication-forge` branding; **gitolite retired** (`git-ssh.nix` owns `git@` on WG :22) | documentation/gitea-fabrication-forge.md; git log 2026-10-01 |
| **In-house binary cache** | Signed nix-serve on remote-builder:5001, TLS `cache.johnbargman.net`, wired into flake + fleet substituters | services/nix-cache-serve.nix; flake.nix:5-12 |
| **Backup / offsite replication** | `genBackup` + `topology.backup` on gaming-host-1, LINDA, local-nas, terminal-zero; B2/rclone offsite on local-nas | topology/*.json `backup` keys; lib/rclone-target.nix |
| **Monitoring Phase 1** | All dashboards generative (genDashboard + inventory); no static dashboard JSON | documentation/monitoring-automation.md |
| **AI stack (live)** | Ollama on LINDA + pillar-of-autum, LiteLLM gateway on alpha-three; vLLM **undeployed** (migration executed then reversed) | machines/alpha-three/default.nix backends |
| **Assimilator-probe proven** | pillar-of-autum Phases 1–3 complete (probe → verified install → NVMe); first proven assimilation | documentation/planning-pillar-of-autum.md |
| **CI pipeline** | Generated workflow, auto-derived build matrices, security scan (Gitleaks + plaintext + hardcoded-IP) | ci.nix; documentation/ci-readme.md |
| **Documentation QA (this revision)** | 2026-10-05 refresh: stale claims corrected; archive established; this LDR | git 70a7f89 + this revision |

### 2.2 UNDERWAY

| Track | State | Next gate |
|---|---|---|
| **PR #24 `web-updates`** | CI in flight (Gitea branding, PostgreSQL migration, gitolite retirement, B2 backup targets); assumed complete for docs purposes | Green CI → merge decision (secrets confirmed age/secrix — see F-15) |
| **Enterprise orchestration split (P1–P5)** | **MASTER TRACK (user spec, 2026-10-05):** mono-repo → enterprise machine-orchestration design. Toolkit repos (`lib`, `LLM-CORE`, `github-ci`) + clean machine repos (own goldens/topology/llm-fleet via custom flake schema) + parent as standard deployment. §4.4 | P1: `lib` schema contract |
| **gaming-host-1 pivot → machine repo** | **NEW MISSION (user, 2026-10-05):** becomes a **remote-development machine** hosting the **free-agent game server** (co-developed). **First extraction (D-02)** into `bargman-tech/gaming-host-1` — clean minimal NixOS config, own truth files, separately maintained / freezable. | P2 of the master track |
| **Documentation QA review** | This document + archive | D-01/D-05/D-06 remain open |
| **Backup/offsite formalisation** | Replication live but no restore-test procedure fleet-wide (F-08) | User decision D-05 |

### 2.3 FUTURE / DEFERRED (the spec ahead)

| Track | Priority signal | Notes |
|---|---|---|
| **Architecture modularisation into standalone flakes** | **NEW — this session's mandate** | §4 below; **first extraction: gaming-host-1 → game-server-1 (D-02)** |
| **overlord-iii — genWireguard client migration** | Architectural closure | 16 machines on `enable-wg-topology.nix`; hub side already generated |
| **Monitoring Phase 2 — scrape generation** | Additive-only design already written | Root of AI-stack monitoring gaps (F-12) |
| **CI velocity / runner capacity** | Pain every PR (F-06…F-09) | 2 x86 slots, starved aarch64, near-OOM validation, store growth |
| **Game-server shared base module** | Subsumed by the game-server-1 extraction (D-02) | Shared notes future project; game servers currently disabled |
| **Host-key doctrine hardening** | Deferred by user ruling (D-04, 2026-10-05) | Re-key pillar-of-autum + ARM Stage 3 reconciliation in the **next hardening phase** |
| **Phase C1 (ketchup/mayo split), C2 (GH runner module)** | Deferred by design | AGENTS.md Phase C |
| **pillar-of-autum Phase 4 remainder, Phase 5 (OpenVINO/NPU)** | Low priority | Bootloader migration, iGPU validation, NPU research |
| **LLM-CORE extraction (opencode side)** | External track | overall-plan.md:448-470 |

---

## 3. Known Faults Register — FOR USER REVIEW

Severity: **critical / major / minor**. Status: **open** (needs user call or work),
**decided-deferred** (accepted, parked), **resolved** (fixed this revision).

### Critical / methodology

| ID | Fault | Sev | Status |
|---|---|---|---|
| F-01 | Two contradictory "active" x86 deployment guides existed (x86-bootstrap Stage 3 commits the probe's transient host key as identity; assimilator doc declares this "architecturally wrong") | critical | **resolved this revision** — x86-bootstrap guide archived; assimilator is the sole authority |
| F-02 | **pillar-of-autum's actual deployment used the void practice** — probe host key committed as device identity ("archived from probe, Stage 3"); no out-of-band fingerprint verification recorded | major | **decided-deferred (D-04)** — machine works; re-key in the **next hardening phase** |
| F-03 | **ARM deployment flow still uses host-key extraction** (Stage 3 pulls bootstrap host key, private key over SSH to /tmp) — same class of practice the x86 correction forbade | major | **decided-deferred (D-04)** — reconcile in the next hardening phase |

### Major — infrastructure & operations

| ID | Fault | Sev | Status |
|---|---|---|---|
| F-06 | PR CI wall-clock 3–5.5h; exactly 2 runner instances documented for x86 builds | major | open |
| F-07 | LINDA cold-cache builds ~6h (12h job timeout) — standing constraint | major | open |
| F-08 | No backup restore-test procedure fleet-wide | major | **decided-accepted (D-05, 2026-10-05)** — posture is **by design**; no drill mandate at this time |
| F-09 | MinIO backup bucket retains ALL history (46 files / 743 GB vs source 8 files / 163 GB) | major | **resolved — BY DESIGN (D-05)**: upload costs minimal; unlimited retention intentional; deletion is **manual** |
| F-10 | **Gitea settings are not covered by golden tests** (`dump-config` doesn't serialize `services.gitea.settings`) — validated only by `nixos-rebuild build` | major | decided-accepted |
| F-11 | **cluster-box MAX_QUEUE decision open since 2026-09-19** — MAX_QUEUE=512 with NUM_PARALLEL=1 allows ~256h queue vs 1h LiteLLM timeout | major | **routed (D-06)** — recorded in **Malayalam** `documents/known-issues.md` §7 with recommendation; dlyon to action independently (short-term horizon) |
| F-12 | Monitoring Phase 2 unimplemented; pillar-of-autum scrape target missing (dashboard already generated); 4 stale smartctl targets pinned as legacy | major | decided-deferred |
| F-13 | genWireguard client migration pending (overlord-iii) — 16 machines on legacy module | major | decided-deferred |
| F-14 | AI stack end-to-end gates open: gateway harness completion never recorded; near-128K memory measurement never done | major | open |
| F-15 | **PR #24 secrets** — `b2_master_sync_token` + `rclone-b2-config-file` confirmed **age/secrix encrypted** (watch-item closed). `b2_master_sync_token` is **held in reserve with intent** — not an orphan (D-07) | major | **resolved (D-07)** — recorded in operations-runbooks secrets inventory |
| F-16 | Identity risks on Gitea/LDAP: DB-backed auth sources reconciled by oneshot (not immutable); directory empty until `inetOrgPerson` provisioned ("login works for nobody"); anonymous LDAP search by directory policy | major | open |
| F-17 | CI validation near-OOM on runner (15.8 GB / 94% RAM peak, 1.0 GB min free, 16 GB runners) | major | open |
| F-18 | `/nix` store growth 0.5–5 GB per successful run; disk hits min-free in ~20 runs without GC | major | open |
| F-19 | aarch64 runner starvation — print-controller queues 2h+ for a ~2min build (real but previously unrecorded) | major | open |

### Minor

| ID | Fault | Sev | Status |
|---|---|---|---|
| F-20–F-23 | Spec gaps/contradictions (vision vocabulary, monolith-vs-flake, Flake Schemas, `nix flake update` policy) — see §1 | minor-major | **open (D-01, D-02, D-03)** |
| F-24 | Key-encryption flag policy drift: `--all-users` vs `-u John88 -s <host>` patterns documented inconsistently across 5 files | minor | open |
| F-25 | Gitea tmpfiles `Z ${stateDir}/custom` recursive chown vs branding symlinks — unverified | minor | open |
| F-26 | `fabrication-forge.com` DNS A-record manual step never closed out in docs | minor | open |
| F-27 | pillar-of-autum: GRUB→systemd-boot deferred; Vulkan iGPU offload validation pending deploy+reboot | minor | decided-deferred |
| F-28 | Prometheus alerting rules never implemented (KV-cache, queue depth, GPU temp, gateway health) | minor | decided-deferred |
| F-29 | Laguna GGUF→HF conversion deferred (needs dlyon/Malayalam coordination) | minor | decided-deferred |
| F-30 | ARM workflow stale branch reference (`jb/overlord-I`); pillar-of-autum.md double "## 6." numbering | minor | resolved this revision where touched; ARM branch ref remains |
| F-31 | `gitea-customization-options.md` §7.1 "goldens blocked" claim; gaming-host-1 stale backup JSON; `topology/cortex-alpha.nix` ref; ai-inference-findings hybrid-layout target | minor | **resolved this revision** |
| F-32 | Game-server module duplication (SteamCMD/user/firewall/tmpfiles ×5) | minor | decided-deferred (future base-module project) |

**Superseded/moot:** vLLM-era pending items (Qwen3.8 CPU testing, Phase 6.3) — see `archive/`.

---

## 4. Architecture Boundaries — Enterprise Orchestration Design

**D-01 RESOLVED (user spec, 2026-10-05).** The boundary question is settled by
the target architecture itself: break out of the mono-repo into a clearly
defined **enterprise-grade nix machine-orchestration design** (R-11). The A/B/C
options discussion is closed — this design supersedes it.

### 4.1 The target stack (user spec, 2026-10-05)

| Repo | Role |
|---|---|
| `bargman-tech/lib` | **Supporting toolkit** — shared utilities; **defines the custom flake schema contract** (golden/topology/llm-fleet JSON export shape) used by machine repos and the parent alike |
| `bargman-tech/LLM-CORE` | Supporting toolkit — agent fleet generation (already extracted) |
| `bargman-tech/github-ci` | Supporting toolkit — CI generation (today's `ci.nix` + `ci/generate-workflow.nix` shape) |
| `bargman-tech/gaming-host-1` | **Machine repo** — very clean minimal NixOS configuration. Carries **its own** golden tests, `topology.json`, and llm-fleet JSONs, exported as a **custom flake schema** |
| `bargman-tech/nixos-configuration` | **Parent project** — the standard deployment. Registers every machine's flake input, **validates its own evaluation** against the consumed machine's schema-exported JSON, deploys all systems |

### 4.2 The invariant and the variable

- **Invariant (R-10):** deployment authority is *here*. Every system's flake
  input is recorded in this `flake.nix`; this repo defines the machine's actual
  state; **no registration → no switch.** Automatically, eventually, all systems.
- **Variable:** where the *source* is maintained. Source may live in an
  independently maintained, freezable repo; its truth (goldens, topology,
  llm-fleet) travels with it through the schema.

### 4.3 Cross-flake validation without boundary violation

The golden discipline survives the flake boundary intact:

```
machine repo (e.g. gaming-host-1)                parent (nixos-configuration)
───────────────────────────────                  ────────────────────────────
nixosConfigurations.gaming-host-1 ─────────────► evaluate (parent's own evaluation)
schemas.truth = {                                  │
  goldens/gaming-host-1.json,                      │   compare eval
  topology.json,                            ─────► │   ⇄ schema-exported goldens
  llm-fleet.json                                   │
}  (defined by bargman-tech/lib)                    ▼
                                            match  → state defined → deploy
                                            mismatch → BLOCK switch
```

- The parent consumes the machine's JSON **through the flake schema output** —
  never by reaching into the machine's tree. Flake boundary unviolated.
- The machine repo regenerates its goldens when *its* config changes
  (intentional-change discipline unchanged, just relocated).
- This is the purpose the Flake Schemas doctrine (R-04) always pointed at —
  schemas are the **contract mechanism**, defined once in `lib`, exported by
  machine repos, consumed by the parent (resolves F-22).

### 4.4 Migration programme

Phased, deliberate (Phase Discipline). Service definitions port out slowly.

| Phase | Work | Gate |
|---|---|---|
| **P1** | `bargman-tech/lib` toolkit: custom schema definition + golden/topology validation utilities extracted from today's `lib/` (serialize-config, golden tooling, topology generators as needed) | schema contract approved; goldens still pass in-place |
| **P2** | **gaming-host-1 machine repo** (first extraction, D-02): minimal NixOS config + own `topology.json` + own goldens + llm-fleet JSON → schema export; parent registers input and validates | parent eval matches machine goldens; deploy path proven (Malayalam passthrough mechanics as prior art) |
| **P3** | `bargman-tech/github-ci` toolkit: CI generation ported out; per-machine repos get lean own CI where they maintain source | fleet CI still green; matrices still auto-derived from registration |
| **P4** | Subsequent machine repos follow (candidate order below) + **services slowly port out** to owning machine repos / `lib` | each machine: same validation gate |
| **P5** | Parent becomes pure orchestrator: registration, validation, deployment | AGENTS.md + development-guide rewritten to the design |

| Candidate | Target | Status |
|---|---|---|
| **gaming-host-1 → machine repo** (remote-dev + free-agent game server) | `bargman-tech/gaming-host-1` | **SELECTED — first extraction (D-02)** |
| cluster-box | Malayalam (external) | already outside; remains the external-ownership variant of this pattern |
| Gitea / Fabrication Forge stack | service port-out (own repo or `lib`) | gradual (P4) |
| AI stack (ollama/LiteLLM schema) | toolkit or machine-local | gradual (P4) |
| Monitoring (inventory + dashboards) | `lib` toolkit | gradual (P4) |
| Backup/rclone-target | `lib` toolkit | gradual (P4) |
| Topology generators (`gen*`) | `lib` toolkit | gradual (P4) |

### 4.5 Prior art and boundary hygiene

- **Malayalam/cluster-box** is the proven external-ownership variant: verbatim
  passthrough + `extendModules`/`mkForce` on deployment metadata only; contract
  in the Malayalam repo's `documents/architecture-passthrough.md`.
- The AGENTS.md Architecture Boundary (generator-vs-user-Nix) remains settled
  and moves with the topology generators into `lib` when they port (P4).
- Every machine repo carries a contract document (owner, freeze policy, schema
  version, handover items: WireGuard keys, secrix recipients, users).
- Golden regeneration authority follows the source: the machine repo regenerates
  its own goldens; the parent never edits them.

---

## 5. Documentation Remediation Register (R-F\*)

| ID | Action | Acceptance criteria | Status |
|---|---|---|---|
| R-F-01 | Archive superseded docs: `vllm-migration-plan.md`, `vllm-architecture.md`, `vllm-cpu-fix.md`, `ai-upgrades.md`, `x86-bootstrap-deployment-workflow.md`, `ci-build-metrics/` | `documentation/archive/README.md` lists all with reasons; no active doc presents them as guidance; cross-refs updated | **done** |
| R-F-02 | Fix stale claims: gaming-host-1 backup JSON, gitea-customization §7.1, `topology/cortex-alpha.nix` ref, ai-inference-findings target-layout banner | grep for stale strings returns only historical framings | **done** |
| R-F-03 | Record cluster-box unmanaged boundary in AGENTS.md Fleet Status | AGENTS.md names ownership, authority split, and lifecycle carve-outs | **done** |
| R-F-04 | Produce this LDR as the living spec/tracks/faults/boundaries record | User review completed; open decisions answered or explicitly deferred | **in progress — awaiting user** |
| R-F-05 | Resolve D-03 `nix flake update` policy in active docs | One rule stated in AGENTS.md and reflected in runbooks | **done** — per-input only, in AGENTS.md CRITICAL Constraints + operations-runbooks + gitea-customization note |
| R-F-06 | Fold unique x86-bootstrap build/discovery content into assimilator doc if anything remains unstated | assimilator doc self-sufficient; archive file untouched | pending review |
| R-F-07 | Fix ARM workflow stale branch ref + pillar-of-autum double §6 (F-30 remainders) | grep clean | **done** |
| R-F-08 | Document B2 secrets (`rclone-b2-config-file` wiring; `b2_master_sync_token` fate) in operations-runbooks | Secrets table complete; no orphans | **done** — Known Secrets Inventory table added (D-07: reserve with intent) |

---

## 6. Evidence Appendix (reproduction commands)

| Claim | Command | Observed |
|---|---|---|
| 21 machines, 3 dormant | `ls machines/ \| wc -l`; `flake.nix` `dormantConfigurations` | 21; alpha-two, storage-array, display-0 |
| 22 goldens | `ls goldens/ \| wc -l` | 22 (20 machines + ci.json + bargman-greeter-vm.json) |
| Backup keys live | `git grep -l '"backup"' origin/web-updates -- topology/` | gaming-host-1, LINDA, local-nas, terminal-zero |
| Cache operational | `grep substituters flake.nix configuration.nix`; `machines/remote-builder/default.nix` | cache.johnbargman.net wired, port 5001, TLS nginx |
| gitolite retired | `ls server_services/` | `git-ssh.nix` present, `gitolite.nix` absent (deleted 2026-10-01) |
| vLLM undeployed | `grep -rln vllm machines/` | (no matches) |
| genWireguard hub-only | `sed -n '290,297p' lib/topology/mktopology.nix` | conditional on `topology.wireguard` |
| enable-wg on 16 machines | `grep -rln enable-wg-topology machines/ \| wc -l` | 16 |
| B2 secrets age/secrix | `head -1 secrets/b2_master_sync_token secrets/rclone-b2-config-file` | `age-encryption.org/v1`, ssh-ed25519 recipients |
| b2_master_sync_token orphan | `grep -rn b2_master_sync_token .` | secrets/ file only |
| CI: 2 runner instances | `documentation/archive/ci-build-metrics-2026-08/README.md` | hate-filled-1/2 on remote-builder |

---

## 7. Close

**Version 1.3 — 2026-10-05.**

### Decisions resolved (user rulings, 2026-10-05)

| ID | Ruling |
|---|---|
| **D-01** | **RESOLVED by the enterprise orchestration spec (§4).** Mono-repo → toolkit repos (`lib`, `LLM-CORE`, `github-ci`) + clean machine repos (own goldens/topology/llm-fleet exported via custom flake schema defined in `lib`) + this repo as parent/standard deployment. Parent validates its own evaluation against the consumed machine's schema JSON without violating the flake boundary. Services port out slowly. The A/B/C discussion is closed. |
| **D-02** | **gaming-host-1 is the first machine repo** (`bargman-tech/gaming-host-1`) — remote-dev + free-agent game server, separately maintained, freezable. P2 of the master track. |
| **D-03** | **`nix flake update` per input only.** Wholesale update prohibited. Documented in AGENTS.md + runbooks. |
| **D-04** | **No re-keying now.** pillar-of-autum works; host-key doctrine (F-02/F-03) deferred to the **next hardening phase**. |
| **D-05** | **Backup posture is by design.** Upload costs minimal; unlimited retention intentional; deletion is **manual**. No restore-test mandate at this time. |
| **D-06** | **Routed to Malayalam documentation.** MAX_QUEUE analysis + recommendation recorded in Malayalam `documents/known-issues.md` §7; to be actioned independently on a short-term horizon. |
| **D-07** | **`b2_master_sync_token` is held in reserve with intent** — not an orphan. Do not delete. Recorded in operations-runbooks. |

### Open questions (non-blocking, design detail for P1/P2)

| ID | Question |
|---|---|
| Q-01 | Machine repo naming: `bargman-tech/gaming-host-1` (matches the spec list) vs `game-server-1` (the pivot name)? Rename of the machine itself is a separate, later decision. |
| Q-02 | Schema contract scope in `lib`: goldens + topology + llm-fleet only, or also monitoring/backup declarations? |
| Q-03 | During migration, does gaming-host-1 keep parent-side golden coverage until P2 completes (recommended — continuous validation), or drop it at extraction? |
| Q-04 | `github-ci` toolkit: extract `ci.nix` as-is first, or redesign the workflow shape while extracting? |
