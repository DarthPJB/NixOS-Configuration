# lib/topology/mkHostsEntries.nix
# Generates /etc/hosts entries from topology data
# Reads from the JSON registry (mkRegistry.nix) which has coordinate data.
{ lib }:

let
  # Helper: derive IP from coordinate (subnet + peer_id)
  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      ip = builtins.head parts;
      octets = lib.splitString "." ip;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString coord.peer_id}";

  # Generate hosts entries from topology registry
  # Each machine with a wireguard coordinate gets an entry
  mkHostsEntries = topology:
    let
      machinesWithWireguard = lib.filterAttrs
        (_name: host:
          builtins.any (c: c.plane_name == "wg") (host.coordinate or [ ])
        )
        topology;

      entries = lib.mapAttrsToList
        (name: host:
          let
            wgCoords = builtins.filter (c: c.plane_name == "wg") (host.coordinate or [ ]);
            wgCoord = if wgCoords != [ ] then builtins.head wgCoords else null;
            wgIp = if wgCoord != null then coordToIp wgCoord else null;
          in
          if wgIp != null then "${wgIp} ${name}" else null
        )
        machinesWithWireguard;

      validEntries = builtins.filter (e: e != null) entries;
    in
    lib.concatStringsSep "\n" validEntries;
in
{
  inherit mkHostsEntries;
}
