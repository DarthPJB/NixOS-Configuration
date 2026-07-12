# lib/topology_library.nix
# Ketchup — The open-source topology engine library.
#
# Exports all transformers, generators, validation, and serialization functions
# as a clean API for consuming machines. This is the boundary between the
# generic topology engine (Ketchup) and the proprietary machine configs
# (Secret-Sauce).
#
# Usage:
#   ketchup = import ./lib/topology_library.nix { inherit lib; };
#   ketchup.transformers.mkDnsSettings topology
#   ketchup.generators.genDns settings hostname
#   ketchup.utils.safeLookup attrs name default
#   ketchup.validate.validateTopology topology
#   ketchup.serializeConfig.serializeConfig config
{ lib }:
{
  # --- Transformers (WIP pattern: { lib } -> topology -> { machines, warnings, errors }) ---
  transformers = {
    mkWireguardSettings = import ./topology/mkWireguardSettings.nix { inherit lib; };
    mkDnsSettings = import ./topology/mkDnsSettings.nix { inherit lib; };
    mkFirewallSettings = import ./topology/mkFirewallSettings.nix { inherit lib; };
    mkNginxSettings = import ./topology/mkNginxSettings.nix { inherit lib; };
    mkBackupSettings = import ./topology/mkBackupSettings.nix { inherit lib; };

    # --- Transformers (Production pattern: { lib } -> topology -> NixOS config) ---
    mkDhcpDns = import ./topology/mkDhcpDns.nix { inherit lib; };
    mkNginxProxies = import ./topology/mkNginxProxies.nix { inherit lib; };
    mkForwarding = import ./topology/mkForwarding.nix { inherit lib; };
    mkTailscaleConfig = import ./topology/mkTailscaleConfig.nix { inherit lib; };
    mkMonitoringSettings = import ./topology/mkMonitoringSettings.nix { inherit lib; };

    # --- WireGuard peers (curried: { lib } -> topology -> self -> result) ---
    mkWireguardPeers = import ./topology/mkWireguardPeers.nix { inherit lib; };
  };

  # --- Generators (WIP pattern: { lib } -> settings -> hostname -> NixOS config) ---
  generators = {
    genWireguard = import ./topology/genWireguard.nix { inherit lib; };
    genDns = import ./topology/genDns.nix { inherit lib; };
    genFirewall = import ./topology/genFirewall.nix { inherit lib; };
    genNginx = import ./topology/genNginx.nix { inherit lib; };
  };

  # --- Core utilities (Mayo shared helpers) ---
  utils = import ./topology/utils.nix { inherit lib; };

  # --- Topology validation ---
  validate = import ./topology/validate.nix { inherit lib; };

  # --- Config serializer (for golden tests) ---
  serializeConfig = import ./serialize-config.nix { inherit lib; };
}
