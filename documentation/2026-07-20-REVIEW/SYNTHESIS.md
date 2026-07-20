# SYNTHESIS — Overlord-II Cleaning Review

**Date:** 2026-07-20
**Commander:** hy3-free
**Reviewers:** tpol-minimax, tuvok-deepseek, hoshi-xai, bellana-grok-code, bellana-codex
**Inputs:** 5 independent verbose reports in this folder.
**Method:** 5 agents, identical prompt, parallel passive review (no changes, no live access).

This document reconciles the five reports into a single, prioritized synthesis.
Where reviewers disagreed, the majority/corroborated position is taken and the
conflict is noted inline.

---

## 0. Headline

The fleet's nginx surface is **larger and more fragmented than the documented
"topology is the single source of truth" implies**, the **WIP two-layer
architecture is partially live on the production hub (cortex-alpha) despite the
stated "WIP is dead code until wired" rule**, and there is a **substantial body
of dead documentation, dead snippets, and orphaned secrets** that should be
removed or archived. The single highest-value cleanup is reconciling the
production vs WIP nginx paths and deleting the orphaned `hedgedoc.nix`.

---

## GROUND 1 — Complete Fleetwide Nginx Vhost Inventory

Consolidated from all five reports. Status reflects the `overlord-II` branch
as evaluated in the worktree. "WIP path" = `core-router-topology.nix` +
`genNginx.nix`; "production path" = `core-router.nix` + `mkNginxProxies.nix`.

> **Important correction across reviewers:** tuvok-deepseek marked the gitolite
> `raw` vhost as "Dead" and attributed the carmel sites to `remote-builder`.
> Corroborated evidence (hoshi-xai, bellana-codex, bellana-grok-code) shows
> `server_services/gitolite.nix` IS imported by `machines/local-nas` (active,
> WG-only) and the carmel sites live in `flake.nix:622-652` as an extraModule
> **for `remote-worker`**, not remote-builder. This synthesis uses the
> corroborated position.

### Active vhosts (~21)

| Domain / server_name | TLS | Upstream / action | Defined in | Machine | Notes |
|---|---|---|---|---|---|
| `_` (catch-all) | none (444) | return 444 | topology/cortex-alpha.nix:509-519 | cortex-alpha | Also mirrored as `default` on remote-worker |
| `johnbargman.net` | ACME+forceSSL | static `../webroot` | topology/cortex-alpha.nix:513-515; machines/remote-worker/default.nix:54-62; flake.nix:622 | cortex-alpha + remote-worker | **Defined 3× (split-horizon)** |
| `cortex-alpha.johnbargman.net` | forceSSL | static `../webroot` | topology/cortex-alpha.nix:517-519 | cortex-alpha | |
| `print-controller.johnbargman.net` | addSSL | `http://10.88.127.30:80` | topology/cortex-alpha.nix:535-540 (+ print-controller fluidd) | cortex-alpha (+ print-controller) | **Duplicated** (topology proxy + fluidd side) |
| `code.johnbargman.net` | addSSL | `http://10.88.127.3:80` | topology/cortex-alpha.nix:540-544 | cortex-alpha | Gitea |
| `git.johnbargman.net` | addSSL | `http://10.88.127.3:80` | topology/cortex-alpha.nix:545-549 | cortex-alpha | Gitea alias |
| `prometheus.johnbargman.net` | addSSL | `http://10.88.127.3:8080` | topology/cortex-alpha.nix:550-554 | cortex-alpha | |
| `grafana.johnbargman.net` | addSSL | `http://10.88.127.3:3101` | topology/cortex-alpha.nix:555-559 | cortex-alpha | |
| `ap.johnbargman.net` | addSSL | `http://10.88.128.2:80` | topology/cortex-alpha.nix:560-564 | cortex-alpha | |
| `johnbargman.com` | ACME+forceSSL | static `../../webroot` | machines/remote-worker/default.nix:66-74 | remote-worker | |
| `johnbargman.com-wg` | ACME+forceSSL (WG IP 10.88.127.50) | personal-site webroot | machines/remote-worker/default.nix:76-84 | remote-worker | split-horizon WG-only |
| `nextcloud.johnbargman.com` | forceSSL+redirect | → .net | server_services/nextcloud.nix:67-76 | remote-worker | |
| `nextcloud.johnbargman.net` | forceSSL | nextcloud/php | server_services/nextcloud.nix:78-87 | remote-worker | |
| `csfinancialconsulting.com` | forceSSL | carmelsite webroot | flake.nix:625-634 | remote-worker | extraModule |
| `csfincon.us` | forceSSL | carmelsite webroot | flake.nix:635-644 | remote-worker | extraModule |
| `carmel-staging.johnbargman.net` | forceSSL | carmelsite webroot | flake.nix:645-652 | remote-worker | extraModule |
| `gaming-host-1.johnbargman.net` | forceSSL | `http://127.0.0.1:8080` | machines/gaming-host-1/default.nix:70-77 | gaming-host-1 | squaremap |
| `raw` (gitolite) | none (WG-only :80) | uwsgi cgit | server_services/gitolite.nix:87-140 | local-nas | internal cgit |
| `print-controller.johnbargman.net` (fluidd) | from fluidd | fluidd/moonraker | server_services/klipper.nix:232-269 | print-controller | see duplication above |

