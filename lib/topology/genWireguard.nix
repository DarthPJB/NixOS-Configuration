{ lib }:
# genWireguard: settings -> hostname -> NixOS networking.wireguard config
# settings is the output of mkWireguardSettings
# Returns the interface config; privateKeyFile must be set separately in the module
settings: hostname:
let
  machineSettings = settings.machines.${hostname};

  # Add /32 CIDR suffix if not already present
  addCidr = ip: if lib.hasInfix "/" ip then ip else "${ip}/32";
in
{
  networking.wireguard.interfaces.${machineSettings.interface} = {
    inherit (machineSettings) listenPort;
    ips = if machineSettings.isHub then machineSettings.hubIps else [ (addCidr machineSettings.machineIp) ];
    peers = builtins.map
      (peer: {
        inherit (peer) publicKey;
        allowedIPs = builtins.map addCidr peer.allowedIPs;
        endpoint = peer.endpoint or null;
        persistentKeepalive = if peer ? endpoint then 25 else null;
      })
      machineSettings.peers;
  };
}
