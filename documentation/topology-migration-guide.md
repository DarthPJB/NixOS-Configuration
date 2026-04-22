# Topology-Driven Configuration Migration Guide

## Overview

This guide explains how to migrate existing NixOS machines to use the topology-driven configuration pattern, as successfully implemented for `cortex-alpha`. This pattern separates network topology data from NixOS module logic, providing a single source of truth for network configuration and regression testing.

## Prerequisites

A machine is a good candidate for topology-driven configuration if it meets any of these criteria:

- **Router/Gateway machines**: Machines that route traffic between networks (e.g., `cortex-alpha`)
- **Complex networking**: Machines with multiple network interfaces, bridges, VLANs, or advanced firewall rules
- **Consistent network config needs**: Machines requiring predictable network behavior across deployments
- **Network services**: Machines running DNS, DHCP, VPN, or other network services

### Identifying Candidates

Review machines in your `flake.nix` and check their `machines/<hostname>/default.nix` for:
- Multiple `networking.interfaces` definitions
- `networking.wireguard` or `services.tailscale` configurations
- `services.dnsmasq` or `services.nginx` with multiple virtual hosts
- Custom firewall rules or NAT configurations

Potential candidates in this repository:
- `local-nas` - Network-attached storage with multiple interfaces
- `storage-array` - Storage server with network configuration
- `remote-worker` - Web server with complex nginx configuration
- `LINDA` - Gaming host with WireGuard configuration
- `terminal-zero` - Central builder with DNS services

## Step-by-Step Migration Guide

### 1. Analyze Current Configuration

First, examine the current networking setup:

```bash
# Review the machine's networking configuration
cat machines/<machine-name>/default.nix | grep -A 20 "networking"
```

### 2. Create Topology File

Create `real-topology/<machine-name>.nix` based on the template:

```bash
cp real-topology/_template.nix real-topology/<machine-name>.nix
```

Edit the file to match your machine's network reality. Key sections:

- **domain**: Your domain name (e.g., "johnbargman.net")
- **lan/wan**: Network segments with subnets, gateways, and host definitions
- **hosts**: IP assignments, MAC addresses, routing features

Example for a simple router machine:

```nix
{ ... }:
{
  domain = "johnbargman.net";

  lan = {
    subnet = "10.88.127.0/24";
    gateway = "10.88.127.1";

    hosts = {
      router = {
        ip = "10.88.127.1";
        mac = "aa:bb:cc:dd:ee:ff";
        routing = {
          tailscale = true;
          wireguard = false;
        };
      };
      nas = {
        ip = "10.88.127.3";
        mac = "11:22:33:44:55:66";
        routing = {
          tailscale = false;
          wireguard = false;
        };
      };
    };
  };
}
```

### 3. Create System Configuration File

Create `systems/<machine-name>.nix` following the pattern:

```nix
# systems/<machine-name>.nix
{ ... }:
{
  imports = [
    ../machines/<machine-name>
    ../modules/core-router.nix
  ];
}
```

### 4. Update Flake.nix

Modify `flake.nix` to use the new system configuration:

```nix
# Before
<machine-name> = mkX86_64 "<machine-name>" { ... };

# After
<machine-name> = mkX86_64 "<machine-name>" {
  extraModules = [
    ../systems/<machine-name>.nix
  ];
  ...
};
```

### 5. Generate Initial Golden File

Generate and save the golden baseline:

```bash
nix run .#generate-golden -- <machine-name> > real-topology/golden/<machine-name>.json
```

### 6. Commit Changes

Add the new files to git:

```bash
git add systems/<machine-name>.nix real-topology/<machine-name>.nix real-topology/golden/<machine-name>.json
git commit -m "Migrate <machine-name> to topology-driven configuration"
```

## Example Migration: local-nas

### Current Configuration

`machines/local-nas/default.nix` has:

```nix
networking = {
  useDHCP = false;
  interfaces.enp0s31f6.useDHCP = true;
  interfaces.wlp4s0.useDHCP = true;
  hostId = "d5710c9a";
};
```

### Step 1: Create Topology File

`real-topology/local-nas.nix`:

```nix
{ ... }:
{
  domain = "johnbargman.net";

  lan = {
    subnet = "10.88.127.0/24";
    gateway = "10.88.127.1";

    hosts = {
      nas = {
        ip = "10.88.127.3";
        mac = "aa:bb:cc:dd:ee:ff";  # Replace with actual MAC
        routing = {
          tailscale = false;
          wireguard = false;
        };
      };
    };
  };
}
```

### Step 2: Create System File

`systems/local-nas.nix`:

```nix
{ ... }:
{
  imports = [
    ../machines/local-nas
    ../modules/core-router.nix
  ];
}
```

### Step 3: Update Flake

```nix
local-nas = mkX86_64 "local-nas" {
  host = "10.88.127.3";
  extraModules = [
    ../systems/local-nas.nix
  ];
};
```

### Step 4: Generate Golden

```bash
nix run .#generate-golden -- local-nas > real-topology/golden/local-nas.json
```

## Testing Procedure

### Build Test

Verify the configuration builds successfully:

```bash
nixos-rebuild build --flake .#<machine-name>
```

### Deploy Test

Test deployment (dry-run first):

```bash
# Dry run
nix run .#<machine-name> -- --dry-activate

# Actual deploy
nix run .#<machine-name>
```

### Network Verification

After deployment, verify network configuration:

```bash
# Check network status
ssh <machine-name> ip addr show
ssh <machine-name> ip route show

# Test connectivity
ping <machine-name>
```

### Golden Check

Ensure configuration matches golden file:

```bash
nix run .#check-network -- <machine-name>
```

## Rollback Procedure

If issues occur during migration:

### Immediate Rollback

1. Revert flake.nix changes:

```bash
git checkout HEAD~1 flake.nix
```

2. Redeploy without topology:

```bash
nix run .#<machine-name>
```

### Clean Rollback

If you want to remove topology files:

```bash
rm systems/<machine-name>.nix real-topology/<machine-name>.nix real-topology/golden/<machine-name>.json
git add -A
git commit -m "Rollback <machine-name> topology migration"
```

### Troubleshooting

- **Build fails**: Check for missing imports or syntax errors in topology file
- **Network issues**: Verify IP addresses and MAC addresses in topology file
- **Golden mismatch**: Update golden file if configuration changes are intentional

## Benefits After Migration

- **Consistency**: Network config driven by topology data
- **Regression protection**: Golden files prevent accidental changes
- **Maintainability**: Network changes in one place
- **Documentation**: Topology files serve as network documentation

## Related Documentation

- [Network Topology Golden System](network-topology-golden.md)
- [Core Router Usage](core-router-usage.md)
- AGENTS.md