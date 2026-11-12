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
| **mayo** (schema + shared config surface) | `github.com/Bargman-Tech/mayo` | `/speed-storage/bargman-tech/mayo` | **public** · AGPL-3.0-or-later (2026-11-11) |

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
| **Ketchup** | **Topology + host management** (ruling 2026-11-11): pure JSON→attrset generators, validation, serialization, generic NixOS modules, and registry/hosts/known-hosts construction (`mkRegistry`, `mkHostsEntries`, `mkKnownHosts`). No machine data, no secrets. | shared lib (portable) |
| **Mayo** | **System configuration helpers + other library assets** (ruling 2026-11-11): reusable NixOS modules + helpers shared across machines (`rclone-target`; `ssh-multiplex` only after its embedded fleet IP patterns are parameterised — as it stands it names real IPs and is Secret-Sauce by the demarkation rule; `network-interfaces`/`config-baseline` names retired — never materialised). Generic, non-proprietary. | shared lib (the "mayo library") |
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

**Step 1 status — GATE A ✅ PASS (2026-11-09).**
- Child repo `gitlab.com/mecha-team-zero/gaming-host-1` @ `61a535b` (HEAD
  includes the `nixpkgs-fmt` pass); parent `gamingHost1` input locked to
  `61a535b` (per-input lock only — no other input drift).
- Gate A evidence (re-confirmed at `61a535b`):
  - `nix run .#validate-goldens -- gaming-host-1` → **matches golden**
    (byte-identical; `goldens/gaming-host-1.json` unchanged).
  - `nix build .#nixosConfigurations.gaming-host-1.config.system.build.toplevel`
    → BUILD_EXIT=0
    (`/nix/store/i0979lmnmii2cpqzhs73k99cxf50kzqy-nixos-system-gaming-host-1-26.05.20261006.b253099`).
  - Deploy app resolves → `apps.x86_64-linux.gaming-host-1` →
    `/nix/store/ivzqblmi8vaa3yaw1spvl4wd72cvhpfp-deploy-gaming-host-1.sh/bin/deploy-gaming-host-1.sh`.
  - Note: toplevel/deploy store paths shift with the parent's dirty tree
    (`nixos-deployment-exporter` + nixinate embed `self.rev`/`self.outPath`).
    The Gate-A invariant is golden parity + build exit 0, not a fixed store hash.
