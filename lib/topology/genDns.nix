{ lib }:
# genDns: settings -> hostname -> NixOS services.dnsmasq config
# Produces the same dnsmasq config as production mkDhcpDns.nix.
# NixOS module adds conf-file, dhcp-leasefile, resolv-file automatically.
settings: hostname:
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
