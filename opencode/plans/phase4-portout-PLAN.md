# Phase 4 — Machine Repos & Service Port-Out — Run Document

> **Status:** ACTIVE — discussion draft. Open rulings (§5) gate execution.
> **Owner:** John88 / USS-Voyager (Janeway)
> **Date:** 2026-11-12
> **Predecessors:** `mayo-split-PLAN.md` (P1/P2 ✅), `structure-checks-PLAN.md`
> (D-11 ✅), `secret-sauce-PLAN.md` (P3 realised + first P4 port-out ✅).
> **Spec:** LDR-001 §4.4 (migration programme P1–P5), §4.5 (boundary hygiene).

---

## 1. Objective

**P4 (LDR-001 §4.4):** *subsequent machine repos follow + services slowly port
out to owning machine repos / `lib`.* Gate per the spec: **each machine — same
validation gate** (golden parity + build + deploy path, exactly the Gate A/B
pattern proven on gaming-host-1).

P4 ends when the parent holds only orchestrator duties → **P5** (*parent
becomes pure orchestrator: registration, validation, deployment*; AGENTS.md +
development-guide rewritten to the design).

### What P4 inherited (already ported — context, not work)

| Item | Destination | LDR P4 row |
|---|---|---|
| Topology generators + mktopology + registry | `mayo:lib/ketchup/` | ✅ done (mayo-split) |
| rclone-target (backup options module) | `mayo:lib/mayo/` | ✅ done (mayo-split) |
| Golden tooling + structure lints | `mayo:lib/mayo/` | ✅ done (mayo-split) |
| Grafana dashboards (genDashboard + templates) | `mayo:lib/mayo/monitoring/` | ✅ done (secret-sauce R2) |
| CI generation | `nix-github-ci` (public) | ✅ done (secret-sauce R1 = P3) |

So of the §4.4 candidate table, **Monitoring (dashboards), Backup/rclone and
Topology generators are complete**; what remains is below.

---

## 2. Workstreams

### W1 — Machine repo extractions (the P4 core)

Roll the gaming-host-1 pattern (passthrough → schema export → mayo consumption
+ D-08 staging doctrine) to subsequent machines. **Candidate order is an open
ruling (R-4a)** — candidates by value:

| Candidate | Why | Weight |
|---|---|---|
| **cortex-alpha** (hub) | hub of hubs — firewall/DNS/nginx/WG hub config; highest topology coupling; proves the hub case (gaming-host-1 was a leaf) | heavy, high value |
| **LINDA** | biggest single machine (AI stack, GPU, Windows VM estate); owns the most services that are P4 port-out targets anyway | heavy, high value |
| **local-nas** | monitoring host (prometheus/grafana), backups, postgres/minio — owns two port-out targets | medium-heavy |
| **terminal-zero / terminal-nx-01** | lighter leaf-ish machines; fast pattern rehearsal | light |

**Pattern per machine (unchanged from mayo-split Gates A/B):**
1. Child repo created (org/location per machine; GitLab for fleet machines unless ruled otherwise).
2. Step-1 passthrough: parent consumes via `extendModules`, D-08 overrides only, golden byte-identical → **GATE Aᵢ**.
3. Step-2 schema export (`bargman-tech.topology.json` + `identity.*`), parent aggregates by precedence → **GATE Bᵢ**.
4. Step-3: child vendors nothing; consumes mayo (+ nix-github-ci if it gets CI) → **GATE Cᵢ**.
5. Golden authority moves to the machine repo (LDR §4.5); parent keeps its copy until cutover.

### W2 — Service port-outs (§4.4 candidate table, remaining rows)

| Service | Parent location | Target options | Notes |
|---|---|---|---|
| **Gitea / Fabrication Forge stack** | `server_services/gitea.nix`, `gitea-branding/`, `git-ssh.nix`, `ldap.nix` (+ acme/porkbun deps) | own repo (like gaming-host-1) **or** Mayo generic module + parent data | largest proprietary stack; R-4b |
| **AI stack** | `services/{ollama,ollama-ui,litellm}.nix`, `pkgs/{vllm-cpu,zentorch,models/}` | machine-local (LINDA/alpha-three own it) **or** toolkit repo | schema-shaped (backends/Modelfiles) — R-4c |
| **Monitoring inventory Phase 2** | `lib/monitoring/inventory.nix` (Phase 1 done) | scrape generation from inventory → `services/prometheus.nix` shrinks | documented future work (`monitoring-automation.md`); machinery could then follow dashboards into mayo (data-injected) |
| **Game-server base module** | `server_services/game_servers/` (disabled 2026-10-04) | owning machine repo when re-enabled | deferred with game servers |
| **ssh-multiplex** | `modules/ssh-multiplex.nix` | **Mayo candidate after parameterisation** (embeds real fleet IPs → Secret-Sauce as-is; mayo-split as-built note) | small, mechanical |

