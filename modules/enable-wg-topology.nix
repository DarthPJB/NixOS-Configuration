# modules/enable-wg-topology.nix
# Topology-driven WireGuard module for client machines
{ config
, lib
, self
, ...
}:

let
  topology = import ../topology.nix { inherit lib; };
  wireguardSettings = (import ../lib/topology/mkWireguardSettings.nix { inherit lib; }) topology;
  hostname = config.networking.hostName;
  machineExists = wireguardSettings.machines ? ${hostname};
  machineSettings = if machineExists then wireguardSettings.machines.${hostname} else null;
  wireguardConfig = if machineExists then
    (import ../lib/topology/genWireguard.nix { inherit lib; }) wireguardSettings hostname
  else null;
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

    networking.wireguard.enable = true;
    networking.wireguard.interfaces.wireg0 = lib.mkMerge [
      wireguardConfig.networking.wireguard.interfaces.wireg0
      {
        privateKeyFile =
          config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
      }
    ];

    secrix.services.wireguard-wireg0.secrets."${hostname}".encrypted.file =
      ../secrets/private_keys/wireguard/wg_${hostname};

    services.openssh = lib.mkIf config.services.openssh.enable {
      listenAddresses = [{
        addr = machineSettings.machineIp;
        port = 1108;
      }];
    };

    networking.firewall.allowedTCPPorts = [ 2108 ];
    networking.firewall.allowedUDPPorts = [ 2108 ];
  };
}