- As-built deviations (recorded, not silent):
  1. **Public identity keys** live in the child under `identity/` (not
     `secrets/public_keys/`): `JOHN_BARGMAN_ED_25519.pub`,
     `INSPECT_ED_25519.pub`, `host_keys/gaming-host-1.pub`,
     `wireguard/wg_cortex-alpha_pub`. No file under `secrets/` was copied (Hard
     Rule #3); these are public identity data carried as Step-1 transitional
     material pending the Step-2 schema export.
  2. **F-33 tolerant backup paths**: the child's vendored
     `lib/topology/mktopology.nix` `resolveBackupPaths` returns a string when the
     path is absent (`if builtins.pathExists p then builtins.path { path = p; } else toString p`).
     Reconciliation candidate for the parent (F-33).
  3. **Fleet identity aggregation override** (new ruling, 2026-11-09): the
     Step-1 `productionOverride` also sets
     `programs.ssh.knownHosts = lib.mkForce (mkKnownHosts self.nixosConfigurations)`.
     This is **public identity aggregation, not D-08 secret actualisation**: the
     child owns only its own identity; the parent is the fleet registry
     aggregator. Approved under Hard Rule #5.
  4. **Input-pinning gotcha**: pin child inputs from the parent's
     `nodes.root.inputs.<name>` → node (`nixpkgs_stable` = `b253099`, secrix =
     `4d0e6a9`, determinate = 3.22.4), **not** the top-level
     `nodes.nixpkgs_stable` orphan node (`4382ed2`), which is stale and unused.
     The golden captures derivation versions (openssh-10.5p1, tailscale-1.98.10),
     so the package tree must match exactly.

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

**Step 2 status — GATE B ✅ PASS (2026-11-09).**
- Child repo @ `5efb9a0`: adds the `bargman-tech` output —
  `topology.json` (own peer topology), `identity.ssh-host`, `identity.wireguard` —
  and seeds `identity/wireguard/wg_gaming-host-1_pub`
  (`LnVeRKKXrTduFZj3ttg/qxaPPjAJimotyMsj56e1x0I=`). Public key only; no secrets,
  no ciphertext.
- Parent `gamingHost1` re-locked **per input only** to `5efb9a0`; drift check
  shows every other root input unchanged.
- Parent wiring (`flake.nix`):
  - `gamingSchema = gamingHost1.bargman-tech`
  - `gamingTopology = gamingSchema.topology.json`
  - `aggregatedHosts = topoRegistry.hosts // { <gamingTopology.hostname> = gamingTopology; }`
  - `aggregatedRegistry = topoRegistry // { hosts = aggregatedHosts; }`
  - `topologyConfigs = mktopology { topologyDir = ./topology; registry = aggregatedRegistry;
    wireguardPubKeys = { <gamingTopology.hostname> = gamingSchema.identity.wireguard; }; }`
  - `topo` / `topoIp` now read `aggregatedHosts`.
- `lib/topology/mktopology.nix` accepts either a **path** (legacy file
  discovery) or **`{ topologyDir, registry, wireguardPubKeys }`** (injected
  registry + public-key overrides). All existing callers keep the path form.
- Gate B evidence:
  - `nix run .#validate-goldens -- gaming-host-1` → **matches golden**.
  - `nix run .#validate-goldens -- cortex-alpha` → **matches golden**. Its
    WireGuard peer list is generated by `genWireguard` from the registry, so this
    proves the **child-supplied** public key flows through into fleet config.
  - `nix build .#nixosConfigurations.gaming-host-1.config.system.build.toplevel`
    → BUILD_EXIT=0.
  - Deploy script builds (`…-deploy-gaming-host-1.sh`) and embeds
    `deploy@10.88.127.52`, port 1108 — the target is derived from the
    child-supplied topology via `topoIp`.
  - **Consumption proof (non-destructive):** `--override-input gamingHost1
    path:<mutated child>` with the child's WG `peer_id` changed 52→53 (parent's
    own `topology/gaming-host-1.json` untouched) moved cortex-alpha's peer
    `allowedIPs` from `10.88.127.52/32` to `10.88.127.53/32`. The parent
    genuinely consumes the child export rather than its own file.
- As-built deviations / decisions:
  1. **Parent keeps `topology/gaming-host-1.json`** (not deleted). `mkRegistry` is
     imported directly by `services/prometheus.nix`, `modifier_imports/hosts.nix`,
     `modules/enable-wg-topology.nix`, `lib/golden_coverage.nix`,
     `lib/topology_library.nix`, and `tests/topology/*`; deleting the file would
     silently drop gaming-host-1 from the scrape / known-hosts / WG sets.
     Aggregation is by **precedence** (`//`): the child export wins for
     gaming-host-1, everything else is unchanged. Single-source deletion is
     deferred to Step 3.
  2. **No duplicate list merging:** the parent does not re-apply its own
     `topologyConfigs` entry on top of the child's `topologyConfig` module (that
     would concatenate `types.listOf` values and duplicate firewall ports).
     Gaming-host-1's topology config is still produced **inside the child**; the
     parent aggregation exists for the rest of the fleet (peer lists, scrape
     targets, known hosts) and for `topoIp`.
  3. `programs.ssh.knownHosts = lib.mkForce (mkKnownHosts …)` unchanged from Step 1.
- **Pre-existing golden drift found (not caused here, not fixed):** `alpha-one`,
  `alpha-two`, `alpha-three`, `LINDA`, `storage-array`, `terminal-nx-01`,
  `terminal-zero` fail `validate-goldens` because commit `213e030` added
  `glab`/`gh` to `environments/code.nix` (all seven import it) without
  regenerating their goldens. Reproduced identically on a pristine worktree at
  `ce41010`, so it predates Steps 1–2. Golden regeneration requires explicit user
  authorization and must not be bundled into a refactor.

