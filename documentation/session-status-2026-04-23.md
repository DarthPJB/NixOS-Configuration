# Topology-Driven Router Refactoring - Status Report
**Date**: 2026-04-23
**Machine**: cortex-alpha
**Branch**: jb/ai/overlord-9
**Status**: PARTIALLY COMPLETE - NOT READY FOR DEPLOYMENT

## Executive Summary

The topology-driven router refactoring for cortex-alpha has made significant progress but has critical issues that must be addressed before deployment. The golden test passes and WireGuard public keys are now correctly read from files, but validation integration, error handling, and several architectural issues remain.

## What Was Accomplished Today

### 1. Golden Test Validation ✓
- Generated fresh golden from main branch's inline configuration
- Confirmed topology-driven output matches main exactly
- Enhanced golden test to capture 32 options (up from 20+)
- Added coverage for: networking.interfaces, security.acme, networking.nameservers

### 2. WireGuard Public Keys ✓
- **Critical bug fixed**: Was using placeholder keys (`"placeholder-alpha-one"`)
- Now reads actual keys from `secrets/public_keys/wireguard/wg_${name}_pub`
- All 18 peers have valid public keys
- Matches original `wg_peers.nix` behavior exactly

### 3. Topology Data Fixed ✓
- Peer names now match original `peerList` exactly (LINDA, local-nas, terminal-zero, etc.)
- Added `wireguardIp` fields to LAN hosts needing separate WireGuard IPs
- Added `hostname` field for dnsmasq domain resolution

### 4. Architecture Cleaned Up ✓
- Removed `enable-wg.nix` from cortex-alpha (it's for clients, not hub)
- Removed `mkForce` hacks from core-router.nix
- Added proper secrix configuration for WireGuard private key
- Removed development artifacts (evaluate-golden*.nix, generate-main.nix)

### 5. Multi-Agent Review Completed ✓
- Three agents (tpol-xai, tpol-minimax, tuvok-deepseek) reviewed topology generators
- Identified 11 issues ranging from critical to low priority
- Created detailed issue tracker with solutions

## Current State

### Golden Test
```
✓ Network config matches golden for cortex-alpha
```

### WireGuard Configuration
| Property | Status |
|----------|--------|
| Enabled | ✓ Yes |
| Private Key | ✓ Via secrix |
| Public Keys | ✓ Read from files |
| Peers | ✓ 18 peers |
| IPs | ✓ 10.88.127.1/32, 10.88.127.0/24 |
| Listen Port | ✓ 2108 |

### Secrex Configuration
| Element | Value |
|---------|-------|
| Encrypted File | `secrets/private_keys/wireguard/wg_cortex-alpha` |
| Decrypted Path | `/run/wireguard-wireg0-keys/cortex-alpha` |
| Module | `secrix.nixosModules.default` |

## Critical Issues Remaining

### 1. validate.nix Not Integrated (TG-001)
- **Impact**: Invalid topology data causes cryptic errors
- **Status**: OPEN
- **Solution**: Add validation call in core-router.nix

### 2. Silent Failures (TG-002)
- **Impact**: Missing peers silently dropped
- **Status**: PARTIAL (trace warnings added)
- **Solution**: Convert to assertions

### 3. Hardcoded Nginx IPs (TG-005)
- **Impact**: Won't work for other machines
- **Status**: OPEN
- **Solution**: Derive from topology data

## Known Working Configuration

The following has been validated against main branch:

| Component | Validated |
|-----------|-----------|
| WireGuard peers | ✓ 18 peers with correct IPs and keys |
| Nginx proxies | ✓ 9 virtual hosts |
| DHCP hosts | ✓ 11 reservations |
| DNS entries | ✓ 8 static addresses |
| Firewall rules | ✓ Per-interface rules |
| Tailscale routes | ✓ Advertised routes |
| Network interfaces | ✓ enp2s0 (DHCP), enp3s0 (static) |
| ACME certificates | ✓ Email and cert list |

## Deployment Recommendation

**DO NOT DEPLOY** until:
1. TG-001: validate.nix is integrated
2. TG-002: Silent failures converted to assertions
3. TG-005: Nginx IPs derived from topology

These issues could cause:
- Cryptic errors on invalid topology
- Missing WireGuard peers
- Nginx binding to wrong addresses

## Files Modified

### Core Infrastructure
- `modules/core-router.nix` - Passes `self` to transformations
- `lib/topology/mkWireguardPeers.nix` - Reads public keys from files
- `machines/cortex-alpha/default.nix` - Added secrix config

### Topology Data
- `real-topology/cortex-alpha.nix` - Fixed peer names, added wireguardIp
- `real-topology/default.nix` - Enhanced golden test options
- `real-topology/golden/cortex-alpha.json` - Regenerated from main

### Documentation
- `documentation/topology-generator-issues.md` - Issue tracker (NEW)
- `documentation/session-status-2026-04-23.md` - This report (NEW)

## Next Steps

1. **Immediate**: Fix TG-001, TG-002, TG-005
2. **This Week**: Standardize function signatures (TG-003)
3. **Next Week**: Add error handling (TG-004), documentation (TG-006)
4. **Following Week**: Type safety (TG-007), forwarding (TG-008)

## Appendix: Agent Review Summary

### tpol-xai Analysis
- Identified 5 potential errors in transformation functions
- Found golden test gaps (forwarding rules, nginx extraGroups)
- Recommended shared validation lib

### tpol-minimax Analysis
- Compared against nix-topology best practices
- Identified inconsistent function signatures
- Recommended standardization and integration testing

### tuvok-deepseek Analysis
- Found WireGuard placeholder key issue (now fixed)
- Identified 10 logical flaws
- Recommended defensive programming approach

---

*Report generated by Janeway R&D Team*
*Agents: tpol-xai, tpol-minimax, tuvok-deepseek*
