{ config, pkgs, lib, ... }:
let
  # Import shared topology (single source of truth for all machine IPs)
  topology = import ../topology/shared.nix { inherit lib; };

  # Import hosts generation function
  hostsLib = import ../lib/topology/mkHostsEntries.nix { inherit lib; };

  # Generate hosts entries from topology
  topologyHosts = hostsLib.mkHostsEntries topology;
in
{
  networking.extraHosts = ''
    # Fleet machines (auto-generated from topology/shared.nix)
    ${topologyHosts}

    # External hosts (manual entries)
    167.172.199.21 forme.prod
    193.16.42.101 remote.worker
    100.127.45.55 propylaia.platonic
    100.107.101.14 hyperhyper.platonic hyperhyper
    100.91.247.95 acropolis.platonic
    100.75.142.109 tumulus.platonic
    100.105.114.89 springboard.platonic
    193.16.42.95 entrypoint.pinkerton
  '';
}