### Step 3 — `bargman-tech` schema/lib repo (mayo library's first application)

- The `bargman-tech` schema/lib repo is `github.com/Bargman-Tech/mayo`
  (**public**, licensed **AGPL-3.0-or-later** as of 2026-11-11; created 2026-11-07).
  It holds (a) the schema definition (§5) and (b) the mayo
  library (the shared config surface).
- Move the Step-1 vendored files out of the child into the mayo library; both
  parent and child consume it via flake input (no cycle).
- This is the first application of the mayo library and the fixed boundary.

**GATE C (boolean):** child no longer vendors library files; both sides consume
the shared lib; gates A and B still hold. → then proceed to higher complexities
(§7).

**Step 3 status — GATE C ✅ PASS (2026-11-10).**

*What moved / what was pruned:*
- **Into mayo (15 moved + 1 new, published `1129b92`):** the 9 generators,
  `mktopology.nix`, `mkRegistry.nix`, `mkHostsEntries.nix`, `validate.nix`,
  `utils.nix`, `rclone-target.nix`, plus the **new** unified `lib/mkKnownHosts.nix`
  (ruling c) — 12 of the 13 moved files are byte-identical to their pre-move
  sources; only `mkRegistry` and `mktopology` carry the three seams.
- **Child prune (ruling B):** all 16 vendored files left `gaming-host-1` — 13
  relocated, 3 dropped as dead (`lib/mkKnownHosts.nix` superseded,
  `lib/topology/{validate,utils}.nix` unreferenced there).
- **Parent prune (ruling d, all proven dead by repo-wide grep, code AND docs):**
  `lib/mkKnownHosts.nix`, `lib/network-interfaces.nix`,
  `lib/make-storeless-image.nix`. `lib/topology_library.nix` **retained** and
  rewired (`{ lib, mayo, topologyDir }`) as the Step-3b wrapper seed.

*Consumption wiring (no consumer still imports a moved parent path):*
- Parent: `flake.nix` (topoRegistry, mktopology+`pubKeyDir`, rclone module,
  `knownHostsLib` for coordToIp/deriveTopo/mkKnownHosts),
  `modifier_imports/hosts.nix` (+`self`), `modules/enable-wg-topology.nix`
  (registry + genWireguard), `services/prometheus.nix` (registry),
  `lib/golden_coverage.nix`, `lib/topology_library.nix`, and the three orphaned
  but intact tests (`tests/topology/{mkRegistry,genNginx}.nix`,
  `tests/topology-validation.nix`).
- Child: `flake.nix` (mktopology with `topologyDir` + `pubKeyDir`,
  mkRegistry, mkKnownHosts, rclone module), `modifier_imports/hosts.nix`,
  `modules/enable-wg-topology.nix`.
- Access pattern: outputs are attrsets, so paths are `"${mayo.lib}/…"`;
  module-list entries need a path (`(mayo.lib + "/rclone-target.nix")` — bare
  `+` in a list element is a parse error).

*Equivalence proofs (run BEFORE consumers were touched):*
- mayo `mktopology` output `==` parent's live `topologyConfigs` —
  `identicalToParent = true`, 32 hosts, registry errors `[]`.
- mayo `mkKnownHosts` over the parent's inputs → 19 entries, matching the golden.

*Gate C evidence:*
- Child vendors no library files: `lib/` deleted; `nix flake lock` shows
  `mayo` → `1129b92` and `gamingHost1` → `339c593`, **zero drift** on every
  other root input (diff against the Step-2 baseline).
- Gates A+B still hold: `validate-goldens gaming-host-1` ✓ and `cortex-alpha` ✓.
- Fleet sweep (serial, all 20 goldens): **13 pass / 7 fail — the 7 are exactly
  the pre-existing `glab`/`gh` drift set** (`alpha-one`, `alpha-two`,
  `alpha-three`, `LINDA`, `storage-array`, `terminal-nx-01`, `terminal-zero`),
  and their diffs contain **only** the two lines
  `<derivation:gh-2.102.0>` / `<derivation:glab-1.99.0>` — zero mayo delta.
