# NixOS Topology-Driven Configuration Expansion Plan

**Document Status**: Planning Phase  
**Created**: 2026-05-06  
**Scope**: Multi-phase rollout of topology-driven configuration across ~15 machines  
**Repository**: `/speed-storage/repo/DarthPJB/NixOS-Configuration`

---

## Executive Summary

This document outlines a five-phase plan to achieve complete topology-driven configuration coverage across the NixOS fleet, moving from `cortex-alpha` (the proof-of-concept hub machine) to all x86_64 and ARM machines. The architecture separates **topology data** (network reality) from **transformation functions** (Nix logic) from **core modules** (NixOS configuration), enabling regression testing via golden files and reducing configuration drift.

**Current State**: Only `cortex-alpha` has full topology coverage with golden test. 18 x86_64 machines and 5 ARM machines use inline configuration.

**Target State**: All machines with topology files and per-machine golden tests; robust validation; consistent function signatures; complete documentation.

---

## Section 1: Architecture Standard — Two-Layer Topology Pattern (AUTHORITATIVE)

This section defines THE CANONICAL ARCHITECTURE for all topology-driven configuration in this repository. All subsequent phases conform to this standard. This supersedes previous design discussions and becomes the operational specification.

### 1.1 The Two-Layer Architecture Pattern

The topology system follows a mandatory two-layer architecture:

```
topology.nix data → Layer 1: Transformer → Pure Data → Layer 2: Generator → NixOS config
                    (mk*Settings)      (flat)        (gen*)
```

**Key Principle**: Hub vs client is NOT separate modules. The SAME generator, given the same data but different hostnames, produces the correct config for each role. The topology data knows who the hub is; the generator looks up the hostname and acts accordingly.

### 1.2 Layer 1: Transformer (`mk*Settings`)

**Responsibility**: I/O and validation

**Pattern Signature**:
```nix
{ lib }: topology: {
  # Pure data output (flat structure with minimal nesting)
  setting1 = value;
  setting2 = value;
  peers = { name = { ... }; };  # attrset keyed by hostname
  warnings = [ "..." ];
}
```

**Behavior**:
- Reads topology data AND required files (WireGuard public keys, certificates, etc.)
- Performs cross-section validation (forwarding targets exist, nginx backends reachable, etc.)
- Returns a FLAT pure data structure (see Section 1.4 for rules)
- Handles missing files gracefully: warning + skip, not hard error
- **OWNS ALL I/O** — files are never read by generators

**Example: `mkWireguardSettings`**
```nix
# Input: topology attrset from real-topology/<hostname>.nix
# Output: flat data structure with resolved keys

mkWireguardSettings topology = {
  interface = "wireg0";
  listenPort = 2108;
  hubName = "cortex-alpha";
  
  # Hub-only config (populated if this machine IS the hub)
  hub = {
    ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
  };
  
  # This machine's WireGuard IP (determined by hostname lookup in topology)
  machineIp = "10.88.127.108/32";
  
  # All peers with RESOLVED public keys (file reading happens here)
  peers = {
    "cortex-alpha" = { 
      publicKey = "abc123...";  # Read from file
      ip = "10.88.127.1"; 
      isHub = true; 
    };
    "alpha-one" = { 
      publicKey = "def456...";  # Read from file
      ip = "10.88.127.108"; 
      isHub = false; 
    };
    # All peers with keys resolved
  };
  
  # Missing keys tracked as warnings (not errors)
  warnings = [ "Missing public key for peer 'alpha-two' at secrets/..." ];
}
```

### 1.3 Layer 2: Generator (`gen*`)

**Responsibility**: Pure transformation

**Pattern Signature**:
```nix
{ lib }: { settings, hostname }: {
  # NixOS module config
}
```

**Behavior**:
- Pure function: takes transformer output + hostname
- Produces NixOS module config for THAT specific machine
- Works for both hub AND client — distinction is emergent from data
- No file I/O, no `self` reference, no side effects
- Can be tested in isolation with mock data

**Example: `genWireguard`**

For the hub (cortex-alpha):
```nix
genWireguard { settings, hostname = "cortex-alpha" } = {
  networking.wireguard.interfaces.wireg0 = {
    ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
    listenPort = 2108;
    privateKeyFile = <secrix path>;
    peers = [
      { publicKey = "def456..."; allowedIPs = [ "10.88.127.108/32" ]; }
      # All non-hub peers
    ];
  };
}
```

For a client (alpha-one):
```nix
genWireguard { settings, hostname = "alpha-one" } = {
  networking.wireguard.interfaces.wireg0 = {
    ips = [ "10.88.127.108/32" ];
    privateKeyFile = <secrix path>;
    peers = [
      { 
        publicKey = "abc123..."; 
        allowedIPs = [ "10.88.127.0/24" ];
        endpoint = "cortex-alpha.johnbargman.net:2108";
        persistentKeepalive = 25;
      }
    ];
  };
}
```

**The Generator Decision Logic**:
```nix
# genWireguard checks: are we the hub?
if hostname == settings.hubName then
  # Generate hub config: listen on all IPs, include all peers
  generateHubConfig settings
else
  # Generate client config: connect to hub, include only hub as peer
  generateClientConfig settings hostname
```

### 1.4 Data Structure Standard: Flat With Minimal Nesting

The transformer output MUST be predominantly flat. Nesting is allowed ONLY when:
1. A group of attributes forms a logical unit (e.g., `hub = { name, ips, endpoint }`)
2. The number of attributes in the group is 3+ (otherwise flatten)
3. The group is referenced as a unit by the generator