### W3 — P3/P4 remainders (cheap, ride-along)

- **Per-machine lean CI:** gaming-host-1 has no `.github/workflows` — give it a
  nix-github-ci consumption (or GitLab CI — it lives on GitLab; open point R-4d).
- **Structure-checks P3:** CI single-input lock lint + generator unit-test
  fixtures as checks — natural home is now `nix-github-ci`'s own CI.
- **Staging keys / native virtualisation** for children (mayo-split §7 gated
  task — child's own staging identities, never production material).

### W4 — P5 exit criteria (definition of done for P4)

- [ ] Every deployed machine except cluster-box (external) is either a child
      flake or explicitly ruled to stay parent-side.
- [ ] Parent `services/`, `server_services/`, `environments/` hold only
      fleet/Secret-Sauce data; generic modules live in mayo / machine repos.
- [ ] `nix flake check` + structure suite green; golden sweep green; fleet CI green.
- [ ] AGENTS.md + development-guide rewritten to the orchestrator design (P5 gate).

---

## 3. Sequencing proposal (draft — pending R-4a…R-4d)

```
S1  W3 remainders (lean CI for child, structure-checks P3)   — small, independent
S2  W2 ssh-multiplex parameterisation → mayo                 — small, proves Mayo-module path
S3  W2 Monitoring inventory Phase 2 (scrape generation)      — parent-internal, shrinks prometheus.nix
S4  W1 next machine repo (per R-4a) — full Gates Aᵢ/Bᵢ/Cᵢ   — the heavy lift
S5  W2 AI stack port-out (follows/parallels LINDA extraction if LINDA chosen)
S6  W2 Gitea stack port-out (largest; last, after pattern is routine)
S7  P5 rewrite + close
```

Rationale: S1–S3 are low-risk rehearsals that shrink the parent before the
next heavy extraction; the Gitea stack waits until the extraction pattern has
been run twice.

---

## 4. Hard rules (carry over unchanged)

1. Goldens sacrosanct; regeneration only on intentional change, user-authorised.
2. Per-input flake updates only.
3. D-08 staging doctrine for every new child (no ciphertext, no placeholders,
   no `secrets/` copies; standalone eval failure accepted).
4. Production overrides = D-08 allowlist only (no widening without ruling).
5. No child imports parent (flake cycle).
6. New repos: public/private per content (fleet data ⇒ private; generic
   library ⇒ public like mayo/nix-github-ci).
7. Push before parent relocks (`git+https` resolves pushed revs only).

---

## 5. Open rulings (discuss before S1)

| ID | Question | Options | Recommendation |
|---|---|---|---|
| **R-4a** | Which machine is extracted next, and the order after it? | cortex-alpha (hub case) · LINDA (owns AI stack) · local-nas (owns monitoring) · terminals (light rehearsal first) | **cortex-alpha first** — proves the hub case while the pattern is fresh from gaming-host-1; leaves LINDA (heaviest) until the pattern has run twice |
| **R-4b** | Gitea/Forge stack target? | own repo · mayo (generic forge module + parent data) · stay parent | **own repo** — it is proprietary, multi-domain, LDAP-coupled; Secret-Sauce by the demarkation rule |
| **R-4c** | AI stack target? | machine-local (follows its machines) · separate toolkit repo | **machine-local first** (LINDA/alpha-three), toolkit only if a third consumer appears |
| **R-4d** | gaming-host-1 CI shape? | nix-github-ci on GitHub Actions (child mirrors parent) · GitLab CI (child lives on GitLab) · none | **GitLab CI** — the child's forge is GitLab; GitHub Actions would need runners there |
| **R-4e** | Do S1–S3 ride along now, or wait for R-4a decision only? | all now · S1 only | **S1 now** (cheap, independent), S2–S3 after R-4a |

---

## 6. Decision log

| Date | Decision |
|---|---|
| 2026-11-12 | Run document created; P4 scope inventoried against LDR §4.4 — Monitoring/Backup/Topology rows already complete via mayo-split + secret-sauce (plan) |
| | *R-4a…R-4e pending user discussion* |
