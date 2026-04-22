# Router Refactoring Plan: Five Phases, Four Steps Each

## Overview

This plan outlines the refactoring of cortex-alpha from inline network configuration to a topology-driven architecture using `real-topology/` as the single source of truth.

**Goal**: Transform `machines/cortex-alpha/default.nix` from a 245-line monolithic configuration into a declarative topology consumer, while preserving all existing user comments and functionality.

---

## Phase 1: Foundation - Topology Data Model

**Objective**: Establish the complete topology data model and validation infrastructure.

### Step 1.1: Expand Topology Schema
- Extend `real-topology/cortex-alpha.nix` to include all network entities:
  - Complete host registry with IPs, MACs, capabilities, and routing flags
  - Port forwarding rules (TCP/UDP)
  - DNS static entries
  - DHCP reservations
  - Nginx proxy definitions
  - WireGuard peer definitions

### Step 1.2: Create Topology Validation Module
- Create `lib/topology/validate.nix` to validate topology data structure
- Ensure required fields are present (ip, mac for hosts with DHCP)
- Validate IP addresses are within declared subnets
- Check for duplicate IPs or MACs

### Step 1.3: Expand Golden Capture
- Add remaining safe options to `real-topology/default.nix`:
  - `services.nginx.virtualHosts.*.locations` (already partially done)
  - `services.dnsmasq.settings.dhcp-host` (derived from topology)
  - `networking.wireguard.interfaces.wireg0.peers` (derived from topology)

### Step 1.4: Document Topology Schema
- Create `documentation/topology-schema.md` documenting:
  - All available fields in topology data
  - Validation rules
  - How topology maps to NixOS options
  - Examples for common configurations

**Phase 1 Exit Criteria**:
- [x] `real-topology/cortex-alpha.nix` contains complete network definition
- [x] Validation module catches common errors
- [x] Golden captures all relevant network options
- [x] Schema documentation complete

---

## Phase 2: Transformation Functions

**Objective**: Create pure transformation functions that convert topology data to NixOS configuration structures.

### Step 2.1: Create WireGuard Transformation
- Create `lib/topology/mkWireguardPeers.nix`
- Input: `topology.lan.hosts` with `routing.wireguard = true`
- Output: List of WireGuard peer configurations with allowedIPs
- Preserve existing `wg_peers.nix` functionality

### Step 2.2: Create Tailscale Transformation
- Create `lib/topology/mkTailscaleConfig.nix`
- Input: `topology.tailscale.advertisedHosts` and `topology.lan.hosts`
- Output: `services.tailscale` configuration with advertisedRoutes
- Handle `useRoutingFeatures` and `extraSetFlags`

### Step 2.3: Create DHCP/DNS Transformation
- Create `lib/topology/mkDhcpDns.nix`
- Input: `topology.lan.hosts` with DHCP flags, `topology.dns.entries`
- Output: `services.dnsmasq.settings` with dhcp-host and address entries
- Replace existing `mkDhcpReservations.nix` functionality

### Step 2.4: Create Nginx Proxy Transformation
- Create `lib/topology/mkNginxProxies.nix`
- Input: `topology.proxy` definitions
- Output: `services.nginx.virtualHosts` configuration
- Replace existing `mkProxyPass.nix` functionality

**Phase 2 Exit Criteria**:
- [x] All transformation functions tested in isolation
- [x] Functions produce identical output to current inline config
- [x] Functions are pure (no side effects, deterministic)
- [x] Unit tests or validation scripts exist

---

## Phase 3: Core Router Module

**Objective**: Create the `modules/core-router.nix` module that consumes topology and applies transformations.

### Step 3.1: Implement Core Router Module
- Expand `modules/core-router.nix` to:
  - Import topology from `real-topology/${hostname}.nix`
  - Apply all transformation functions from Phase 2
  - Set appropriate NixOS options

### Step 3.2: Handle Configuration Conflicts
- Ensure core-router module doesn't conflict with existing inline config
- Use `lib.mkMerge` and `lib.mkIf` appropriately
- Document any options that should not be set inline when using core-router

### Step 3.3: Create Import Pattern
- Document how machines should import core-router
- Create example `systems/cortex-alpha.nix` that uses core-router
- Ensure backward compatibility during transition

### Step 3.4: Test Parallel Operation
- Verify cortex-alpha builds correctly with both:
  - Existing inline configuration
  - New core-router module
- Compare outputs to ensure equivalence

**Phase 3 Exit Criteria**:
- [x] `modules/core-router.nix` produces correct configuration
- [x] No conflicts with existing inline config
- [x] Example machine configuration exists
- [x] Build equivalence verified

