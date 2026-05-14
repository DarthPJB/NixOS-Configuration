{ lib }:
# genDns: settings -> hostname -> NixOS services.dnsmasq config
# Generates config for machines with DNS settings
settings: hostname:
let
  machineSettings = settings.machines.${hostname} or null;
in
if machineSettings == null then { } else {
  services.dnsmasq = {
    enable = true;
    settings = {
      address = map (entry: "/${entry.domain}/${entry.ip}") machineSettings.dnsEntries;
      "bogus-priv" = [ true ];
      "cache-size" = [ 1000 ];
      "conf-file" = [ "/etc/dnsmasq-conf.conf" ];
      "dhcp-host" = machineSettings.dhcpHosts;
      "dhcp-leasefile" = [ "/var/lib/dnsmasq/dnsmasq.leases" ];
      "dhcp-range" = [ machineSettings.dhcpRange ];
      "domain" = [ machineSettings.hostname ];
      "domain-needed" = [ true ];
      "interface" = [ machineSettings.interface ];
      "local" = [ "/${machineSettings.hostname}/" ];
      "no-resolv" = [ true ];
      "resolv-file" = [ "/etc/dnsmasq-resolv.conf" ];
      "server" = machineSettings.upstreamServers;
    };
  };
}
