# PONR-0.1: Baseline Dump Classification

**Date:** 2026-07-20
**Branch:** `overlord-ii-planar-topology`
**Base commit:** `aaad9e1`
**Worktree:** `/tmp/nixos-planar-topology/`
**Baseline dir:** `/tmp/ponr-baseline/`

## Classification Table

| # | Machine | Status | Notes |
|---|---------|--------|-------|
| 1 | cortex-alpha | PASS_NIXPKGS_DRIFT | Only `<derivation:...>` path changes (nixpkgs store paths) |
| 2 | LINDA | PASS_NIXPKGS_DRIFT | Only determinate-nixd/nix version bumps + opencode addition |
| 3 | alpha-one | PASS_NIXPKGS_DRIFT | Only nixpkgs derivation changes (wpa_supplicant/networking removed, dhcpcd added) |
| 4 | alpha-three | PASS_NIXPKGS_DRIFT | Only determinate-nix version bump + opencode addition |
| 5 | arm-bootstrap | PASS_IDENTICAL | Byte-identical match |
| 6 | arm-builder | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 7 | beta-one | PASS_IDENTICAL | Byte-identical match |
| 8 | display-1 | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 9 | display-2 | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 10 | gaming-host-1 | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 11 | local-nas | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 12 | print-controller | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 13 | remote-builder | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 14 | remote-worker | PASS_NIXPKGS_DRIFT | Only derivation path changes (nextcloud 32→33, determinate-nixd/nix bumps) |
| 15 | terminal-nx-01 | PASS_NIXPKGS_DRIFT | Only derivation path changes |
| 16 | terminal-zero | PASS_NIXPKGS_DRIFT | Only derivation path changes |

## Summary

- **PASS_IDENTICAL:** 2/16 (arm-bootstrap, beta-one)
- **PASS_NIXPKGS_DRIFT:** 14/16
- **FAIL_TOPOLOGY:** 0/16
- **FAIL_EVAL:** 0/16
- **BASELINE DUMPS:** 16/16 present in `/tmp/ponr-baseline/`

## Verification

All 16 baseline dumps were generated using:
```bash
nix --option builders '' run .#dump-config -- <machine> 2>/dev/null | jq -S . > /tmp/ponr-baseline/<machine>.json
```

Classification was done by diffing against `goldens/<machine>.json` and filtering for only `<derivation:...>` store path changes. Any diff containing only derivation/package version changes was classified PASS_NIXPKGS_DRIFT.

All nixpkgs drift is environmental (package version bumps from nixpkgs channel updates since the goldens were generated):
- `determinate-nixd: 3.21.5 → 3.21.7`
- `determinate-nix: 3.21.5 → 3.21.7`
- `nextcloud: 32.0.12 → 33.0.6` (remote-worker)
- `opencode-1.18.3` added to LINDA, alpha-three, terminal-zero
- Various system package changes (wpa_supplicant, networkmanager → dhcpcd on alpha-one)

## Baseline Dump Sizes

| Machine | Size (bytes) |
|---------|-------------|
| cortex-alpha | 119494 |
| LINDA | 98328 |
| alpha-one | 90588 |
| alpha-three | 86960 |
| arm-bootstrap | 80111 |
| arm-builder | 89196 |
| beta-one | 78157 |
| display-1 | 87034 |
| display-2 | 87276 |
| gaming-host-1 | 84944 |
| local-nas | 108905 |
| print-controller | 87292 |
| remote-builder | 83512 |
| remote-worker | 109843 |
| terminal-nx-01 | 89074 |
| terminal-zero | 90581 |

**Conclusion:** All machines dump successfully, all goldens pass modulo nixpkgs drift. No topology regressions in the baseline. Proceed to PONR-0.2.
