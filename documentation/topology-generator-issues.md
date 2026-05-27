# Topology Generator Issue Tracker
**Created**: 2026-04-23
**Last Updated**: 2026-05-06
**Status**: Active
**Priority**: High

## Just Resolved (2026-05-27)

### TG-014: Syntax Errors in mkWireguardSettings Consumers — RESOLVED
- **Severity**: Critical
- **Status**: RESOLVED
- **Description**: Two `inherit` statements used `machines= filteredMachines` (invalid Nix syntax) instead of `machines = filteredMachines`.
- **Files fixed**: `lib/topology/mkNginxSettings.nix:79`, `lib/topology/mkDnsSettings.nix:27`

### TG-015: Missing hubName/hubIps in mkWireguardSettings — RESOLVED
- **Severity**: Critical
- **Status**: RESOLVED
- **Description**: `genWireguard.nix` and `core-router-topology.nix` referenced `settings.hubName` and `machineSettings.hubIps` which were not produced by `mkWireguardSettings.nix`. Fixed by adding per-machine `isHub` and `hubIps` to the transformer, and updating consumers to use per-machine fields.
- **Files fixed**: `lib/topology/mkWireguardSettings.nix`, `lib/topology/genWireguard.nix`, `modules/core-router-topology.nix`

### TG-016: Documentation Misrepresented WIP Status — RESOLVED
- **Severity**: Medium
- **Status**: RESOLVED
- **Description**: AGENTS.md presented the new two-layer architecture as active/current and the production per-machine architecture as "legacy/being phased out". Corrected to accurately reflect: production architecture uses per-machine files, new architecture is WIP and not yet used by any machine.
- **Files fixed**: `AGENTS.md`, `documentation/topology-migration-guide.md`, `documentation/core-router-usage.md`

## Resolved Issues

### TG-001: validate.nix Not Integrated — RESOLVED (2026-05-06)
- **Severity**: Critical
- **Status**: RESOLVED
- **Resolution**: `core-router.nix` now imports `validate.nix` and runs `validateTopology` at module evaluation time. An assertion blocks deployment if validation fails.
- **Location**: `modules/core-router.nix` lines 15-16, 36-40

### TG-002: Silent Peer/Host Failures — RESOLVED (2026-05-06)
- **Severity**: Critical
- **Status**: RESOLVED
- **Resolution**: `mkWireguardPeers.nix` now uses `throw` for three failure modes: missing host in `lan.hosts`, missing IP address, and missing public key file. Error messages include the peer name and valid host list.
- **Location**: `lib/topology/mkWireguardPeers.nix` lines 43-49

### TG-009: Duplicated Dedup Logic — RESOLVED (2026-05-06)
- **Severity**: Medium
- **Status**: RESOLVED
- **Resolution**: Shared `dedupPreserveOrder` function extracted to `lib/topology/utils.nix`. Used by both `mkWireguardPeers.nix` and `mkTailscaleConfig.nix`.
- **Location**: `lib/topology/utils.nix` lines 9-25

### TG-011: No Shared Utilities — RESOLVED (2026-05-06)
- **Severity**: Low
- **Status**: RESOLVED
- **Resolution**: `lib/topology/utils.nix` created with shared functions: `dedupPreserveOrder`, `safeLookup`, `isIP`, `isCIDR`, `isIPv4`, `isMAC`, `isPort`, `normalizePath`.
- **Location**: `lib/topology/utils.nix`

## Resolved via Dead Code Removal (2026-05-06)

### TG-008: Forwarding Rules Not Transformed — RESOLVED
- **Severity**: Medium
- **Status**: RESOLVED
- **Resolution**: `lib/topology/mkForwarding.nix` generates nftables DNAT rules and masquerade from `topology.forwarding.tcp/udp`. Integrated in `core-router.nix` lines 86-90.

### TG-010: Top-Level Evaluation — RESOLVED
- **Severity**: Low
- **Status**: RESOLVED
- **Resolution**: `mkDhcpDns.nix` computations are inside function body, evaluated only when `mkDhcpDns.nix` is imported and applied.

## Active Issues

