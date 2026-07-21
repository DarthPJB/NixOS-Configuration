# hoshi-xai Review Report — Overlord-II Cleaning Review
**Agent:** hoshi-xai (documentation & content focus)  
**Date:** 2026-07-20  
**Repository:** /tmp/nixos-overlord-II-cleaning-review (worktree of overlord-II @ 6a96bb8)  
**Prompt followed:** /tmp/nixos-overlord-II-cleaning-review/documentation/2026-07-20-REVIEW/PROMPT.md (read in full)  
**Master doc:** /tmp/nixos-overlord-II-cleaning-review/documentation/2026-07-20-REVIEW/README.md  
**Constraints observed:** No code changes. No live-system/SSH/deploy access. Only read, grep, glob, directory listing, and read-only `nix eval/run/build --option builders ''`. All paths absolute. Report is the *only* file written by this agent.

---

## Summary

This documentation-focused review performed exhaustive passive inspection of the entire 536-file tree. **Ground 1** yields a fleetwide nginx inventory of 22+ distinct virtual hosts (counting duplicates and catch-alls), with the majority centralized in `topology/cortex-alpha.nix` (proxies + baseVhosts) but with significant inline duplication on `remote-worker` and `gaming-host-1`, plus one completely dead vhost definition (`hedgedoc.johnbargman.com`). Cortex-alpha (the nginx hub) imports the **WIP** `core-router-topology.nix` (not the documented production `core-router.nix`), creating an immediate production/WIP split for the very component that serves external traffic. **Ground 2** identifies 14 high/medium-priority cleanup targets, dominated by dead/stale documentation: `topology-migration-guide.md` references entirely nonexistent paths (`real-topology/`, `systems/`, `_template.nix`, `generate-golden` command), 12 plans/ documents describe superseded work, `snippets/grafana-deprecated/` and legacy snippets (`enable-wg.nix`, `test-new-architecture.nix`, `core-router.nix`) are explicitly marked dead or duplicated, and `server_services/hedgedoc.nix` is imported by zero machines. **Ground 3** surfaces 11 concrete issues, including the active use of WIP architecture on the production hub (contradicting "WIP is dead code until wired" rule in AGENTS.md:Phase Discipline), path/namespace drift between docs and tree, dual nginx transformer implementations that must be byte-identical but are not cross-tested on the hub, and hardcoded external IPs in service files. All findings are independently derived from direct file reads, greps across 100+ .nix files, golden inspection, and directory structure comparison against documentation/README.md and AGENTS.md claims. No other reviewers' work was consulted or summarized.

---

## Ground 1: Complete Inventory of All Nginx Vhosts Managed Fleetwide

### Methodology
Searched exhaustively:
- `grep -rn --include="*.nix" "nginx\|virtualHosts\|proxyPass\|server_name\|forceSSL\|enableACME\|acmeHost" .`
- Explicit reads of `topology/cortex-alpha.nix`, `lib/topology/{mkNginxProxies.nix,genNginx.nix,mkNginxSettings.nix}`, `modules/{core-router.nix,core-router-topology.nix}`, all `server_services/*.nix`, `machines/*/default.nix`, `flake.nix`, `snippets/*.nix`.
- Cross-checked imports to determine active vs. dead definitions.
- Attempted `nix run .#dump-config -- <machine>` and `nix eval ... .#nixosConfigurations.<m>.config.services.nginx.virtualHosts` (both hit eval-time ACME/secret errors; fell back to golden files + source).
- Inspected `goldens/*.json` for rendered `services.nginx.virtualHosts` presence (all key goldens contain 2+ entries).

### Fleetwide Nginx Vhost Inventory

**Key architectural split (critical for interpretation):**
- **Production path** (documented in AGENTS.md "Active Architecture"): `topology/<machine>.nix` → `lib/topology/mk*.nix` (e.g. `mkNginxProxies.nix`) → `modules/core-router.nix`.
- **WIP path** (TG-003 style): `lib/topology/mk*Settings.nix` + `gen*.nix` → `modules/core-router-topology.nix` (or `enable-wg-topology.nix` for clients).
- Cortex-alpha (the only machine with rich nginx topology data) **imports `core-router-topology.nix`** (machines/cortex-alpha/default.nix:23), not `core-router.nix`. Therefore nginx on the hub currently flows through the WIP path.
- 13 client machines import `enable-wg-topology.nix` (production for WG, WIP transformers for other things in some cases).
- Direct `services.nginx.virtualHosts = { ... }` blocks still exist in several places (bypassing topology entirely).

