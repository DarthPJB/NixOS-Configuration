{ lib }:
# genFirewall: settings -> hostname -> NixOS networking.firewall config
# Produces the same firewall config as production topology-derive.nix:
#   networking.firewall = lib.mkOverride 100 topology.firewall;
settings: hostname:
let
  machineSettings = settings.machines.${hostname} or null;
in
if machineSettings == null then { } else
{
  networking.firewall = machineSettings.firewall;
}
