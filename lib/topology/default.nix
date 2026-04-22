# lib/topology/default.nix
# Topology transformation library - consumes real-topology data
{ lib, ... }:
{
  # Placeholder for future mk* functions that will transform real-topology
  # into WireGuard peers, nftables rules, Tailscale config, etc.
  mkWireguardPeers = topology: [ ];
  mkTailscaleConfig = topology: { };
  mkNftablesConfig = topology: "";
  mkDhcpConfig = topology: [ ];

  # Filter config tree to only networking-relevant parts
  filterConfig =
    config: filterTerms:
    lib.filterAttrsRecursive (name: value: lib.any (term: lib.hasPrefix term name) filterTerms) config;
}
