# gaming-host-1 Extraction — Working Plan (Boundary Work)

> **Status:** ACTIVE — primary track (user ruling 2026-11-04)
> **Owner:** John88 / USS-Voyager (Janeway)
> **Companion docs:** `documentation/LDR-001-fleet-spec-and-boundaries.md` (D-08),
> `AGENTS.md` (Architecture Boundary), `documentation/gaming-host-1.md`
> **Hosting:** GitLab `mecha-team-zero/gaming-host-1` **only** (user decision 2026-11-04).
> Local checkout: `/speed-storage/bargman-tech/gaming-host-1`, remote `upstream`.
> No GitHub counterpart.

## Mission (user ruling 2026-11-04)

**Boundary work of gaming-host-1 is the primary aim.** The topology / llm-core
fleet definition / ketchup / mayo demarkation lines are proven **by unlatching
whole systems from the core codebase**, not designed in the abstract first.
Extraction is both the goal and the proof of the split.

---

## §0 Doctrine — Staging / Production actualisation (LDR-001 D-08)

1. **Machine flake = staging source of truth (development).** Secrets and
   settings declared *within* the machine flake are the verbatim staging
   environment for development. Secret declarations are **bindings only**
   (name, service attachment, owner/mode) pointing at repo-local paths whose
   files are **absent**. **No ciphertext. No placeholder encryption. No secret
   file copies. No decryption — anywhere in this work.** Standalone eval
   failure from missing secrets is **accepted and expected**.
2. **Master-control flake (NixOS-Configuration) = single source of truth for
   production.** Secrets and settings **overridden by the parent** via
   `extendModules` (secrix `encrypted.file` → parent ciphertext paths,
   `hostPubKey`, `defaultEncryptKeys`, nixinate deploy metadata) are what a
   real deployment *is*.
3. **Master keyset confinement.** The only location the master keyset (John88
   user key, host pubkeys, all production ciphertext including WG private
   keys, rekey identity) is stored is **this repository**, via secrix.
4. **Virtualised/testing vs real** configurations are separated by *which flake
   actualises them* — not by forked configs.
5. **Structural guarantee (tool-enforced, not discipline).** secrix's
   encryption app builds its `-u`/`-s` keymap by scanning the flake's own
   `nixosConfigurations` (`applicableConfs`, secrix/flake.nix). The machine
   flake declares no `hostPubKey` and holds no ciphertext → **production
   sealing is impossible from the machine repo**.

## §1 Coupling inventory — what extraction cuts

| # | Coupling | Location | Cut |
|---|---|---|---|
| 1 | `self`-resolved secrets | `services/dynamic_domain_porkbun.nix:110-112` (`${self}/secrets/porkbun-api-bargman{,-secret-key}`) | binding → machine-local absent `./secrets/...`; parent `mkForce` to real ciphertext |
| 2 | Repo-relative secret arg | `services/acme_server.nix` `secretFile` ← `../../secrets/porkbun-dns01-envfile` | same pattern |
| 3 | WG private key seam | `modules/enable-wg-topology.nix:171-177` (`../secrets/private_keys/wireguard/wg_${hostname}`) | same pattern |
| 4 | Fleet topology registry | `enable-wg-topology.nix` → `lib/topology/mkRegistry.nix` (repo-relative fleet `topology/`) | transitional: eval flows via parent input; schema ingest later (P1) |
| 5 | `mkKnownHosts` ← `secrets/ssh/public_key/` | `lib/mkKnownHosts.nix` | public keys only; via parent input |
| 6 | `commonModules` bundle | `flake.nix:151-181` (secrix, ratty, rclone-target, configuration.nix, ssh-multiplex, determinate, mkKnownHosts, overlays, defaultEncryptKeys) | extract to importable entry point `lib/fleet_modules.nix` (the mayo split, made load-bearing); machine flake imports one library surface |
| 7 | Registration site | `mkX86_64 "gaming-host-1"` `flake.nix:780-785` | replaced by cluster-box-pattern `extendModules` (prior art: `flake.nix:878-887`) |

## §2 Secret-binding inventory

Each binding becomes (a) a machine-side absent `./secrets/...` path and
(b) a parent-side `lib.mkForce ./secrets/<ciphertext>` override:

| Binding | Unit | Parent ciphertext |
|---|---|---|
| `porkbun_api_key`, `porkbun_secret_api_key` | `dynamic-<domain>` (service) | `secrets/porkbun-api-bargman`, `secrets/porkbun-api-bargman-secret-key` |
| `dns01-porkbun` | system secret (acme) | `secrets/porkbun-dns01-envfile` |
| `wg_gaming-host-1` | `wireguard-wireg0` (service) | `secrets/private_keys/wireguard/wg_gaming-host-1` |
| rclone config (via `topology.backup.configFile`) | backup timer | `secrets/rclone-config-file` |

**Known wrinkle (recorded, LDR F-33):** `topology/gaming-host-1.json` embeds
`backup.configFile = "../secrets/rclone-config-file"` — a secret *path* inside
the schema payload. Transitional resolution: parent's
`topology/gaming-host-1.json` remains the eval feed (`mkRegistry` is
repo-relative); the machine copy is canonical-by-policy until schema ingest.
Flag for P1 schema-contract design (path must become overrideable, not
data-embedded).

## §3 Phases

### Phase 0 — Record the doctrine (this repo)

1. `documentation/LDR-001-fleet-spec-and-boundaries.md` — ruling **D-08**
   (doctrine §0 verbatim), F-33 wrinkle entry, Q-03 answered, track rows
   updated.
