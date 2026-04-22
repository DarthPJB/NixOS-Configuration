{ lib ? import <nixpkgs/lib> }:

topology:

let
  # Helper: mkDhcpHosts - Returns dhcp-host entries for hosts with MAC addresses
  mkDhcpHosts = topology: lib.mapAttrsToList
    (name: host:
      if host ? mac then
        "${host.mac},${host.hostname},${host.ip},infinite"
      else
        null
    )
    topology.lan.hosts;

  # Filter out nulls
  dhcpHostsList = lib.filter (x: x != null) (mkDhcpHosts topology);

  # Helper: mkDnsAddresses - Returns address entries from dns.static
  mkDnsAddresses = topology: map (entry: "/${entry.domain}/${entry.ip}") topology.dns.static;

  # Main function: mkDhcpDns - Returns dnsmasq settings
  mkDhcpDns = topology: {
    interface = topology.dns.interface;
    dhcp-range = [ "${topology.dns.interface},${topology.dns.dhcp.range}" ];
    dhcp-host = dhcpHostsList;
    address = mkDnsAddresses topology;
    server = topology.dns.servers;
    domain-needed = true;
    bogus-priv = true;
    no-resolv = true;
    cache-size = 1000;
  };

in
{
  mkDhcpHosts = dhcpHostsList;
  mkDnsAddresses = mkDnsAddresses topology;
  config = mkDhcpDns topology;
}
