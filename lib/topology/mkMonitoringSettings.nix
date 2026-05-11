/*
  Purpose: Transform topology monitoring configuration into NixOS prometheus exporters config

  Inputs:
  - topology.monitoring: monitoring configuration including exporters

  Output: NixOS services.prometheus.exporters config
*/
{ lib }:

topology:

let
  utils = import ./utils.nix { inherit lib; };
  inherit (utils) safeLookup;
in
rec {
  # Generate prometheus exporters config from topology
  mkMonitoringConfig =
    { config ? { }
    ,
    }:
    let
      monitoring = safeLookup topology "monitoring" { };
      exporters = safeLookup monitoring "exporters" { };
    in
    exporters;
}