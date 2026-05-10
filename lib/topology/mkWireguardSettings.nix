{ lib }:
# mkWireguardSettings: topology -> { hostname -> wireguard settings }
# Reads public keys from secrets/public_keys/wireguard/wg_${hostname}_pub
# Returns settings for WireGuard configuration
topology:
let
  # Helper to read public key, returning null if missing
  readPubKey = hostname:
    let
      path = ../../secrets/public_keys/wireguard/wg_${hostname}_pub;
    in
    if builtins.pathExists path
    then builtins.readFile path
    else null;

  # Find the hub: the machine that has peers defined
  hubName = lib.findFirst (name: topology.${name} ? peers) null (builtins.attrNames topology);

  # Collect all warnings
  warnings = lib.flatten (
    lib.mapAttrsToList
      (hostname: machine:
        if readPubKey hostname == null
        then "Missing public key for ${hostname} at secrets/public_keys/wireguard/wg_${hostname}_pub"
        else [ ]
      )
      topology
  );

  # Build settings for each machine
  settings = lib.mapAttrs
    (hostname: machine:
      let
        isHub = hostname == hubName;
        pubKey = readPubKey hostname;
      in
      if pubKey == null then null else {
        inherit hostname;
        interface = "wireg0";
        listenPort = if isHub then 2108 else null;
        hubName = if isHub then null else hubName;
        hubIps = if isHub then [ machine.wireguard "10.88.127.0/24" ] else null;
        machineIp = machine.wireguard;
        peers =
          if isHub then
          # For hub, list all peers with their keys
            lib.filter (x: x != null)
              (
                lib.mapAttrsToList
                  (peerName: peerMachine:
                    let peerKey = readPubKey peerName;
                    in if peerKey == null then null else {
                      name = peerName;
                      publicKey = peerKey;
                      allowedIPs = [ peerMachine.wireguard ];
                    }
                  )
                  (lib.filterAttrs (name: _: builtins.elem name machine.peers) topology)
              )
          else
          # For client, connect to hub
            let
              hubMachine = topology.${hubName};
              hubKey = readPubKey hubName;
              uplinkIp = if hubMachine ? uplink then builtins.head (builtins.attrNames hubMachine.uplink) else "cortex-alpha.johnbargman.net";
            in
            if hubKey == null then [ ] else [{
              name = hubName;
              publicKey = hubKey;
              allowedIPs = [ hubMachine.wireguard "10.88.127.0/24" ];
              endpoint = "${uplinkIp}:2108";
            }];
      }
    )
    topology;
in
{
  inherit hubName warnings;
  machines = lib.filterAttrs (_: v: v != null) settings;
}