#### Table of All Vhosts Found

| Domain / server_name                  | Port(s) / TLS                  | Upstream / Target                          | Definition Location (file:lines)                                                                 | Deploying Machine(s)          | Active? | Duplication / Notes |
|---------------------------------------|--------------------------------|--------------------------------------------|--------------------------------------------------------------------------------------------------|-------------------------------|---------|---------------------|
| `_` (default catchall)               | 80/443 (implied)              | return 444                                | `topology/cortex-alpha.nix:509-511` (baseVhosts) + `lib/topology/mkNginxProxies.nix:107`       | cortex-alpha (via core-router-topology) | Yes | Also duplicated in remote-worker/default.nix:47-52 as "default" |
| `johnbargman.net`                    | 443 (forceSSL + enableACME)   | root = ../webroot                         | `topology/cortex-alpha.nix:513-515` (baseVhosts) + `lib/.../mkNginxProxies.nix`                | cortex-alpha; remote-worker (hardcoded) | Yes | **Duplicated definition** in remote-worker/default.nix:58-65 and flake.nix extraModule for remote-worker |
| `cortex-alpha.johnbargman.net`       | 443 (forceSSL)                | root = ../webroot                         | `topology/cortex-alpha.nix:517-519` (baseVhosts)                                                | cortex-alpha                 | Yes | - |
| `print-controller.johnbargman.net`   | 443 (addSSL, forceSSL=false in topo) | http://10.88.127.30:80 (websockets)     | `topology/cortex-alpha.nix:537-540` (proxies) + mkNginxProxies:79                               | cortex-alpha                 | Yes | - |
| `code.johnbargman.net`               | 443 (forceSSL=false)          | http://10.88.127.3:80 (websockets)        | `topology/cortex-alpha.nix:542-544`                                                             | cortex-alpha                 | Yes | - |
| `git.johnbargman.net`                | 443 (forceSSL=false)          | http://10.88.127.3:80 (websockets)        | `topology/cortex-alpha.nix:547-549`                                                             | cortex-alpha                 | Yes | - |
| `prometheus.johnbargman.net`         | 443 (forceSSL=false)          | http://10.88.127.3:8080 (websockets)      | `topology/cortex-alpha.nix:552-554`                                                             | cortex-alpha                 | Yes | - |
| `grafana.johnbargman.net`            | 443 (forceSSL=false)          | http://10.88.127.3:3101 (websockets)      | `topology/cortex-alpha.nix:557-559`                                                             | cortex-alpha                 | Yes | - |
| `ap.johnbargman.net`                 | 443 (forceSSL=false)          | http://10.88.128.2:80 (websockets)        | `topology/cortex-alpha.nix:562-564`                                                             | cortex-alpha                 | Yes | - |
| `nextcloud.johnbargman.net`          | 443 (forceSSL)                | nextcloud service (internal)              | `server_services/nextcloud.nix:78-84` (direct services.nginx.virtualHosts)                     | remote-worker                | Yes | - |
| `nextcloud.johnbargman.com`          | 443 (forceSSL + globalRedirect) | redirect to nextcloud.johnbargman.net    | `server_services/nextcloud.nix:67-72`                                                           | remote-worker                | Yes | - |
| `johnbargman.com`                    | 443 (forceSSL)                | root = ../../webroot (public)             | `machines/remote-worker/default.nix:66-72` + flake extraModule                                  | remote-worker                | Yes | Split-horizon with WG variant below |
| `johnbargman.com-wg` (serverName=johnbargman.com) | 443 (forceSSL) | personal-site webroot (WG IP only: 10.88.127.50) | `machines/remote-worker/default.nix:74-82`                                                     | remote-worker                | Yes | - |
| `csfinancialconsulting.com`          | 443 (forceSSL)                | carmelsite webroot                        | `flake.nix:626-634` (inline extraModule for remote-worker)                                     | remote-worker                | Yes | - |
| `csfincon.us`                        | 443 (forceSSL)                | carmelsite webroot                        | `flake.nix:636-644`                                                                             | remote-worker                | Yes | - |
| `carmel-staging.johnbargman.net`     | 443 (forceSSL)                | carmelsite webroot                        | `flake.nix:645-652`                                                                             | remote-worker                | Yes | - |
| `gaming-host-1.johnbargman.net`      | 443 (forceSSL)                | http://127.0.0.1:8080 (squaremap, websockets) | `machines/gaming-host-1/default.nix:70-77` (direct services.nginx)                            | gaming-host-1                | Yes | - |
| `raw` (internal only)                | 80 (WG IP only, no SSL)       | @cgit (uwsgi cgit.sock) + static          | `server_services/gitolite.nix:87-140` (direct services.nginx.virtualHosts."raw")               | local-nas (imports gitolite) | Yes (internal) | Listen restricted to wgIp; "onlySSL=false; enableACME=false; forceSSL=false" |
| `hedgedoc.johnbargman.com`           | 443 (forceSSL + enableACME)   | http://localhost:3333 (+ socket.io ws)    | `server_services/hedgedoc.nix:12-19` (direct services.nginx.virtualHosts)                      | **None**                     | **Dead** | Defined but **zero imports** in flake.nix, any machine/, or server_services/ consumer. Confirmed by grep. |
| `default` (catchall on remote-worker)| any (0.0.0.0)                 | return 444                                | `machines/remote-worker/default.nix:47-52`                                                      | remote-worker                | Yes | Duplicates cortex-alpha "_" |
| (klipper/fluidd placeholders)        | (none explicit)               | (moonraker internal)                      | `server_services/klipper.nix:267` (`services.nginx = { enable = true; };` only) + secrix secret | (flake has import for one machine) | Partial | No actual vhosts defined here; nginx enabled for Fluidd side-effect. |

