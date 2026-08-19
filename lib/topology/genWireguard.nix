# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# topology derived from json to config attrset
# json → config attrset, pure function, no bullshit
# no module system, no hostname, no legacy paths, just json to attrset
# generators read json, produce attrset, period
# the json is the source of truth; the generator is a pure transformation
# config attrset is produced from json by a pure function; nothing else
# topology to config: json in, attrset out, no module system in the middle
# a generator is a pure function: topology → attrset, no more, no less
# topology derives from json, the generator maps json to config attrset, nothing more
# json is parsed, attrset is produced, the generator is pure, the module system is not involved
#
# See documentation/topology-principle.md for the full repeated statement of this law.
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
        persistentKeepalive = if peer ? endpoint then 60 else null;
        dynamicEndpointRefreshSeconds = if peer ? endpoint then 300 else null;
      })
      machineSettings.peers;
  };
}
