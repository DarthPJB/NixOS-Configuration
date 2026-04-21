# Tailscale Subnet Router Implementation Synthesis

**Document Purpose**: Shared Agent Knowledge Base for implementing Tailscale Subnet Routers in NixOS configurations. Synthesized from `/speed-storage/repo/platonic.systems/infrastructure-2` (particularly `services/tailscale/`, `modules/ts-acl.nix`, `systems/_base.nix`, and `systems/hyperhyper/default.nix`) and cross-referenced with current NixOS-Configuration patterns.

**Status**: Synthesized Reference - v0.1 (Preserves all original user intent and comment philosophy)

## Core Concepts

### 1. Subnet Router Pattern
A machine acts as a **Tailscale subnet router** when it needs to advertise internal networks (LAN, libvirt, etc.) into the Tailscale mesh.

**Key Configuration** (from infrastructure-2):

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "server";           # Critical: enables subnet routing
  extraSetFlags = [
    "--advertise-routes=10.88.128.0/24"    # Advertise specific CIDR(s)
    "--accept-routes"                       # Usually paired on server side
  ];
};
```

### 2. Route Acceptance on Clients
Clients that should use the advertised routes:

```nix
services.tailscale.extraSetFlags = [ "--accept-routes" ];
```

### 3. Advanced ACL Management (`remoteACL`)
The reference implementation uses a sophisticated declarative ACL system:

- `services.tailscale.remoteACL` option (defined in `modules/ts-acl.nix`)
- Uses tags like `tag:hypervisor`, `tag:*-pools`
- Assigns `ipPool` ranges to tagged groups
- Central ACL file managed via `remoteACL`

**Example from reference**:
```nix
services.tailscale.remoteACL = {
  hosts.vms = "100.77.86.0/24";  # or specific CIDR
  nodeAttrs = [{
    target = [ "tag:some-pool" ];
    ipPool = [ "10.88.128.0/24" ];
  }];
  # ... ACL rules
};
```

### 4. State Persistence
```nix
systemd.services.tailscaled.serviceConfig.BindPaths = [ 
  "/persist/tailscale:/var/lib/tailscale" 
];
```

### 5. Network Integration Patterns

**From `systems/_base.nix`**:
- Deep integration with `physical.networks.*` attrset
- Automatic SSH service ordering after Tailscale interface comes up
- Persistent state directory creation via activation script

**From `hyperhyper`** (complex example):
- Advertising libvirt VM networks
- UDP GRO forwarding optimization for performance (`tailscale-udp-gro` service)
- Complex wake-on-SSH logic for VMs over Tailscale

## Current Repository Context (NixOS-Configuration)

**Existing Components**:
- `locale/tailscale.nix`: Basic enablement + package installation
- `modules/enable-wg.nix`: Primary VPN (WireGuard) - Tailscale would be secondary
- `cortex-alpha`: Core router with nftables, dnsmasq, WireGuard hub
- `modifier_imports/` and `services/`: Extension points available

**Target Use Case**:
> "cortex-alpha can provide routes for two of the systems on lan"

This suggests we want `cortex-alpha` (or another machine) to act as a **Tailscale exit node / subnet router** for two specific LAN systems, allowing them to be reached via Tailscale IPs while behind the main router.

## Implementation Considerations for This Repo

1. **Comment Preservation**: All existing user comments in `cortex-alpha/default.nix` and related files **MUST** be preserved per prime directive.

2. **Modular Approach**: Create new module in `modules/` or extend `locale/tailscale.nix` with subnet router options.

3. **Integration Strategy**:
   - Should work alongside existing WireGuard (`wireg0`)
   - Must not interfere with nftables port forwarding
   - Consider `networking.firewall.checkReversePath = "loose";` (currently commented)

4. **Declarative Style**: Follow pattern established by `mkNftables`, `mkProxyPass`, `wg_peers.nix`.

## Next Phase: Planning

Once this document is accepted into shared knowledge, we will:

1. Design a clean `subnetRouter` option for Tailscale
2. Determine which two LAN systems should be routed
3. Decide whether `cortex-alpha` itself becomes the subnet router or if we designate another machine
4. Create the implementation while preserving every existing comment

---

**Synthesis Complete**. This document captures the architectural wisdom from the `infrastructure-2` and `platonicVMs` (where accessible) codebases.

**Ready for Planning Phase.**

Do you want me to:
A) Save this as `documentation/tailscale-subnet-routers.md`?
B) Append key sections to `AGENTS.md`?
C) Begin planning the cortex-alpha modifications immediately (with comment preservation guaranteed)?

Awaiting your command. (All user comments remain 100% untouched in all operations.)