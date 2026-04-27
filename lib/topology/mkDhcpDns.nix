/*
Purpose: Transform topology DNS and DHCP config into NixOS dnsmasq config

Inputs:
- topology.lan.hosts: host definitions with mac, ip, hostname for DHCP
- topology.dns: DNS configuration including interface, range, static entries, servers

Output: NixOS services.dnsmasq config
*/

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