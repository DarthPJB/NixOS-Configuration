# NixOS Topology-Driven Configuration: Canonical Architecture

**Document Status**: Architecture Standard (Authoritative)  
**Created**: 2026-05-06  
**Revised**: 2026-05-06  
**Scope**: Complete network topology in a single file; transformation-driven configuration  
**Repository**: `/speed-storage/repo/DarthPJB/NixOS-Configuration`

---

## Executive Summary

This document is the **authoritative specification** for topology-driven configuration in this repository. A SINGLE `topology.nix` file describes the ENTIRE network. Machines are attribute set keys with minimal essential data (WireGuard IPs, LAN mappings, peer lists, proxy declarations). Everything else — WireGuard peer configs, firewall rules, DNS entries, nginx virtualHosts, nftables forwarding — is derived through deterministic computation.

The architecture separates **data** (topology.nix), **transformation** (mk*Settings), and **generation** (gen*), enabling regression testing via golden files, validation of cross-service consistency, and clean separation of concerns.

---

## Section 1: Architecture Standard (AUTHORITATIVE)

### 1.1 Core Principle: One File, Minimal Data, Everything Derived

The entire network is declared in **one file**: `topology.nix` at the repository root.

```nix
{...}:
{
  beta-one   = { wireguard = "10.88.128.53"; lan = { "192.51.31.10" = "enpf0s2"; }; };
  beta-two   = { wireguard = "10.88.128.54"; lan = { "192.51.31.31" = "enps0"; }; };
  cortex-beta = {
    wireguard = "10.88.128.1";
    lan = { "192.51.31.1" = "enps1"; };
    uplink = { "83.12.23.44" = "enps2"; };
    peers = [ "beta-two" "beta-one" ];
    nginx-proxy = { "grafana.johnbargman.net" = "beta-two:3000"; };
  };
}
```

**Each machine is an attrset key.** Each declares ONLY what's essential:

**Client Machine Fields**:
- `wireguard` — WireGuard IP address (single string, not CIDR — /32 derived)
- `lan` — Optional. Attrset mapping LAN IP → interface name. Only if machine has LAN presence.

**Hub Machine Fields (additional)**:
- `uplink` — Optional. Attrset mapping WAN IP → interface name
- `peers` — List of hostnames this hub serves
- `nginx-proxy` — Optional. Attrset mapping hostname → "backend:port"

**That's it.** No firewall ports, no DNS entries, no WireGuard listen ports, no interface config beyond IP ↔ interface mapping. **ALL of that is derived.**

### 1.2 What the Transformer Derives

| Derived Output | Source |
|---|---|
| WireGuard hub config (listen port, interface, all peers) | `peers` list + all `wireguard` IPs in topology |
| WireGuard client config (connects to hub) | Machine's `wireguard` IP + hub's `peers` containing this hostname |
| Firewall ports | `nginx-proxy` backends + WireGuard + SSH (standard ports) |
| nginx virtualHosts | `nginx-proxy` entries |
| DNS entries | `nginx-proxy` hostnames → hub's LAN IP (nginx listens there) |
| nftables forwarding | `nginx-proxy` backends (WAN → client) |
| DHCP reservations | `lan` entries |
| LAN interface config | `lan` IP → interface mapping |
| NAT/masquerade | `uplink` interface + subnet |

### 1.3 Two-Layer Architecture: Transformer → Generator

```
topology.nix (single file, minimal data)
      │
      ▼
  mkSettings (reads topology, derives everything, reads key files)
      │
      ▼
  genConfig (settings + hostname → NixOS config for THAT machine)
```

#### Layer 1: Transformer (`mk*Settings`)

**Responsibility**: I/O and validation

**Signature**:
```nix
{ lib }: topology: {
  # Pure data output (flat structure)
  setting1 = value;
  setting2 = value;
  peers = { name = { ... }; };  # attrset keyed by hostname
  warnings = [ "..." ];
}
```

**Behavior**:
- Reads the SINGLE topology.nix
- Reads WireGuard public key files by convention: `secrets/public_keys/wireguard/wg_${hostname}_pub`
- Performs cross-section validation (forwarding targets exist, nginx backends reachable, etc.)
- Returns a FLAT pure data structure
- Handles missing files gracefully: warning + skip, not hard error
- **OWNS ALL I/O** — no file reads in generators

**Example: `mkWireguardSettings`**

