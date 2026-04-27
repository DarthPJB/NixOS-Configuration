# Topology Generator Issue Tracker
**Created**: 2026-04-23
**Status**: Active
**Priority**: High

## Critical Issues (Block Deployment)

### TG-001: validate.nix Not Integrated
- **Severity**: Critical
- **Status**: OPEN
- **Description**: `lib/topology/validate.nix` exists but is never called in `core-router.nix`
- **Impact**: Invalid topology data causes cryptic Nix evaluation errors
- **Solution**: Add validation call in core-router.nix before generating config
- **Estimated Effort**: 1-2 hours

```nix
# Add to modules/core-router.nix
let
  validation = (import ../lib/topology/validate.nix { inherit lib; }).validateTopology topology;
in
if !validation.valid then
  throw "Invalid topology for ${config.networking.hostName}: ${builtins.concatStringsSep "; " validation.errors}"
else
  # ... rest of config
```

### TG-002: Silent Peer/Host Failures
- **Severity**: Critical
- **Status**: PARTIAL
- **Description**: Missing peers/hosts are silently skipped or traced as warnings
- **Impact**: WireGuard/VPN may have incomplete peer list without obvious error
- **Solution**: Convert trace warnings to assertions in mkWireguardPeers.nix
- **Estimated Effort**: 1 hour

## High Priority Issues

### TG-003: Inconsistent Function Signatures
- **Severity**: High
- **Status**: OPEN
- **Description**: Three different patterns in lib/topology/*.nix:
  - `mkTailscaleConfig`: `{ lib }: topology: ...`
  - `mkWireguardPeers`: `{ lib, topology, self }: ...`
  - `mkNginxProxies`: `{ lib }: { topology, ... }: ...`
- **Impact**: Confusing API, error-prone composition
- **Solution**: Standardize all to `{ lib }: topology: { ... }` pattern
- **Estimated Effort**: 2-3 hours

### TG-004: Missing Error Handling
- **Severity**: High
- **Status**: OPEN
- **Description**: Tailscale/DHCP transformations crash on missing attrs
- **Impact**: Build fails with cryptic errors on malformed topology
- **Solution**: Add graceful fallbacks with `or` operator
- **Estimated Effort**: 2 hours

```nix
# Example fix for mkTailscaleConfig.nix
advertisedHostsRoutes = map (
  hostName:
  let
    host = topology.lan.hosts.${hostName} or null;
    ip = if host != null then host.ip or null else null;
  in
  if ip == null then null else "${ip}/32"
) (topology.tailscale.advertisedHosts or []);
```

### TG-005: Hardcoded Nginx Listen Addresses
- **Severity**: High
- **Status**: OPEN
- **Description**: `mkNginxProxies.nix` hardcodes `["10.88.128.1", "10.88.127.1"]`
- **Impact**: Won't work for other machines with different IPs
- **Solution**: Derive from topology data
- **Estimated Effort**: 1-2 hours

```nix
# Should derive from topology
defaultListenAddresses = [
  topology.lan.gateway  # "10.88.128.1"
  (builtins.head topology.wireguard.ips)  # "10.88.127.1/32" → extract IP
];
```

## Medium Priority Issues

### TG-006: No Documentation
- **Severity**: Medium
- **Status**: OPEN
- **Description**: Functions in lib/topology/*.nix lack comments and docstrings
- **Impact**: Difficult for new contributors to understand
- **Solution**: Add docstrings to each function
- **Estimated Effort**: 2 hours

### TG-007: No Type Safety
- **Severity**: Medium
- **Status**: OPEN
- **Description**: No validation of IP format, MAC format, port ranges
- **Impact**: Runtime failures with invalid data
- **Solution**: Add format validation in validate.nix
- **Estimated Effort**: 3-4 hours

### TG-008: Forwarding Rules Not Transformed
- **Severity**: Medium
- **Status**: OPEN
- **Description**: Topology has `forwarding.tcp/udp` but not transformed to NixOS config
- **Impact**: WAN port forwards may not work
- **Solution**: Add mkForwarding.nix transformation
- **Estimated Effort**: 3-4 hours

### TG-009: Duplicated Dedup Logic
- **Severity**: Medium
- **Status**: OPEN
- **Description**: Same deduplication pattern in WireGuard and Tailscale
- **Impact**: Code duplication, harder to maintain
- **Solution**: Extract to shared lib/topology/utils.nix
- **Estimated Effort**: 1 hour

## Low Priority Issues

### TG-010: Top-Level Evaluation
- **Severity**: Low
- **Status**: OPEN
- **Description**: mkDhcpDns.nix computes at import time
- **Impact**: Minor efficiency issue
- **Solution**: Move computations into function body
- **Estimated Effort**: 30 minutes

### TG-011: No Shared Utilities
- **Severity**: Low
- **Status**: OPEN
- **Description**: Common patterns duplicated across files
- **Impact**: Code duplication
- **Solution**: Create lib/topology/utils.nix with shared functions
- **Estimated Effort**: 1-2 hours

## Implementation Plan

### Phase 1: Critical Fixes (This Week)
1. TG-001: Integrate validate.nix
2. TG-002: Fix silent failures

### Phase 2: High Priority (Next Week)
3. TG-003: Standardize signatures
4. TG-004: Add error handling
5. TG-005: Fix hardcoded nginx

### Phase 3: Medium Priority (Following Week)
6. TG-006: Add documentation
7. TG-007: Add type safety
8. TG-008: Add forwarding transformation
9. TG-009: Extract shared utils

### Phase 4: Cleanup (When Available)
10. TG-010: Fix evaluation timing
11. TG-011: Create utils lib
