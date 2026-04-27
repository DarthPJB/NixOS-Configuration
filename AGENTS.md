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

### Topology-Driven Router Configuration

The topology-driven architecture follows a pattern: topology data → transformation functions → core-router module.

**Data Flow:**
```
real-topology/cortex-alpha.nix (topology data)
         ↓
lib/topology/*.nix (transformation functions)
         ↓
modules/core-router.nix (NixOS config generation)
```

**Files:**
- `real-topology/cortex-alpha.nix` - Topology data (peers, hosts, firewall, etc.)
- `real-topology/default.nix` - Golden test generator
- `real-topology/golden/cortex-alpha.json` - Golden test reference (generated from main)
- `lib/topology/mkWireguardPeers.nix` - WireGuard peer transformation (requires `self`)
- `lib/topology/mkTailscaleConfig.nix` - Tailscale configuration
- `lib/topology/mkDhcpDns.nix` - DHCP/DNS configuration
- `lib/topology/mkNginxProxies.nix` - Nginx proxy configuration
- `lib/topology/validate.nix` - Topology validation (NOT YET INTEGRATED)
- `modules/core-router.nix` - Core router module

**Transformation Function Signatures (INCONSISTENT - see TG-003):**
```nix
# mkWireguardPeers.nix - uses self for key file paths
{ lib, topology, self }: ...

# mkTailscaleConfig.nix - curried
{ lib }: topology: ...

# mkNginxProxies.nix - takes config object
{ lib }: { topology, ... }: ...
```

**Known Issues:**
See `documentation/topology-generator-issues.md` for full list. Critical:
- TG-001: validate.nix not integrated
- TG-002: Silent peer/host failures
- TG-005: Hardcoded nginx listen addresses

### Module Responsibilities

**core-router.nix** (hub machines):
- WireGuard interface configuration (via topology)
- Tailscale route advertisement (via topology)
- DHCP/DNS configuration (via topology)
- Firewall rules (via topology)
- Nginx proxy configuration (via topology)

**enable-wg.nix** (client machines ONLY):
- WireGuard client configuration (connecting TO hub)
- Do NOT import for hub machines like cortex-alpha

## Common Tasks

### Validate Topology Configuration
```bash
nix run .#check-network -- cortex-alpha
```

### Generate Golden from Main
```bash
git worktree add /tmp/nixos-main main
mkdir -p /tmp/nixos-main/real-topology
cp real-topology/default.nix /tmp/nixos-main/real-topology/
cd /tmp/nixos-main && nix eval --json --impure --expr '...' | jq -S . > golden.json
git worktree remove /tmp/nixos-main --force
```

### Dump Full Configuration
```bash
nix run .#dump-config -- cortex-alpha > config.json
```

### Compare Between Revisions
```bash
./scripts/compare-configs.sh cortex-alpha main HEAD
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