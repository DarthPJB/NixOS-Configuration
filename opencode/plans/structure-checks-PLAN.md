# Structure Checks as Nix Flake Checks — Plan of Record

**Status:** P1 complete (2026-11-11), P2 complete (2026-11-11), P3 deferred.
**Ruling:** D-11 (LDR-001). Implements the structure-assurance methods as
executable `checks."x86_64-linux"` in the consuming repos.

## Design decisions (all user-confirmed 2026-11-11)

1. **Lint scripts live in `mayo:lib/mayo/lints/`** (plain shell, scan root as
   the only argument); **checks are wired in the consumers** (parent +
   gaming-host-1). Mayo stays input-free — its flake has no nixpkgs, so it
   cannot host derivation checks; adding one would transitive-lock into every
   consumer. One script per rule, two enforcement points, unit-testable
   against fixture trees.
2. **Execution pattern: `writeShellApplication` + `runCommand` wrapper
   (`mkLintCheck`).** `nix flake check` only *builds* check derivations — a
   bare `writeShellApplication` check compiles its script and never runs it
   (the `checks.deadnix`/`golden-validation` pattern before this change).
   `runCommand` executes the app at build time (`formatting`-check semantics)
   so violations fail the build.
3. **Eval-time invariants** as `throw` inside the checks attrset — failed at
   evaluation, zero build cost. Used for `split-ready` and
   `known-hosts-identity`.
4. **`checks.deadnix` fixed** (now actually executes); **`golden-validation`
   left as-is** — it invokes `nix run .#dump-config` and cannot run in the
   build sandbox; goldens stay enforced via the `validate-goldens` app + CI.

## Check inventory

### Mayo — `lib/mayo/lints/` (shared scripts)

| Script | Rule | Fails on |
|---|---|---|
| `layer-boundary.sh` | Ketchup <-> Mayo never import each other (split-readiness) | cross-layer path references (comments stripped; `lints/` excluded — tooling names both layers) |
| `api-freeze.sh` | Consumers use only the two layer APIs | raw `mayo.lib}/<file>` outside `topology_library.nix`/`mayo_library.nix` (bare `mayo.lib}` directory refs allowed) |
| `anti-vendor.sh` | D-10, enforceable | mayo-owned basenames (`gen*`, `mk*`, serializers, ...) under `<root>/lib/` |
| `d08-lint.sh` | D-08 staging doctrine | `*.age` files, `age -d`/`age --decrypt`, files under `secrets/`, `../../../` escapes in `*.nix` |

### Parent — `checks."x86_64-linux"` (NixOS-Configuration)

- `structure-layer-boundary` -> `layer-boundary.sh ${mayo.lib}`
- `structure-api-freeze` -> `api-freeze.sh ${self}`
- `structure-anti-vendor` -> `anti-vendor.sh ${self}`
- `split-ready` (eval assert) — the layer APIs resolve from consumer seams
  alone; `ketchup.generators` exposes exactly the nine generators
- `known-hosts-identity` (eval assert) — every wired machine holds the full
  canonical `mkKnownHosts` set (19 entries); extras allowed (LINDA/
  remote-builder = 21, terminal-zero = 20); excluded: `arm-bootstrap`,
  `beta-one`, `bargman-greeter-vm`, `cluster-box`, `x86-bootstrap` (no
  fleet-identity wiring — bootstrap/minimal/test/external profiles)
- `deadnix` — wrapped to actually execute (fixed vacuous check)

### gaming-host-1 — `checks."x86_64-linux"`

- `structure-d08` -> `d08-lint.sh ${self}`
- `structure-api-freeze` -> `api-freeze.sh ${self}`
- `structure-anti-vendor` -> `anti-vendor.sh ${self}`
- `schema-contract` (eval assert) — the `bargman-tech` export keeps exactly
  the `{ topology.json; identity.ssh-host; identity.wireguard }` shape

### Not flake checks (documented, out of scope)

- **Single-input lock lint** — needs git history (diff `flake.lock` vs PR
  base); belongs in CI (`ci.nix`), not a sandboxed check.
- **Golden policy gate** — PRs touching `goldens/` need explicit
  authorisation; CI/actor policy.

## Verification (2026-11-11)

- Positive: all checks build green in the parent worktree + gaming-host-1;
  NOTE: the child's standalone `nix flake check` fails on absent secret files by
  design (D-08) — its checks are verified via `nix build .#checks.x86_64-linux.*`
  `nix flake check --no-build` exit 0 on the parent (which actualises the child via
  extendModules).
- Negative: each lint fails on injected-violation fixtures (cross-layer
  import, raw-API reference, vendored file, ciphertext/decrypt/escape); the
  eval asserts threw during development exactly as designed
  (`known-hosts-identity` caught unwired machines before the exclusion set was
  evidence-based; `api-freeze` caught a non-API reference).
- fmt + deadnix clean on all changed files.

## Phasing

| Phase | Work | Gate | Status |
|---|---|---|---|
| P1 | mayo lints + parent checks + deadnix fix + tests | all checks green, negatives fail as expected | **DONE 2026-11-11** |
| P2 | gaming-host-1 checks + schema assert + tests | same | **DONE 2026-11-11** |
| P3 | CI single-input lock lint; generator unit-test fixtures as checks | — | deferred |

## Repos / revisions

- mayo: `lib/mayo/lints/` + `lints` catalogue attr in `mayo_library.nix`
- NixOS-Configuration: `flake.nix` checks block (`mkLintCheck`, six checks)
- gaming-host-1: `flake.nix` `checks."x86_64-linux"` block (four checks)
