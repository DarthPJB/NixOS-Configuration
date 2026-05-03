# Reconciliation Report: cortex-alpha Isomorphism Verification
**Date:** 2026-05-03
**Target machine:** `cortex-alpha`
**Criticality:** Mission-critical core router
**Objective:** Confirm topology-driven configuration remains 1:1 operationally isomorphic to the stable 2026-04-22 baseline.

## Executive Summary
**Result: PASS (Operational Isomorphism)**

The current `cortex-alpha` configuration matches the April 22 baseline across all mission-critical router subsystems (WireGuard, firewall/nftables policy, NAT external interface behavior, dnsmasq cardinality, nginx vhosts, tailscale advertised routes).

Observed differences are non-operational drift:
1. Nix store path/version drift for `kernel.poweroff_cmd`
2. Two additional kernel hardening sysctls
3. MAC formatting correction (`e9-4a` -> `e9:4a`)
4. Serializer schema drift: `networking.nat.internalInterfaces` was absent in older baseline, now present as `[]`

No behavioral routing-plane regression was detected.

---

## Evidence Collected

### 1) Golden Check
Command:
```bash
nix --option builders '' --extra-experimental-features 'nix-command flakes' run .#check-network -- cortex-alpha
```
Outcome:
- Golden diff shown, but only expected/acceptable differences:
  - `kernel.poweroff_cmd` store path
  - added `vm.mmap_rnd_bits`, `vm.mmap_rnd_compat_bits`
  - corrected dnsmasq MAC delimiter

### 2) Build Validation
Command:
```bash
nix --option builders '' --extra-experimental-features 'nix-command flakes' build --print-out-paths '.#nixosConfigurations."cortex-alpha".config.system.build.toplevel'
```
Outcome:
- Build succeeded.

### 3) WireGuard Key Material Presence
Command:
```bash
ls secrets/public_keys/wireguard
```
Outcome:
- Expected peer public key files present.

### 4) Subsystem Diff vs April 22 Baselines
Compared current output against these baseline snapshots:
- `8dae2b9` (2026-04-22 10:41)
- `6f1d668` (2026-04-22 22:52)
- `8a32e8f` (2026-04-23 12:11)

Common findings across all candidate baselines:
- **MATCH:** `networking.wireguard.interfaces` (18 peers, IPs unchanged)
- **MATCH:** `networking.firewall.interfaces`
- **MATCH:** `networking.firewall.allowedTCPPorts`
- **MATCH:** `networking.firewall.allowedUDPPorts`
- **MATCH:** `networking.nftables.enable`
- **MATCH:** `networking.nat.externalInterface`
- **MATCH:** `networking.tailscale.advertisedRoutes`
- **MATCH:** `services.nginx.virtualHosts` (same vhost set/cardinality)
- **DIFF:** `services.dnsmasq.settings` (MAC delimiter normalization only)
- **DIFF:** `networking.nat.internalInterfaces` (`<missing>` in baseline vs `[]` current)

---

## NAT Baseline Concern: Analysis

### Observation
`networking.nat.internalInterfaces` is missing in older baseline JSON but appears as `[]` in current output.

### Root Cause
Serializer schema changed over time:
- **Baseline-era serializer (`real-topology/default.nix` at `6f1d668`)** did not include key `networking.nat.internalInterfaces`.
- **Current serializer** explicitly includes:
  ```nix
  "networking.nat.internalInterfaces" = config: config.networking.nat.internalInterfaces or [ ];
  ```

### Operational Impact
**None** for current router behavior in this config context:
- `networking.nat.enable = false` on cortex-alpha
- external forwarding is handled by nftables ruleset generation path
- `[]` vs missing here is a serialization-shape difference, not a policy change

### Risk Classification
- **Type:** Metadata/schema drift
- **Severity:** Low
- **Deployment blocker:** No

---

## Go / No-Go Decision

## ✅ GO (with explicit drift acknowledgement)

Deployment is acceptable for mission-critical operations based on this reconciliation.

### Conditions for Confidence
- Keep current MAC normalization (correctness fix)
- Treat `nat.internalInterfaces` discrepancy as schema versioning artifact
- Preserve topology-driven nftables path already validated in build

---

## Recommended Follow-up (Non-blocking)
1. Add a `goldenSchemaVersion` field to generated golden output.
2. Document normalization rules (e.g., MAC delimiter canonicalization).
3. Add compare tooling that classifies drift as:
   - `operational-change`
   - `metadata-drift`
   - `toolchain/store-drift`
4. Re-generate golden intentionally after approval to align expected snapshot with current serializer schema.

---

*Prepared for mission-critical release confidence. Operational parity confirmed.*
