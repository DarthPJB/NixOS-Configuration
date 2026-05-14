{ lib }:
# mkDnsSettings: topology -> DNS/DHCP settings for the hub
# Derives DNS entries from topology.dns.static, DHCP from lan.hosts
topology:
let
  validate = import ./validate.nix { inherit lib; };
  crossRefValidation = validate.validateCrossReferences topology;
let
  # Hub is the current machine
  hubName = topology.hostname;

  # DNS entries from topology.dns.static
  dnsEntries = topology.dns.static;

  # DHCP hosts from lan.hosts
  dhcpHosts = let
    entries = lib.mapAttrsToList (name: host: if host ? mac && host ? ip && host ? hostname then "${host.mac},${host.ip},${host.hostname},infinite" else null) topology.lan.hosts;
  in lib.filter (x: x != null) entries;

  # Other settings from topology.dns
  inherit (topology.dns) interface dhcp servers;
  dhcpRange = topology.dns.dhcp.range;
  upstreamServers = topology.dns.servers;

  # Warnings
  warnings = [ ];

  # Cross-reference validation errors
  errors = crossRefValidation.errors;
in
{
  inherit hubName interface dnsEntries dhcpRange dhcpHosts upstreamServers errors;
  hostname = hubName;
  inherit warnings;
}
