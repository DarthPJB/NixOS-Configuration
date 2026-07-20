# Point of No Return — FREEZE

**Branch:** `overlord-ii-planar-topology`  
**Worktree:** `/tmp/nixos-planar-topology/`

## Status

Topology JSON + `modules/topology-derive.nix` (in `commonModules`) is the sole producer of:

- `services.prometheus.exporters.*` (where listed in topology JSON)
- `services.nginx.virtualHosts` entries from topology `vhosts` (machine overlays may still add non-topology vhosts, e.g. carmelsite)
- Interface addresses where topology-derive assigns them
- ACME flags on topology vhosts

WireGuard, Tailscale, firewall, DNS/DHCP, nftables forwarding remain outside topology-derive for now.

## Golden certification

All 16 golden-enabled machines: PASS_IDENTICAL or PASS_NIXPKGS_DRIFT only. Zero topology regressions.

See `documentation/ponr-3-golden-results.md`.

## Deploy

**DO NOT deploy from this freeze without express human authorization.**  
PONR is codebase + goldens only. Live rebuild/nixinate is a separate step.

## Rollback

```bash
git log --oneline -5   # identify parent of PONR commit
git checkout <parent-sha>   # or git revert <ponr-sha>
```

## SHA

**PONR commit:** `4e2d55d5a05ebbb95cdf29f45b7d8ecfcf1dbd6e`