- `nix build .#nixosConfigurations.gaming-host-1.config.system.build.toplevel`
  → BUILD_EXIT=0; deploy app resolves
  (`…-deploy-gaming-host-1.sh/bin/deploy-gaming-host-1.sh`).
- `nixpkgs-fmt --check` and `deadnix` clean on all touched files.
- Child standalone (no secrets): hostName, extraHosts
  (`10.88.127.1 cortex-alpha` / `10.88.127.52 gaming-host-1`), knownHosts
  (`["gaming-host-1"]`), rclone-target F-33 (configFile is a **string** — file
  absent, deferred to the parent override), wg peers
  (`lMo4Rf3nlXqd8rIX7rNMedygdsHTZqh+NLxre+vwYH8=`), `bargman-tech` export.
  Still no `secrets/` content in the child (absent from tree, index, history).

*As-built notes / findings:*
- **Dead code PRUNED 2026-11-11 (user authorisation; was left untouched at
  Step 3 because ruling (d) covered lib/ only):**
  `modules/core-router{,-topology}.nix` (never imported; referenced six
  nonexistent `mk*Settings`/`mkWireguardPeers` files),
  `lib/topology/archive/topology-derive.nix` (its `../lib/topology/…` paths
  resolved to a directory that never existed), and
  `tests/topology/{mkHorizons,genNftablesMatrix,genDnsmasqHorizons,
  topology-derive,ponr-subset-equality}.nix` (referenced files that do not
  exist). Proven dead by repo-wide audit across all file types: only doc lines
  and stale comments referenced them (both updated). **Kept** (orphaned but
  intact and now mayo-wired): `tests/topology/{mkRegistry,genNginx}.nix` and
  `tests/topology-validation.nix` — **pruned 2026-11-12** (secret-sauce plan R3, with `tests/test-hub-of-hubs.nix` and the broken `scripts/validate-topology.sh`).
- **F-33 reconciliation landed:** mayo carries the tolerant `resolveBackupPaths`;
  deep-equality proved it is inert for the parent (all secret files exist there).
- **Open flags:** (1) ~~fetching the private mayo input needs local git
  credentials or an nix `access-tokens` entry — CI runners must be provisioned
  before the first CI run after this commit~~ **RESOLVED 2026-11-11: mayo made
  public (F-35 closed) — it fetches anonymously like any other github input,
  no CI provisioning needed**; (2) ~~the 7-machine `gh`/`glab` golden
  drift still awaits your authorisation to regenerate (Golden Rule)~~
  **RESOLVED 2026-11-11: goldens regenerated under authorisation, deltas
  verified as gh/glab-only, sweep 20/20 (F-34 closed)**.
- Step 3b (wrapped API over the moved engine) is sequenced after this extraction.

**Step 3 scope rulings (user, 2026-11-09):**

| # | Ruling |
|---|---|
| (a) | **Content = engine as-is.** Files move in place — no restructuring, no wrapper at extraction time. The wrapped API (option C) is **sequenced after extraction** as Step 3b. The child's dead vendored files are pruned as part of the move (option B). |
| (b) | **`validate.nix` + `utils.nix` go into mayo.** The parent's tests and `core-router*` modules import them from the mayo input. |
| (c) | **`mkKnownHosts` unified now** — one implementation in mayo; each side supplies its machine set, key source, and topology view. Output must stay byte-identical (parent golden carries 19 `services.openssh.knownHosts` entries). |
| (d) | **Parent dead files pruned only where provably dead.** `lib/topology_library.nix` is import-dead but plan-live (C1 API + the Step-3b wrapper seed) → retained unless ruled otherwise. |

**Step 3b (after extraction lands):** add the wrapped API on top of the moved
engine (former option C — the C1 `topology_library.nix` façade), sequenced as
its own change with its own golden gate.

