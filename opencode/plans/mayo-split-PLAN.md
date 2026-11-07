# Mayo Split — Phase Working Document

> **Status:** ACTIVE — living working document (not frozen). Updates in place as gates clear.
> **Owner:** John88 / USS-Voyager (Janeway)
> **Companion docs:** `documentation/LDR-001-fleet-spec-and-boundaries.md` (D-08,
> §4.4), `AGENTS.md` (Architecture Boundary + Staging/Production Doctrine),
> `documentation/topology-principle.md` (generator purity law),
> `documentation/gaming-host-1.md` (machine ops).
> **First subject:** gaming-host-1 → `gitlab.com/mecha-team-zero/gaming-host-1` (private, GitLab).
> **Supersedes:** the earlier gaming-host-1 extraction plan (this document absorbs it).

---

## Repository Map

| Repo | Location | Local checkout | Visibility |
|---|---|---|---|
| **gaming-host-1** (child machine flake) | `gitlab.com/mecha-team-zero/gaming-host-1` | `/speed-storage/bargman-tech/gaming-host-1` | private |
| **mayo** (schema + shared config surface) | `github.com/Bargman-Tech/mayo` | `/speed-storage/bargman-tech/mayo` | private |

Both repositories are **created** (2026-11-07) with an initial README commit on `main`.

---

## 1. Phase Objective

The objective of this phase is the **full Ketchup / Mayo / Secret-Sauce boundary**
— demarking the three layers of the fleet configuration so that machines can be
unlatched from the parent into their own flakes. The demarkation is **proven by
extraction, not designed in the abstract**: we unlatch a whole system first
(gaming-host-1), observe where the boundary actually falls, and only then fix
the boundary in code.

The boundary is expressed through **flake inputs as the contract points**.
Shared libraries are separated **incrementally**; an exported module or function
on a consumed input is the unit of contract. The contract can be **fulfilled by
the parent** (real data: topology, keys, production overrides) or **mocked for
local development** (so a child can evaluate standalone).

### The three layers

| Layer | What it is | Where it lives (target) |
|---|---|---|
| **Ketchup** | Open-source topology engine: pure JSON→attrset generators, validation, serialization, generic NixOS modules. No machine data, no secrets. | shared lib (portable) |
| **Mayo** | Shared configuration surface: reusable NixOS modules + helpers shared across machines (ssh-multiplex, rclone-target, mkKnownHosts, network-interfaces, config baseline). Generic, non-proprietary. | shared lib (the "mayo library") |
| **Secret-Sauce** | Proprietary: machine-specific configs, real topology data, secrets, proprietary service definitions and overlays, the parent flake itself. | parent (and each owning machine repo for its own config) |

The **mayo library** is the home of Mayo (+ Ketchup) code. Its **first
application** is the `bargman-tech` schema/lib repo (§5).

---

## 2. Contract Model

### 2.1 Child (machine) flake — a working environment

A child machine flake is a **complete, standalone-runnable NixOS config** — the
staging truth. It *exports*:

1. **System config** — `nixosConfigurations.<machine>` (its own buildable config).
2. **Contract surface** — exported modules and functions (flake outputs) that the
   parent consumes.
3. **Schema export** — its **own** peer topology and public keys, under a
   `bargman-tech` output attribute (§5).

### 2.2 Parent flake — production orchestrator

The parent **consumes each child as a flake input** and:

1. **Aggregates** every child's exported topology into the fleet registry (the
   function `mkRegistry`/`mktopology` currently performs by reading all
   `topology/*.json` from disk — this moves to aggregating children's schema exports).
2. **Overrides options** on the child's config via `extendModules` — secrix
   `encrypted.file` → parent ciphertext paths, `hostPubKey`,
   `defaultEncryptKeys`, nixinate deploy metadata. This is production actualisation (D-08).
3. **Validates** against the parent-side golden (byte-identical; regeneration forbidden).

### 2.3 Fulfil vs mock

The exported modules/functions define a **contract**. Two implementations:

- **Fulfilled** — the parent provides real data and overrides.
- **Mocked** — for local/standalone child development, the child carries a mock
  of the parent-provided side (stub registry, dummy peer list, placeholder parent
  inputs) so it can evaluate in isolation. The mock lives in the child's dev
  surface (`devShell`/`checks`), **not** in the shipped contract.

### 2.4 Hard constraint — no flake cycles

A flake cannot import its importer. Because the parent imports the child as an
input, **the child must never import the parent**. Therefore the child cannot
reuse parent library files by input reference; any shared surface the child
needs is either **vendored temporarily** (§6 Step 1) or, later, obtained from
the **shared `bargman-tech` lib repo** — which both parent and child consume
independently (no cycle).

---

## 3. Two Consumption Patterns

The fleet contains two distinct parent↔child shapes. They must not be conflated.

