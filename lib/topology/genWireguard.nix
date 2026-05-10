{ lib }:
# genWireguard: settings -> hostname -> NixOS networking.wireguard config
# settings is the output of mkWireguardSettings
# Returns the interface config; privateKeyFile must be set separately in the module
settings: hostname:
let
  machineSettings = settings.machines.${hostname};
  isHub = hostname == settings.hubName;
in
{
  networking.wireguard.interfaces.${machineSettings.interface} = {
    inherit (machineSettings) listenPort;
    ips = if isHub then machineSettings.hubIps else [ machineSettings.machineIp ];
    peers = builtins.map (peer: {
      inherit (peer) publicKey allowedIPs;
      endpoint = peer.endpoint or null;
      persistentKeepalive = if peer ? endpoint then 25 else null;
    }) machineSettings.peers;
  };
}