**Step 3b status — ✅ COMPLETE (2026-11-11).** The wrapped API landed as the
**layer split + layer APIs** per the demarkation ruling (not a flat wrapper):

- **mayo `bbd8192`:** `lib/ketchup/` (engine + host management +
  `topology_library.nix` Ketchup API — seams pre-bound, `mktopology` accepts
  overrides) and `lib/mayo/` (`rclone-target` + `mayo_library.nix` Mayo API +
  `golden/` tooling: `serialize-config.nix`, data-injected `coverage.nix`,
  `apps.nix` dump-config/validate-goldens builders, `compare-configs.sh`).
- **Golden tooling extracted (ruling):** the parent now builds its golden apps
  from the Mayo layer, runs coverage via `mayoLib.golden.coverage`, and
  `scripts/compare-configs.sh` is a thin wrapper (the tool lives in the lib;
  a `compare-configs` app execs it). Deleted from the parent:
  `lib/serialize-config.nix`, `lib/golden_coverage.nix`, `lib/topology_library.nix`
  (C1 resolved inside the mayo library).
- **Consumers call layer APIs only** — grep-proven: zero raw
  `mayo.lib}/topology/…` references remain in either flake. Child `66df4b4`
  rewired identically (ketchup/mayoLib instances).
- **Split-readiness:** `lib/ketchup/` and `lib/mayo/` never import each other;
  golden coverage takes topology data injected. The deferred Ketchup/Mayo repo
  separation is a directory move.
- **Gate:** fleet sweep **20/20** byte-identical (gaming-host-1 + cortex-alpha
  validated first), fmt + deadnix clean, locks `gamingHost1=66df4b4`
  `mayo=bbd8192` (only those two inputs moved).
- **As-built notes:** the golden-coverage machine-exclusion list stays
  parent-side (fleet data — now injected, Secret-Sauce by the demarkation
  rule); `ssh-multiplex` NOT moved (contains real fleet IPs → Secret-Sauce as
  it stands; Mayo candidate after parameterisation); `network-interfaces` /
  `config-baseline` names retired; `ci_library` + the `check-ci` app stay
  parent-side (CI domain → P3 github-ci toolkit).

**Unavoidable seams — the only edits allowed inside otherwise-verbatim moves
(verified by inspection, 2026-11-09):**

1. `mkRegistry.nix:64` `topologyDir = ../../topology` → injected argument
   (mayo has no `topology/`).
2. `mkRegistry.nix:363` backup `configFile` resolution `../../${pkf}` →
   injected repo-root argument.
3. `mktopology.nix` `readPubKey` (`../../secrets/public_keys/wireguard/…` in the
   parent, `../../identity/wireguard/…` in the child) → injected `pubKeyDir`
   argument, alongside the existing `wireguardPubKeys` override — this is the
   seam the Step-1 child patch was already working around.

All other files move byte-for-byte: `mktopology` imports its generators
relatively (`import ./genFirewall.nix`), so the generator directory travels as
a unit. Consumers import as
`import "${mayo}/lib/topology/<f>.nix" { inherit lib; … }`.

