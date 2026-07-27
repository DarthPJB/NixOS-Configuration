{ lib }:
# genDns: settings -> hostname -> NixOS services.dnsmasq config
# Produces the same dnsmasq config as the inline in topology-derive.nix:387-415.
#
# Supports:
# - topology-direct path (FIRST): when settings has `topology` key (used in Phase 2+)
#   Reads lan_dhcp.hosts (list), dns.* directly. Must be byte-identical to inline.
# - New schema: dns.planes (dormant, Phase C)
# - Legacy: machines.${hostname} via mkDnsSettings (to be removed in Phase C)
settings: hostname:
if settings ? topology then
  # Topology-direct path — must match inline logic at topology-derive.nix:387-415 exactly.
  let
    t = settings.topology;
    dhcpIface = t.lan_dhcp.interface or t.dns.dhcp.interface or t.dns.interface or "";
    dhcpRange = t.lan_dhcp.range or t.dns.dhcp.range or "";
  in
  {
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = [ (t.dns.interface or t.lan_dhcp.interface or "") ];
        "dhcp-range" = [ "${dhcpIface},${dhcpRange}" ];
        address = map (entry: "/${entry.domain}/${entry.ip}") (t.dns.static or []);
        server = t.dns.servers or [];
        dhcp-host = builtins.sort (a: b: a < b) (
          map (h: "${h.mac},${h.ip},${h.hostname},infinite")
            (t.lan_dhcp.hosts or t.dns.dhcp.hosts or [])
        );
        domain = [ hostname ];
        local = [ "/${hostname}/" ];
        domain-needed = true;
        bogus-priv = true;
        no-resolv = true;
        cache-size = 1000;
      };
    };
  }
else if settings ? dns && settings.dns ? planes then
  # New schema: per-subnet auth-server via genDnsmasqHorizons.
  # The generator reads coordinate from settings to derive listen-addresses
  # and dns.planes.<plane>.zones for auth-server entries (Phase 5 C populates
  # the zones).  The raw dnsmasq settings from the generator are wrapped
  # in the services.dnsmasq.settings attrset expected by the NixOS module.
  let
    generator = import ./genDnsmasqHorizons.nix { inherit lib; };
    dnsmasqSettings = generator settings;
  in
  {
    services.dnsmasq = {
      enable = true;
      settings = dnsmasqSettings;
    };
  }
else
  # Legacy path: read per-machine flat DNS settings
  # from settings.machines.${hostname}.
  let
    machineSettings = settings.machines.${hostname} or null;
  in
  if machineSettings == null then { } else
  {
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = machineSettings.interface;
        dhcp-range = [ machineSettings.dhcpRange ];
        dhcp-host = machineSettings.dhcpHosts;
        address = machineSettings.dnsEntries;
        server = machineSettings.upstreamServers;
        domain = [ machineSettings.domain ];
        local = [ "/${machineSettings.domain}/" ];
        domain-needed = true;
        bogus-priv = true;
        no-resolv = true;
        cache-size = 1000;
      };
    };
  }