2. `AGENTS.md` — Architecture Boundary pointer to D-08.
3. `documentation/gaming-host-1.md` — status banner → this plan.
4. This working document.

**Gate:** cross-references consistent; no content contradicts D-08.

### Phase 1 — Create + initialise repository

1. Create GitLab project `mecha-team-zero/gaming-host-1` (does not exist yet).
2. Local init at `/speed-storage/bargman-tech/gaming-host-1`;
   remote `upstream = git@gitlab.com:mecha-team-zero/gaming-host-1`.
3. Initial commit: README (doctrine summary) + `.gitignore` (`secrets/`,
   `result`). Nothing else.

**Gate:** `git grep -l age-encryption` returns nothing in the new repo.

### Phase 2 — Flake skeleton (staging truth)

1. `flake.nix` inputs: nixpkgs pin matching parent's `nixpkgs_stable` revision
   (golden continuity), `secrix`, `nixos-configuration`
   (`git+ssh://git@gitlab.com/mecha-team-zero/NixOS-Configuration.git`).
   Libraries via ketchup/mayo entry points (`lib/topology_library.nix`,
   shared helpers); shared fleet modules via input path — port-out deferred
   per LDR §4.4 ("service definitions port out slowly").
2. **Demarkation action:** extract `commonModules` (flake.nix:151-181) into
   `lib/fleet_modules.nix` — one importable entry point. This is the mayo
   split made load-bearing (Phase C1 proven by use, not design).
3. Move `machines/gaming-host-1/` + `hardware-configuration.nix`; every secrix
   binding → absent `./secrets/...` path (§2); `acme_server.nix` `secretFile`
   arg likewise.
4. Carry `topology/gaming-host-1.json` as the machine's schema payload
   (R-11). Transitional: registry eval still flows through parent input.

**Gate:** standalone `nix eval` fails **only** with "path does not exist" on
the secret paths — any other failure is a boundary bug. Tree carries zero
secret bytes (`git grep -l age-encryption` empty).

### Phase 3 — Parent registration (production actualisation)

1. Replace `mkX86_64 "gaming-host-1"` (flake.nix:780-785) with the
   cluster-box pattern generalised (prior art flake.nix:878-887):
   `gaminghost1.nixosConfigurations.gaming-host-1.extendModules` with an
   override module containing **exactly four things**:
   - `secrix.hostPubKey` ← parent `secrets/public_keys/host_keys/gaming-host-1.pub`
   - `secrix.defaultEncryptKeys.John88` ← parent key
   - per-secret `encrypted.file = lib.mkForce ./secrets/<ciphertext>` (parent paths)
   - `_module.args.nixinate = lib.mkForce { host, sshUser, port, ... }`

   **Override allowlist stays narrow:** secret material + deploy metadata.
   Service values remain machine-declared (staging truth).
2. `goldens/gaming-host-1.json` stays **parent-side** (answers LDR Q-03:
   continuous coverage during migration). **Regeneration forbidden** — any
   diff is an extraction bug, never a golden problem.

**Gates:**
- `nix run .#validate-goldens -- gaming-host-1` green with the golden **byte-identical**.
- `nix run .#secrix -- -s gaming-host-1` resolves from the parent
  (production sealing path works only here, by construction).
- `nix eval` of the standalone machine repo still fails only on absent secrets.

### Phase 4 — Handover (after production parity proven)

1. Golden + topology schema export move to the machine repo (same schema
  mechanism later carrying llm-fleet JSON — the demarkation line named in the
  2026-11-04 ruling).
2. `machines/gaming-host-1/` retires from parent; parent's
   `topology/gaming-host-1.json` remains as fleet-registry feed until
   schema ingest (P1).
3. Game-server base module (F-32 dedup) and free-agent game-server
   co-development land in the machine repo on clean ground.

## §4 Verification commands

```bash
# Golden parity (parent, Phase 3 gate) — golden must not change
nix run .#validate-goldens -- gaming-host-1

# Secret-material audit (machine repo, any phase)
git grep -l 'age-encryption'            # must be empty
git grep -l 'BEGIN.*PRIVATE KEY'        # must be empty

# Failure-mode audit (machine repo, Phase 2 gate)
nix eval .#nixosConfigurations.gaming-host-1.config.system.build.toplevel
# acceptable failure: "path ... does not exist" on ./secrets/... only

# Production sealing resolution (parent)
nix run .#secrix -- --list-systems      # must list gaming-host-1
```

## §5 Forbidden operations (hard rules)

- **NO** `age -d` (decryption) of any secret, ever, during this work.
- **NO** `secrix create` / `secrix rekey` / `secrix edit` producing placeholder
  or staging ciphertext.
- **NO** copying any file under `secrets/` into the machine repo (or anywhere).
- **NO** golden regeneration for gaming-host-1 during Phases 1–3.
- **NO** widening the Phase 3 override allowlist without a new user ruling.

## §6 Decision log (this plan)

| Date | Decision |
|---|---|
| 2026-11-04 | Boundary work of gaming-host-1 is the primary aim; splits proven by extraction (user) |
| 2026-11-04 | Secrets: no decryption, no placeholders, no copies; eval failure from missing secrets accepted (user) |
| 2026-11-04 | Doctrine note → LDR-001 (D-08) + AGENTS.md pointer (user) |
| 2026-11-04 | Hosting: GitLab `mecha-team-zero/gaming-host-1` only (user) |