**F-33 reconciliation (rides along):** the child's tolerant `resolveBackupPaths`
(`if builtins.pathExists p then builtins.path … else toString p`) becomes the
single mayo version, replacing the parent's strict form. Behaviour-neutral where
the secret file exists (the parent's case); both sides re-validate goldens.

**Child prune (option B):** `lib/mkKnownHosts.nix` (superseded by the inline
implementation), `lib/topology/validate.nix`, `lib/topology/utils.nix` (both
unreferenced) leave the child — config-neutral, proven by re-running goldens.

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
| 2026-11-09 | Step 1 complete — GATE A PASS: golden byte-identical, toplevel builds, deploy app resolves |
| 2026-11-09 | Step-1 override may include `programs.ssh.knownHosts = lib.mkForce (mkKnownHosts self.nixosConfigurations)` — fleet identity aggregation, not D-08 secret actualisation (user) |
| 2026-11-09 | Child public identity keys carried under `identity/` (no `secrets/` copy) as transitional Step-1 material |
| 2026-11-09 | Step 2 complete — GATE B PASS: gaming-host-1 + cortex-alpha goldens byte-identical, toplevel builds, deploy target derived from child topology; `--override-input` mutation proof |
| 2026-11-09 | Parent keeps `topology/gaming-host-1.json`; registry aggregation is precedence-based (`//`) because `mkRegistry` has direct consumers — single-source deletion deferred to Step 3 |
| 2026-11-09 | `mktopology` gained an optional injected-registry arg; path form remains the default signature (no caller churn) |
| 2026-11-09 | Found pre-existing golden drift (`glab`/`gh` from `213e030` × 7 machines) reproduced at `ce41010`; NOT fixed here (golden regeneration needs user authorisation) |
| 2026-11-09 | Step-3 scope rulings: content = engine as-is; `validate`+`utils` into mayo; `mkKnownHosts` unified now; parent dead files pruned only when provably dead (user) |
| 2026-11-09 | Wrapped API (former option C) sequenced AFTER extraction as Step 3b (user) |
| 2026-11-10 | Step 3 complete — GATE C PASS: child vendors no library files, both sides consume mayo, 13/7 sweep (7 = pre-existing gh/glab, 2-line delta), build exit 0 |
| 2026-11-10 | mayo consumed via `git+https` (private repo — local git credentials; CI needs `access-tokens`/netrc before its first run) |
| 2026-11-10 | Dead modules/tests (core-router*, archive/topology-derive, 5 broken tests) left in place — already non-functional pre-move; ruling (d) covers lib/ only |
| 2026-11-11 | Mayo repository made **public** (the original intention) — F-35 closed; the `mayo` input fetches anonymously, no CI credential provisioning needed (user) |
| 2026-11-11 | Mayo licensed **AGPL-3.0-or-later** (user choice) — `LICENSE` (full AGPL v3 text), README grant covering all files with SPDX identifier, SPDX header in `flake.nix`; unmodified consumers (parent, child) keep their own licensing, modified versions must ship AGPL-3.0-or-later (user) |
| 2026-11-11 | Locks re-locked to `gamingHost1` bf596c3 + `mayo` c6e3c0f (licence commit); only those two inputs moved in this session — `carmelsite` 6942741f is from your own commit `a5ad92e` "tight coupling in practice" |
| 2026-11-11 | F-34 resolved — golden regeneration authorised: 7 machines' goldens updated only after verifying each delta was exactly the two gh/glab addition lines (LINDA carries gh-2.97.0/glab-1.111.0 from its own nixpkgs); sweep 20/20 |
| 2026-11-11 | Dead code pruned (user authorisation): core-router×2 modules, lib/topology/archive/topology-derive.nix, and 5 broken orphan tests — all proven unreferenced repo-wide except docs/comments, which were updated; the 3 intact orphan tests kept (offer to prune) |
| 2026-11-11 | **Delineation ruling (user):** Ketchup = topology + host management; Mayo = system configuration helpers + other library assets. `mkKnownHosts`/`mkHostsEntries` → **Ketchup** (host management), superseding the old Mayo exemplar row. Single shared lib for now; eventual Ketchup/Mayo repo separation deferred ("it can wait") but the layout must keep it a directory move: **no cross-layer imports** (Ketchup ↮ Mayo) |
| 2026-11-11 | **Ruling (user): golden tooling is library surface** — `serialize-config`, golden coverage, and the golden app tooling extract into the Mayo layer (`lib/mayo/golden/`). Golden coverage takes its topology/registry data **injected** (never imports Ketchup). `check-ci` stays parent-side (CI domain → P3 github-ci toolkit). `check-ci`'s own golden stays fleet tooling |
| 2026-11-11 | **Step 3b complete** — layer split + layer APIs landed in mayo (bbd8192): Ketchup API (topology + host management) + Mayo API (helpers + golden tooling extracted per ruling); consumers call layer APIs only; C1 resolved; fleet sweep 20/20 |
