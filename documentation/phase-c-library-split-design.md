# Phase C: Library Split Design

> **Created:** 2026-07-12
> **Status:** ACTIVE
> **Branch:** `overlord-II`

## Overview

Split NixOS-Configuration infrastructure into three modular library components:

- **Ketchup** — Open-source, freely distributable topology engine
- **Secret-Sauce** — Closed-source Bargman proprietary library
- **Mayo** — Shared helpers and utilities

## Boundary Definitions

### Ketchup (Open-Source — `lib/topology_library.nix`)

Generic NixOS modules, topology engine, transformers, generators, validation,
and serialization. No machine-specific data, no secrets, no proprietary config.

**Transformers (WIP pattern — `{ machines, warnings, errors }` return):**
- `lib/topology/mkWireguardSettings.nix` — WG transformer (for client machines)
- `lib/topology/mkDnsSettings.nix` — DNS/DHCP transformer
- `lib/topology/mkFirewallSettings.nix` — Firewall transformer
- `lib/topology/mkNginxSettings.nix` — Nginx transformer
- `lib/topology/mkBackupSettings.nix` — Backup transformer (WIP)

**Transformers (Production pattern — direct NixOS config return):**
- `lib/topology/mkWireguardPeers.nix` — WG peer transformer (for hub)
- `lib/topology/mkDhcpDns.nix` — DNS/DHCP transformer (production)
- `lib/topology/mkNginxProxies.nix` — Nginx transformer (production)
- `lib/topology/mkForwarding.nix` — nftables forwarding transformer
- `lib/topology/mkTailscaleConfig.nix` — Tailscale config transformer
- `lib/topology/mkMonitoringSettings.nix` — Prometheus exporter transformer

**Generators (WIP pattern — `settings -> hostname -> NixOS config`):**
- `lib/topology/genWireguard.nix` — WG generator
- `lib/topology/genDns.nix` — DNS generator
- `lib/topology/genFirewall.nix` — Firewall generator
- `lib/topology/genNginx.nix` — Nginx generator

**Core utilities:**
- `lib/topology/utils.nix` — Shared utilities (safeLookup, dedupPreserveOrder, etc.)
- `lib/topology/validate.nix` — Topology validation
- `lib/serialize-config.nix` — Config serializer (for golden tests)
- `lib/golden_coverage.nix` — Coverage tracking

**NixOS modules:**
- `modules/core-router-topology.nix` — WIP two-layer router module
- `modules/enable-wg-topology.nix` — WireGuard client module (13 machines)
- `modules/core-router.nix` — Production router module (legacy, being replaced)
- `lib/rclone-target.nix` — Backup module (generic)

### Secret-Sauce (Proprietary — not a library, the flake itself)

Machine-specific data, configurations, secrets, and services. This is the
Bargman-Tech proprietary layer that imports Ketchup and Mayo.

**Topology data (real IPs, hostnames, network details):**
- `topology/shared.nix` — Shared topology (WG IPs, LAN IPs, hub relationships)
- `topology/cortex-alpha.nix` — Per-machine detailed topology
- `topology/default.nix` — Topology entry point

**Machine configurations:**
- `machines/*/default.nix` — Per-machine NixOS configs (hardware, services)
- `environments/*.nix` — Environment configs (sshd, etc.)
- `modifier_imports/*.nix` — Modifier imports (zfs, etc.)

**Secrets:**
- `secrets/private_keys/` — Encrypted private keys
- `secrets/public_keys/` — Public keys

**Service definitions:**
- `services/*.nix` — Service configs (acme, ldap, dynamic_domain_gandi)
- `server_services/*.nix` — Server service configs

### Mayo (Shared Helpers — `lib/mayo_library.nix`)

Functions and utilities shared between Ketchup and Secret-Sauce.

**Shared utilities:**
- `lib/topology/utils.nix` — Core utilities (also exported by Ketchup)
- `lib/mkKnownHosts.nix` — SSH known hosts generator
- `lib/network-interfaces.nix` — Network interface helpers
- `lib/golden_generator.nix` — Old golden generator (reference only)
- `lib/make-storeless-image.nix` — Image builder utility

## API Design

### Ketchup Entry Point (`lib/topology_library.nix`)

```nix
{ lib }:
{
  transformers = { mkWireguardSettings, mkWireguardPeers, mkDnsSettings, ... };
  generators = { genWireguard, genDns, genFirewall, genNginx };
  utils = { safeLookup, dedupPreserveOrder, isIP, isMAC, ... };
  validate = { validateTopology, validateCrossReferences };
  serializeConfig = { serializeConfig };
}
```

### Mayo Entry Point (`lib/mayo_library.nix`)

```nix
{ lib }:
{
  inherit (import ./topology/utils.nix { inherit lib; }) safeLookup dedupPreserveOrder;
  mkKnownHosts = import ./mkKnownHosts.nix;
  networkInterfaces = import ./network-interfaces.nix;
}
```

### Secret-Sauce (Flake)

The flake itself is Secret-Sauce. It imports Ketchup and Mayo:
```nix
{
  ketchup = import ./lib/topology_library.nix { inherit lib; };
  mayo = import ./lib/mayo_library.nix { inherit lib; };
}
```

## Migration Strategy

The library split is achieved through **API boundaries** (entry points) and
**documentation**, NOT file movement. Files stay where they are; the split is
enforced by clear interfaces.

Future physical separation (separate repos/flakes) can be done without changing
import paths, since all paths go through the entry points.

### Import patterns before Phase C:
```nix
wireguardLib = (import ../lib/topology/mkWireguardPeers.nix) { inherit lib; } topology self;
```

### Import patterns after Phase C:
```nix
ketchup = import ../lib/topology_library.nix { inherit lib; };
wireguardLib = ketchup.transformers.mkWireguardPeers topology self;
```

Note: Existing modules (core-router-topology.nix) can continue using direct
imports for now. The entry point is for consumers who want a clean API.

## What Does NOT Move

- `topology/*.nix` stays in Secret-Sauce (real network data)
- `machines/*` stays in Secret-Sauce (real hardware configs)
- `secrets/*` stays in Secret-Sauce (encrypted secrets)
- `flake.nix` stays in Secret-Sauce (the flake itself)

## What Does NOT Change

- Golden tests continue to work (no import path changes)
- No files are physically moved
- No golden regeneration needed
- All existing modules continue to work via direct imports