**Flatness Rules**:
- Top-level keys should be simple strings: `interface`, `listenPort`, `machineIp`
- Peer data is an attrset keyed by hostname (flat lookup structure)
- Warnings/errors are flat lists
- Avoid deep nesting (>2 levels) — it makes generators complex
- Avoid single-attribute nesting (don't wrap one value in an attrset)

**Example Structure**:
```nix
{
  # Simple scalar values (flat)
  interface = "wireg0";
  listenPort = 2108;
  hubName = "cortex-alpha";
  machineIp = "10.88.127.108/32";
  
  # Logical unit (acceptable nesting - 3+ attributes)
  hub = {
    ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
    endpoint = "cortex-alpha.johnbargman.net";
    port = 2108;
  };
  
  # Attrset keyed by hostname (flat lookup)
  peers = {
    "cortex-alpha" = { publicKey = "..."; ip = "10.88.127.1"; isHub = true; };
    "alpha-one" = { publicKey = "..."; ip = "10.88.127.108"; isHub = false; };
  };
  
  # Flat lists
  warnings = [];
  missingKeys = ["alpha-two"];
}
```

### 1.5 Graceful Degradation

The system must handle missing data without cryptic errors:

| Condition | Behavior |
|---|---|
| Topology file missing for a machine | `coreRouter.enable = false;` + warning in build output |
| Key file missing for a peer | Peer skipped in config + warning, other peers still configured |
| Forwarding target IP not in hosts | **Assertion error** with clear message |
| Nginx backend unreachable | **Assertion error** with clear message |
| Cross-service validation fails | **Assertion error** listing ALL failures |

**Principle**: 
- **Warnings** for optional/missing data (graceful skip)
- **Assertions** for broken invariants (deployment fails with clear message)

### 1.6 Cross-Service Validation (CRITICAL PATTERN)

The topology system MUST enforce consistency across services. When a service connection is declared, ALL required infrastructure is validated.

**Example: Nginx Proxy from cortex-alpha to local-nas**

The topology declares:
```nix
nginx.proxies = {
  "code.johnbargman.net" = {
    backend = "http://10.88.127.3:80";  # local-nas
  };
};
```

The system MUST validate:
1. `10.88.127.3` exists in `lan.hosts` (IP is assigned to a known machine)
2. Port 80 is allowed on the firewall interface between cortex-alpha and local-nas
3. If WireGuard is the transport, both peers have WireGuard enabled
4. If the backend is on a client, the client's topology acknowledges the service

**Validation Rules by Service Connection**:

| Service Connection | Required Validation |
|---|---|
| **Nginx proxy → backend IP** | IP exists in hosts; port allowed on firewall; transport (WG/Tailscale/LAN) enabled on both sides |
| **Port forwarding → target IP** | IP exists in hosts; target port matches service declaration; firewall allows |
| **DNS static entry → IP** | IP exists in hosts; service running (if declared) |
| **WireGuard peer → host** | Host exists; has WireGuard IP; public key file exists |
| **Tailscale route → subnet** | Subnet matches declared LAN/WAN subnets; advertising machine is connected |

If validation fails: **assertion error with clear message**, not a cryptic Nix evaluation failure.

**Assertion Message Example**:
```
Topology validation failed:
  - Nginx proxy 'code.johnbargman.net' targets IP 10.88.127.99 (not found in lan.hosts)
  - Nginx proxy 'code.johnbargman.net' backend port 80 not allowed between cortex-alpha and unknown-host
  - WireGuard peer 'beta-one' not found in lan.hosts
```

### 1.7 Golden Test Integration

Every machine that uses topology-driven config MUST have a golden test:

1. Create topology file for machine
2. Transformer produces settings
3. Generator produces NixOS config
4. Capture full config as golden JSON (network-relevant sections only)
5. Any future change that alters the config breaks the golden test
6. Intentional changes require regenerating the golden file

**Golden Test Lifecycle**:
```bash
# Initial creation
nix run .#check-network -- cortex-alpha > golden/cortex-alpha.json

# During CI/CD
nix run .#check-network -- cortex-alpha --compare
# Fails if current output != golden file

# After intentional change
nix run .#check-network -- cortex-alpha > golden/cortex-alpha.json
git add golden/cortex-alpha.json
git commit -m "topology: update golden for cortex-alpha due to firewall rule change"
```

**Coverage Requirement**:
- `nix flake check` MUST include a topology completeness test
- For every machine in `nixosConfigurations`, a topology file must exist OR have documented exemption
- Coverage percentage reported in CI output
- Missing topology = build warning (Phase 1), build failure (Phase 2+)

### 1.8 The Generative Principle

Given a hostname, the system can derive everything:

| Derived From Hostname | Convention | Example |
|---|---|---|
| Topology file | `real-topology/${hostname}.nix` | `real-topology/cortex-alpha.nix` |
| WireGuard public key | `secrets/public_keys/wireguard/wg_${hostname}_pub` | `secrets/public_keys/wireguard/wg_cortex-alpha_pub` |
| WireGuard private key | `secrets/private_keys/wireguard/wg_${hostname}` (via secrix) | `secrets/private_keys/wireguard/wg_cortex-alpha` |
| SSH host public key | `secrets/public_keys/host_keys/${hostname}.pub` | `secrets/public_keys/host_keys/cortex-alpha.pub` |
| NixOS configuration | `nixosConfigurations.${hostname}` | `nixosConfigurations.cortex-alpha` |

**Adding a new machine `alpha-four` requires**:
1. Topology file with its network position: `real-topology/alpha-four.nix`
2. Key files at the conventional paths
3. NixOS configuration in `machines/alpha-four/`
4. Entry in `flake.nix` using `mkX86_64 "alpha-four"`

The system validates all requirements exist. Missing any = clear error message.

---

## Section 2: Phase Overview & Timeline

### Phase Dependencies

```
Phase 1: Implement Two-Layer Architecture (Transformer + Generator pattern)
    ↓
Phase 2: Golden Coverage (x86_64)
    ↓
Phase 3: Coverage Validation
    ↓
Phase 4: Unified Client Generators
    ↓
Phase 5: Cross-Section Validation
```

### Phase Summary Table

| Phase | Objective | Duration | Exit Criteria | Risk |
|-------|-----------|----------|---------------|------|
| **Phase 1** | Implement two-layer architecture; standardize mk*.nix signatures | 2-3 weeks | Transformers follow `{ lib }: topology: { }` pattern (inputs); Generators follow `{ lib }: { settings, hostname }: { }` pattern (outputs); core-router.nix refactored; cortex-alpha golden test passes | **High**: Breaking changes to existing API |
| **Phase 2** | Golden test for all x86_64 machines | 3-4 weeks | 18 topology files + 18 golden files; visual audit complete; no golden regressions; cross-service validation catches errors | **Medium**: Large number of manual topology datapoints |
| **Phase 3** | Meta-test: topology completeness | 1-2 weeks | `nix flake check` integration; per-machine coverage report; CI/CD pipeline integration | **Low**: New test infra, no behavioral changes |
| **Phase 4** | Unified client generators (hub and client from same data) | 3-4 weeks | Generators work for both hub and client; hardcoded cortex-alpha reference removed from client config; 5 client machines tested | **High**: Requires unified generator pattern validation |
| **Phase 5** | Cross-service validation enforcement | 2-3 weeks | Assertions catch invalid references; forwarding/nginx/dns refs validated; comprehensive test suite | **Medium**: Complex validation logic |

**Total Estimated Effort**: 11-15 weeks. Can run phases 2 & 3 in parallel.

---

## Section 3: Phase 1 — Implement Two-Layer Architecture

### Objective

Refactor all transformation functions to implement the two-layer architecture defined in Section 1. This is the **foundational phase** — all subsequent work depends on this pattern.

### Key Changes

1. **Separate Transformer from Generator**
   - Current: `mkWireguardPeers` does both transformation and generation
   - New: `mkWireguardSettings` (transformer) + `genWireguard` (generator)

2. **Transformer Layer: `mk*Settings` Functions**
   - Input: `{ lib }: topology: { ... }`
   - Output: Flat pure data structure with all files read
   - Owns ALL I/O (file reading, network checks, etc.)
   - Performs cross-section validation

   Example signature:
   ```nix
   { lib }: topology: {
     interface = "wireg0";
     listenPort = 2108;
     hubName = "cortex-alpha";
     peers = { ... };
     warnings = [ ... ];
   }
   ```

3. **Generator Layer: `gen*` Functions**
   - Input: `{ lib }: { settings, hostname }: { ... }`
   - Output: NixOS configuration for the specific hostname
   - Pure function: no file I/O, no side effects
   - Works for both hub and client (distinction is emergent from data)

   Example signature:
   ```nix
   { lib }: { settings, hostname }: {
     networking.wireguard.interfaces.wireg0 = { ... };
   }
   ```

### Implementation Steps

1. **Refactor existing mk*.nix files into transformer + generator pairs**
   
   For each existing function:
   ```nix
   # OLD: lib/topology/mkWireguardPeers.nix (does everything)
   { lib }: topology: self: { ... }
   
   # NEW: lib/topology/mkWireguardSettings.nix (transformer)
   { lib }: topology: { 
     peers = { ... };  # with publicKey read from file
     warnings = [ ... ];
   }
   
   # NEW: lib/topology/genWireguard.nix (generator)
   { lib }: { settings, hostname }: {
     networking.wireguard.interfaces = { ... };
   }
   ```

2. **Create `lib/topology/default.nix` as canonical entry point**
   
   ```nix
   { lib, self, topology }:
   {
     # Transformers (run once per flake eval, read files)
     settings.wireguard = (import ./mkWireguardSettings.nix) { inherit lib; } topology;
     settings.tailscale = (import ./mkTailscaleSettings.nix) { inherit lib; } topology;
     settings.dhcpDns = (import ./mkDhcpDnsSettings.nix) { inherit lib; } topology;
     settings.nginx = (import ./mkNginxSettings.nix) { inherit lib; } topology;
     settings.forwarding = (import ./mkForwardingSettings.nix) { inherit lib; } topology;
     
     # Generators (pure, per-machine config)
     generators = {
       wireguard = (import ./genWireguard.nix) { inherit lib; };
       tailscale = (import ./genTailscale.nix) { inherit lib; };
       dhcpDns = (import ./genDhcpDns.nix) { inherit lib; };
       nginx = (import ./genNginx.nix) { inherit lib; };
       forwarding = (import ./genForwarding.nix) { inherit lib; };
     };
     
     # Validation
     validate = (import ./validate.nix) { inherit lib; };
     utils = import ./utils.nix { inherit lib; };
   }
   ```

3. **Update `core-router.nix` to use the new structure**
   
   ```nix
   { config, lib, pkgs, self, ... }:
   let
     topology = import ../real-topology/${config.networking.hostName}.nix { inherit lib; };
     topologyLib = import ../lib/topology { inherit lib self topology; };
     hostname = config.networking.hostName;
   in
   {
     config = lib.mkIf config.coreRouter.enable {
       # Validation
       assertions = [
         { assertion = topologyLib.validate.validateTopology topologyLib.settings.wireguard.valid; }
       ];
       
       # Generate config for this hostname using settings
       networking.wireguard.interfaces.wireg0 = lib.mkOverride 100
         (topologyLib.generators.wireguard { inherit (topologyLib) settings; inherit hostname; });
     };
   }
   ```

4. **Update modules to use topology-driven config**
   - `modules/core-router.nix`: import from `lib/topology`
   - `modules/enable-wg-topology.nix`: new client module (Phase 4)

5. **Verify golden test still passes**
   ```bash
   nix run .#check-network -- cortex-alpha --compare
   ```

### Graceful Degradation Implementation

During Phase 1:
- Missing key files: logged as warning, peer skipped
- Invalid topology: logged as warning, that section disabled
- Only hard assertions: cross-reference validation (Phase 5)

### Exit Criteria for Phase 1

- [ ] All mk*.nix refactored into transformer + generator pairs
- [ ] `lib/topology/default.nix` is the canonical entry point
- [ ] `core-router.nix` uses new architecture
- [ ] All generators work for both hub and client (logic proves this)
- [ ] Cortex-alpha golden test still passes
- [ ] Documentation updated: AGENTS.md with new function signatures
- [ ] All changes committed with clear messages about architecture change

---

## Section 4: Phase 2 — Golden Coverage for All x86_64 Machines

### Scope: x86_64 Machines Only

**Why x86_64 First?**
- Simpler to test (can build locally)
- No cross-compilation overhead
- All critical machines are x86_64 (routers, NAS, builders)

**ARM machines defer to Phase 5** (minimal config or simpler topology).

### Machine Classification

Based on `/speed-storage/repo/DarthPJB/NixOS-Configuration/machines/`:

| Hostname | Category | Topology Candidacy | Reasoning |
|----------|----------|-------------------|-----------|
| **cortex-alpha** | Hub/Router | ✅ Yes (Done) | Core router, full network scope, needs all generators |
| **local-nas** | Storage | ✅ Yes | Simple NAS, likely single subnet membership, needs DHCP reservation |
| **storage-array** | Storage | ✅ Yes | Storage server, may need port forwarding, Tailscale routing |
| **terminal-zero** | Builder | ✅ Yes | Central builder, likely Tailscale/WireGuard client, needs DNS |
| **terminal-nx-01** | Workstation | ✅ Yes | NVIDIA gaming, WireGuard client, may have special firewall rules |
| **alpha-one** | Gaming Host | ✅ Yes | Gaming, Tailscale/WireGuard capable, may need port forwarding |
| **alpha-two** | Gaming Host | ✅ Yes | Gaming, similar to alpha-one |
| **alpha-three** | Gaming Host | ✅ Yes | Gaming + zeroclaw service (3D printer), needs service-specific config |
| **LINDA** | Remote Gaming | ✅ Yes | Remote build node, WireGuard/Tailscale, remote access service |
| **gaming-host-1** | Gaming | ✅ Yes | Gaming host, client networking |
| **remote-worker** | Web Server | ✅ Yes | **High Priority**: Nginx service, port forwarding, SSL, complex network footprint |
| **remote-builder** | Builder | ✅ Yes | Remote build machine, WireGuard/Tailscale access |
| **local-worker** | Workstation | ✅ Candidate | Check inline config; may not need topology (desktop machine) |
| **obs-box** | Media | ✅ Candidate | Check inline config; streaming/OBS setup, may need firewall |

### Rollout Strategy

**Tier 1 (Weeks 1-2)**: Simple clients, no hub complexity
- `local-nas` — Simple storage client
- `storage-array` — Storage client
- Objective: Establish pattern for client topology files

**Tier 2 (Weeks 2-3)**: Clients with special services
- `terminal-zero` — Builder with DNS/Tailscale
- `gaming-host-1`, `alpha-one`, `alpha-two` — Gaming clients with firewall rules
- Objective: Expand pattern to handle service-specific configs

**Tier 3 (Weeks 3-4)**: Complex clients & services
- `remote-worker` — Web server with Nginx (largest, most complex)
- `LINDA` — Remote gaming/builder node
- `alpha-three` — Special service (zeroclaw)
- Objective: Full service coverage

**Tier 4 (Week 4)**: Remaining/optional
- `terminal-nx-01`, `local-worker`, `obs-box` — Quick wins or defer if inline config is minimal

### Topology Data Structure for Clients

Clients differ from hub (cortex-alpha) in what they declare:

#### Client Machine Topology (Minimal Example)

```nix
{ ... }:
{
  # Clients still declare their position in the network
  # but don't manage the entire topology
  
  domain = "johnbargman.net";
  
  # Self-declaration only
  lan = {
    subnet = "10.88.128.0/24";  # Which subnet I'm on
    gateway = "10.88.128.1";    # How to reach hub
    
    # Only declare myself, not all hosts
    hosts = {
      "gaming-host-1" = {
        ip = "10.88.128.25";
        mac = "aa:bb:cc:dd:ee:ff";
        routing = {
          tailscale = true;      # I'm Tailscale-capable
          wireguard = true;      # I'm WireGuard-capable
        };
        services = [ "gaming" ];  # Services I provide
      };
    };
  };
  
  # Optional: services I expose that need inbound routes
  # (hub's topology will reference these)
  services = {
    gaming = {
      ports = [ 27015 27016 ];   # Port numbers for this service
    };
  };
}
```

**Note**: Clients DON'T declare:
- `forwarding` (hub does that)
- `dns.static` (hub manages DNS)
- `nginx.proxies` (hub manages reverse proxy)
- `wireguard.peers` (hub manages peer list)

Clients declare:
- Their own IP, MAC, hostname
- Their routing capabilities (Tailscale, WireGuard)
- Services they provide (used by hub's topology)

### Golden Test Creation Process

For each machine:

1. **Create topology file** from template or existing inline config
   ```bash
   cp real-topology/_template.nix real-topology/<hostname>.nix
   ```

2. **Populate topology** with actual network data
   - IP addresses from `ip addr` on the machine
   - MAC addresses from `ip link show`
   - Subnet/gateway from network config
   - Services from machines/<hostname>/default.nix

3. **Validate topology** passes `nix flake check`
   ```bash
   nix flake check
   ```

4. **Generate golden file**
   ```bash
   nix run .#check-network -- <hostname> > real-topology/golden/<hostname>.json
   ```

5. **Visual audit** of golden output
   - Check WireGuard peer config
   - Verify firewall rules
   - Validate DNS entries
   - Spot-check nginx proxies

6. **Commit**
   ```bash
   git add real-topology/<hostname>.nix real-topology/golden/<hostname>.json
   git commit -m "topology: add golden test for <hostname>"
   ```

### Validation Checklist per Machine

Before committing golden file:

- [ ] Topology file parses (nix flake check passes)
- [ ] No eval errors in core-router.nix
- [ ] Golden file is non-empty JSON
- [ ] Golden output looks sane (visual spot-check):
  - [ ] WireGuard IPs are correct
  - [ ] Firewall rules make sense
  - [ ] DNS entries point to right IPs
  - [ ] No hardcoded "TODO" values
- [ ] Golden test passes: `nix run .#check-network -- <hostname> --compare`
- [ ] No golden regressions on other machines

### Exit Criteria for Phase 2

- [ ] 18 x86_64 machines have topology files
- [ ] 18 golden files generated and committed
- [ ] Visual audit complete for all 18 (spot-check for sanity)
- [ ] No golden test regressions on cortex-alpha
- [ ] All topology files pass validation
- [ ] Rollout documented (which machines completed, any blockers)
- [ ] Create `documentation/phase-2-rollout-log.md` with per-machine notes

---

## Section 5: Phase 3 — Topology Coverage Meta-Test

### Objective

Implement a test that validates **topology completeness**: ensure every machine in `flake.nix` has a corresponding topology file.

### Implementation

#### 4.1 Create `topology-coverage.nix` Check

Create `real-topology/coverage.nix`:

```nix
# real-topology/coverage.nix
# Checks that all machines declared in flake have topology files
{ nixos-machines }:  # passed from flake.nix
let
  lib = import <nixpkgs/lib>;
  
  # Extract machine names from flake config
  machineNames = builtins.attrNames nixos-machines;
  
  # Check which topology files exist
  topologyFiles = map (name: {
    inherit name;
    hasFile = builtins.pathExists .//${name}.nix;
  }) machineNames;
  
  # Categorize by coverage
  covered = lib.filter (x: x.hasFile) topologyFiles;
  missing = lib.filter (x: !x.hasFile) topologyFiles;
in
{
  inherit machineNames covered missing;
  totalMachines = builtins.length machineNames;
  coveredCount = builtins.length covered;
  missingCount = builtins.length missing;
  coveragePercent = (coveredCount * 100) / builtins.length machineNames;
  
  # Validation assertion for CI
  isComplete = builtins.length missing == 0;
}
```

#### 4.2 Integration with `nix flake check`

Add to `flake.nix`:

```nix
{
  # ... existing code ...
  
  checks.x86_64-linux = {
    # Existing checks...
    
    topology-coverage = let
      coverage = import ./real-topology/coverage.nix {
        nixos-machines = self.nixosConfigurations;
      };
    in if !coverage.isComplete then
      throw "Topology coverage incomplete. Missing: ${builtins.toJSON coverage.missing}"
    else
      pkgs.runCommand "topology-coverage-check" { } ''
        echo "Topology coverage: ${toString coverage.coveragePercent}%"
        echo "Machines: ${toString coverage.coveredCount}/${toString coverage.totalMachines}"
        touch $out
      '';
    
    # Per-machine golden tests
    golden-cortex-alpha = import ./real-topology/default.nix { 
      hostname = "cortex-alpha"; 
      inherit pkgs;
    };
  };
}
```

#### 4.3 Coverage Report Script

Create `scripts/topology-report.sh`:

```bash
#!/usr/bin/env bash
# Generate topology coverage report

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACHINES_DIR="$REPO_ROOT/machines"
TOPOLOGY_DIR="$REPO_ROOT/real-topology"
GOLDEN_DIR="$TOPOLOGY_DIR/golden"

echo "=== Topology Coverage Report ==="
echo ""

# Extract machine names from flake.nix (simple grep)
MACHINES=$(grep -o 'mkX86_64 "\w\+"\|mkAarch64 "\w\+' "$REPO_ROOT/flake.nix" | sed 's/.*"\([^"]*\)".*/\1/' | sort -u)

COVERED=0
TOTAL=0

echo "x86_64-linux machines:"
for machine in $MACHINES; do
  TOTAL=$((TOTAL + 1))
  if [ -f "$TOPOLOGY_DIR/$machine.nix" ]; then
    if [ -f "$GOLDEN_DIR/$machine.json" ]; then
      echo "  ✓ $machine (topology + golden)"
      COVERED=$((COVERED + 1))
    else
      echo "  ~ $machine (topology only, no golden)"
    fi
  else
    echo "  ✗ $machine (missing topology)"
  fi
done

echo ""
echo "Coverage: $COVERED/$TOTAL machines"
echo "Percentage: $(echo "scale=1; $COVERED * 100 / $TOTAL" | bc)%"
```

### Benefits

- **CI/CD Integration**: Catch missing topology files in PR checks
- **Progress Tracking**: Easy to see rollout progress
- **Accountability**: Visible when machines are added to flake but not topology-driven
- **Enforcement**: Can make it a hard failure in CI

### Exit Criteria for Phase 3

- [ ] `nix flake check` includes topology-coverage test
- [ ] `topology-coverage.nix` correctly identifies missing files
- [ ] `scripts/topology-report.sh` works and shows accurate counts
- [ ] CI/CD pipeline runs topology-coverage check
- [ ] Documentation updated with coverage target (e.g., "80% by end of Phase 2")
- [ ] Warnings/errors have clear guidance for fixing (link to migration guide)

---

## Section 6: Phase 4 — Unified Client Generators

### Objective

Enable client machines to use the SAME generator pattern as the hub, producing the correct config for their role based on hostname and topology data. This phase proves the architecture standard works for both hub and client.

### Unified Generator Pattern

Per the Two-Layer Architecture (Section 1.3), the same `genWireguard` generator works for both hub and client:

```nix
# genWireguard decision logic
genWireguard = { lib }: { settings, hostname }:
  if hostname == settings.hubName then
    # Hub: listen on all IPs, include all peers
    { 
      networking.wireguard.interfaces.wireg0 = {
        ips = settings.hub.ips;
        listenPort = settings.listenPort;
        privateKeyFile = <secrix path>;
        peers = [ /* all non-hub peers */ ];
      };
    }
  else
    # Client: connect to hub as endpoint
    {
      networking.wireguard.interfaces.wireg0 = {
        ips = [ settings.machineIp ];
        privateKeyFile = <secrix path>;
        peers = [
          {
            publicKey = settings.peers.${settings.hubName}.publicKey;
            endpoint = "${settings.hub.endpoint}:${toString settings.listenPort}";
            allowedIPs = [ settings.hub.allocationRange ];
            persistentKeepalive = 25;
          }
        ];
      };
    }
```

**Key insight**: The generator doesn't need separate client/hub logic in different files. It's all in one function, with a simple conditional.

### Client Topology Data

Client topology files declare their position and how to reach the hub:

```nix
# real-topology/gaming-host-1.nix (client example)
{ lib }:
{
  domain = "johnbargman.net";
  
  # Client declares its own position
  lan = {
    subnet = "10.88.128.0/24";
    gateway = "10.88.128.1";
    hosts = {
      "gaming-host-1" = {
        ip = "10.88.128.25";
        mac = "aa:bb:cc:dd:ee:ff";
        routing = {
          tailscale = true;
          wireguard = true;
        };
        services = [ "gaming" ];
      };
    };
  };
  
  # Client declares how to reach the hub
  hub = {
    name = "cortex-alpha";
    endpoint = "cortex-alpha.johnbargman.net";
    port = 51820;
    
    # Client's IP on WireGuard subnet (assigned by hub)
    wireguardIp = "10.88.127.108/32";
    
    # Routes to advertise via Tailscale (optional)
    tailscaleAdvertisedRoutes = [ "10.88.128.0/24" ];
  };
}
```

**What clients DON'T declare**:
- `lan.hosts` list (only themselves)
- `forwarding`, `nginx.proxies`, `dns.static` (hub manages these)
- `wireguard.peers` (hub manages peer list)

### Transformer for Clients: `mkWireguardSettings`

The transformer works on BOTH hub and client topologies, producing the right settings for each:

```nix
# lib/topology/mkWireguardSettings.nix
{ lib }: topology:

let
  # For hub: read all peer keys
  # For client: read only hub's key
  isHub = topology.lan ? hosts;  # Hub declares all hosts
  
  peerNames = if isHub
    then builtins.attrNames topology.lan.hosts
    else [ topology.hub.name ];
  
  peers = builtins.mapAttrs (name: _:
    let
      keyPath = ../../secrets/public_keys/wireguard/wg_${name}_pub;
      keyExists = builtins.pathExists keyPath;
    in
    {
      publicKey = if keyExists then builtins.readFile keyPath 
                  else "<missing>";
      ip = if isHub then topology.lan.hosts.${name}.ip else topology.hub.wireguardIp;
      isHub = (name == (if isHub then topology.networking.hostName else topology.hub.name));
    }
  ) (builtins.listToAttrs (map (n: { name = n; value = null; }) peerNames));
  
  warnings = lib.filter (x: x != null) (map (name:
    let keyPath = ../../secrets/public_keys/wireguard/wg_${name}_pub;
    in if builtins.pathExists keyPath then null
       else "Missing WireGuard public key for ${name} at ${keyPath}"
  ) peerNames);
in

{
  interface = "wireg0";
  listenPort = topology.hub.port or 2108;
  hubName = topology.hub.name;
  
  hub = if topology.lan ? hosts then {
    ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
    endpoint = "cortex-alpha.johnbargman.net";
  } else {
    endpoint = topology.hub.endpoint;
  };
  
  machineIp = topology.wireguardIp or topology.hub.wireguardIp;
  
  peers = peers;
  warnings = warnings;
}
```

### Generator for Clients: Use Same `genWireguard`

No separate client generator needed. The same generator handles both:

```nix
# In core-router.nix or enable-wg-topology.nix
let
  topologyLib = import ../lib/topology { inherit lib self topology; };
  settings = topologyLib.settings.wireguard;
  hostname = config.networking.hostName;
in

# Same generator for both hub and client
{
  networking.wireguard.interfaces.wireg0 = 
    topologyLib.generators.wireguard { inherit settings hostname; };
}
```

### Client Module: `modules/enable-wg-topology.nix`

For client machines, use the topology-driven module:

```nix
# modules/enable-wg-topology.nix
# Works for both hub and client via unified generator

{ config, lib, self, ... }:

let
  topology = import ../real-topology/${config.networking.hostName}.nix { inherit lib; };
  hasWireguard = topology ? hub || (topology ? lan && topology.lan ? hosts);  # hub or client
  
  privateKeyPath = 
    if config ? secrix.services.wireguard-wireg0.secrets then
      config.secrix.services.wireguard-wireg0.secrets.${config.networking.hostName}.decrypted.path
    else
      throw "No secrix WireGuard key for ${config.networking.hostName}";
  
  topologyLib = import ../lib/topology { inherit lib self topology; };
in

{
  config = lib.mkIf hasWireguard {
    assertions = [
      {
        assertion = topologyLib.validate.wireguard.valid;
        message = "WireGuard topology validation failed: ${builtins.concatStringsSep ", " topologyLib.validate.wireguard.errors}";
      }
    ];
    
    networking.wireguard.enable = true;
    networking.wireguard.interfaces.wireg0 = lib.mkDefault
      (topologyLib.generators.wireguard { 
        settings = topologyLib.settings.wireguard; 
        hostname = config.networking.hostName;
      });
  };
}
```

### Secrix Integration for Client Keys

Client machines manage their private keys via secrix (same as hub):

```nix
# machines/gaming-host-1/default.nix

{
  imports = [
    ../../modules/enable-wg-topology
  ];
  
  secrix.services.wireguard-wireg0.secrets.gaming-host-1.encrypted.file =
    ../../secrets/private_keys/wireguard/wg_gaming-host-1;
}
```

Private key setup (same for hub and client):
```bash
# Generate key pair
wg genkey > wg_gaming-host-1
wg pubkey < wg_gaming-host-1 > wg_gaming-host-1.pub

# Encrypt private key with secrix
secrix encrypt wg_gaming-host-1 \
  secrets/private_keys/wireguard/wg_gaming-host-1

# Commit public key
git add secrets/public_keys/wireguard/wg_gaming-host-1.pub
```

### Hub Topology Remains Hub-Only

Hub topology still declares all hosts (it manages the entire network):

```nix
# real-topology/cortex-alpha.nix (hub - unchanged pattern)
{ lib }:
{
  domain = "johnbargman.net";
  
  lan = {
    subnet = "10.88.127.0/24";
    gateway = "10.88.127.1";
    hosts = {
      "cortex-alpha" = { ip = "10.88.127.1"; ... };
      "gaming-host-1" = { ip = "10.88.128.25"; ... };
      # All other hosts
    };
  };
  
  wireguard = {
    interface = "wireg0";
    peers = [ "cortex-alpha" "gaming-host-1" ... ];  # All peers
  };
  
  # ... nginx, dns, forwarding, etc.
}
```

**Note**: Hub topology does NOT import client topologies. Clients are declared as data points in `lan.hosts`.

### Exit Criteria for Phase 4

- [ ] `genWireguard` works for both hub and client (proven by testing)
- [ ] `mkWireguardSettings` produces correct settings for both hub and client
- [ ] `modules/enable-wg-topology.nix` works for hub and client (same module)
- [ ] At least 5 client machines tested: gaming-host-1, terminal-zero, alpha-one, alpha-two, alpha-three
- [ ] No hardcoded `cortex-alpha` references in client configs
- [ ] Secrix integration verified for all 5 clients
- [ ] No golden test regressions on hub
- [ ] Documentation updated: all generators work for both hub and client
- [ ] All changes committed with unified generator pattern

---

## Section 7: Phase 5 — Validation and Cross-Section Consistency

### Problem Statement (TG-007)

Current validation (`validate.nix`) checks **structure** only:
- Is `lan.hosts` an attribute set? ✓
- Are IPs in valid CIDR format? ✓
- Are there duplicate IPs? ✓

But doesn't check **cross-section consistency**:
- Forwarding rules target IPs that exist in `lan.hosts`? ✗
- Nginx proxy backends point to valid host IPs? ✗
- DNS static entries reference existing hosts? ✗
- WireGuard peers are declared in `lan.hosts`? ✗

### Implementation: Extended Validation

#### 6.1 Add Cross-Reference Functions to `utils.nix`

```nix
# lib/topology/utils.nix (additions)

{
  # ... existing functions ...
  
  # Check if an IP is in any declared host
  isValidIP = topology: ip:
    lib.any (host: host.ip == ip) (builtins.attrValues topology.lan.hosts);
  
  # Check if a hostname is in hosts
  hostExists = topology: hostname:
    builtins.hasAttr hostname topology.lan.hosts;
  
  # Get host by name
  getHost = topology: hostname:
    topology.lan.hosts.${hostname} or
      (throw "Host '${hostname}' not found in topology");
  
  # Extract IP from "host:port" string
  parseHostPort = str:
    let
      parts = lib.strings.split ":" str;
    in {
      host = lib.elemAt parts 0;
      port = if builtins.length parts > 1 
             then lib.toInt (lib.elemAt parts 2)
             else null;
    };
}
```

#### 6.2 Extend `validate.nix` with Cross-Section Checks

```nix
# lib/topology/validate.nix (additions)

validateCrossReferences = topology:
let
  lib = import <nixpkgs/lib>;
  
  # Validation functions
  checkForwardingRefs = 
    let
      rules = (topology.forwarding.tcp or []) ++ (topology.forwarding.udp or []);
    in
    builtins.map (rule:
      let
        hostIp = lib.head (lib.strings.split ":" rule.to);
      in
      if utils.isValidIP topology hostIp
      then null
      else "Forwarding rule targets non-existent IP: ${hostIp}"
    ) rules;
  
  checkNginxRefs =
    let
      proxies = topology.nginx.proxies or {};
    in
    builtins.mapAttrs (vhost: backend:
      let
        hostIp = lib.head (lib.strings.split ":" backend);
      in
      if utils.isValidIP topology hostIp
      then null
      else "Nginx proxy '${vhost}' targets non-existent IP: ${hostIp}"
    ) proxies;
  
  checkDnsRefs =
    let
      entries = topology.dns.static or [];
    in
    builtins.map (entry:
      if utils.isValidIP topology entry.ip
      then null
      else "DNS entry '${entry.domain}' targets non-existent IP: ${entry.ip}"
    ) entries;
  
  checkWireguardPeers =
    let
      peers = topology.wireguard.peers or [];
    in
    builtins.map (peer:
      if utils.hostExists topology peer
      then null
      else "WireGuard peer '${peer}' not found in lan.hosts"
    ) peers;
  
  # Collect all errors
  allErrors = lib.flatten [
    (lib.filter (x: x != null) (checkForwardingRefs))
    (lib.filter (x: x != null) (checkNginxRefs))
    (lib.filter (x: x != null) (checkDnsRefs))
    (lib.filter (x: x != null) (checkWireguardPeers))
  ];
in
{
  valid = builtins.length allErrors == 0;
  errors = allErrors;
}
```

#### 6.3 Integration into Validation Flow

Update `core-router.nix`:

```nix
let
  # ... existing code ...
  validator = import ../lib/topology/validate.nix { inherit lib; };
  
  # Structural validation
  structuralValidation = validator.validateTopology topology;
  
  # Cross-reference validation
  crossRefValidation = validator.validateCrossReferences topology;
  
  # Combined validation
  allValid = structuralValidation.valid && crossRefValidation.valid;
  allErrors = structuralValidation.errors ++ crossRefValidation.errors;
in
{
  config = {
    assertions = [
      {
        assertion = config.coreRouter.enable -> allValid;
        message = "Topology validation failed: ${builtins.concatStringsSep "\n  " allErrors}";
      }
    ];
  };
}
```

### Test Suite for Validation

Create `tests/topology-validation.nix`:

```nix
# tests/topology-validation.nix
# Test suite for topology validation
#
# Run with: nix eval tests/topology-validation.nix

{ pkgs ? import <nixpkgs> { } }:

let
  lib = pkgs.lib;
  validate = import ../lib/topology/validate.nix { inherit lib; };
  
  # Test case: valid topology
  validTopology = {
    domain = "example.com";
    lan = {
      subnet = "10.0.0.0/24";
      gateway = "10.0.0.1";
      hosts = {
        "host1" = { ip = "10.0.0.10"; };
      };
    };
    wireguard.peers = [ "host1" ];
    forwarding.tcp = [ { to = "10.0.0.10:80"; } ];
  };
  
  # Test case: invalid forwarding reference
  invalidForwarding = validTopology // {
    forwarding.tcp = [ { to = "10.0.0.99:80"; } ];  # IP doesn't exist
  };
  
  # Test case: invalid wireguard peer
  invalidPeer = validTopology // {
    wireguard.peers = [ "nonexistent" ];
  };
  
  # Run tests
  tests = {
    valid = validate.validateCrossReferences validTopology;
    invalidFwd = validate.validateCrossReferences invalidForwarding;
    invalidPeer = validate.validateCrossReferences invalidPeer;
  };
in
tests
```

### TG-012: Golden Test Scope Refinement (Optional Phase 5 Task)

Currently golden tests capture full NixOS config (567 lines). Non-network changes break golden tests.

**Option A**: Extract only network-relevant sections (WireGuard, Tailscale, DNS, firewall, nginx)

```nix
# In real-topology/default.nix
let
  fullConfig = ...; # existing
  networkConfig = {
    networking = fullConfig.networking;
    services.dnsmasq = fullConfig.services.dnsmasq;
    services.nginx = fullConfig.services.nginx;
    services.tailscale = fullConfig.services.tailscale;
  };
in
networkConfig
```

**Option B**: Create separate `golden.json` and `golden-network.json` targets

**Recommendation**: **Option A** for simplicity. Narrowing scope reduces false positives.

### Exit Criteria for Phase 5

- [ ] Cross-reference validation functions added to `validate.nix`
- [ ] `validateCrossReferences` integrated into `core-router.nix`
- [ ] At least 5 test cases in `tests/topology-validation.nix` (valid, invalid fwd, invalid peer, invalid DNS, invalid nginx)
- [ ] All test cases pass with expected results
- [ ] Documentation updated with validation rules
- [ ] TG-007 marked resolved
- [ ] Optional: TG-012 resolved (golden scope narrowed)

---

### 7.1 Cross-Service Validation Rules (IMPLEMENTATION GUIDE)

This subsection defines the validation rules that enforce consistency across services. These rules are implemented in Phase 5 via assertions in `core-router.nix` and `enable-wg-topology.nix`.

#### 7.1.1 Cross-Service Validation Pattern

When a service connection is declared (e.g., nginx proxy points to backend IP), the system MUST validate that:
1. The target IP exists in `lan.hosts`
2. The transport layer supports the connection (WireGuard, LAN, Tailscale)
3. Firewall rules allow the connection
4. The target service is actually running

#### 7.1.2 Validation Rules by Service Type

**WireGuard Peer Validation**:
- [ ] Each declared peer exists in `lan.hosts` (by hostname)
- [ ] Each peer has a WireGuard public key file at `secrets/public_keys/wireguard/wg_${hostname}_pub`
- [ ] Peer's WireGuard IP is allocated in the correct subnet
- [ ] Hub has WireGuard enabled and is reachable
- **Validation Level**: ERROR (breaks network connectivity)

**Nginx Reverse Proxy Validation**:
- [ ] Backend IP exists in `lan.hosts`
- [ ] Backend port is declared in the host's services config
- [ ] Transport path between cortex-alpha and backend is enabled:
  - LAN: Both on same subnet
  - WireGuard: Backend is a WireGuard peer
  - Tailscale: Both have Tailscale enabled
- [ ] Firewall rules allow traffic on backend port
- **Validation Level**: ERROR (breaks service accessibility)

**Port Forwarding Validation**:
- [ ] Target IP exists in `lan.hosts`
- [ ] Target port is declared in the host's services config
- [ ] Transport path from WAN to target is enabled
- [ ] Firewall rules allow the forward
- **Validation Level**: ERROR (security risk if broken)

**Static DNS Entry Validation**:
- [ ] Target IP exists in `lan.hosts` OR is an external IP
- [ ] If local IP: the service actually runs on that host
- [ ] No duplicate DNS entries (different IPs for same domain)
- **Validation Level**: WARNING (DNS misconfig is less critical than routing)

**Tailscale Route Validation**:
- [ ] Advertised subnet matches declared LAN/WAN subnets
- [ ] Advertising machine is Tailscale-enabled and hub is Tailscale-enabled
- [ ] No conflicting routes (same subnet from different machines)
- **Validation Level**: WARNING (advisory, not critical)

#### 7.1.3 Concrete Example: Nginx Proxy Validation

**Scenario**: Hub topology declares `code.johnbargman.net → 10.88.127.3:80`

**Validation Checklist**:

```nix
# In lib/topology/validate.nix

validateNginxProxy = { lib, topology, utils }:
  let
    proxies = topology.nginx.proxies or {};
  in
  builtins.foldl' (acc: vhost:
    let
      backend = proxies.${vhost};
      # Parse "10.88.127.3:80" → { ip: "10.88.127.3", port: 80 }
      parsed = utils.parseHostPort backend;
      targetHost = utils.getHost topology parsed.host or (throw "Invalid backend format: ${backend}");
    in
    acc ++ lib.optionals (!targetHost ? ip) [
      "Nginx proxy '${vhost}' targets non-existent IP: ${parsed.host}"
    ] ++ lib.optionals (!(targetHost.services or []) |> lib.any (s: s.port == parsed.port)) [
      "Nginx proxy '${vhost}' backend port ${toString parsed.port} not declared for ${parsed.host}"
    ] ++ lib.optionals (!(utils.canReach topology "cortex-alpha" targetHost)) [
      "Nginx proxy '${vhost}' cannot reach backend (no WireGuard/LAN/Tailscale path)"
    ]
  ) [] (builtins.attrNames proxies);
```

**Output if validation fails**:
```
assertion error:
Topology validation failed:
  - Nginx proxy 'code.johnbargman.net' targets IP 10.88.127.99 (not found in lan.hosts)
  - Nginx proxy 'code.johnbargman.net' backend port 80 not declared for local-nas
  - Nginx proxy 'code.johnbargman.net' backend 'local-nas' not reachable from cortex-alpha
```

#### 7.1.4 Implementation in core-router.nix

```nix
# modules/core-router.nix

let
  topology = import ../real-topology/${config.networking.hostName}.nix { inherit lib; };
  topologyLib = import ../lib/topology { inherit lib self topology; };
  
  # Validation results
  structuralValidation = topologyLib.validate.topology topology;
  crossServiceValidation = {
    wireguard = topologyLib.validate.wireguardPeers topology;
    nginx = topologyLib.validate.nginxProxies topology;
    forwarding = topologyLib.validate.portForwarding topology;
    dns = topologyLib.validate.dnsEntries topology;
    tailscale = topologyLib.validate.tailscaleRoutes topology;
  };
  
  # Combine results
  criticalErrors = (structuralValidation.errors or [])
    ++ (crossServiceValidation.wireguard.errors or [])
    ++ (crossServiceValidation.nginx.errors or [])
    ++ (crossServiceValidation.forwarding.errors or []);
    
  allWarnings = (crossServiceValidation.dns.warnings or [])
    ++ (crossServiceValidation.tailscale.warnings or []);
in
{
  config = lib.mkIf config.coreRouter.enable {
    assertions = [
      {
        assertion = builtins.length criticalErrors == 0;
        message = "Topology validation FAILED:\n  " + 
          builtins.concatStringsSep "\n  " criticalErrors;
      }
    ];
    
    # Log warnings to build output
    system.extraSystemBuilderCmds = lib.optionalString (builtins.length allWarnings > 0)
      ''
        echo "TOPOLOGY WARNINGS (non-blocking):"
        ${lib.concatMapStrings (w: "echo '  - ${w}'") allWarnings}
      '';
  };
}
```

#### 7.1.5 Testing Cross-Service Validation

Create `tests/cross-service-validation.nix`:

```nix
# tests/cross-service-validation.nix

{ pkgs ? import <nixpkgs> { } }:

let
  lib = pkgs.lib;
  
  # Test case: valid nginx proxy
  validNginx = {
    nginx.proxies.code = "http://10.88.127.3:80";
    lan.hosts = {
      "local-nas" = { ip = "10.88.127.3"; services = [ { name = "http"; port = 80; } ]; };
    };
  };
  
  # Test case: nginx backend IP doesn't exist
  invalidNginxIP = validNginx // {
    nginx.proxies.code = "http://10.88.127.99:80";  # IP doesn't exist
  };
  
  # Test case: nginx backend port not declared
  invalidNginxPort = validNginx // {
    nginx.proxies.code = "http://10.88.127.3:8080";  # Port 8080 not declared for local-nas
  };
  
  # Test case: valid WireGuard peer
  validWG = {
    lan.hosts.peer1 = { 
      ip = "10.88.127.10"; 
      routing.wireguard = true; 
    };
    wireguard.peers = [ "peer1" ];
  };
  
  # Test case: WireGuard peer doesn't exist
  invalidWGPeer = {
    lan.hosts.peer1 = { ip = "10.88.127.10"; };
    wireguard.peers = [ "nonexistent" ];
  };
  
  # Import validator
  validate = import ../lib/topology/validate.nix { inherit lib; };
  
  # Run tests
  tests = {
    nginx_valid = validate.nginxProxies validNginx;
    nginx_invalid_ip = validate.nginxProxies invalidNginxIP;
    nginx_invalid_port = validate.nginxProxies invalidNginxPort;
    wg_valid = validate.wireguardPeers validWG;
    wg_invalid_peer = validate.wireguardPeers invalidWGPeer;
  };
in
tests
```

Run with: `nix eval tests/cross-service-validation.nix`

#### 7.1.6 Exit Criteria for Cross-Service Validation Implementation

- [ ] Cross-service validation functions implemented in `validate.nix`
- [ ] All validation rules from Section 7.2 are checked
- [ ] ERROR-level validations block deployment with clear messages
- [ ] WARNING-level validations log to build output
- [ ] Test cases in `tests/cross-service-validation.nix` pass
- [ ] Documentation updated with validation rules
- [ ] Integration test: intentionally create broken topology, verify error message

---

## Section 8: Remaining Design Questions for Discussion

These design decisions should be finalized **during Phase 1** implementation.

**Status**: The Two-Layer Architecture (Section 1) has RESOLVED the following previously open questions:
- ✅ TG-003 (standardization approach): **RESOLVED** - Transformer/Generator pattern
- ✅ Hub-Client model: **RESOLVED** - Unified generators, distinction is emergent from data
- ✅ Client key management: **RESOLVED** - Use secrix for both hub and client
- ✅ Standard import path: **RESOLVED** - Use `lib/topology/default.nix` (see Phase 1 implementation)
- ✅ Cross-service validation: **RESOLVED** - See Section 7 implementation rules

Remaining design questions below (non-blocking, finalize as needed):

### 8.1 Cross-Service Validation: Error vs Warning by Type

**Question**: Should cross-reference validation be **error** (block deployment) or **warning** (logged but allowed)? Should it vary by service type?

```
All-Error:       Any invalid reference = deployment fails (strictest)
All-Warning:     Any invalid reference = build succeeds, logged (most permissive)
Mixed:           Error for critical (forwarding, WG peers), Warning for optional (DNS, nginx)
```

**Critical vs Optional**:
- **Critical** (should ERROR): Forwarding rules, WireGuard peers, core network paths
  - Rationale: Broken routing = network outage, security risk
- **Optional** (should WARN): DNS entries, deprecated services, nginx backends
  - Rationale: May be intentional (e.g., DNS for decommissioned service)

**Recommendation**: **Mixed approach** - Error for network infrastructure, Warning for services. Table in Section 1.6 defines rules.

---

### 8.2 Golden Test Scope: Full Config vs Network-Only

**Question**: Should golden files capture full NixOS config or only network-relevant sections?

```
Full Config:     Current behavior, catches all changes
Network Only:    Narrow to networking/services sections
Dual Targets:    Both `golden.json` and `golden-network.json`
```

**Trade-off**:
- Full: Catches accidental config changes elsewhere
- Network Only: Reduces false positives from non-network changes, clearer intent
- Dual: More complex, harder to maintain

**Recommendation**: **Network Only** (Phase 5) - Scope to networking, dnsmasq, nginx, tailscale, nftables sections to reduce false positives.

---

### 8.3 ARM Machine Topology Coverage

**Question**: Do ARM machines (Raspberry Pi displays, print-controller, beta-one) need topology files?

```
Yes (full coverage): All machines topology-driven, consistent pattern
No (skip): Only x86_64, ARM machines stay inline
Partial: Only ARM machines with network services (print-controller)
```

**Factors**:
- Print-controller: Has Klipper service, likely special network config → candidate for Phase 4
- Display-* machines: Stateless, may not benefit → defer or skip
- Beta-one: Unknown current role → check and decide

**Recommendation**: Include **print-controller** in Phase 4 (service-driven). Defer display-* and beta-one to Phase 5 or future.

---

### 8.4 Scope: Should All Client Machines Use Topology?

**Question**: Should **all** 23 machines eventually be topology-driven, or only network-critical ones?

```
Full Coverage: 23 machines (x86_64 + ARM), all topology-driven
Partial:       Only hub + network-heavy machines (8-10 machines)
Hub Only:      Just cortex-alpha, others inline (minimal effort)
```

**Considerations**:
- Effort: Full = 5-6 phases; Partial = 3 phases; Hub-only = done
- Value: Full = unified pattern, easy onboarding; Partial = best ROI; Hub-only = low ROI (only 1 machine)
- Desktop machines (gaming workstations, obs-box): Simple config, may not benefit

**Recommendation**: **Partial Coverage** (Hub + network-critical: cortex-alpha, local-nas, storage-array, terminal-zero, remote-worker, gaming hosts with ports). Approximately 8-10 machines. Defer simple machines to future if pattern proves valuable.

---

### 8.5 lib/topology Import Path

**Question**: Should canonical import be `lib/topology.nix` or `lib/topology/default.nix`?

```
lib/topology.nix:          Direct import, split directory structure
lib/topology/default.nix:  Indirect import, contained in topology dir
```

**Nix convention**: Use `default.nix` when importing a directory. Use `lib/topology.nix` only if treating topology as a single function module.

**Recommendation**: **Use `lib/topology/default.nix`**. Import as `import ../lib/topology { inherit lib self topology; }`

---

### 8.6 Hub Topology: Should It Reference Client Topologies?

**Question**: Should hub topology (`cortex-alpha.nix`) import or reference client topology files for service discovery?

```
Separate:      Each machine has independent topology. Hub declares all hosts as data.
Hub-Centric:   Hub topology imports all client topologies for automatic discovery.
Hybrid:        Hub imports client topologies BUT only for validation, not for primary data.
```

**Trade-offs**:

| Approach | Pro | Con |
|---|---|---|
| **Separate** | Decoupled, easy to add/remove clients, no circular deps | Service discovery manual, more duplication |
| **Hub-Centric** | Single source of truth, automatic service discovery | Hub topology gets large, circular dependency risk |
| **Hybrid** | Validation without coupling to primary data | More complex |

**Recommendation**: **Separate** (Phase 4). Hub topology declares clients in `lan.hosts` data. If service discovery becomes pain point in Phase 5+, upgrade to Hybrid approach.

---

---

## Section 9: Implementation Roadmap

### Phased Timeline (Estimated)

```
Week 1 (Design & Prep)
  - [ ] Resolve open questions (Section 8)
  - [ ] Finalize standardization approach (TG-003)
  - [ ] Create Phase 1 PR with design decisions
  - [ ] Update AGENTS.md with final API

Week 2-4 (Phase 1: Standardize Library)
  - [ ] Refactor mkWireguardPeers.nix (keys as argument)
  - [ ] Standardize remaining mk*.nix functions
  - [ ] Create lib/topology/default.nix (canonical export)
  - [ ] Update core-router.nix to use new API
  - [ ] Verify golden test still passes (cortex-alpha)
  - [ ] Commit Phase 1 changes

Week 5-8 (Phase 2: Golden Coverage)
  - [ ] Tier 1: local-nas, storage-array (Week 5)
  - [ ] Tier 2: terminal-zero, gaming-hosts (Week 6)
  - [ ] Tier 3: remote-worker, LINDA, alpha-three (Week 7)
  - [ ] Tier 4: cleanup, remaining (Week 8)
  - [ ] Visual audit all 18 topologies

Week 9 (Phase 3: Coverage Test)
  - [ ] Implement topology-coverage.nix
  - [ ] Integrate with nix flake check
  - [ ] Create scripts/topology-report.sh
  - [ ] Add to CI/CD pipeline

Week 10-12 (Phase 4: Client Generators)
  - [ ] mkWireguardClient.nix, mkTailscaleClient.nix
  - [ ] modules/enable-wg-topology.nix
  - [ ] Test with 5 client machines
  - [ ] Secrix integration for client keys
  - [ ] Hub-client topology model design finalized

Week 13-14 (Phase 5: Cross-Section Validation)
  - [ ] Extend validate.nix with cross-references
  - [ ] Implement tests/topology-validation.nix
  - [ ] Integrate into core-router.nix
  - [ ] Optional: Narrow golden scope (TG-012)
  - [ ] Full test suite passes

Week 15+ (Future)
  - [ ] ARM machine coverage (beta-one, print-controller)
  - [ ] Topology-driven service discovery
  - [ ] Hub topology auto-aggregation from clients
```

### Checkpoint Decisions

Before moving to next phase, confirm:

**After Phase 1**:
- [ ] All mk*.nix functions have consistent signature
- [ ] core-router.nix uses unified API
- [ ] cortex-alpha golden test still passes

**After Phase 2**:
- [ ] 18 x86_64 machines have topology + golden files
- [ ] All topologies pass validation
- [ ] No golden regressions

**After Phase 3**:
- [ ] Coverage test integrated in CI/CD
- [ ] Progress report shows 100% x86_64 coverage (or documented reasons for exceptions)

**After Phase 4**:
- [ ] At least 5 client machines using topology-driven config
- [ ] WireGuard client config removed hardcoded cortex-alpha references
- [ ] secrix integration verified

**After Phase 5**:
- [ ] Cross-reference validation catches invalid references
- [ ] Test suite comprehensive
- [ ] Documentation complete

---

## Section 10: Risk Mitigation

### High-Risk Items

| Risk | Phase | Mitigation |
|------|-------|-----------|
| **TG-003 breaking change** | 1 | Phased rollout; compatibility wrapper for 1 release; test heavily |
| **Golden test regression** | 1-2 | Keep cortex-alpha as canary; run golden test on every change |
| **Data entry errors in topology files** | 2 | Validation script; visual audit per machine; diff against existing config |
| **Service outage during client migration** | 4 | Test on non-critical machines first; keep inline config as fallback |
| **Circular dependencies** | 4 | Use separate client topologies, not hub-centric aggregation |
| **Validation overly strict** | 5 | Start with warnings; escalate to errors only for critical cases |

### Testing Strategy

1. **Unit tests**: Validation functions, transformation functions (create `tests/` directory)
2. **Integration tests**: Golden test per machine; comparison across revisions
3. **Smoke tests**: Deploy to test machine; verify WireGuard, Tailscale, DNS functional
4. **Regression tests**: Golden files catch unexpected config changes

### Rollback Plan

If Phase N breaks critical functionality:
1. Revert most recent commit
2. Debug issue in isolated branch
3. Create test case that catches regression
4. Fix and re-submit

---

## Section 11: Success Criteria

### Overall Success Metrics

- [ ] 18 x86_64 machines have topology files (100% coverage)
- [ ] 18 golden tests generated and pass (no regressions)
- [ ] Cross-reference validation prevents at least 1 real bug during rollout
- [ ] All mk*.nix functions use uniform signature
- [ ] Documentation updated and tutorials written
- [ ] Zero production outages caused by topology migration
- [ ] Team can add new machine to topology in <30 minutes

### Per-Phase Success

**Phase 1**: API is cleaner, no golden regressions  
**Phase 2**: 18 machines have topologies, all validated  
**Phase 3**: Topology coverage is visible in CI/CD  
**Phase 4**: Client machines can use topology-driven networking  
**Phase 5**: Invalid topologies are caught at eval time  

---

## Section 12: Documentation Requirements

### Documents to Create/Update

| Document | Phase | Owner |
|----------|-------|-------|
| AGENTS.md | 1 | Update mk*.nix API docs |
| topology-schema.md | 2 | Expand client topology examples |
| lib/topology/default.nix | 1 | Add docstring explaining exports |
| documentation/phase-2-rollout-log.md | 2 | Per-machine notes, blockers |
| documentation/client-topology-guide.md | 4 | How to create client topology file |
| documentation/lib-topology-design.md | 7 | Design decisions from Section 8 |
| tests/topology-validation.nix | 5 | Test suite documentation |
| README for real-topology/ | 1-5 | Overview of topology structure |

### Example Documentation: Client Topology Guide

```markdown
# Client Topology Configuration Guide

## Overview

Client machines (non-hub machines) declare their position in the network
and how to reach the hub. This guide explains how to create a client topology file.

## Quick Start

Copy the template and customize:

\`\`\`bash
cp real-topology/_template.nix real-topology/<hostname>.nix
\`\`\`

Edit with your machine's details:

\`\`\`nix
{ lib }:
{
  domain = "johnbargman.net";
  
  lan = {
    subnet = "10.88.128.0/24";
    gateway = "10.88.128.1";
    hosts.<hostname> = {
      ip = "10.88.128.XX";
      mac = "aa:bb:cc:dd:ee:ff";
      routing = { tailscale = true; wireguard = true; };
    };
  };
  
  hub = {
    name = "cortex-alpha";
    wireguard = {
      interface = "wireg0";
      ip = "10.88.130.XX/24";
      endpoint = "cortex-alpha.johnbargman.net";
      endpointPort = 51820;
    };
    tailscale = {
      enable = true;
    };
  };
}
\`\`\`

## Fields Explained

- **domain**: Your network domain
- **lan.subnet**: The subnet your machine is on
- **lan.hosts.<hostname>**: Your machine's static IP and MAC
- **hub.wireguard**: WireGuard client config (if `routing.wireguard = true`)
- **hub.tailscale**: Tailscale client config (if `routing.tailscale = true`)

## Validation

Run `nix flake check` to validate your topology.

## Deployment

Machine imports modules/enable-wg-topology to use the topology:

\`\`\`nix
# machines/<hostname>/default.nix
{
  imports = [
    ../../modules/enable-wg-topology
  ];
  
  secrix.services.wireguard-wireg0.secrets.<hostname>.encrypted.file =
    ../../secrets/private_keys/wireguard/wg_<hostname>;
}
\`\`\`

## WireGuard Private Key Setup

The private key is encrypted and managed by secrix:

\`\`\`bash
# Generate key (one-time setup)
wg genkey > wg_<hostname>
wg pubkey < wg_<hostname> > wg_<hostname>.pub

# Encrypt with secrix
secrix encrypt wg_<hostname> secrets/private_keys/wireguard/wg_<hostname>

# Commit public key
git add secrets/public_keys/wireguard/wg_<hostname>.pub
\`\`\`

## Troubleshooting

**Error: "Host not found in topology"**  
→ Verify your hostname matches `networking.hostName` and is in `lan.hosts`

**Error: "Hub config missing 'wireguard' section"**  
→ Set `hub.wireguard` if `routing.wireguard = true`

**WireGuard interface doesn't come up**  
→ Check secrix is decrypting the key: `systemctl status secrix-decrypt`
```

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| **Hub** | Central router machine managing entire network (cortex-alpha) |
| **Client** | Non-hub machine connecting to hub via WireGuard/Tailscale |
| **Topology** | Network reality file (real-topology/<hostname>.nix) |
| **Golden Test** | Captured config snapshot for regression testing |
| **Transformation Function** | mk*.nix function converting topology data to NixOS config |
| **Validation** | Structural (schema check) and cross-reference (consistency check) |
| **Cross-Reference** | Reference from one section to another (e.g., forwarding → IP) |

---

## Appendix B: File Structure After All Phases

```
real-topology/
├── _template.nix
├── cortex-alpha.nix              (hub)
├── local-nas.nix                 (client)
├── storage-array.nix             (client)
├── terminal-zero.nix             (client)
├── terminal-nx-01.nix            (client)
├── alpha-one.nix                 (client)
├── alpha-two.nix                 (client)
├── alpha-three.nix               (client)
├── LINDA.nix                     (client)
├── gaming-host-1.nix             (client)
├── remote-worker.nix             (client)
├── remote-builder.nix            (client)
├── default.nix                   (golden test generator)
└── golden/
    ├── cortex-alpha.json
    ├── local-nas.json
    ├── storage-array.json
    ├── terminal-zero.json
    ├── ... (15+ total)

lib/topology/
├── default.nix                   (canonical export, Phase 1)
├── mkWireguardPeers.nix          (refactored, Phase 1)
├── mkTailscaleConfig.nix         (standardized, Phase 1)
├── mkDhcpDns.nix                 (standardized, Phase 1)
├── mkNginxProxies.nix            (standardized, Phase 1)
├── mkForwarding.nix              (error handling, Phase 1)
├── mkWireguardClient.nix         (new, Phase 4)
├── mkTailscaleClient.nix         (new, Phase 4)
├── validate.nix                  (extended, Phase 5)
├── utils.nix                     (extended, Phase 5)

modules/
├── core-router.nix               (refactored to use lib/topology, Phase 1)
├── enable-wg-topology.nix        (new, Phase 4)

tests/
├── topology-validation.nix       (new, Phase 5)
├── topology-coverage.nix         (new, Phase 3)

documentation/
├── topology-expansion-plan.md    (this document)
├── lib-topology-design.md        (design decisions, Phase 1)
├── client-topology-guide.md      (new, Phase 4)
├── phase-2-rollout-log.md        (new, Phase 2)
├── topology-generator-issues.md  (updated with resolutions)
```

---

## Appendix C: Script Templates

### Phase 2: Topology Creation Script

```bash
#!/usr/bin/env bash
# scripts/create-topology.sh <hostname>
# Quick topology file creation for a machine

set -e

HOSTNAME="${1:?Usage: create-topology.sh <hostname>}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOPOLOGY_FILE="$REPO_ROOT/real-topology/$HOSTNAME.nix"

if [ -f "$TOPOLOGY_FILE" ]; then
  echo "Topology file already exists: $TOPOLOGY_FILE"
  exit 1
fi

# Get IP from machine config or prompt user
if [ -f "$REPO_ROOT/machines/$HOSTNAME/default.nix" ]; then
  IP=$(grep -oP 'networking\.interfaces\.[^ ]+.*ip = "\K[^"]+' "$REPO_ROOT/machines/$HOSTNAME/default.nix" 2>/dev/null | head -1)
fi

IP="${IP:-10.88.128.XXX}"

# Create topology file
cat > "$TOPOLOGY_FILE" << EOF
{ lib }:
{
  domain = "johnbargman.net";
  
  lan = {
    subnet = "10.88.128.0/24";
    gateway = "10.88.128.1";
    hosts.$HOSTNAME = {
      ip = "$IP";
      mac = "TODO";
      routing = {
        tailscale = false;
        wireguard = false;
      };
    };
  };
}
EOF

echo "Created: $TOPOLOGY_FILE"
echo "Edit the file and replace TODO values, then run: nix flake check"
```

### Phase 3: Coverage Report

```bash
#!/usr/bin/env bash
# scripts/topology-report.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Topology Coverage Report ==="
echo ""

# Extract x86_64 machines from flake.nix
X86_MACHINES=$(nix eval --json '.#nixosConfigurations' 2>/dev/null | jq -r 'keys[]' | sort)

COVERED=0
TOTAL=0

for machine in $X86_MACHINES; do
  TOTAL=$((TOTAL + 1))
  
  if [ -f "real-topology/$machine.nix" ]; then
    if [ -f "real-topology/golden/$machine.json" ]; then
      echo "  ✓ $machine (topology + golden)"
      COVERED=$((COVERED + 1))
    else
      echo "  ~ $machine (topology, no golden)"
    fi
  else
    echo "  ✗ $machine (missing topology)"
  fi
done

echo ""
PERCENT=$((COVERED * 100 / TOTAL))
echo "Coverage: $COVERED/$TOTAL machines ($PERCENT%)"
```

---

**End of Document**

---

**Document Control**:
- **Status**: Planning (Pre-Implementation)
- **Last Updated**: 2026-05-06
- **Next Review**: After Phase 1 completion
- **Owner**: DarthPJB NixOS Configuration Maintainers