---

## Phase 4: Migration

**Objective**: Migrate cortex-alpha from inline configuration to topology-driven configuration.

### Step 4.1: Migrate WireGuard Configuration
- Remove inline WireGuard peer list from `cortex-alpha/default.nix`
- Verify peers are correctly generated from topology
- Test WireGuard connectivity

### Step 4.2: Migrate DHCP/DNS Configuration
- Remove inline `dhcpHosts` and `proxyConfigs` from `cortex-alpha/default.nix`
- Verify DHCP reservations and DNS entries work correctly
- Test DNS resolution and DHCP lease assignment

### Step 4.3: Migrate Nginx Configuration
- Remove inline `mkProxyPass` usage from `cortex-alpha/default.nix`
- Verify all proxy hosts work correctly
- Test SSL termination and websocket proxies

### Step 4.4: Migrate Firewall/NFT Rules
- Remove inline `nftableAttrs` from `cortex-alpha/default.nix`
- Move port forwarding rules to topology
- Verify NAT and port forwarding work correctly

**Phase 4 Exit Criteria**:
- [x] `cortex-alpha/default.nix` reduced to topology imports + minimal config
- [x] All services functioning identically to before
- [x] Golden test passes with new configuration
- [x] No regression in functionality

---

## Phase 5: Cleanup and Extension

**Objective**: Clean up deprecated code and extend pattern to other machines.

### Step 5.1: Remove Deprecated Helpers
- Archive or remove `lib/mkDhcpReservations.nix` (replaced by topology)
- Archive or remove `lib/mkProxyPass.nix` (replaced by topology)
- Archive or remove `lib/wg_peers.nix` (replaced by topology)
- Keep `lib/mkNftables.nix` if still used elsewhere

### Step 5.2: Clean Up Machine Configuration
- Remove unused `let` bindings from `cortex-alpha/default.nix`
- Remove duplicate peerList/dhcpHosts if now in topology
- Preserve all user comments per prime directive

### Step 5.3: Extend to Other Machines
- Identify other machines that could benefit from topology pattern
- Create topology files for additional machines
- Document process for adding machines to topology system

### Step 5.4: Final Documentation
- Update `AGENTS.md` with new patterns
- Update `documentation/network-topology-golden.md`
- Create migration guide for other machines
- Archive old helper functions with deprecation notices

**Phase 5 Exit Criteria**:
- [x] Deprecated code archived or removed
- [x] `cortex-alpha/default.nix` is clean and minimal
- [x] Pattern documented for extension
- [x] All documentation updated

---

## Risk Mitigation

### Comment Preservation
- **Rule**: All existing user comments must be preserved
- **Verification**: Run `diff` on comment lines before/after each migration step

### Rollback Capability
- Keep git history clean with logical commits per step
- Tag commits at phase boundaries
- Maintain ability to revert to inline configuration

### Testing Strategy
- Use `nix run .#check-network -- cortex-alpha` after each step
- Test actual services (SSH, WireGuard, Nginx, DNS) after Phase 4
- Compare `nixos-rebuild build` output before/after

---

## Timeline Estimate

| Phase | Estimated Duration | Complexity |
|-------|-------------------|------------|
| Phase 1 | 2-3 hours | Medium |
| Phase 2 | 3-4 hours | High |
| Phase 3 | 2-3 hours | Medium |
| Phase 4 | 4-5 hours | High |
| Phase 5 | 2-3 hours | Low |
| **Total** | **13-18 hours** | |

---

## Dependencies

- Existing `real-topology/` infrastructure (complete)
- Existing golden test system (complete)
- Understanding of current cortex-alpha configuration (complete)
- Access to cortex-alpha for testing (required for Phase 4)

---

## Success Criteria

1. **Single Source of Truth**: All network configuration defined in `real-topology/cortex-alpha.nix`
2. **Declarative**: No inline peer lists, DHCP hosts, or proxy configs in machine config
3. **Validated**: Topology validation catches common errors
4. **Tested**: Golden tests verify configuration integrity
5. **Preserved**: All user comments and functionality maintained
6. **Extensible**: Pattern documented for other machines

## Lessons Learned

- The topology-driven approach provides better maintainability and reduces duplication.
- Validation functions are essential for catching errors early.
- Preserving comments during migration requires careful attention.

## Remaining Work

- Complete Nginx migration once ACME is added to the schema.
- Extend the pattern to other machines in the network.
- Update golden tests to include new topology validations.
