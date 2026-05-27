{ lib }:
# mkDnsSettings: topology -> { machines, warnings, errors }
# Returns DNS/DHCP settings for machines that have lan
topology:
let
  # For each machine with lan, generate settings
  machines = lib.mapAttrs
    (hostname: machine:
      if ! (machine ? lan) then null else
      {
        inherit hostname;
        interface = lib.head (builtins.attrValues machine.lan); # Assume one interface
        dnsEntries = [ ]; # No static DNS in topology
        dhcpHosts = [ ]; # No DHCP hosts in topology
        dhcpRange = "10.89.128.100,10.89.128.200,24h"; # Example range
        upstreamServers = [ "8.8.8.8" "1.1.1.1" ]; # Default
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