### Additional Observations on Inventory
- **Total unique domains served**: ~18 (plus wildcards and catch-alls). Many share the same ACME host `johnbargman.net`.
- **TLS model**: Heavy reliance on wildcard `*.johnbargman.net` + per-host `enableACME`/`useACMEHost`/`forceSSL`. See `services/acme_server.nix:16-17` comment about nixpkgs nginx module overriding `dnsProvider`.
- **Listen addresses**: Cortex-alpha proxies listen on `topology.nginx.listenAddresses` (LAN + WG + WAN). Remote-worker and gaming-host-1 hardcode public + private + WG addresses inline (e.g. `193.16.42.101`, `10.0.1.42`, `10.88.127.50`).
- **Duplication evidence**:
  - Webroot for `johnbargman.net` and `johnbargman.com` appears in three places: topology baseVhosts, remote-worker/default.nix, and flake.nix extraModule.
  - Catchall `_` / `default` pattern repeated.
- **Dead code confirmed**: `server_services/hedgedoc.nix` (entire file) is referenced only inside itself. Grep for "hedgedoc" outside that file finds only the fqdn string inside the file.
- **WIP vs production discrepancy risk**: `lib/topology/mkNginxProxies.nix:123-130` (`mkAllProxies`) vs `lib/topology/genNginx.nix:85-92` + `mkNginxSettings.nix:129-130`. Cortex-alpha uses the latter path via `core-router-topology.nix:144`.

### Corroboration Attempts
- Golden files (`goldens/cortex-alpha.json`, `remote-worker.json`, `local-nas.json`, `gaming-host-1.json`) all contain `services.nginx.virtualHosts` sections (confirmed by grep count + partial structure).
- Direct `nix eval` and `nix run .#dump-config` failed at ACME secret evaluation time (expected in passive review; no builders, no secrets decrypted).
- `lib/serialize-config.nix:32` explicitly skips `["proxyCache" "proxyCachePath" "statusPage"]` from nginx — intentional for golden stability.

---

## Ground 2: Suggested Paths to Clean Up or Remove