```nix
{ lib }: topology:

let
  # Determine which machine we're building config for
  # (passed via context, e.g., in core-router.nix)
  
  # Read all WireGuard public keys by convention
  readPublicKey = hostname:
    let
      path = ../../secrets/public_keys/wireguard/wg_${hostname}_pub;
    in
    if builtins.pathExists path
    then {
      key = builtins.readFile path;
      missing = false;
    }
    else {
      key = "<missing>";
      missing = true;
    };
  
  # Collect all hostnames (both hubs and clients)
  allHostnames = builtins.attrNames topology;
  
  # For each hostname, read its public key
  peerPublicKeys = builtins.listToAttrs (map (hostname: {
    name = hostname;
    value = readPublicKey hostname;
  }) allHostnames);
  
  # Track missing keys as warnings
  missingKeyWarnings = lib.concatMap (hostname:
    if peerPublicKeys.${hostname}.missing
    then [ "Missing WireGuard public key for ${hostname} at secrets/public_keys/wireguard/wg_${hostname}_pub" ]
    else []
  ) allHostnames;
  
in
{
  interface = "wireg0";
  listenPort = 2108;
  
  # All peers with their resolved public keys
  peers = builtins.mapAttrs (hostname: keyData: {
    publicKey = keyData.key;
    wireguardIp = topology.${hostname}.wireguard;
    isHub = (topology.${hostname} ? peers);  # hub has peers field
  }) peerPublicKeys;
  
  warnings = missingKeyWarnings;
}
```

#### Layer 2: Generator (`gen*`)

**Responsibility**: Pure transformation to NixOS config

**Signature**:
```nix
{ lib }: { settings, hostname }: {
  # NixOS module config
}
```

**Behavior**:
- Takes transformer output + hostname
- Produces NixOS module config for THAT specific machine
- Works for **both hub AND client** — distinction is emergent from data
- Pure function: no file I/O, no side effects
- Testable in isolation with mock data

**Example: `genWireguard`**

```nix
{ lib }: { settings, hostname }:

let
  # Look up this machine's data
  thisMachine = settings.peers.${hostname};
  hubMachine = lib.findFirst (m: m.isHub) null (builtins.attrValues settings.peers);
  
  # Decision: are we the hub?
  isHub = thisMachine.isHub;
  
in

if isHub then
  # HUB CONFIG: listen on all IPs, include all peers
  {
    networking.wireguard.interfaces.wireg0 = {
      ips = [ 
        "10.88.127.1/32"          # WireGuard interface IP
        "10.88.127.0/24"          # WireGuard allocation range
      ];
      listenPort = settings.listenPort;
      privateKeyFile = <secrix path for hub private key>;
      peers = lib.mapAttrsToList (name: data:
        # Include all non-hub peers
        lib.optionalAttrs (!data.isHub) {
          publicKey = data.publicKey;
          allowedIPs = [ "${data.wireguardIp}/32" ];
        }
      ) settings.peers;
    };
  }
else
  # CLIENT CONFIG: connect to hub as endpoint
  {
    networking.wireguard.interfaces.wireg0 = {
      ips = [ "${thisMachine.wireguardIp}/32" ];
      privateKeyFile = <secrix path for client private key>;
      peers = [
        {
          publicKey = hubMachine.publicKey;
          allowedIPs = [ "10.88.127.0/24" ];
          endpoint = "cortex-alpha.johnbargman.net:${toString settings.listenPort}";
          persistentKeepalive = 25;
        }
      ];
    };
  }
```

### 1.4 Hub vs Client Emergence

The SAME generator, given the same data but different hostnames, produces the correct config:

- `genWireguard { settings, hostname = "cortex-alpha" }` → Hub config (has `peers` field) → listen + all peers
- `genWireguard { settings, hostname = "beta-one" }` → Client config (no `peers` field) → connect to hub

**The topology data knows who the hub is** (it has the `peers` field). The generator looks up the hostname and acts accordingly.

### 1.5 Cross-Service Derivation Example

When the topology declares:

```nix
cortex-alpha = {
  wireguard = "10.88.127.1";
  lan = { "10.88.128.1" = "enps1"; };
  peers = [ "beta-one" "beta-two" ];
  nginx-proxy = {
    "grafana.johnbargman.net" = "beta-two:3000";
  };
};
```

The transformer derives:

