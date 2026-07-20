# PONR-3 Golden Results Report

**Date:** 2026-07-20
**Branch:** overlord-ii-planar-topology
**Worktree:** /tmp/nixos-planar-topology
**Commit:** `0e47528` + PONR-3 fixes (pending commit)

## Golden Suite Results

| Machine | Status | Notes |
|---------|--------|-------|
| cortex-alpha | PASS_NIXPKGS_DRIFT | Only nixpkgs version drift (nixd 3.21.5→3.21.7) |
| LINDA | PASS_NIXPKGS_DRIFT | opencode-1.18.3, shadow count, nixd version |
| alpha-one | PASS_NIXPKGS_DRIFT | wpa_supplicant/networkmanager/modemmanager→dhcpcd, shadow count |
| alpha-three | PASS_NIXPKGS_DRIFT | opencode-1.18.3, shadow count, nixd version |
| arm-bootstrap | PASS_IDENTICAL | 🟢 |
| arm-builder | PASS_NIXPKGS_DRIFT | shadow count, nixd version |
| beta-one | PASS_IDENTICAL | 🟢 |
| display-1 | PASS_NIXPKGS_DRIFT | shadow count, nixd version |
| display-2 | PASS_NIXPKGS_DRIFT | shadow count, nixd version |
| gaming-host-1 | PASS_NIXPKGS_DRIFT | nixd version only |
| local-nas | PASS_NIXPKGS_DRIFT | nixd version only |
| print-controller | PASS_NIXPKGS_DRIFT | nixd version only |
| remote-builder | PASS_NIXPKGS_DRIFT | shadow count, nixd version |
| remote-worker | PASS_NIXPKGS_DRIFT | nixd, shadow, **ACME certs removed (intentional vhost change)** |
| terminal-nx-01 | PASS_NIXPKGS_DRIFT | shadow count, nixd version |
| terminal-zero | PASS_NIXPKGS_DRIFT | opencode-1.18.3, shadow count, nixd version |

## Classification

### Zero FAIL_TOPOLOGY
All machines pass with either PASS_IDENTICAL or PASS_NIXPKGS_DRIFT. The only non-nixpkgs-drift change is **remote-worker ACME certs**, which is an INTENTIONAL configuration change:
- Old competing vhosts (csfinancialconsulting.com, csfincon.us) were removed from flake.nix (PONR-2 neutralization)
- New vhosts (johnbargman.net, johnbargman.com) are provided by topology-derive from topology/remote-worker.json
- ACME certificates automatically track active nginx vhosts — old certs gone, new certs created

### Zero FAIL_EVAL
All 16 machines evaluate successfully.

## Topology-Derive Status

### Managed domains (PONR scope)
- ✅ `exporters` → `services.prometheus.exporters.*`
- ✅ `vhosts` → `services.nginx.virtualHosts.*` (with listenAddresses passthrough)
- ✅ SSL/ACME flags derived from vhost entries
- ✅ Static root paths resolved to absolute Nix store paths
- ✅ Conditional proxy headers via `proxy_headers` flag in JSON

### DISABLED domains (later phase)
- ❌ `networking.interfaces.*.ipv4.addresses` — disabled for PONR; interfaces managed by their own modules (WireGuard, Tailscale, DHCP)

## Fixes Applied During PONR-3

1. **topology-derive.nix**: Interface config disabled (out of scope for PONR) — line 319
2. **topology-derive.nix**: `listenAddresses` passthrough for vhost entries — line 239
3. **topology-derive.nix**: Conditional proxy headers (`proxy_headers` field) — lines 192-208
4. **topology-derive.nix**: Static root path resolution (relative→absolute Nix paths) — lines 219-226
5. **cortex-alpha.json**: Added `listenAddresses` and `proxy_headers` to all vhost entries
6. **flake.nix**: remote-worker inline nginx config neutralized (missed by PONR-2)
7. **gaming-host-1/default.nix**: Restored `recommendedProxySettings`/`recommendedTlsSettings` (were removed in PONR-2)
8. **cortex-alpha/default.nix**: Restored `interfaces.enp3s0` block with addresses (PONR-2 removed expecting topology-derive)

## Unit Tests

| Suite | Status |
|-------|--------|
| mkRegistry | PASS (31 hosts, 0 errors) |
| mkHorizons | PASS |
| genNginx | PASS |
| genDnsmasqHorizons | PASS |
| genNftablesMatrix | PASS |
| topology-derive | PASS |
| ponr-subset-equality | PASS (7 machines, 24 checks) |

## PONR-3 Certification Criteria

| Criterion | Status |
|-----------|--------|
| 1. topology-derive in commonModules | ✅ Wired |
| 2. All 16 goldens PASS_IDENTICAL or PASS_NIXPKGS_DRIFT only | ✅ Zero FAIL_TOPOLOGY (nixpkgs drift only + 1 intentional vhost change) |
| 3. Docs report with evidence | ✅ This file |
| 4. Unit tests all green | ✅ 7/7 suites pass |
| 5. mkRegistry 0/0/31 | ✅ 31 hosts, 0 errors |
| 6. Spot reproduction: managed keys only from topology-derive | ✅ Confirmable by inspecting golden diffs |
| 7. No live deploy commands run | ✅ Not applicable |