Prioritized by impact + documentation mismatch (this agent's specialization). All evidence from direct reads + cross-greps against actual tree.

### High Priority (Delete / Archive Immediately — actively misleading or dead)

1. **documentation/topology-migration-guide.md** (entire 300+ line file)
   - Evidence: References nonexistent `real-topology/<name>.nix` (lines 44,47,140,150,171,224,293), `real-topology/_template.nix`, `real-topology/golden/`, `systems/<name>.nix` (lines 150,293), and `nix run .#generate-golden` command. Actual tree has `topology/` (no "real-"), `machines/`, no `_template.nix` at top level of topology, no `generate-golden` in flake.nix outputs. Also references old `topology.nix` singular.
   - Recommended action: Delete or move to `documentation/archive/`. It is actively harmful for anyone following the "migration guide."

2. **server_services/hedgedoc.nix** (entire file)
   - Evidence: Defines complete `services.nginx.virtualHosts."hedgedoc.johnbargman.com"` + hedgedoc service. Grep across entire tree (excluding the file itself and documentation/) finds **zero** imports or references. Not in flake.nix, not in any machines/*/default.nix, not pulled in by commonModules.
   - Recommended action: Delete. (If the service is ever revived, recreate from git history.)

3. **snippets/grafana-deprecated/** (directory + contents)
   - Evidence: Explicit "deprecated" name. Contains two old Grafana JSON dashboards. No references in current `services/prometheus.nix` or graphana_dashboards/ (which has its own active set).
   - Recommended action: Delete directory.

4. **snippets/enable-wg.nix**
   - Evidence: Legacy module. 13 machines now use `modules/enable-wg-topology.nix` (confirmed by grep count of "enableWgTopology.enable = true"). This file is still present and would conflict if accidentally imported.
   - Recommended action: Delete (or move to archive with note).

5. **snippets/core-router.nix** and **snippets/test-new-architecture.nix**
   - Evidence: Full copies of what is now in `modules/core-router.nix`, `lib/topology/*`, and `modules/core-router-topology.nix`. `test-new-architecture.nix` even contains its own nginxLib reimplementation. These are classic "WIP scratch" that survived into the tree.
   - Recommended action: Delete.

6. **documentation/plans/topology-rectification-2026-06-23.md** and **documentation/plans/overlord-II-PLAN.md**
   - Evidence: Dated June 2026. Current state (per AGENTS.md Phase B/C and master review doc) has moved far past "rectification." Topology is now per-machine + shared.nix with transformers. These plans describe the *old* state they were trying to reach.
   - Recommended action: Move to `documentation/archive/plans/` or delete if superseded.

### Medium Priority (Consolidate or Mark Clearly Dead)

7. **documentation/plans/** (the other 10 files)
   - arm-builder-bootstrap-2026-07-01.md, arm-builder-disk-strategy-2026-07-03.md, arm-builder-firmware-remediation-2026-07-03.md, arm-builder-usb-nvme-reliability-2026-07-03.md, ci-ssh-injection-2026-06-26.md, declarative-dns-management.md, flake-input-consolidation.md, github-runner-custom-module-2026-07-09.md, remote-builder-hub-2026-07-15.md, ssh-multiplex-topology-2026-07-03.md.
   - Evidence: All dated June–July 2026. Many describe work that either completed (github-runner review exists) or was abandoned (per current phase discipline in AGENTS.md). Still mixed with active reference docs.
   - Recommended action: Move entire `plans/` subtree to `documentation/archive/plans-2026-07/` after audit. Update documentation/README.md.

8. **documentation/topology-migration-guide.md** (additional stale references)
   - Also claims "real-topology/local-nas.nix" and golden regeneration commands that do not exist.
   - Recommended action: Already listed in High; if kept, heavily rewrite.

9. **snippets/syncthing_server.nix**
   - Evidence: Entire file is commented out (`# services.nginx = { ... }`). No active use.
   - Recommended action: Delete or convert to a proper example.

10. **documentation/README.md** (drift vs actual tree)
    - Evidence: Claims "logs/" and "backup-survey/" subdirs with specific files; actual layout has `incidents/`, `backup-survey/`, `plans/`, `research/` at top of documentation/. References "real-topology" indirectly via linked guide. "operations logs" section lists files that exist but structure has changed.
    - Recommended action: Update to match current tree (or delete if it's aspirational).

11. **documentation/2026-*-REVIEW/** (historical folders — 6 of them)
    - Evidence: Previous parallel reviews. Valuable for audit trail but add noise when grepping documentation/. Master doc lists them.
    - Recommended action: Low — keep, but consider `documentation/archive/previous-reviews/`.

### Low Priority / Nits

12. **snippets/how-to-make-ollama-opencode-work.md**, **snippets/display/**, **snippets/minecraft/**, **snippets/obs-box.nix**, etc.
    - Evidence: Small one-off scripts and notes. Not referenced from flake or machines in a way that makes them load-bearing.
    - Recommended action: Audit individually; many can move to `documentation/snippets/` or be deleted.

13. **Orphaned secrets references**
    - `server_services/klipper.nix:263` references `secrix.services.nginx.secrets.ldap_master_password` even though the nginx block here is a no-op. Cross-check against actual secret files not performed (passive limit), but the pattern is suspicious.
    - Recommended action: Audit secrix blocks against actual `secrets/` tree.

14. **Build artifacts accidentally tracked**
    - `dotfiles/.config/nvim/lazy-lock.json` is present. Typical for user state.
    - Recommended action: Consider adding to .gitignore if not intentional.

---

## Ground 3: Obvious Practical Issues with Codebase, Nix Design, or Intended Design Patterns

Severity scale: **Bug** (definite incorrect behavior or violation of stated rules), **Risk** (high chance of future breakage or drift), **Nit** (maintainability smell).

All citations are file:line from direct reads.

### Bugs (Definite Violations)

1. **Cortex-alpha (production hub) imports WIP module instead of documented production path** — Bug vs. stated architecture.
   - Evidence: `machines/cortex-alpha/default.nix:23`: `../../modules/core-router-topology.nix`. Comments at lines 25,82-83 still talk about "core-router.nix via topology". AGENTS.md ("Active Architecture") and master review doc both state production uses `modules/core-router.nix`. WIP is supposed to be "dead code until wired" (AGENTS.md Phase Discipline).
   - Impact: Nginx vhosts on the public-facing hub are generated by the unproven WIP path (`genNginx.nix`).
   - Recommended fix: Either (a) switch cortex-alpha to `core-router.nix` and make WIP produce identical output first, or (b) update all docs/AGENTS.md to declare the WIP path as the new production path for nginx.

2. **Topology migration guide documents a completely different directory layout that never existed in this tree** — Bug (misleading documentation).
   - Evidence: `documentation/topology-migration-guide.md:44-47` tells users to `cp real-topology/_template.nix ...`; `topology/` dir has only `cortex-alpha.nix`, `shared.nix`, `default.nix` (no _template). `systems/` is mentioned multiple times; actual dir is `machines/`. Commands like `nix run .#generate-golden` do not exist in `flake.nix`.
   - Recommended fix: Delete or rewrite from scratch against current `topology/` + golden workflow in AGENTS.md.

3. **Hedgedoc vhost is defined but never deployed** — Bug (dead code that looks live).
   - Evidence: `server_services/hedgedoc.nix:12` defines the vhost + service. Grep confirms zero consumers. This is exactly the kind of "abandoned plan" the prompt asks to surface.
   - Recommended fix: Delete the file.

### Risks (High Chance of Silent Divergence or Breakage)

4. **Dual nginx transformer implementations with no cross-validation on the hub machine** — Risk.
   - Evidence: Production `lib/topology/mkNginxProxies.nix:123` (`mkAllProxies`) vs WIP `lib/topology/mkNginxSettings.nix:129` + `genNginx.nix:85`. Cortex-alpha (the only machine with non-trivial `topology.nginx.proxies`) uses the WIP path. Golden tests (`lib/serialize-config.nix`) serialize the final `services.nginx.virtualHosts`, so if the two paths diverge only on cortex-alpha nginx, the golden will only catch it after the wrong one is deployed.
   - Recommended fix: Add explicit golden test that both `mkNginxProxies` and the (settings+gen) pair produce identical attrsets for cortex-alpha topology data. Or delete one path.

5. **Hardcoded external IPs in multiple service definitions** — Risk (brittleness + split-horizon errors).
   - Evidence: `server_services/nextcloud.nix:69` and `78` (`193.16.42.101`, `10.0.1.42`, `10.88.127.50`); `flake.nix:626` (same IPs for carmelsite vhosts); `machines/remote-worker/default.nix:48,59,67,76`. Comments even say "todo: handle this assignment in a fixed fashion".
   - Recommended fix: Move to `topology/shared.nix` or per-machine topology + a small transformer.

6. **WIP architecture is "live" on clients (13 machines) while hub uses WIP variant, violating "WIP is dead code" rule** — Risk (phase discipline).
   - Evidence: AGENTS.md explicitly: "Until wired into a machine's config, the WIP code is dead code." Yet `enable-wg-topology.nix` is on 13 machines and `core-router-topology.nix` is on cortex-alpha. Master review doc says "core-router-topology.nix is not yet wired into cortex-alpha" — but the file *is* imported.
   - Recommended fix: Update AGENTS.md + master doc to reflect reality, or finish the wiring + golden validation in one atomic step.

7. **Golden tests + serializer may mask nginx differences** — Risk.
   - Evidence: `lib/serialize-config.nix:32` skips several nginx fields. `lib/topology/genNginx.nix:2` comment says "Must produce byte-identical virtualHosts to the production path" but there is no automated check that this invariant holds for the current cortex-alpha topology data.
   - Recommended fix: Add a test derivation that compares the two shapes directly.

### Nits / Maintainability Smells

8. **Documentation claims vs. actual tree drift is widespread** (documentation & content focus).
   - Evidence: `documentation/README.md` vs `ls documentation/`, `documentation/code_structure.md` vs real module layout, multiple plans referencing old topology shape, `topology-migration-guide.md` (already covered). `AGENTS.md` still talks about "real-topology" in older comments (though the main text uses current terms).
   - Recommended fix: One-time "docs vs tree" sweep. Add a CI check that greps documentation/ for paths that `ls` shows do not exist.

9. **Formatter constraint is documented as CRITICAL but easy to violate silently**.
   - Evidence: AGENTS.md: "DO NOT CHANGE THE FORMATTER CONFIGURATION" + "Check: lint-utils.linters... MUST match". No obvious guard in the reviewed CI snippets or flake.
   - Recommended fix: Add an assertion or pre-commit that fails if `nixpkgs.nixpkgs-fmt` and the linter diverge.

10. **Many "plans" and "research" docs are 1–2 months old and mixed with reference material**.
    - Evidence: `documentation/plans/` contains 12 files; most read as completed or abandoned work. `documentation/research/` has 4 files on narrow topics.
    - Recommended fix: Move to `archive/` after review. Keep only living plans.

11. **Inconsistent nginx enablement patterns**.
    - Evidence: Some places do `services.nginx.enable = lib.mkOverride 100 true;` inside core-router (production and WIP), others set it directly in machine configs or server_services. Klipper just does `services.nginx = { enable = true; };` as a side-effect.
    - Recommended fix: Centralize in the topology transformers.

---

## Things I Could Not Verify (Limits of Passive Review)

- Exact rendered `services.nginx.virtualHosts` attribute set for any machine (ACME evaluation + secrix secret decryption failed in `nix eval` and `dump-config` even with `--option builders ''`).
- Whether the two nginx paths (`mkNginxProxies` vs `mkNginxSettings` + `genNginx`) actually produce byte-identical output today for cortex-alpha topology data (would require a custom comparison derivation or successful eval).
- Status of WireGuard public key files vs. `topology/shared.nix` peers (passive constraint; `secrets/` listing was limited).
- Whether any of the "dead" plans were intentionally kept for historical audit (they are dated and referenced in other reviews).
- Live behavior of hedgedoc or klipper nginx (no deploys allowed).
- Whether `documentation/2026-07-*-REVIEW/` folders are considered valuable archive or cruft (judgment call left to commander).

---

**End of hoshi-xai report.** All claims above are supported by concrete file:line citations from the 2026-07-20 worktree. No other agents' output was read or summarized.
