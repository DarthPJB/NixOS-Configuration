# LDR-001 — Fleet Spec, Tracks & Architecture Boundaries

**Type:** Living Decision Record (one living document — corrections in place, never forked)
**Version:** 1.1
**Date:** 2026-10-05
**Author:** USS-Voyager (Captain), for user QA review
**Status:** Partially decided — D-02/D-03/D-04/D-07 **RESOLVED** (user rulings
2026-10-05); D-01/D-05/D-06 **OPEN** with briefings supplied below

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

**F-20 (spec gap):** the grand-vision vocabulary (netrunner, fabrication forge,
siloed/proprietary split) exists only in repo docs, not in the shared notes.
**F-21 (spec gap):** "Monolithic codebases embraced" (shared notes) vs the
mecha-team-zero multi-flake split (LLM-CORE, Malayalam, denton-glasses,
assimilator-probe, personal-site) is **unreconciled** — this is exactly what §4
must resolve. **F-22 (spec gap):** Flake Schemas doctrine is unimplemented in
`flake.nix` and unmentioned in active docs. **F-23 (contradiction):** shared
principles say "never `nix flake update`" while `operations-runbooks.md` and
`gitea-customization-options.md` show `nix flake update` commands.

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
| **gaming-host-1 pivot → `game-server-1`** | **NEW MISSION (user, 2026-10-05):** the machine becomes a **remote-development machine** and hosts the game server for the **free-agent game** (co-developed). First modularisation extraction (D-02). Game servers currently disabled — preserved config becomes the seed of the extraction. | D-01 boundary principle + extraction-tier confirmation (§4.3 design) |
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
| F-08 | **No backup restore-test procedure exists fleet-wide** — while B2/MinIO replication is now load-bearing | major | open (D-05) |
| F-09 | MinIO backup bucket unbounded: 46 files / 743 GB vs source 8 files / 163 GB; no lifecycle policy | major | open |
| F-10 | **Gitea settings are not covered by golden tests** (`dump-config` doesn't serialize `services.gitea.settings`) — validated only by `nixos-rebuild build` | major | decided-accepted |
| F-11 | **cluster-box MAX_QUEUE decision open since 2026-09-19** — MAX_QUEUE=512 with NUM_PARALLEL=1 allows ~256h queue vs 1h LiteLLM timeout; recommendation MAX_QUEUE=8 unactioned | major | **open (D-06 — briefing supplied 2026-10-05)** |
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

## 4. Architecture Boundaries & Modularisation Direction

### 4.1 The three tiers already in the tree (R-08, evidenced)

| Tier | Pattern | Prior art | Ownership | Lifecycle |
|---|---|---|---|---|
| **1. Monolith** (default) | `machines/` + `server_services/` + `modules/` inside NixOS-Configuration | the fleet itself | John88 | topology transforms, goldens, CI |
| **2. Module-export flake** | External flake exports `nixosModules.*`, composed via `extraModules` | denton-glasses (`eye-tracking`, `voxtype`); LLM-CORE (`opencode-fleet`); assimilator-probe | shared / mecha-team-zero | golden-tested as part of host closure |
| **3. Verbatim passthrough** | External flake owns the entire `nixosConfiguration`; parent passes it through with `extendModules` + `mkForce` on **deployment metadata only** | **Malayalam / cluster-box** (`git+https://gitlab.com/mecha-team-zero/Malayalam.git`) | external operator (dlyon); parent holds architectural authority only | **Excluded** from topology transforms, goldens, CI |

Malayalam contract (fl.nix:851-889 + Malayalam `documents/architecture-passthrough.md`):
system closure identical across deploy paths; only nixinate host/sshUser/port may
differ; `git+https` input format required for netrc auth.

### 4.2 Proposed boundary principle — **D-01 OPEN (Captain recommendation: A)**

> A component is extracted into a standalone flake when it crosses an
> **ownership boundary** (different operator), an **appliance boundary**
> (self-contained hardware/product), or a **reuse boundary** (consumed by other
> repos). Everything else stays in the monolith.

Options for D-01:
- **A.** Adopt as written; tier-2 for shared components, tier-3 for external ownership.
- **B.** Stricter: only ownership boundaries justify extraction (monolith-maximalist).
- **C.** Looser: also extract by domain (e.g., Gitea stack, AI stack) for independent release cadence.

**Captain's briefing (user requested direction — 2026-10-05):**

Recommend **A**. The tree already embodies A — it is both descriptive of the
three existing tiers and prescriptive for what comes next. The selected first
extraction (D-02: game-server-1 / free-agent game) hits **all three triggers**:
appliance (game server), ownership (co-developed free-agent project), and reuse
(remote-development access). Option B would block the game-server base-module
extraction (a stated future project) — module extraction has value even without
external ownership. Option C would extract Gitea/AI/monitoring by domain, but
those are single-owner and golden-tested against topology; the extraction cost
exceeds the benefit until a boundary appears — it also conflicts with the
"monolithic codebases embraced" doctrine in the shared notes (F-21).
A is the only option that reconciles F-21 (monolith default) with R-08 (tiered
modularisation exists) without flake sprawl.

### 4.3 Extraction programme — **D-02 DECIDED (user, 2026-10-05)**

**Ruling: `game-server-1` (today's gaming-host-1) is the FIRST extraction.** The
machine pivots to a **remote-development machine** and hosts the game server for
the **free-agent game** (co-developed). Remaining candidates below stay parked.

**Recommended extraction design (pending D-01 confirmation) — split by boundary:**

| Piece | Goes where | Tier | Why |
|---|---|---|---|
| **Free-agent game server** (game config, data dirs, backup targets, updates) | Standalone flake in the free-agent project repo (mecha-team-zero / co-dev space) | **2** — exports `nixosModules.*`, composed via `extraModules` | Ownership boundary: co-developed. Co-devs iterate on the game server without touching fleet config. |
| **Machine base** (remote-dev environment, WireGuard, topology, secrix, sshd) | Stays in NixOS-Configuration monolith | **1** | Keeps goldens/CI/topology coverage — avoids the Malayalam carve-out cost while John88 remains the operator. |
| **Whole-machine passthrough** (Malayalam style) | — | 3 | **Not recommended yet** — only if the free-agent project grows its own operator. Costs: loses goldens/topology/CI, requires an architecture-passthrough contract. |

Also planned with the pivot: machine rename `gaming-host-1` → `game-server-1`
(topology JSON, flake registration, golden regeneration — intentional config
change, golden regen authorized). The disabled game-server modules become the
seed of the extracted flake.

| Candidate | Tier | Rationale | Status |
|---|---|---|---|
| **game-server-1 (gaming-host-1) — free-agent game server + remote-dev** | 2 (split) | D-02 ruling; all three boundary triggers | **SELECTED — first extraction** |
| Game-server shared base module | 2 | Kills 5× SteamCMD/user/firewall/tmpfiles duplication | subsumed by the extraction above |
| Gitea / Fabrication Forge stack | 2 or 3 | Self-contained; brand is product-facing | parked (only under D-01 option C) |
| AI stack (ollama module + LiteLLM schema) | 2 | Reused across LINDA, pillar-of-autum, alpha-three | parked |
| Monitoring (inventory + dashboard gen) | 2 | Already a coherent `lib/` + templates unit | parked |
| Backup/rclone-target | 2 | Small, shared across 4 machines | parked |

### 4.4 Boundary hygiene required regardless of D-01/D-02

- The AGENTS.md Architecture Boundary (generator-vs-user-Nix) is settled (2026-10-05: genNginx emits the full topology-derived vhost surface).
- Tier-3 members must stay carved out of topology/goldens/CI (cluster-box is the proof; now recorded in AGENTS.md Fleet Status).
- Any extraction must declare its tier, owner, and lifecycle obligations in its own `documents/architecture-passthrough.md`-style contract.

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

**Version 1.1 — 2026-10-05.**

### Decisions resolved (user rulings, 2026-10-05)

| ID | Ruling |
|---|---|
| **D-02** | **game-server-1 (gaming-host-1) is the first extraction.** Machine pivots to remote-development + free-agent game server (co-developed). Design in §4.3. |
| **D-03** | **`nix flake update` per input only.** Wholesale update prohibited. Documented in AGENTS.md + runbooks. |
| **D-04** | **No re-keying now.** pillar-of-autum works; host-key doctrine (F-02/F-03) deferred to the **next hardening phase**. |
| **D-07** | **`b2_master_sync_token` is held in reserve with intent** — not an orphan. Do not delete. Recorded in operations-runbooks. |

### Open decisions — briefings supplied (2026-10-05)

| ID | Question | Briefing |
|---|---|---|
| **D-01** | Boundary principle | **Captain recommends A** — full rationale in §4.2. A reconciles the monolith doctrine (F-21) with the three existing tiers and unlocks the D-02 extraction cleanly. B blocks the game-server module; C causes flake sprawl on golden-tested single-owner stacks. |
| **D-05** | Backup restore-testing | **What exists:** two-hop chain — machines → MinIO (LINDA/terminal-zero → `minio:obsidian-v3`; gaming-host-1 → `minio:minecraft-backups`) → B2 (`b2:minio-backup-bargman/*` — obsidian-v3, linda-home, bargman-tech, minecraft-backups, fs-v3-88 + 1). Restore must traverse B2→MinIO→machine **and** the secrix-encrypted rclone configs — the decryption path is itself an untested failure mode. **Options:** (a) **Tiered drills** — monthly automated `rclone check` (hash verify, ~zero egress cost), quarterly manual sample-restore of latest backups to a scratch target (trivial B2 egress ~$0.01/GB), annual full-restore drill of `obsidian-v3` (the irreplaceable 88-DB knowledge base); (b) quarterly sample-restore only; (c) accept risk. **Captain recommends (a)** — cost is negligible next to 743 GB of unverified backups (F-09). Deliverable: `documentation/backup-restore-testing.md` runbook + timers. |
| **D-06** | MAX_QUEUE | **What exists:** cluster-box runs `laguna-xs-2.1:q4_K_M` (33.4B) at NUM_PARALLEL=1 — ~30 min/request; Ollama default MAX_QUEUE=512 means request #512 waits ~256h while LiteLLM per-model timeout is 1h (request_timeout 8h). Every timeout expires long before service — silent failure accumulation. LINDA runs NUM_PARALLEL=1, MAX_LOADED_MODELS=1 (RAM safety for Laguna S 96GB loads). **Options:** (a) **MAX_QUEUE=8 on LINDA + request dlyon set the same on cluster-box** (cluster-box is Malayalam-managed — we hold architectural authority but dlyon operates it); keep NUM_PARALLEL=1; fail-fast beats silent queuing; agent fleet can reroute. (b) MAX_QUEUE=16–32 (burst buffer for batch jobs, ~8–16h garbage tail). (c) Leave 512 and rely on LiteLLM timeouts. (d) Raise NUM_PARALLEL instead (real throughput lever but roughly doubles KV-cache RAM — risky next to 96GB model loads). **Captain recommends (a)** — matches the timeout reality; also verify the exact Ollama env var name on the running version before applying. |
