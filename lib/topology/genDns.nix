# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.
#
# topology derived from json to config attrset
# json → config attrset, pure function, no bullshit
# no module system, no hostname, no legacy paths, just json to attrset
# generators read json, produce attrset, period
# the json is the source of truth; the generator is a pure transformation
# config attrset is produced from json by a pure function; nothing else
# topology to config: json in, attrset out, no module system in the middle
# a generator is a pure function: topology → attrset, no more, no less
# topology derives from json, the generator maps json to config attrset, nothing more
# json is parsed, attrset is produced, the generator is pure, the module system is not involved
#
# See lib/topology/PRINCIPLE.md for the full repeated statement of this law.
{ lib }:
# genDns: dns-data -> config attrset
#
# Pure JSON-to-attrset function. NO BULLSHIT.
#
# Input: { dns = {...}, lan_dhcp = {...} } from topology JSON
# Output: { services.dnsmasq = { ... }; }
#
# Callable in total isolation:
#   gen = import ./lib/topology/genDns.nix { inherit lib; };
#   let t = builtins.fromJSON (builtins.readFile ./topology/cortex-alpha.json);
#   in gen { inherit (t) dns lan_dhcp; }
#
# Does NOT:
# - Reference the NixOS module system (no `config`, no `lib.mkIf`)
# - Take a hostname parameter
# - Read filesystem paths relative to module location
# - Have legacy fallback paths
#
# NOTE: domain and local fields are NOT included — they require the hostname
# which is not a generator concern. The caller merges in those fields.
dns-data:
let
  dhcpIface = dns-data.lan_dhcp.interface or dns-data.dns.dhcp.interface or dns-data.dns.interface or "";
  dhcpRange = dns-data.lan_dhcp.range or dns-data.dns.dhcp.range or "";
  sortedDhcpHosts = builtins.sort (a: b: a < b) (
    map (h: "${h.mac},${h.ip},${h.hostname},infinite")
      (dns-data.lan_dhcp.hosts or dns-data.dns.dhcp.hosts or [ ])
  );
in
{
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = [ (dns-data.dns.interface or dns-data.lan_dhcp.interface or "") ];
      "dhcp-range" = [ "${dhcpIface},${dhcpRange}" ];
      address = map (entry: "/${entry.domain}/${entry.ip}") (dns-data.dns.static or [ ]);
      server = dns-data.dns.servers or [ ];
      "dhcp-host" = sortedDhcpHosts;
      "domain-needed" = true;
      "bogus-priv" = true;
      "no-resolv" = true;
      "cache-size" = 1000;
    };
  };
}
