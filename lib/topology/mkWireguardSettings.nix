{ lib }:
# mkWireguardSettings: topology -> { machines, warnings, errors }
# topology is the attrset from topology.nix
# Returns settings for WireGuard configuration for all machines
topology:
let
  domain = "johnbargman.net";

  # Helper to read public key, returning null if missing
  readPubKey = hostname:
    let
      path = ../../secrets/public_keys/wireguard/wg_${hostname}_pub;
    in
    if builtins.pathExists path
    then builtins.readFile path
    else null;

  # Determine which machines are serving as hubs (have clients)
  isServing = lib.genAttrs (lib.attrNames topology) (hostname:
    lib.any (name: topology.${name} ? hub && topology.${name}.hub == hostname) (lib.attrNames topology)
  );

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
  machines = lib.mapAttrs
    (hostname: machine:
      let
        pubKey = readPubKey hostname;
      in
      if pubKey == null then null else
        let
          isHub = isServing.${hostname};
          # Derive subnet IP from machine's wireguard IP (e.g., "10.88.127.1" -> "10.88.127.0")
          ipParts = lib.splitString "." machine.wireguard;
          subnetIp = "${builtins.elemAt ipParts 0}.${builtins.elemAt ipParts 1}.${builtins.elemAt ipParts 2}.0";
        in
        {
        inherit hostname;
        interface = "wireg0";
        listenPort = if isHub then 2108 else null;
        machineIp = machine.wireguard;
        inherit isHub;
        hubIps = if isHub then [ "${machine.wireguard}/32" "${subnetIp}/24" ] else [ ];
        peers = builtins.filter (p: p != null) (lib.flatten [
          # If this machine has a hub, connect to it
          (if machine ? hub then
            let
              hubName = machine.hub;
              hubMachine = topology.${hubName};
              hubKey = readPubKey hubName;
            in
            if hubKey == null then [ ] else [{
              name = hubName;
              publicKey = hubKey;
              allowedIPs = [ hubMachine.wireguard "10.88.127.0/24" ];
              endpoint = "${hubName}.${domain}:2108";
            }]
          else [ ])
          # If this machine is serving clients, list them
          (if isServing.${hostname} then
            lib.map
              (clientName:
                let
                  clientMachine = topology.${clientName};
                  clientKey = readPubKey clientName;
                in
                if clientKey == null then null else {
                  name = clientName;
                  publicKey = clientKey;
                  allowedIPs = [ clientMachine.wireguard ];
                }
              )
              (lib.filter (name: topology.${name} ? hub && topology.${name}.hub == hostname) (lib.attrNames topology))
          else [ ])
        ]);
      }
    )
    topology;

  # Filter out null entries
  filteredMachines = lib.filterAttrs (_: v: v != null) machines;

  # For now, no errors
  errors = [ ];
in
{
  inherit warnings errors;
  machines = filteredMachines;
}
