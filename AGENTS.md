## Architecture

### CRITICAL: Formatter Configuration
**DO NOT CHANGE THE FORMATTER CONFIGURATION** without explicit user approval.
- Current formatter: `nixpkgs.nixpkgs-fmt`
- Check: `lint-utils.linters.x86_64-linux.nixpkgs-fmt`
- These MUST match. Changing one without the other breaks the build.
- Do NOT run `nix fmt` on the entire codebase without explicit permission.

### CRITICAL: Golden Test
The golden test validates topology-driven configuration against main branch:
```bash
nix run .#check-network -- cortex-alpha
```
**DO NOT DEPLOY** if golden test fails. The golden file was generated from main's inline configuration and must match exactly.

### CRITICAL: WireGuard Public Keys
Public keys are read from `secrets/public_keys/wireguard/wg_${name}_pub` files using `builtins.readFile`. The transformation function requires `self` (the flake) to construct paths. **DO NOT use placeholder keys** - the system was broken by this previously.

### CRITICAL: Secrex Private Key
WireGuard private key is managed by secrix:
```nix
secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file =
  ../../secrets/private_keys/wireguard/wg_cortex-alpha;

networking.wireguard.interfaces.wireg0.privateKeyFile =
  config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
```

### Two-Layer Topology Architecture (Current)

The new architecture uses a **single topology source of truth** with a clear two-layer pattern: **Transformers** → **Generators**.

**Architecture Pattern:**
```
topology.nix (single source of truth for entire network)
     ↓
lib/topology/mk*Settings.nix (transformers: topology + files → flat pure data)
     ↓
lib/topology/gen*.nix (generators: settings + hostname → NixOS config)
     ↓
modules/core-router-topology.nix or modules/enable-wg-topology.nix
```

**Core Concept:**
- **One `topology.nix`** at repo root describes the entire network
- Each machine is an attrset key with minimal data
- Transformers read the topology and any required files, returning normalized flat data
- Generators consume settings + hostname and produce machine-specific NixOS configuration
- All golden tests validate against this single source

**Files:**
- `topology.nix` - Single source of truth for entire network topology
- `lib/topology/mkWireguardSettings.nix` - WireGuard transformer (reads topology + key files)
- `lib/topology/genWireguard.nix` - WireGuard generator (settings + hostname → config)
- `lib/topology/mkNginxSettings.nix` - Nginx transformer
- `lib/topology/genNginx.nix` - Nginx generator
- `lib/topology/mkFirewallSettings.nix` - Firewall transformer
- `lib/topology/genFirewall.nix` - Firewall generator
- `lib/topology/mkDnsSettings.nix` - DNS/DHCP transformer
- `lib/topology/genDns.nix` - DNS/DHCP generator
- `lib/topology/mkMonitoringSettings.nix` - Monitoring transformer
- `lib/topology/genMonitoring.nix` - Monitoring generator
- `real-topology/golden/<machine>.json` - Golden test reference (generated from main)
- `modules/core-router-topology.nix` - Hub machine module (uses generators)
- `modules/enable-wg-topology.nix` - Unified WireGuard module for all machines

**Golden Tests:**
- All 12 x86_64 machines have golden tests
- `real-topology/golden/<machine>.json` for each machine
- Validates exact configuration output against main branch
- Must match exactly before deployment

**Module Responsibilities:**

**core-router-topology.nix** (hub machines):
- Imports all gen* modules
- WireGuard interface configuration (via genWireguard)
- Nginx proxy configuration (via genNginx)
- Firewall rules (via genFirewall)
- DNS/DHCP configuration (via genDns)
- Monitoring configuration (via genMonitoring)

**enable-wg-topology.nix** (all machines):
- Unified WireGuard client configuration
- Connecting TO hub machines
- Used by both hub and client machines

### Legacy Topology Architecture (Being Phased Out)

The previous topology-driven architecture used per-machine files:

**Data Flow:**
```
real-topology/cortex-alpha.nix (topology data)
         ↓
lib/topology/*.nix (transformation functions)
         ↓
modules/core-router.nix (NixOS config generation)
```

**Legacy Files:**
- `real-topology/cortex-alpha.nix` - Topology data (peers, hosts, firewall, etc.)
- `real-topology/default.nix` - Golden test generator
- `lib/topology/mkWireguardPeers.nix` - WireGuard peer transformation (requires `self`)
- `lib/topology/mkTailscaleConfig.nix` - Tailscale configuration
- `lib/topology/mkDhcpDns.nix` - DHCP/DNS configuration
- `lib/topology/mkNginxProxies.nix` - Nginx proxy configuration
- `modules/core-router.nix` - Core router module

**Legacy Known Issues:**
- Inconsistent function signatures across transformers
- validate.nix not integrated
- Silent peer/host failures possible
- Hardcoded nginx listen addresses

## Common Tasks

### New Architecture Tasks

#### Validate Against Golden Test
```bash
nix run .#check-network -- cortex-alpha
```
Validates that the current configuration matches the golden test for cortex-alpha.

#### Validate All Machines
```bash
nix run .#check-network -- cortex-alpha
nix run .#check-network -- cortex-beta
nix run .#check-network -- cortex-gamma
# ... for all 12 machines
```

#### Generate New Golden File from Current Configuration
```bash
nix run .#dump-config -- cortex-alpha | jq -S . > real-topology/golden/cortex-alpha.json
```

#### Generate Golden Files for All Machines
```bash
for machine in cortex-alpha cortex-beta cortex-gamma; do
  nix run .#dump-config -- "$machine" | jq -S . > "real-topology/golden/${machine}.json"
done
```

#### Add a New Machine to Topology
1. Edit `topology.nix` and add your machine as an attrset key:
   ```nix
   my-machine = {
     ipAddress = "10.x.x.x";
     # ... other attributes as needed
   };
   ```
2. Create WireGuard public key: `secrets/public_keys/wireguard/wg_my_machine_pub`
3. Create WireGuard private key: `secrets/private_keys/wireguard/wg_my_machine` (via secrix)
4. Enable the topology modules in your machine's NixOS configuration
5. Generate golden test: `nix run .#dump-config -- my-machine | jq -S . > real-topology/golden/my_machine.json`
6. Test: `nix run .#check-network -- my-machine`

#### Dump Full Configuration
```bash
nix run .#dump-config -- cortex-alpha > config.json
```

#### Compare Between Revisions
```bash
./scripts/compare-configs.sh cortex-alpha main HEAD
```

### Legacy Architecture Tasks (Being Phased Out)

These tasks apply to machines still using the old per-file topology architecture.

#### Generate Golden from Main (Legacy)
```bash
git worktree add /tmp/nixos-main main
mkdir -p /tmp/nixos-main/real-topology
cp real-topology/default.nix /tmp/nixos-main/real-topology/
cd /tmp/nixos-main && nix eval --json --impure --expr '...' | jq -S . > golden.json
git worktree remove /tmp/nixos-main --force
```

## Repository Structure
- `real-topology/` - Topology data and golden tests
- `lib/topology/` - Transformation functions
- `modules/` - NixOS modules (core-router.nix, enable-wg.nix)
- `documentation/` - Architecture docs and session status
- `scripts/` - Utility scripts (compare-configs.sh)
- `secrets/` - Encrypted secrets (private keys) and public keys

## Deployment Flow
1. Run golden test: `nix run .#check-network -- cortex-alpha`
2. Verify WireGuard keys exist: `ls secrets/public_keys/wireguard/wg_*_pub`
3. Check for warnings in nix eval output
4. Deploy with appropriate caution