### TG-003: Inconsistent Function Signatures
- **Severity**: High
- **Status**: OPEN
- **Description**: Three calling conventions in lib/topology/*.nix:
  - `mkWireguardPeers`: `{ lib }: topology: self:` (needs `self` for key file paths)
  - `mkTailscaleConfig`: `{ lib }: topology:` (curried)
  - `mkNginxProxies`: `{ lib }: topology:` (curried, returns `rec` set)
- **Impact**: Confusing API, error-prone composition. The `self` dependency couples WireGuard peer generation to the flake structure.
- **Proposed Solution**: Standardize to `{ lib }: topology: { ... }` by passing keys as an argument rather than reading files. See discussion notes.
- **Estimated Effort**: 2-3 hours

### TG-004: Missing Error Handling in Tailscale/DHCP
- **Severity**: High
- **Status**: PARTIAL
- **Description**: `mkTailscaleConfig.nix` uses `or { }` / `or null` for graceful fallback. `mkDhcpDns.nix` uses `safeLookup`. But `mkForwarding.nix` has no fallback for missing `topology.forwarding`.
- **Impact**: Build fails with cryptic errors if forwarding section is missing.
- **Proposed Solution**: Add `or` defaults to `mkForwarding.nix` for missing sections.
- **Estimated Effort**: 30 minutes

### TG-005: Hardcoded Nginx Listen Addresses
- **Severity**: High
- **Status**: PARTIAL
- **Description**: `mkNginxProxies.nix` fallback references `topology.hosts.cortex-alpha.ip` which doesn't exist (hosts are under `topology.lan.hosts`). Currently masked because cortex-alpha's topology defines `topology.nginx.listenAddresses` explicitly.
- **Impact**: Would crash for any machine relying on the fallback path.
- **Proposed Solution**: Change fallback to `topology.lan.hosts.${config.networking.hostName}.ip` or require `listenAddresses` in topology schema.
- **Estimated Effort**: 1 hour

### TG-006: Incomplete Documentation
- **Severity**: Medium
- **Status**: OPEN
- **Description**: Transformation functions have docstrings (good) but `lib/topology/utils.nix` and `lib/topology/validate.nix` lack usage examples. The topology-schema.md references deprecated files.
- **Impact**: New contributors may reference stale docs.
- **Proposed Solution**: Update topology-schema.md to remove deprecated file references. Add usage examples to utils.nix and validate.nix.
- **Estimated Effort**: 1-2 hours

### TG-007: Validation Gaps
- **Severity**: Medium
- **Status**: OPEN
- **Description**: `validate.nix` checks structural validity (format, duplicates) but not cross-section consistency:
  - Forwarding rules targeting IPs not in `lan.hosts`
  - Nginx proxy backends pointing to unreachable IPs
  - DNS static entries pointing to unassigned IPs
- **Impact**: Structural validation passes but runtime config references non-existent hosts.
- **Proposed Solution**: Add cross-section validation rules to `validate.nix`.
- **Estimated Effort**: 2-3 hours

### TG-012: Golden Test Scope — INTENTIONAL BY DESIGN
- **Severity**: N/A — This is not an issue
- **Status**: CLOSED (not a defect)
- **Rationale**: The golden test intentionally captures the FULL deterministic output of nix evaluation — not just network-relevant sections. This is by design:
  - Golden tests represent the best possible working state
  - All failures are errors (no silent failure)
  - The golden captures exactly what nix evaluates — no abstraction, no subset
  - This ensures structural changes cannot have unintended side effects
  - Intended side effects require manual golden update by the user
- **Decision**: Golden scope is intentionally broad. Coverage grows over time as machines are added.

### TG-013: lib/topology/default.nix Dead Code
- **Severity**: Low
- **Status**: RESOLVED (removed 2026-05-06)
- **Resolution**: Placeholder functions removed. Individual mk*.nix files are imported directly by core-router.nix.

## Implementation Plan

### Completed
1. ~~TG-001: Integrate validate.nix~~ ✓
2. ~~TG-002: Fix silent failures~~ ✓
3. ~~TG-008: Add forwarding transformation~~ ✓
4. ~~TG-009: Extract shared utils~~ ✓
5. ~~TG-010: Fix evaluation timing~~ ✓
6. ~~TG-011: Create utils lib~~ ✓
7. ~~TG-013: Remove dead code~~ ✓

### Next: High Priority
8. TG-003: Standardize function signatures (discuss approach)
9. TG-004: Add error handling to mkForwarding.nix
10. TG-005: Fix hardcoded nginx listen addresses

### Following: Medium Priority
11. TG-006: Update documentation
12. TG-007: Add cross-section validation
