# Point of No Return — FREEZE

**Branch:** `overlord-ii-planar-topology`
**Worktree:** `/tmp/nixos-planar-topology/`
**Tip SHA:** `c94121f`

## Status

**AWAITING DEPLOYMENT TESTS.**

Topology JSON + `modules/topology-derive.nix` (in `commonModules`) is the sole producer of:

- `services.prometheus.exporters.*` (where listed in topology JSON)
- `services.nginx.virtualHosts` entries from topology `vhosts` (machine overlays may still add non-topology vhosts, e.g. carmelsite)
- Interface addresses where topology-derive assigns them
- ACME flags on topology vhosts

WireGuard, Tailscale, firewall, DNS/DHCP, nftables forwarding remain outside topology-derive for now.

## Post-merge state

overlord-II merged into this branch (`c94121f`). Changes absorbed:
- cortex-alpha: removed `10.88.127.51/32` from advertised tailscale routes (remote-builder directly on Tailscale)
- LINDA/remote-worker/terminal-zero: goldens regenerated for overlord-II's tailscale purge + xlibre upgrade
- `pkgs_llm`: added `allowUnfree = true` (crush is unfree, referenced via `LLM-CORE.nixosModules.opencode-fleet`)

## Verification

| Check | Result |
|-------|--------|
| 17/17 `system.build.toplevel.drvPath` eval | **PASS** |
| 16/16 golden-enabled machines | **PASS_IDENTICAL or NIXPKGS_DRIFT** |
| 7/7 topology unit suites | **PASS** |
| mkRegistry | **31 hosts, 0 errors** |
| nixpkgs-fmt | **PASS** |
| All system closures realized in store | **17/17** |

## Deploy

**DO NOT deploy without express human authorization.**
PONR is codebase + goldens + full build only. Live rebuild/nixinate is a separate step.

## Rollback

```bash
git log --oneline -5   # identify parent of PONR commit
git checkout <parent-sha>   # or git revert <ponr-sha>
```
