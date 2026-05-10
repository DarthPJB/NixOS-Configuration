{ lib }:
# mkDnsSettings: topology -> DNS/DHCP settings for the hub
# Derives DNS entries from nginx-proxy, DHCP from lan entries
topology:
let
  # Find the hub: the machine that has peers defined
  hubName = lib.findFirst (name: topology.${name} ? peers) null (builtins.attrNames topology);

  hubMachine = topology.${hubName};

  # Hub's LAN IP: assuming lan is { ip = interface; }, take the key
  hubLanIp = if hubMachine ? lan then builtins.head (builtins.attrNames hubMachine.lan) else null;

  # Interface: the value of lan
  interface = if hubMachine ? lan then builtins.head (builtins.attrValues hubMachine.lan) else null;

  # DNS entries: domain -> hub's LAN IP for each nginx-proxy entry
  dnsEntries =
    if hubMachine ? nginx-proxy then
      lib.mapAttrsToList (domain: _target: { inherit domain; ip = hubLanIp; }) hubMachine.nginx-proxy
    else [ ];

  # DHCP range: hardcoded for now, assuming 10.88.128.0/24
  dhcpRange = "10.88.128.128,10.88.128.254,24h";

  # DHCP hosts: for now, empty since MACs not in topology
  dhcpHosts = [ ];

  # Upstream DNS servers
  upstreamServers = [ "1.1.1.1" "8.8.8.8" ];

  # Warnings
  warnings = lib.flatten [
    (if hubName == null then "No hub machine found (machine with 'peers' field)" else [ ])
    (if hubLanIp == null then "Hub machine '${hubName}' missing lan IP" else [ ])
    (if interface == null then "Hub machine '${hubName}' missing lan interface" else [ ])
  ];
in
{
  inherit hubName interface dnsEntries dhcpRange dhcpHosts upstreamServers;
  hostname = hubName;
  inherit warnings;
}