### Dead / orphaned vhosts (1 confirmed)

| Domain | Defined in | Why dead |
|---|---|---|
| `hedgedoc.johnbargman.com` | server_services/hedgedoc.nix:12-21 | Complete module + vhost, **zero imports** anywhere (not flake, not machines/*, not commonModules). Confirmed by all grep-based reviewers. |

### Structural findings (Ground 1)
- **Authority is scattered.** The topology "single source of truth" only
  governs cortex-alpha's 9 vhosts. Everything else (remote-worker,
  gaming-host-1, nextcloud, gitolite, klipper, carmel sites) is defined via
  ad-hoc `services.nginx.virtualHosts = { ... }` blocks in machine configs,
  `server_services/`, and even `flake.nix` extraModules.
- **Duplication is real:** `johnbargman.net` defined 3×; `print-controller`
  proxy + fluidd; catch-all `_`/`default` in two machines.
- **cortex-alpha (the public hub) is currently served by the WIP path**
  (`core-router-topology.nix` imported at machines/cortex-alpha/default.nix:23),
  not the documented production `core-router.nix`. This is the single most
  important architectural fact of this review.

---

## GROUND 2 — Suggested Paths to Clean Up or Remove

Prioritized. Each item is corroborated by ≥2 reviewers unless noted.

### HIGH — delete / archive now (actively misleading or dead)

1. **`server_services/hedgedoc.nix`** — complete orphaned service+vhost, never
   imported. (tpol, tuvok, hoshi, grok, codex — unanimous)
2. **`documentation/topology-migration-guide.md`** — documents a
   `real-topology/`, `systems/`, `_template.nix`, and `nix run .#generate-golden`
   layout that **never existed** in this tree. Actively harmful to follow.
   (tpol, hoshi, codex)
3. **`documentation/2026-07-18-MULTI-HORIZON-GATEWAY-PLAN.md`** — instructs
   editing `topology/<machine>.json` / `real-topology/golden/*.json`; tree is
   `.nix`. Misleading. (codex, hoshi)
4. **`snippets/core-router.nix`** — byte-identical to `modules/core-router.nix`.
   (tpol, tuvok, hoshi, grok)
5. **`snippets/test-new-architecture.nix`** — identical to
   `tests/test-new-architecture.nix`; also hardcodes
   `/speed-storage/repo/DarthPJB/NixOS-Configuration`. (tpol, tuvok, hoshi, grok, codex)
6. **`snippets/enable-wg.nix`** — legacy module superseded by
   `modules/enable-wg-topology.nix` (13 machines). (tpol, tuvok, hoshi, codex)
7. **`snippets/grafana-deprecated/`** — two JSON dashboard dumps, never loaded.
   (tpol, hoshi, codex)
8. **`lib/topology/default.nix`** — dead per TG-013, still present, creates a
   second (undocumented) library entry point. (tpol, tuvok, grok)
9. **`lib/mayo_library.nix`** — never imported (Phase C artifact). (tpol, grok)
10. **`lib/topology/mkBackupSettings.nix` + `genBackup.nix`** — exported to
    library but no consumer module exists. (tpol, grok, codex)

### MEDIUM — consolidate / mark dead

11. **`snippets/syncthing_server.nix`** — entirely commented out; not imported;
    contains plaintext placeholders + hardcoded `/futureNAS`. (tpol, tuvok, hoshi, codex)
12. **`snippets/obs-box.nix`, `snippets/local-worker.nix`** — retired machine
    configs importing non-existent `hardware-configuration.nix`. (tpol, codex)
13. **`snippets/systems-cortex-alpha.nix`** — example that doesn't match real
    import structure. (tpol, grok)
14. **`documentation/plans/` (12 files)** — mostly superseded/abandoned June–July
    plans mixed with live reference docs. (tuvok, hoshi, grok, codex)
15. **`lib/topology_library.nix`** — flagged by tuvok as dead; other reviewers
    believe it is the *intended* Ketchup boundary. **Needs human adjudication**
    before deletion (see Open Questions).
16. **Orphaned secrets:**
    - `secrets/public_keys/wireguard/wg_acropolis_pub` — no topology peer
      `acropolis`. (tuvok, grok)
    - `secrets/private_keys/wireguard/wg_display-module` — no matching public
      key, no topology entry. (tpol)
    - Host keys for machines absent from `flake.nix`
      (`alpha-two`, `local-worker`, `display-0`, `hyper_build`, …). (tuvok, grok)

### LOW — hygiene / nits

17. **`documentation/README.md`** and **`code_structure.md`** — drift from actual
    tree layout. (tpol, hoshi)
18. **`documentation/roadmap-snapshot.md`** — explicitly historical; move to
    `archive/`. (tpol, grok)
19. **`snippets/how-to-make-ollama-opencode-work.md`** — operational note, not
    config; relocate. (tpol)
20. **`dotfiles/.config/nvim/lazy-lock.json`** — user state, consider gitignore.
    (hoshi)
21. **`documentation/2026-*-REVIEW/` (6 prior reviews)** — valuable but noisy;
    move to `archive/previous-reviews/`. (hoshi)

---

## GROUND 3 — Obvious Practical Issues (Bugs / Risks / Nits)

### DEFINITE BUGS (fix before any WIP wiring)

- **B1 — `genNginx.nix` ACME host propagation** (`lib/topology/genNginx.nix:41`):
  `useACMEHost = s.acmeHost` is applied uniformly, overriding per-vhost
  `useACMEHost = null` (the catch-all's correct "disable ACME" behavior).
  Production `mkNginxProxies.nix:95` correctly does
  `useACMEHost' = baseConfig.useACMEHost or (if enableACME' then null else s.acmeHost)`.
  If the WIP module is wired to the hub, the `_` catch-all would request the
  `johnbargman.net` cert and TLS-break unknown hosts. (tpol — high confidence)
- **B2 — cortex-alpha runs WIP path, contradicting documented architecture.**
  `machines/cortex-alpha/default.nix:23` imports `core-router-topology.nix`;
  AGENTS.md "Active Architecture" and the master review doc both state
  production uses `core-router.nix` and that the WIP module "is not yet wired
  into cortex-alpha." This is a live phase-discipline violation. (hoshi, grok, codex)
- **B3 — `topology-migration-guide.md` documents a phantom layout** (see G2#2).
  Anyone following it will operate on nonexistent paths. (hoshi, codex)
- **B4 — `hedgedoc.nix` dead code that looks live** (see G2#1). (all)

### DESIGN RISKS (silent divergence / future breakage)

- **R1 — Dual nginx transformers with no cross-validation.** Production
  `mkNginxProxies.nix` vs WIP `mkNginxSettings.nix`+`genNginx.nix`. genNginx
  copy-pastes `mkProxyHost`/`mkBaseHost` nearly verbatim
  (`genNginx.nix:26-48` vs `mkNginxProxies.nix:48-83`). Golden tests only
  serialize the *currently evaluated* path, so production/WIP drift on the hub
  is invisible until the wrong one ships. **Recommend:** a test derivation that
  diffs both paths' output for cortex-alpha topology data. (grok, tuvok, hoshi)
- **R2 — Hardcoded external IPs** (`193.16.42.101`, `10.0.1.42`, `10.88.127.50`,
  `82.5.173.252`) repeated across `flake.nix:622-652`,
  `server_services/nextcloud.nix`, `machines/remote-worker/default.nix`, with a
  `#todo: handle this assignment in a fixed fashion` comment. (tpol, tuvok, hoshi, grok, codex)
- **R3 — `writeShellScript` / raw `${pkgs.foo}/bin/foo` instead of
  `writeShellApplication` + `lib.getExe`.** Found in
  `modules/core-router.nix:66`, `services/dynamic_domain_gandi.nix`,
  `sysdiag.nix`, `rclone-target.nix`, `mkRunners.nix`, `github_runners.nix`, etc.
  Violates prime-directive #18/#19 and breaks reproducibility on package path
  changes. (grok; partially tuvok)
- **R4 — Formatter/linter fragility is documented-CRITICAL but unenforced.**
  AGENTS.md mandates `nixpkgs.nixpkgs-fmt` and `lint-utils` MUST match, yet no
  CI gate/pre-commit enforces it. A stray `nix fmt` is catastrophic if they
  drift. (tpol, tuvok, hoshi, grok)
- **R5 — Missing eval-time filesystem-read error handling.** `builtins.readFile`
  for WireGuard/host public keys fails hard with opaque errors if a key file is
  absent (`mkWireguardPeers.nix`, `flake.nix` mkX86_64/mkAarch64). Recommend
  `pathExists` guard with a clear `throw`. (tuvok)
- **R6 — Inconsistent nginx enablement & backend-reference patterns** across
  topology vs machine vs server_services; `gitolite.nix` uses low-level `listen`
  instead of `listenAddresses`. (tpol, tuvok)

### NITS / MAINTAINABILITY

- WIP architecture "live" on 13 clients + hub while docs call it dead (phase
  discipline). (hoshi, grok)
- `tests/test-new-architecture.nix:9,13` hardcodes a stale absolute repo path.
  (tpol, codex)
- `snippets/enable-wg.nix:9` typo "WireGaurd". (tpol)
- `server_services/syncthing_server.nix` plaintext `password = "A_SAFE_PASSWORD"`.
  (tpol)
- 20+ "Obsolete option" eval traces noted in golden output — build noise. (tuvok)
- No nginx vhost-uniqueness validation in `lib/topology/validate.nix`. (grok)

---

## Open Questions for the User (judgment calls the agents could not make)

1. **Is `lib/topology_library.nix` (the "Ketchup" boundary) intended to stay?**
   tuvok calls it dead; others treat it as the planned library surface. Deleting
   it would break the Phase C library-split intent if it is the intended entry.
2. **Should the entire WIP two-layer subtree
   (`mk*Settings.nix`, `gen*.nix`, `core-router-topology.nix`) be archived or
   finished?** It is partially live and duplicates production. The cleanest
   path per AGENTS.md philosophy is: prove byte-identical output via a diff
   test, then either delete the WIP layer or make it the sole path — but not
   keep both.
3. **Orphaned secrets** (wg_acropolis_pub, wg_display-module key, stale host
   keys) — are these external-VPN endpoints (private keys intentionally absent)
   or genuinely orphaned? Requires user knowledge of topology intent.
4. **Documentation archive policy** — move `plans/`, old `REVIEW/`, historical
   snapshots to `documentation/archive/`? Recommended yes, but affects audit
   trail.

---

## Recommended Execution Order (if user approves cleanup)

1. **Fix B1** (`genNginx.nix` ACME logic) — blocks any WIP hub wiring.
2. **Delete `hedgedoc.nix`** (unambiguous dead code).
3. **Reconcile cortex-alpha module** — decide production vs WIP path; update
   AGENTS.md to match reality.
4. **Add a golden diff test** between production & WIP nginx transformers.
5. **Bulk-remove HIGH list** (dead snippets/docs/secrets) — low risk, high clarity.
6. **Archive MEDIUM documentation** to `documentation/archive/`.
7. **Sweep `writeShellScript`→`writeShellApplication` + `lib.getExe`** (R3).
8. **Extract hardcoded IPs** into `topology/shared.nix` (R2).

---

*Synthesis produced by hy3-free (commander) from 5 independent reviewer reports.
No code was modified. Review artifacts are in this folder; the worktree
`overlord-II-cleaning-review` is uncommitted pending user direction.*
