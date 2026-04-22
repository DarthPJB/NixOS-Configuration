# Network Topology Golden System

## Overview

The Network Topology Golden System provides a single source of truth for network configuration and a regression testing mechanism to ensure network configuration changes are intentional.

## Directory Structure

```
real-topology/
├── default.nix              # Core module - golden generation logic
├── cortex-alpha.nix         # Machine-specific topology data
└── golden/
    └── cortex-alpha.json    # Golden snapshot of network config

lib/topology/
└── default.nix              # Transformation functions (placeholder)

modules/
└── core-router.nix          # Core router module

systems/
└── cortex-alpha.nix         # Transition file for new architecture
```

## Commands

### Generate Golden JSON

Outputs the current network configuration as JSON to stdout:

```bash
nix run .#generate-golden -- <machine-name>
```

Example:
```bash
nix run .#generate-golden -- cortex-alpha
```

### Update Golden File

Save current configuration as the new golden baseline:

```bash
nix run .#generate-golden -- cortex-alpha > real-topology/golden/cortex-alpha.json
```

### Check Network Configuration

Validate that current configuration matches the golden file:

```bash
nix run .#check-network -- <machine-name>
```

Example:
```bash
nix run .#check-network -- cortex-alpha
```

Output on success:
```
✓ Network config matches golden for cortex-alpha
```

Output on mismatch:
```
✗ Network configuration has changed from golden!
If intentional, update with:
  nix run .#generate-golden -- cortex-alpha > real-topology/golden/cortex-alpha.json
```

## Adding a New Machine

1. Create `real-topology/<machine-name>.nix` with topology data:

```nix
{ ... }:
{
  domain = "johnbargman.net";
  
  lan = {
    subnet = "10.88.128.0/24";
    gateway = "10.88.128.1";
    
    hosts = {
      my-host = {
        ip = "10.88.128.XX";
        mac = "xx:xx:xx:xx:xx:xx";
        routing = {
          tailscale = false;
          wireguard = false;
        };
      };
    };
  };
}
```

2. Generate initial golden file:

```bash
nix run .#generate-golden -- <machine-name> > real-topology/golden/<machine-name>.json
```

3. Add to git:

```bash
git add real-topology/golden/<machine-name>.json
```

## Captured Options

The golden generator captures the following network-related options:

### Identity
- `networking.hostName`
- `networking.hostId`

### NAT and Firewall
- `networking.nat.enable`
- `networking.nftables.enable`
- `networking.nftables.ruleset` (normalized to `<ruleset-string>`)
- `networking.firewall.allowedTCPPorts`
- `networking.firewall.allowedUDPPorts`
- `networking.firewall.interfaces`

### WireGuard
- `networking.wireguard.enable`
- `networking.wireguard.interfaces` (IPs, listenPort, peers with allowedIPs)

### Tailscale
- `services.tailscale.enable`
- `services.tailscale.useRoutingFeatures`
- `services.tailscale.extraSetFlags`
- `networking.tailscale.advertisedRoutes`

### DNS/DHCP
- `services.dnsmasq.enable`
- `services.dnsmasq.settings`

### Nginx
- `services.nginx.enable`
- `services.nginx.virtualHosts` (with normalized store paths)

### Prometheus
- `services.prometheus.exporters.node.enable/port`
- `services.prometheus.exporters.dnsmasq.enable/port`

### System
- `boot.kernel.sysctl`
- `time.timeZone`
- `environment.systemPackages` (unique package names only)
- `systemd.services.tailscale-udp-gro.enable`

### Normalization

To ensure deterministic golden files, the following normalizations are applied:
- Nix store paths are replaced with `<store>`
- Nftables ruleset is replaced with `<ruleset-string>`
- System packages are deduplicated and only names are captured

To add more options, edit the `safeOptions` attrset in `real-topology/default.nix`.

## Design Principles

1. **Single Source of Truth**: `real-topology/<machine>.nix` files define the physical network reality
2. **Safe Evaluation**: Only specific, known-safe options are evaluated to avoid deprecated option errors
3. **Regression Detection**: Golden files capture expected configuration; changes must be intentional
4. **Separation of Concerns**: Topology data is separate from NixOS module logic

## Related Files

- `AGENTS.md` - General agent instructions
- `documentation/tailscale-subnet-routers.md` - Tailscale implementation synthesis