1. **nginx**: virtualHost for `grafana.johnbargman.net` → proxy_pass to `10.88.128.54:3000` (beta-two's WireGuard IP)
2. **firewall**: port 3000 open on wireg0 interface
3. **DNS**: `grafana.johnbargman.net` → hub's LAN IP (`10.88.128.1`)
4. **nftables**: WAN:3000 → `10.88.128.54:3000` (for external access)
5. **assertions**: Validates that beta-two exists and is reachable

All from a single declaration.

### 1.6 Flat Data Structure Rules

The transformer output MUST be predominantly flat. Nesting is allowed ONLY when:
1. A group of attributes forms a logical unit (e.g., `hub = { name, ips, endpoint }`)
2. The number of attributes in the group is 3+
3. The group is referenced as a unit by the generator

**Flatness Rules**:
- Top-level keys: simple strings (`interface`, `listenPort`, `machineIp`)
- Peer data: attrset keyed by hostname (flat lookup structure)
- Warnings/errors: flat lists
- Avoid deep nesting (>2 levels)
- Avoid single-attribute nesting

**Example Structure**:

```nix
{
  # Simple scalar values
  interface = "wireg0";
  listenPort = 2108;
  
  # Logical unit (3+ attributes)
  hub = {
    ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
    endpoint = "cortex-alpha.johnbargman.net";
    port = 2108;
  };
  
  # Attrset keyed by hostname (flat lookup)
  peers = {
    "cortex-alpha" = { publicKey = "..."; ip = "10.88.127.1"; isHub = true; };
    "beta-one" = { publicKey = "..."; ip = "10.88.128.53"; isHub = false; };
  };
  
  # Flat lists
  warnings = [];
}
```

### 1.7 Graceful Degradation

| Condition | Behavior |
|---|---|
| topology.nix missing | `coreRouter.enable = false;` + warning in build |
| WireGuard key file missing for peer | Peer skipped + warning; other peers configured |
| Forwarding target not in topology | **Assertion error** with clear message |
| Nginx backend unreachable | **Assertion error** with clear message |
| Cross-service validation fails | **Assertion error** listing ALL failures |

**Principle**:
- **Warnings** for optional/missing data (graceful skip)
- **Assertions** for broken invariants (deployment fails clearly)

### 1.8 Cross-Service Validation (CRITICAL)

When a service connection is declared, ALL required infrastructure is validated.

**Example: Nginx proxy from cortex-alpha to beta-two**

Topology declares:
```nix
nginx-proxy = { "grafana.johnbargman.net" = "beta-two:3000"; }
```

System MUST validate:
1. `beta-two` exists in topology
2. Port 3000 is open on WireGuard interface
3. WireGuard peer configuration enables connectivity
4. If backend is on client, client has WireGuard enabled

**Validation Rules**:

| Service Connection | Required Validation |
|---|---|
| **Nginx proxy → backend** | Backend hostname exists; port open on transport; transport enabled on both sides |
| **Port forwarding → target** | Target hostname exists; port matches service declaration; firewall allows |
| **WireGuard peer → host** | Host exists; has wireguard IP; public key file exists |
| **DNS entry → IP** | IP exists in topology; service runs (if declared) |

**Error Output**:
```
assertion error:
Topology validation failed:
  - Nginx proxy 'grafana' targets unknown backend 'unknown-host'
  - Nginx proxy 'grafana' backend port 3000 not allowed on WireGuard interface
  - WireGuard peer 'beta-one' missing public key at secrets/...
```

### 1.9 Golden Test Integration

Every machine in nixosConfigurations MUST have a golden test:

1. Topology data exists for the machine
2. Transformer produces settings
3. Generator produces NixOS config
4. Capture network-relevant config as golden JSON
5. Future changes that alter config break golden test
6. Intentional changes require regenerating golden file

**Lifecycle**:
```bash
# Initial creation
nix run .#check-network -- cortex-alpha > real-topology/golden/cortex-alpha.json

# During CI/CD
nix run .#check-network -- cortex-alpha --compare
# Fails if current output != golden file

# After intentional change
nix run .#check-network -- cortex-alpha > real-topology/golden/cortex-alpha.json
git add real-topology/golden/cortex-alpha.json
git commit -m "topology: update golden for cortex-alpha"
```

**Coverage Requirement**:
- `nix flake check` includes topology-coverage test
- For every machine in `nixosConfigurations`, topology data must exist
- Missing topology = warning (Phase 1), error (Phase 2+)

### 1.10 Naming Conventions

All file paths are derived from hostname:

| Convention | Pattern | Example |
|---|---|---|
| Topology data | Single file: `topology.nix` | `topology.nix` (shared) |
| WireGuard public key | `secrets/public_keys/wireguard/wg_${hostname}_pub` | `secrets/public_keys/wireguard/wg_cortex-alpha_pub` |
| WireGuard private key | `secrets/private_keys/wireguard/wg_${hostname}` (via secrix) | `secrets/private_keys/wireguard/wg_cortex-alpha` |
| Golden test | `real-topology/golden/${hostname}.json` | `real-topology/golden/cortex-alpha.json` |
| NixOS configuration | `nixosConfigurations.${hostname}` | `nixosConfigurations.cortex-alpha` |

---

## Section 2: Special Extensions and Exceptions

The minimal topology covers 90% of cases. For the remaining 10%, optional extensions:

### 2.1 Extra Firewall Ports

Open specific ports not derived from services:

```nix
cortex-alpha = {
  # ... standard fields ...
  firewall = {
    tcp = [ 2208 ];              # SSH to NAS from WAN
    udp = [ 17780 17781 17782 ]; # Game ports
  };
};
```

### 2.2 Custom Proxy Destinations

Proxy to external IP not in topology:

```nix
cortex-alpha = {
  # ... standard fields ...
  nginx-proxy = {
    # Standard: derives from topology
    "grafana.johnbargman.net" = "beta-two:3000";
    
    # Special: external destination
    "legacy.johnbargman.net" = { 
      backend = "192.168.1.50:8080";  # External IP
      listenAddresses = [ "82.5.173.252" ];  # Override default listen
    };
  };
};
```

### 2.3 Routing Exceptions

Non-standard routing rules:

```nix
cortex-alpha = {
  # ... standard fields ...
  routing = {
    # Static routes to external networks
    static = {
      "10.0.0.0/8" = "10.88.128.254";  # Route to VPN
    };
    # Policy routing
    policy = [
      { from = "10.88.128.0/24"; to = "10.0.0.0/8"; table = 100; }
    ];
  };
};
```

### 2.4 Hub-of-Hubs Topology

Complex topologies with nested hubs:

```nix
{...}:
{
  # Top-level hub (internet-facing)
  cortex-alpha = {
    wireguard = "10.88.127.1";
    lan = { "10.88.128.1" = "enps1"; };
    uplink = { "82.5.173.252" = "enps2"; };
    peers = [ "building-b" "building-c" ];
    nginx-proxy = { ... };
  };
  
  # Sub-hub (serves a building)
  building-b = {
    wireguard = "10.88.127.100";
    lan = { "10.89.128.1" = "enps3"; };
    peers = [ "office-1" "office-2" ];      # Serves these
    hub = "cortex-alpha";                   # Is client of this
    nginx-proxy = { ... };
  };
  
  # Leaf machines
  office-1 = { wireguard = "10.89.128.10"; };
  office-2 = { wireguard = "10.89.128.11"; };
}
```

In hub-of-hubs: `building-b` is BOTH a hub (has `peers`) AND a client (has `hub`). The generator handles this: if both exist, generate both hub and client config.

---

## Section 3: Implementation Architecture

### 3.1 Transformer Output Structure

Transformers MUST produce a flat data structure with these top-level keys:

```nix
{
  # Metadata
  interface = "wireg0";
  listenPort = 2108;
  
  # Hub designation
  hubName = "cortex-alpha";
  
  # Hub-specific (if this machine IS the hub)
  hub = {
    ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
    endpoint = "cortex-alpha.johnbargman.net";
  };
  
  # This machine's IP
  machineIp = "10.88.127.108/32";
  
  # All peers with resolved keys
  peers = {
    "cortex-alpha" = { publicKey = "abc123..."; ip = "10.88.127.1"; isHub = true; };
    "beta-one" = { publicKey = "def456..."; ip = "10.88.128.53"; isHub = false; };
  };
  
  # Status
  warnings = [ "Missing key for peer X" ];
}
```

### 3.2 Generator Function Signatures

All generators follow this signature:

```nix
{ lib }: { settings, hostname }: {
  # NixOS module config
}
```

**Parameters**:
- `lib` — nixpkgs lib (via `{ lib }:` pattern)
- `settings` — Transformer output (flat data structure)
- `hostname` — This machine's hostname (string)

**Return**: NixOS module config (same as any other NixOS module)

### 3.3 How core-router.nix Consumes the Pattern

```nix
# modules/core-router.nix
{ config, lib, self, ... }:

let
  # Read the shared topology file
  topology = import ../topology.nix { inherit lib; };
  
  # Transform it (once per machine)
  mkWireguardSettings = import ../lib/topology/mkWireguardSettings.nix { inherit lib; };
  wireguardSettings = mkWireguardSettings topology;
  
  # Generate config for THIS machine
  genWireguard = import ../lib/topology/genWireguard.nix { inherit lib; };
  hostname = config.networking.hostName;
  
in
{
  config = lib.mkIf config.coreRouter.enable {
    # Validation assertions
    assertions = [
      {
        assertion = wireguardSettings.warnings == [];
        message = "WireGuard topology warnings: ${builtins.concatStringsSep ", " wireguardSettings.warnings}";
      }
    ];
    
    # Generate config for this machine
    networking.wireguard.interfaces.wireg0 = lib.mkDefault
      (genWireguard { settings = wireguardSettings; inherit hostname; });
  };
}
```

### 3.4 How enable-wg-topology.nix Replaces enable-wg.nix

Unified module for hub AND client:

```nix
# modules/enable-wg-topology.nix
{ config, lib, self, ... }:

let
  topology = import ../topology.nix { inherit lib; };
  mkWireguardSettings = import ../lib/topology/mkWireguardSettings.nix { inherit lib; };
  genWireguard = import ../lib/topology/genWireguard.nix { inherit lib; };
  
  settings = mkWireguardSettings topology;
  hostname = config.networking.hostName;
  
  # Check if this machine is in the topology
  inTopology = builtins.hasAttr hostname topology;
  
in
{
  config = lib.mkIf inTopology {
    assertions = [
      {
        assertion = settings.warnings == [];
        message = "WireGuard topology: ${builtins.concatStringsSep "\n  " settings.warnings}";
      }
    ];
    
    networking.wireguard.enable = true;
    networking.wireguard.interfaces.wireg0 = lib.mkDefault
      (genWireguard { inherit settings hostname; });
  };
}
```

### 3.5 Key File Resolution by Convention

Transformers read public keys by **strict naming convention**:

```nix
# Standard path: secrets/public_keys/wireguard/wg_${hostname}_pub
readPublicKey = hostname:
  let
    path = ../../secrets/public_keys/wireguard/wg_${hostname}_pub;
  in
  if builtins.pathExists path
  then builtins.readFile path
  else "<missing>";
```

Private keys are managed by secrix:

```nix
# In machine config
secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file =
  ../../secrets/private_keys/wireguard/wg_cortex-alpha;

networking.wireguard.interfaces.wireg0.privateKeyFile =
  config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
```

---

## Section 4: Phase Overview & Timeline

### 4.1 Phase Dependencies

```
Phase 1: Implement Single topology.nix + Transformer/Generator Pattern
    ↓
Phase 2: Golden Coverage for All Machines
    ↓
Phase 3: Coverage Meta-Test
    ↓
Phase 4: Cross-Section Validation
    ↓
Phase 5: Extended Network Topologies (Hub-of-Hubs, Complex Routing)
```

### 4.2 Phase Summary

| Phase | Objective | Duration | Exit Criteria |
|-------|-----------|----------|---------------|
| **1** | Implement single `topology.nix` + mk*Settings + gen* pattern | 2-3 weeks | topology.nix exists; transformers produce flat data; generators work for hub + client; cortex-alpha golden passes |
| **2** | Golden coverage for all x86_64 machines | 3-4 weeks | 18 topology entries + 18 golden files; all pass validation |
| **3** | Topology coverage meta-test | 1-2 weeks | `nix flake check` includes completeness check; CI/CD integration |
| **4** | Cross-service validation | 2-3 weeks | Assertions catch invalid references; test suite passes |
| **5** | Extended topologies (hub-of-hubs, complex routing) | 2-3 weeks | Sub-hubs fully functional; golden tests for all patterns |

**Total Estimated Effort**: 10-15 weeks. Phases 2 & 3 can run in parallel.

---

## Section 5: Golden Test Integration

### 5.1 What Golden Tests Capture

Golden tests capture the network-relevant portions of generated NixOS config:
- `networking.wireguard`
- `networking.firewall`
- `services.nginx`
- `services.dnsmasq` or `services.resolved` (DNS)
- `services.tailscale` (if used)

NOT captured (to avoid noise):
- User accounts, permissions
- Package selections
- System packages
- Other service configs unrelated to networking

### 5.2 Creating Golden Tests

For each machine in topology.nix:

```bash
# 1. Ensure topology entry exists
# (see topology.nix, machine's attrset)

# 2. Generate golden file
nix run .#check-network -- cortex-alpha > real-topology/golden/cortex-alpha.json

# 3. Visual audit
cat real-topology/golden/cortex-alpha.json | jq

# 4. Commit
git add real-topology/golden/cortex-alpha.json
git commit -m "topology: add golden test for cortex-alpha"
```

### 5.3 Coverage Requirements

- Every entry in `topology.nix` MUST have a golden test
- `nix flake check` tests golden completeness
- Missing golden = warning (Phase 1), error (Phase 2+)

### 5.4 Updating Golden Tests

When topology changes intentionally:

```bash
# Regenerate
nix run .#check-network -- cortex-alpha > real-topology/golden/cortex-alpha.json

# Review diff
git diff real-topology/golden/cortex-alpha.json

# Commit with clear message
git commit -m "topology: update golden for cortex-alpha (nginx proxy change)"
```

When golden test breaks unexpectedly:
1. DO NOT regenerate without investigation
2. Check what changed: `git diff HEAD -- real-topology/cortex-alpha.nix`
3. Verify the change is intentional
4. Only then regenerate

---

## Section 6: Validation Rules

### 6.1 Cross-Service Assertions

When topology declares a service connection, it's validated:

**WireGuard Peer Validation**:
- Each declared peer exists in topology
- Each peer has public key file at standard path
- Peer's WireGuard IP is in correct subnet
- Hub is reachable

**Nginx Proxy Validation**:
- Backend hostname exists
- Backend port is valid
- Transport path (WireGuard/LAN/Tailscale) is enabled
- Firewall allows traffic

**Port Forwarding Validation**:
- Target hostname exists
- Target port is valid
- Firewall allows forward

**DNS Entry Validation**:
- Target IP exists or is documented as external
- No duplicate entries for same domain

### 6.2 Error vs Warning Policy

**Errors** (block deployment):
- Missing peer in topology
- Topology file invalid
- Cross-reference validation fails
- Critical invariants broken

**Warnings** (log to build output):
- Missing public key file (peer skipped)
- Optional service not configured
- Non-critical validation issues

### 6.3 Missing File Handling

**Missing public key file**:
```nix
# Log warning, skip peer
warnings = [ "Missing public key for beta-one at secrets/public_keys/wireguard/wg_beta-one_pub" ];
# Peer not included in config
```

**Missing topology.nix**:
```nix
# Disable topology-driven networking
# Log error during build
```

**Missing private key (secrix)**:
```nix
# Deployment fails with clear message
# User must generate key and encrypt with secrix
```

---

## Section 7: Implementation Roadmap

### 7.1 Week-by-Week Timeline (Phase 1)

**Week 1: Foundation**
- Consolidate all existing per-machine topology data into single `topology.nix`
- Create template `topology.nix` with current cortex-alpha + 3 client machines
- Create `mkWireguardSettings.nix` (transformer for WireGuard)
- Create `genWireguard.nix` (generator for WireGuard)
- Verify cortex-alpha golden test still passes

**Week 2: Expansion**
- Create `mkNginxSettings.nix` + `genNginx.nix`
- Create `mkFirewallSettings.nix` + `genFirewall.nix`
- Create `mkDnsSettings.nix` + `genDns.nix`
- Integrate all generators into `core-router.nix`
- Test with 5 machines (cortex-alpha + 4 clients)

**Week 3: Validation & Documentation**
- Extend `lib/topology/validate.nix` for cross-service checks
- Create test suite: `tests/topology-validation.nix`
- Update AGENTS.md with new architecture
- Update this document with Phase 2 details
- All goldens still passing

### 7.2 Phase 1 Exit Checklist

- [ ] `topology.nix` exists with current cortex-alpha + sample clients
- [ ] All mk*Settings follow `{ lib }: topology: { }` signature
- [ ] All gen* follow `{ lib }: { settings, hostname }: { }` signature
- [ ] `core-router.nix` uses new architecture
- [ ] `enable-wg-topology.nix` works for hub + client
- [ ] Cortex-alpha golden test passes
- [ ] 5 test machines verified
- [ ] Cross-service validation catches at least 3 error types
- [ ] AGENTS.md updated with new signatures
- [ ] All changes committed with clear messages

### 7.3 Phase 2: Golden Coverage (Weeks 4-7)

**Rollout Strategy**:

**Tier 1** (Weeks 4-5): Simple clients
- `local-nas` — Storage client
- `storage-array` — Storage client

**Tier 2** (Weeks 5-6): Clients with services
- `terminal-zero` — Builder
- `gaming-host-1` — Gaming

**Tier 3** (Week 6-7): Complex services
- `remote-worker` — Web server
- `alpha-three` — Special service (zeroclaw)

### 7.4 Phase 3: Coverage Meta-Test (Weeks 7-8)

- Create `real-topology/coverage.nix` check
- Add to `nix flake check`
- Create `scripts/topology-report.sh`

### 7.5 Phase 4: Validation (Weeks 8-10)

- Extend `validate.nix` with cross-section checks
- Create comprehensive test suite
- Integrate into `core-router.nix`

### 7.6 Phase 5: Extended Topologies (Weeks 10-15)

- Implement hub-of-hubs pattern
- Test with real sub-hub and leaf machines
- Document complex routing patterns

---

## Section 8: Success Criteria

### 8.1 Completion Definition

**A topology-driven network is complete when**:

1. **Single Source of Truth**: All network data in `topology.nix`, no duplicates elsewhere
2. **Minimal Declarations**: Machine entries contain ONLY `wireguard`, `lan`, `uplink`, `peers`, `nginx-proxy`
3. **Complete Derivation**: Every NixOS network config section is derived from topology data
4. **Golden Coverage**: Every machine has golden test; tests pass
5. **Cross-Service Validation**: Invalid references caught with clear error messages
6. **Hub-Client Emergence**: Same generators work for both hub and client
7. **Graceful Degradation**: Missing files/optional data don't break builds; only missing REQUIRED data fails
8. **Documentation**: Architecture documented; team can add machines without guidance

### 8.2 Metrics

- **Topology Coverage**: % of machines in nixosConfigurations that have topology entries
- **Golden Coverage**: % of machines with passing golden tests
- **Validation Pass Rate**: % of topology evaluations passing cross-service checks
- **Code Reduction**: Lines of inline network config removed / lines in topology.nix

### 8.3 Demonstration

By end of all phases:
- Deploy new machine `new-host`: Add 1 entry to `topology.nix`, golden test auto-generates and passes
- Rename machine: Update key in `topology.nix`, all configs update automatically
- Change service port: Update `nginx-proxy` entry, firewall/nginx/DNS all update, golden test catches if rules break
- Add hub: Update `peers` list in hub topology, all clients auto-configured, golden tests pass

---

## Section 9: Delegation Patterns and Workflow

### 9.1 Fleet of Specialized Agents

The project uses a fleet of specialized agents, each with distinct responsibilities:

#### Primary Implementation
- **bellana-grok-code**: Primary engineering agent for all Nix implementation tasks (transformers, generators, module integration, code changes)
- **bellana-codex**: Used for reviews, tests, and periodic validation of bellana-grok-code's work

#### Planning and Validation
- **tpol-minimax**: Validates RESULTS of bellana-grok-code's work at periodic review stages. Also handles research prep and synthesis.
- **hoshi-xai**: Validates DESIGNS before implementation. Also handles research and analysis tasks.

#### Documentation
- **ezri-claude-haiku**: Makes all documentation updates. Creates and maintains planning docs, architecture docs, and session status updates.

#### Analysis
- **tuvok-deepseek**: Logical analysis, adversarial probing, edge case detection. Used for test design and validation.

### 9.2 Workflow Pattern

For each discrete implementation step:

```
1. hoshi-xai validates the design (if design-related)
2. bellana-grok-code implements
3. tpol-minimax validates results at review stage
4. bellana-codex runs reviews/tests periodically
5. User approves before moving to next step
```

For documentation tasks:
```
1. ezri-claude-haiku writes/updates documentation
2. User reviews
```

### 9.3 Agent Responsibilities by Phase

#### Phase 1: Implement Single topology.nix + Transformer/Generator

| Task | Agent | Notes |
|------|-------|-------|
| P1.1: Consolidate topology.nix | bellana-grok-code | Read existing real-topology/cortex-alpha.nix, create new topology.nix |
| P1.2: Create mkWireguardSettings.nix | bellana-grok-code | Transformer: reads topology, reads key files, returns flat data |
| P1.3: Create genWireguard.nix | bellana-grok-code | Generator: settings + hostname → NixOS wireguard config |
| P1.4: Create mkNginxSettings.nix + genNginx.nix | bellana-grok-code | Transformer + generator for nginx |
| P1.5: Create mkFirewallSettings.nix + genFirewall.nix | bellana-grok-code | Transformer + generator for firewall |
| P1.6: Create mkDnsSettings.nix + genDns.nix | bellana-grok-code | Transformer + generator for DNS/DHCP |
| P1.7: Integrate into core-router.nix | bellana-grok-code | Replace current imports with new pattern |
| P1.8: Create enable-wg-topology.nix | bellana-grok-code | Unified hub+client WireGuard module |
| P1.9: Verify cortex-alpha golden | tpol-minimax | Validate results |
| P1.10: Test 5 machines | bellana-codex | Review and test |
| P1.11: Update AGENTS.md | ezri-claude-haiku | Documentation |

#### Phase 2: Golden Coverage

| Task | Agent | Notes |
|------|-------|-------|
| P2.1: Add machines to topology.nix | bellana-grok-code | Data entry |
| P2.2: Generate golden tests | bellana-grok-code | Scripted process |
| P2.3: Visual audit | tpol-minimax | Validate results |

#### Phase 3: Coverage Meta-Test

| Task | Agent | Notes |
|------|-------|-------|
| P3.1: Create topology-coverage.nix | bellana-grok-code | Nix implementation |
| P3.2: Integrate into flake check | bellana-grok-code | Flake integration |
| P3.3: Create report script | bellana-grok-code | Shell scripting |

#### Phase 4: Cross-Service Validation

| Task | Agent | Notes |
|------|-------|-------|
| P4.1: Extend validate.nix | bellana-grok-code | Nix implementation |
| P4.2: Create test suite | tuvok-deepseek (design) + bellana-grok-code (impl) | Test design + implementation |
| P4.3: Integrate assertions | bellana-grok-code | Code integration |

#### Phase 5: Extended Topologies

| Task | Agent | Notes |
|------|-------|-------|
| P5.1: Hub-of-hubs pattern | tpol-minimax (design) + bellana-grok-code (impl) | Design + implementation |
| P5.2: Complex routing | tpol-minimax (design) + bellana-grok-code (impl) | Design + implementation |
| P5.3: Golden tests | bellana-grok-code | Implementation |

### 9.4 Rules

1. Always provide clear and complete instructions to each agent
2. Run to completion to halting issues
3. tpol-minimax validates results at periodic review stages
4. hoshi-xai validates designs before implementation
5. bellana-codex runs reviews/tests periodically
6. ezri-claude-haiku makes all documentation updates

---

## Section 10: Architecture Decisions & Rationale

### 10.1 Why Single topology.nix?

**Single File**:
- One source of truth (no sync issues)
- Easier to understand network holistically
- Smaller surface area for validation
- Simpler to version control

**Alternative Considered**: Per-machine topology files (cortex-alpha.nix, beta-one.nix, etc.)
- **Rejected**: Creates sync problems, hubs must import client files, client data duplication

### 10.2 Why Two-Layer (Transformer + Generator)?

**Transformer** (I/O + validation):
- Centralizes all file reads
- Single place to handle missing keys/files gracefully
- Can validate full network holistically

**Generator** (pure function):
- Testable in isolation with mock data
- Works for both hub and client (emergent distinction)
- No side effects, deterministic

**Alternative Considered**: Single function doing both
- **Rejected**: Mixes I/O with logic, hard to test

### 10.3 Why Minimal Data Declarations?

**Principle**: Declare facts, derive opinions.

- `wireguard = "10.88.127.1"` is a **fact** (machine's IP)
- `listenPort = 2108` is an **opinion** derived from "this is a WireGuard interface"
- `firewall.tcp = [22, 80, 443]` is an **opinion** derived from "this machine has SSH, nginx, etc."

**Alternative Considered**: Declare everything (per-machine topology with full config)
- **Rejected**: Leads to inconsistency, duplication, harder to change

### 10.4 Why Assertions for Validation?

**Assertions block deployment with clear message**: User sees exactly what's wrong.

**Alternative Considered**: Build warnings only
- **Rejected**: Broken configs would silently deploy

---

## Section 11: Troubleshooting Guide

### 11.1 "Missing WireGuard public key"

**Error**: 
```
WARNING: Missing public key for beta-one at secrets/public_keys/wireguard/wg_beta-one_pub
```

**Solution**:
1. Generate key: `wg genkey > wg_beta-one`
2. Extract public: `wg pubkey < wg_beta-one > wg_beta-one.pub`
3. Encrypt private: `secrix encrypt wg_beta-one secrets/private_keys/wireguard/wg_beta-one`
4. Commit public: `git add secrets/public_keys/wireguard/wg_beta-one.pub`
5. Re-eval: `nix flake check`

### 11.2 "Nginx backend not found"

**Error**:
```
assertion error:
Nginx proxy 'grafana.johnbargman.net' targets unknown backend 'unknown-host'
```

**Solution**:
1. Check topology.nix: Is `unknown-host` an entry? If not, add it.
2. If backend is external, use extended syntax:
   ```nix
   nginx-proxy = {
     "grafana" = { backend = "192.168.1.50:3000"; };
   };
   ```

### 11.3 "Golden test mismatch"

**Error**:
```
golden test for cortex-alpha failed: output differs from golden file
```

**Solution**:
1. Check what changed: `git diff -- topology.nix real-topology/golden/cortex-alpha.json`
2. Is it intentional? If yes:
   ```bash
   nix run .#check-network -- cortex-alpha > real-topology/golden/cortex-alpha.json
   git add real-topology/golden/cortex-alpha.json
   git commit -m "topology: update golden for cortex-alpha (intentional change)"
   ```
3. If no, revert topology change and rebuild.

### 11.4 "This machine not in topology"

**Error**:
```
assertion error:
networking.hostName 'new-host' not found in topology.nix
```

**Solution**:
1. Add entry to topology.nix:
   ```nix
   new-host = { wireguard = "10.88.127.99"; lan = { "10.88.128.99" = "eth0"; }; };
   ```
2. Generate golden: `nix run .#check-network -- new-host > real-topology/golden/new-host.json`
3. Commit: `git add topology.nix real-topology/golden/new-host.json && git commit -m "topology: add new-host"`

---

## Appendix: File Locations Reference

| File | Purpose | Status |
|---|---|---|
| `topology.nix` | Single source of truth for entire network | Phase 1 |
| `lib/topology/mkWireguardSettings.nix` | Transformer for WireGuard config | Phase 1 |
| `lib/topology/genWireguard.nix` | Generator for WireGuard (hub + client) | Phase 1 |
| `lib/topology/mkNginxSettings.nix` | Transformer for nginx proxies | Phase 2 |
| `lib/topology/genNginx.nix` | Generator for nginx | Phase 2 |
| `lib/topology/validate.nix` | Validation functions | Phase 4 |
| `lib/topology/utils.nix` | Helper functions | Phase 1 |
| `real-topology/golden/` | Golden test files (one per machine) | Phase 2+ |
| `modules/core-router.nix` | Hub machine module (uses topology) | Phase 1 |
| `modules/enable-wg-topology.nix` | Unified hub+client module | Phase 1 |
| `tests/topology-validation.nix` | Validation test suite | Phase 4 |
| `scripts/topology-report.sh` | Coverage report script | Phase 3 |

---

**Last Updated**: 2026-05-06  
**Next Review**: After Phase 1 completion  
**Maintainer**: Architecture Team