| | **cluster-box** | **gaming-host-1** |
|---|---|---|
| Pattern | **Pure system configuration** (external system) | **Schema-exporting child** (new pattern) |
| Parent consumes | `malayalam.nixosConfigurations.cluster-box.extendModules` | `inputs.<machine>.nixosConfigurations.<machine>.extendModules` **+** `inputs.<machine>.bargman-tech.*` |
| Schema export | none | yes (topology + public keys) |
| Overrides | deploy metadata only (`_module.args.nixinate`) | deploy metadata + secrix production ciphertext (D-08) |
| Fate | **stays** pure system config | first full schema exporter |

**cluster-box** remains the external-ownership variant (owned/operated by dlyon;
John88 holds architectural authority). It is prior art for the `extendModules`
mechanics, not for the schema contract.

**gaming-host-1** is the first machine to export the `bargman-tech` schema. It
is the proving ground for the whole contract model.

---

## 4. Execution — Boolean Gates

Execution iterates through **clear boolean gates**. No step proceeds until its
gate is **true**; a false gate is a stop-and-fix, never a skip.

```
Step 1: passthrough extraction  ──▶  GATE A: "extracted configuration deploys"
Step 2: schema export            ──▶  GATE B: "deploys via consumed topology"
Step 3: bargman-tech lib repo    ──▶  higher complexities (staging keys, roll-out)
```

### Step 1 — Passthrough extraction (the existing cluster-box pattern)

Extract gaming-host-1 as a **pure system configuration** child, exactly as
cluster-box is consumed today. No schema export yet.

**Child repo (`gitlab.com/mecha-team-zero/gaming-host-1`, private — created):**
- `flake.nix` — inputs: nixpkgs (pinned to parent's `nixpkgs_stable` rev for
  golden continuity), secrix. Exports `nixosConfigurations.gaming-host-1`.
- Carry `machines/gaming-host-1/default.nix` + `hardware-configuration.nix`.
- Carry its own `topology/gaming-host-1.json`.
- **Vendor (temporarily)** the library surface the child needs to build its own
  config — topology generators, `enable-wg-topology.nix`, `rclone-target.nix`,
  `ssh-multiplex.nix`, `mkKnownHosts.nix`, `configuration.nix`, `services/*`.
  This vendoring is a **temporary bridge**, extracted into the mayo library in Step 3.
- Secrets: **absent `./secrets/...` bindings only** (D-08). No ciphertext, no
  placeholders, no copies, no decryption.

**Parent (this repo):**
- Add `gaming-host-1` (or `gamingHost1`) as a flake input.
- Replace `mkX86_64 "gaming-host-1"` (flake.nix:780) with the generalized
  cluster-box pattern:
  ```nix
  gaming-host-1 = gamingHost1.nixosConfigurations.gaming-host-1.extendModules {
    modules = [ productionOverride ];
  };
  ```
  where `productionOverride` contains **only** D-08 items: `secrix.hostPubKey`,
  `secrix.defaultEncryptKeys.John88`, per-secret `encrypted.file = lib.mkForce
  <parent-ciphertext>`, `_module.args.nixinate = lib.mkForce {...}`.
- `goldens/gaming-host-1.json` stays parent-side; **regeneration forbidden**.

**GATE A (boolean):** `nix run .#validate-goldens -- gaming-host-1` is green with
the golden **byte-identical**, AND the parent's `nix build` of gaming-host-1
succeeds, AND the nixinate deploy path resolves. → "extracted configuration deploys."

### Step 2 — Schema export (deploy via consumed topology)

Evolve gaming-host-1 to **export** the `bargman-tech` schema (§5): its own peer
topology + public keys (identity). The parent stops reading
`topology/gaming-host-1.json` for gaming-host-1 and instead consumes
`inputs.<machine>.bargman-tech.topology.json` + `inputs.<machine>.bargman-tech.identity.*`.

- Child adds the `bargman-tech` output attribute (its own topology + public keys).
- Parent's registry aggregates: other machines still from parent
  `topology/*.json`; gaming-host-1 from the child's schema export.
- Parent generates gaming-host-1's topology config from the aggregated registry
  (nginx, firewall, dns, backup, WG peers).

**GATE B (boolean):** parent deploys gaming-host-1 with topology consumed from
the child's schema export, golden still byte-identical. → "deploys via consumed topology."

### Step 3 — `bargman-tech` schema/lib repo (mayo library's first application)

- The `bargman-tech` schema/lib repo is `github.com/Bargman-Tech/mayo` (private,
  **created**). It will hold (a) the schema definition (§5) and (b) the mayo
  library (the shared config surface).
- Move the Step-1 vendored files out of the child into the mayo library; both
  parent and child consume it via flake input (no cycle).
