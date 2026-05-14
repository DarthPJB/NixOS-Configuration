{ lib }:
# mkWireguardSettings: topology -> { hostname -> wireguard settings }
# Reads public keys from secrets/public_keys/wireguard/wg_${hostname}_pub
# Returns settings for WireGuard configuration
topology:
let
  validate = import ./validate.nix { inherit lib; };
  crossRefValidation = validate.validateCrossReferences topology;
let
  # Helper to read public key, returning null if missing
  readPubKey = hostname:
    let
      path = ../../secrets/public_keys/wireguard/wg_${hostname}_pub;
    in
    if builtins.pathExists path
    then builtins.readFile path
    else null;

  hubName = topology.hostname;

  # Merge machine configs: hosts + hub extras
  machines = lib.mapAttrs (hostname: host: host // (if host ? wireguardIp then { wireguardIp = host.wireguardIp; } else {}) // (if hostname == hubName then {
    wireguard = topology.wireguard;
  } else {} )) topology.lan.hosts;

  # Collect all warnings
  warnings = lib.flatten (
    lib.mapAttrsToList
      (hostname: machine:
        if readPubKey hostname == null
        then "Missing public key for ${hostname} at secrets/public_keys/wireguard/wg_${hostname}_pub"
        else [ ]
      )
      machines
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
        listenPort = if isHub then topology.wireguard.listenPort else null;
        hubName = if isHub then null else hubName;
        hubIps = if isHub then [ machine.wireguardIp "10.88.127.0/24" ] else null;
        machineIp = machine.wireguardIp;
        peers =
          if isHub then
          # For hub, list all peers with their keys
            lib.filter (x: x != null)
              (
                lib.mapAttrsToList
                  (peerName: _:
                    let peerKey = readPubKey peerName;
                        peerMachine = machines.${peerName};
                    in if peerKey == null then null else {
                      name = peerName;
                      publicKey = peerKey;
                      allowedIPs = [ peerMachine.wireguardIp ];
                    }
                  )
                  (lib.listToAttrs (map (name: { name = name; value = {}; }) topology.wireguard.peers))
              )
          else
          # For client, connect to hub
            let
              hubMachine = machines.${hubName};
              hubKey = readPubKey hubName;
            in
            if hubKey == null then [ ] else [{
              name = hubName;
              publicKey = hubKey;
              allowedIPs = [ hubMachine.wireguardIp "10.88.127.0/24" ];
              endpoint = "${topology.hostname}.${topology.domain}:2108";
            }];
      }
    )
    machines;
  # Cross-reference validation errors
  errors = crossRefValidation.errors;
in
{
  inherit hubName warnings errors;
  machines = lib.filterAttrs (_: v: v != null) settings;
}
