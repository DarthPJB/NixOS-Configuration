{ config, pkgs, lib, self, ... }:
let
  # Ketchup API (topology + host management — mayo-split Step 3b); topologyDir
  # is this repo's own topology/.
  ketchup = import "${self.inputs.mayo.lib}/ketchup/topology_library.nix" {
    inherit lib;
    topologyDir = ../topology;
  };
  registry = ketchup.registry;
  topology = registry.hosts;

  # Generate hosts entries from topology (Ketchup host management)
  topologyHosts = ketchup.mkHostsEntries topology;
in
{
  networking.extraHosts = ''
    # Fleet machines (auto-generated from JSON topology registry)
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
