# Configuration Reconciliation Goal
**Date**: 2026-05-02
**Machine**: cortex-alpha
**Branch**: jb/ai/overlord-9
**Status**: ACTIVE - RECONCILIATION IN PROGRESS

## Goal

Ensure the current configuration of `cortex-alpha` on branch `jb/ai/overlord-9` **perfectly represents** the stable state last built and deployed on **2026-04-22**.

## Context

### The Problem
Since April 22, the repository has undergone significant changes:
- Multiple AI agents have worked on the codebase (9+ overlord branches)
- Topology-driven refactoring was implemented
- Golden tests were created and modified
- Formatter changes caused disruption (since reverted)
- Several "LLM nightmare" commits introduced instability
- The `nftables`/`extraCommands` incompatibility was introduced (now fixed)

### The Risk
The current branch state may have drifted from the last known-good deployed configuration. We need to verify that what we have now matches what was actually running on cortex-alpha as of April 22, 2026.

## Baseline: The Golden Test

The golden test file `real-topology/golden/cortex-alpha.json` was generated from the **main branch's inline configuration** on April 23. This represents the topology-driven output that must match main's configuration exactly.

### Golden Test Command
```bash
nix run .#check-network -- cortex-alpha
```

### Golden Test Coverage
The golden test captures 32+ configuration options including:
- WireGuard peers (18 peers with correct IPs and keys)
- Nginx proxies (9 virtual hosts)
- DHCP hosts (11 reservations)
- DNS entries (8 static addresses)
- Firewall rules (per-interface rules)
- Tailscale routes (advertised routes)
- Network interfaces (enp2s0 DHCP, enp3s0 static)
- ACME certificates (email and cert list)
- nftables ruleset (DNAT and masquerade rules)

## Reconciliation Checklist

### Phase 1: Verify Golden Test Integrity
- [ ] Run `nix run .#check-network -- cortex-alpha` - must pass
- [ ] Compare `real-topology/golden/cortex-alpha.json` against main branch version
- [ ] Verify no golden test options are missing or have changed values

### Phase 2: Verify Topology Data Accuracy
- [ ] All 18 WireGuard peers in `real-topology/cortex-alpha.nix` match actual network hosts
- [ ] All MAC addresses are valid and match physical devices
- [ ] All IP addresses are correct and within subnet
- [ ] All port forwarding rules match intended WAN→LAN mappings
- [ ] All DNS entries resolve to correct IPs
- [ ] All nginx proxies point to correct backends

### Phase 3: Verify Transformation Functions
- [ ] `lib/topology/mkWireguardPeers.nix` produces correct WireGuard config
- [ ] `lib/topology/mkTailscaleConfig.nix` produces correct Tailscale config
- [ ] `lib/topology/mkDhcpDns.nix` produces correct dnsmasq config
- [ ] `lib/topology/mkNginxProxies.nix` produces correct nginx config
- [ ] `lib/topology/mkForwarding.nix` produces correct nftables ruleset
- [ ] `lib/topology/validate.nix` correctly validates topology data

### Phase 4: Verify Machine Configuration
- [ ] `machines/cortex-alpha/default.nix` has no conflicting overrides
- [ ] WireGuard private key managed correctly via secrix
- [ ] Network interfaces configured correctly (enp2s0, enp3s0)
- [ ] nftables enabled and ruleset generated from topology
- [ ] No duplicate configuration between topology and machine config

### Phase 5: Build and Test
- [ ] `nix build .#nixosConfigurations.cortex-alpha.config.system.build.toplevel` succeeds
- [ ] No assertion failures
- [ ] No evaluation warnings
- [ ] Generated config matches golden test

## Current Known Issues

### Fixed Today (2026-05-02)
1. **MAC address typo**: `linda-wm` had `52:54:00:e9-4a:af` (dash instead of colon)
2. **nftables/extraCommands incompatibility**: `mkForwarding.nix` generated iptables rules but system uses nftables
3. **Duplicate forwarding config**: Machine config had `nftableAttrs` that duplicated topology's `forwarding` section
4. **Validator error messages**: `validate.nix` used `host.name` instead of `host.hostname`

### Still Open (from topology-generator-issues.md)
- TG-003: Inconsistent function signatures
- TG-005: Hardcoded nginx listen addresses
- TG-006: No documentation in transformation functions
- TG-009: Duplicated dedup logic
- TG-010: Top-level evaluation timing
- TG-011: No shared utilities

## Reference Files

### Primary Sources
- `real-topology/cortex-alpha.nix` - Topology data (single source of truth)
- `real-topology/golden/cortex-alpha.json` - Golden test reference
- `machines/cortex-alpha/default.nix` - Machine-specific config

### Transformation Functions
- `lib/topology/mkWireguardPeers.nix` - WireGuard peer generation
- `lib/topology/mkTailscaleConfig.nix` - Tailscale config generation
- `lib/topology/mkDhcpDns.nix` - DHCP/DNS config generation
- `lib/topology/mkNginxProxies.nix` - Nginx proxy generation
- `lib/topology/mkForwarding.nix` - nftables forwarding rules
- `lib/topology/validate.nix` - Topology validation
- `lib/topology/utils.nix` - Shared utilities

### Documentation
- `documentation/session-status-2026-04-22.md` - Last stable session
- `documentation/session-status-2026-04-23.md` - Topology refactoring status
- `documentation/topology-generator-issues.md` - Known issues tracker
- `documentation/topology-schema.md` - Topology data schema
- `AGENTS.md` - Repository architecture and constraints

## Success Criteria

The reconciliation is complete when:

1. ✅ Golden test passes: `nix run .#check-network -- cortex-alpha`
2. ✅ Build succeeds: `nix build .#nixosConfigurations.cortex-alpha.config.system.build.toplevel`
3. ✅ All topology data verified against physical network
4. ✅ No duplicate configuration between topology and machine config
5. ✅ All transformation functions produce correct output
6. ✅ Configuration matches what was deployed on 2026-04-22

## Next Steps

1. Run golden test to verify current state
2. Compare topology data against actual network devices
3. Verify all port forwarding rules are correct
4. Test build and check for any remaining issues
5. Document any intentional changes from April 22 baseline

---

*This document should be updated as reconciliation progresses.*
*When complete, mark all checklist items and update status to RECONCILED.*
