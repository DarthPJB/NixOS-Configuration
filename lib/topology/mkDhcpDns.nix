{ lib }:

topology:

let
  utils = import ./utils.nix { inherit lib; };
  inherit (utils) safeLookup;

  mkDhcpHosts = let
    entries = lib.mapAttrsToList (
      name: host: if host ? mac && host ? ip && host ? hostname then "${host.mac},${host.ip},${host.hostname},infinite" else null
    ) topology.lan.hosts;
    validEntries = lib.filter (x: x != null) entries;
  in builtins.sort (a: b: a < b) validEntries;

  mkDnsAddresses = map (entry: "/${entry.domain}/${entry.ip}") topology.dns.static;

  hostname = safeLookup topology "hostname" "local";

in
{
  inherit mkDhcpHosts mkDnsAddresses;
  config = {
    interface = topology.dns.interface;
    dhcp-range = [ "${topology.dns.interface},${topology.dns.dhcp.range}" ];
    dhcp-host = mkDhcpHosts;
    address = mkDnsAddresses;
    server = topology.dns.servers;
    domain = [ hostname ];
    local = [ "/${hostname}/" ];
    domain-needed = true;
    bogus-priv = true;
    no-resolv = true;
    cache-size = 1000;
  };
}