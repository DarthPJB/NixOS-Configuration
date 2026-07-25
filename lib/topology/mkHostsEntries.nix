# lib/topology/mkHostsEntries.nix
# Generates /etc/hosts entries from topology data
# Single source of truth: topology/shared.nix
{ lib }:

let
  # Generate hosts entries from topology attrset
  # Each machine with a wireguard IP gets an entry
  mkHostsEntries = topology:
    let
      # Extract all machines with wireguard IPs
      machinesWithWireguard = lib.filterAttrs
        (name: cfg: cfg ? wireguard && cfg.wireguard != null)
        topology;

      # Generate "IP hostname" entries
      entries = lib.mapAttrsToList
        (name: cfg: "${cfg.wireguard} ${name}")
        machinesWithWireguard;

      # Join with newlines
    in
    lib.concatStringsSep "\n" entries;
in
{
  inherit mkHostsEntries;
}
