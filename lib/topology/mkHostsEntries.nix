# lib/topology/mkHostsEntries.nix
# Generates /etc/hosts entries from topology data
# Single source of truth: JSON topology registry (mkRegistry.nix)
{ lib }:

let
  inherit (builtins) head filter;

  # Derive IP from a coordinate entry (subnet + peer_id)
  # e.g. subnet "10.88.127.0/24" + peer_id 1 → "10.88.127.1"
  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      networkIp = head parts;
      octets = lib.splitString "." networkIp;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString coord.peer_id}";

  # Extract the WG IP from a host entry (from its wg coordinate)
  getWgIp = host:
    let
      wgCoords = filter (c: c.plane_name == "wg") (host.coordinate or [ ]);
    in
    if wgCoords != [ ] then coordToIp (head wgCoords) else null;

  # Generate hosts entries from topology attrset
  # Each machine with a WireGuard coordinate gets an entry
  mkHostsEntries = topology:
    let
      # Extract all machines with WG coordinates
      machinesWithWireguard = lib.filterAttrs
        (_name: host: getWgIp host != null)
        topology;

      # Generate "IP hostname" entries
      entries = lib.mapAttrsToList
        (name: host: "${getWgIp host} ${name}")
        machinesWithWireguard;

      # Join with newlines
    in
    lib.concatStringsSep "\n" entries;
in
{
  inherit mkHostsEntries;
}