- This is the first application of the mayo library and the fixed boundary.

**GATE C (boolean):** child no longer vendors library files; both sides consume
the shared lib; gates A and B still hold. → then proceed to higher complexities
(§7).

---

## 5. The `bargman-tech` Schema

The child's contractual export lives under a **`bargman-tech`** flake output
attribute. Naming (provisional, finalized in Step 3):

```
inputs.<machine>.bargman-tech.topology.json       # own peer topology (coordinate, subnet, hub, endpoint)
inputs.<machine>.bargman-tech.identity.wireguard  # WireGuard public key
inputs.<machine>.bargman-tech.identity.ssh-host   # SSH host public key
# ...additional contract fields as the schema grows
```

**Identity rule:** every public key the machine owns is an **identity** field,
grouped under `bargman-tech.identity`. Topology says *where the machine sits on
the network*; identity says *who the machine is, cryptographically*. Any future
key type (WireGuard, SSH host, age recipient, Tailscale, …) is added as a new
`identity.<type>` field — never a top-level ad-hoc `*-public-key` field.

- The schema holds **the machine's own** peer topology and public keys — **not**
  the full fleet. The parent aggregates all children into the fleet registry.
- **The `bargman-tech` schema/lib repo IS the mayo library's first application**
  (`github.com/Bargman-Tech/mayo`). It is where the schema definition and the
  shared config surface first live together.

---

## 6. Demarkation Rule

Decision procedure for classifying any file as Ketchup / Mayo / Secret-Sauce:

1. **Secret-Sauce** — contains machine-specific data, real topology/IP data,
   secrets, or proprietary service/package logic. Stays in the parent (or moves
   to the *owning* machine repo for that machine's own config).
2. **Ketchup** — a pure transformation of schema/topology data with no
   proprietary content (generators, validation, serialization). Open-source-able.
3. **Mayo** — a generic, reusable config module or helper with no
   machine-specific and no proprietary content (shared config surface).

Rule of thumb: *if it names a machine, a real IP, a secret, or a proprietary
service, it is Secret-Sauce. If it is a pure transform, Ketchup. If it is a
reusable generic module, Mayo.*

---

## 7. Higher Complexities (after Gate C)

Post-Step-3 work, entered only once gates A, B, C are all true:

- **Staging keys / native virtualisation** — the child *eventually* carries
  "staging" versions of its required keys (its own staging WG keypair, staging
  host key) so it can be natively virtualised (VM test harness). These are the
  child's **own staging identities**, freshly generated — **not** placeholders of
  production secrets and **not** decryptions of production secrets. **This is a
  separate task, gated after Step 3.**
- Fleet-wide roll-out of the schema pattern to subsequent machines.
- Service port-out (game-server base module, Gitea stack, AI stack) to owning
  machine repos / the lib repo.
- Parent becomes pure orchestrator (LDR-001 §4.4 P5).

---

## 8. Hard Rules

1. **NO** decryption of any existing secret (`age -d`), ever, in this phase.
2. **NO** placeholder ciphertext standing in for production secrets.
3. **NO** copying any file under `secrets/` into a child repo.
4. **NO** golden regeneration for gaming-host-1 during Steps 1–3; a golden diff
   is an extraction bug, never a golden problem.
5. **NO** widening the production-override allowlist (D-08 items only) without a
   new ruling.
6. **NO** child importing the parent (flake-cycle hazard, §2.4).
7. Staging keys (for native virtualisation) are a **separate, later task** — do
   not fold them into Steps 1–3.

---

## 9. Decision Log

| Date | Decision |
|---|---|
| 2026-11-04 | Boundary work of gaming-host-1 is the primary aim; splits proven by extraction (user) |
| 2026-11-04 | Secrets: no decryption, no placeholders, no copies; eval failure from missing secrets accepted (user) |
| 2026-11-04 | Doctrine → LDR-001 D-08 + AGENTS.md pointer (user) |
| 2026-11-04 | Hosting: GitLab `mecha-team-zero/gaming-host-1` only (user) |
| 2026-11-04 | Phase objective = full Ketchup/Mayo/Secret-Sauce boundary; flake inputs are the contract points (user) |
| 2026-11-04 | Two consumption patterns: cluster-box stays pure system config; gaming-host-1 exports schema (user) |
| 2026-11-04 | Iterate with boolean gates: extracted-config-deploys → deploys-via-consumed-topology → higher complexities (user) |
| 2026-11-04 | Child may eventually carry staging keys for native virtualisation — separate later task (user) |
| 2026-11-04 | `bargman-tech` schema/lib repo is the mayo library's first application (user) |
| 2026-11-04 | Schema export attribute = `bargman-tech`; all public keys are **identity** fields (`topology.json`, `identity.wireguard`, `identity.ssh-host`, …) (user) |
