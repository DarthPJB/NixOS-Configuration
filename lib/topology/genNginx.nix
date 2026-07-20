{ lib }:
# genNginx: horizon -> list of vhost stanzas
#
# Phase B: Dead code stub. No callers.
# The generator takes horizon settings (output of mkHorizons) and produces
# per-subnet vhost stanzas, one per (vhost, plane) entry.
#
# For proxy entries (vhostEntry ? proxy_to), the generator emits proxyPass
# using the proxy_to coordinate from the topology.
# For static entries, the generator emits an empty locations block;
# the machine's nix config fills in the root in Phase F.
#
# Phase 5 (C) wires this into mkNginxSettings and core-router-topology.nix.
# Phase F adds the backend (root or proxyPass) from machine config.
horizon:
let
  vhostPlanes = horizon.vhostPlanes or {};

  # Emit one stanza per (vhost, plane) entry
  # For each vhost name, we have a list of plane entries
  mkStanzasForVhost = vhostName:
    let
      entries = vhostPlanes.${vhostName};
    in
    map (entry:
      let
        isProxy = entry ? proxy_to;
      in
      {
        serverName = vhostName;
        listenAddresses = [];   # Will be filled by Phase 5
      }
      // (if isProxy then {
        locations."/" = { proxyPass = "http://${entry.proxy_to}"; };
      } else {
        locations."/" = { };    # root set by machine's nix config in Phase F
      })
    ) entries;

  # Collect stanzas across all vhosts
  stanzas = builtins.concatLists (
    map mkStanzasForVhost (builtins.attrNames vhostPlanes)
  );
in
stanzas
