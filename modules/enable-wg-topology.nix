# modules/enable-wg-topology.nix
# Unified topology-driven WireGuard module for hub and client machines
{ config
, lib
, self
, ...
}:

let
  # Import topology
  topology = import ../topology.nix { inherit lib; };

  # Compute WireGuard settings
  wireguardSettings = (import ../lib/topology/mkWireguardSettings.nix { inherit lib; }) topology;

  # Generate config for current machine
  hostname = config.networking.hostName;
  wireguardConfig = (import ../lib/topology/genWireguard.nix { inherit lib; }) wireguardSettings hostname;

  # Is this machine in the topology?
  machineExists = wireguardSettings.machines ? ${hostname};
in
{
  options.enableWgTopology.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable topology-driven WireGuard configuration";
  };

  config = lib.mkIf config.enableWgTopology.enable {
    assertions = [
      {
        assertion = machineExists;
        message = "Machine ${hostname} not found in WireGuard topology";
      }
    ];

    # Enable WireGuard
    networking.wireguard.enable = true;
    networking.wireguard.interfaces = lib.mkOverride 100 wireguardConfig.networking.wireguard.interfaces;

    # Set private key via secrix
    secrix.services.wireguard-wireg0.secrets.${hostname}.encrypted.file =
      ../../secrets/private_keys/wireguard/wg_${hostname};
    networking.wireguard.interfaces.wireg0.privateKeyFile =
      config.secrix.services.wireguard-wireg0.secrets.${hostname}.decrypted.path;
  };
}
