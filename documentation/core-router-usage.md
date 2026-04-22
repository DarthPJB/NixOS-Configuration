# Core Router Module Usage Guide

This document explains how to use the `modules/core-router.nix` module for topology-driven network configuration in NixOS machines.

## Overview

The core-router module enables topology-driven configuration by importing network topology data from `real-topology/<hostname>.nix` and applying transformation functions to generate complete NixOS network configurations.

## How to Add Core-Router to a Machine

To enable the core-router module for a machine:

1. Create or update a system configuration file (e.g., `systems/<hostname>.nix`)
2. Import the core-router module alongside your existing machine configuration

Example:
```nix
# systems/<hostname>.nix
{ ... }:
{
  imports = [
    ../machines/<hostname>  # Existing machine config
    ../modules/core-router.nix
  ];
}
```

## The `coreRouter.enable` Option

- **Type**: Boolean
- **Default**: `true`
- **Description**: Enables topology-driven network configuration. When enabled, the module will automatically generate network interfaces, firewall rules, NAT configurations, and service proxies based on the topology data.

To disable:
```nix
coreRouter.enable = false;
```

## How Topology and Inline Config Interact

The core-router module is designed to work alongside existing inline configurations:

- **Topology-Driven**: Network configuration (interfaces, firewall, NAT, proxies) is generated from `real-topology/<hostname>.nix`
- **Inline Overrides**: Machine-specific settings in `machines/<hostname>/default.nix` take precedence
- **Additive Behavior**: The module adds topology-based config without removing existing manual configurations
- **Conflict Resolution**: If there are conflicts, inline config wins; topology config is applied as defaults

## Migration Path from Inline to Topology-Driven

### Phase 1: Enable Core-Router Alongside Existing Config
- Import `modules/core-router.nix` in your system config
- Keep existing inline network config in `machines/<hostname>/default.nix`
- Test that both work together without conflicts

### Phase 2: Gradually Move Config to Topology
- Identify network elements in inline config that can be moved to topology
- Update `real-topology/<hostname>.nix` with the new elements
- Remove corresponding inline config
- Regenerate golden file: `nix run .#generate-golden -- <hostname> > real-topology/golden/<hostname>.json`

### Phase 3: Validate and Commit
- Run `nix run .#check-network -- <hostname>` to ensure topology matches golden
- Test deployment with `nix run .#<hostname>`
- Commit changes with updated golden file

### Phase 4: Complete Migration
- Remove all inline network config from `machines/<hostname>/default.nix`
- Ensure only topology-driven config remains
- Final validation and deployment

## Example Configurations

### Basic Router Machine
```nix
# systems/router.nix
{ ... }:
{
  imports = [
    ../machines/router
    ../modules/core-router.nix
  ];
  # Topology handles all network config
}
```

### Router with Custom Overrides
```nix
# systems/router.nix
{ ... }:
{
  imports = [
    ../machines/router
    ../modules/core-router.nix
  ];
  
  # Disable topology for testing
  coreRouter.enable = false;
  
  # Add custom packages
  environment.systemPackages = with pkgs; [ tcpdump ];
}
```

### Partial Migration Example
```nix
# systems/router.nix
{ ... }:
{
  imports = [
    ../machines/router
    ../modules/core-router.nix
  ];
  
  # Topology handles interfaces and firewall
  # Keep inline NAT rules for now
  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    internalInterfaces = [ "wg0" ];
  };
}
```