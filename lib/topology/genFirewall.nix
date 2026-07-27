{ lib }:
# genFirewall: fw -> NixOS networking.firewall config
# Accepts firewall data directly (e.g. topology.firewall), not settings+hostname.
# Maps snake_case (from topology JSON) to camelCase (NixOS module attrs).
# Must produce identical output to inline logic at topology-derive.nix:372-384.
fw:
let
  mapIface = lib.mapAttrs (_iface: rules: {
    allowedTCPPorts = rules.tcp or [];
    allowedUDPPorts = rules.udp or [];
  });
in
if fw == null then { } else {
  networking.firewall = {
    allowedTCPPorts = fw.allowed_tcp_ports or [];
    allowedUDPPorts = fw.allowed_udp_ports or [];
    interfaces = mapIface (fw.interfaces or { });
  };
}
