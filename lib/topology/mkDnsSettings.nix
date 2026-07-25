{ lib }:
# mkDnsSettings: per-machine topology -> { machines, warnings, errors }
# Extracts DNS/DHCP settings from per-machine topology data.
# Consumes: topology.dns, topology.lan.hosts, topology.hostname
# Must match production mkDhcpDns.nix data extraction.
topology:
let
  utils = import ./utils.nix { inherit lib; };
  inherit (utils) safeLookup;

  machines = lib.mapAttrs
    (hostname: machine:
      if !(machine ? dns) then null else
      let
        # DHCP hosts from topology.lan.hosts — format: "mac,ip,hostname,infinite"
        # Must match production mkDhcpDns.nix mkDhcpHosts exactly (sorted)
        dhcpHosts = builtins.sort (a: b: a < b) (
          lib.filter (x: x != null) (
            lib.mapAttrsToList
              (_: host:
                if host ? mac && host ? ip && host ? hostname
                then "${host.mac},${host.ip},${host.hostname},infinite"
                else null
              )
              (machine.lan.hosts or { })
          )
        );

        # DNS static entries — format: "/domain/ip"
        dnsEntries = map (entry: "/${entry.domain}/${entry.ip}") machine.dns.static;

        # DHCP range with interface prefix — format: "interface,start,end,lease"
        dhcpRange = "${machine.dns.interface},${machine.dns.dhcp.range}";

        # Upstream DNS servers
        upstreamServers = machine.dns.servers;

        # Domain (hostname of the machine)
        domain = machine.hostname;
      in
      {
        inherit hostname;
        interface = machine.dns.interface;
        inherit dnsEntries dhcpHosts dhcpRange upstreamServers domain;
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
