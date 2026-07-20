{ lib }:
# genDns: settings -> hostname -> NixOS services.dnsmasq config
# Produces the same dnsmasq config as production mkDhcpDns.nix.
# NixOS module adds conf-file, dhcp-leasefile, resolv-file automatically.
#
# Phase 5 (C): Per-subnet auth-server support (gated on field presence).
# If the settings have `dns.planes` (the new schema), use genDnsmasqHorizons
# for per-subnet auth-server directives.  Otherwise, fall back to the
# current behavior.  This path is dormant until a machine has dns.planes
# in its topology data (useNewPipeline = true in Phase 6).
settings: hostname:
if settings ? dns && settings.dns ? planes then
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
  # Legacy path (unchanged): read per-machine flat DNS settings
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
