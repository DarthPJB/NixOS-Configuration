{ lib }:
# mkFirewallSettings: per-machine topology -> { machines, warnings, errors }
# Extracts firewall settings directly from topology.firewall.
# Must match production core-router.nix which uses topology.firewall directly:
#   networking.firewall = lib.mkOverride 100 topology.firewall;
topology:
let
  machines = lib.mapAttrs
    (hostname: machine:
      if !(machine ? firewall) then null else
      {
        inherit hostname;
        firewall = machine.firewall;
      }
    )
    topology;

  filteredMachines = lib.filterAttrs (_: v: v != null) machines;

  warnings = [ ];
  errors = [ ];
in
{
  inherit warnings errors;
  machines = filteredMachines;
}