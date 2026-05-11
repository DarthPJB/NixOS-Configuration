{ lib }:
# genDns: settings -> hostname -> NixOS services.dnsmasq config
# Only generates config for the hub machine
settings: hostname:
let
  isHub = hostname == settings.hubName;
in
if !isHub then { } else {
  services.dnsmasq = {
    enable = true;
    settings = {
      address = map (entry: "/${entry.domain}/${entry.ip}") settings.dnsEntries;
      "bogus-priv" = [ true ];
      "cache-size" = [ 1000 ];
      "conf-file" = [ "/etc/dnsmasq-conf.conf" ];
      "dhcp-host" = settings.dhcpHosts;
      "dhcp-leasefile" = [ "/var/lib/dnsmasq/dnsmasq.leases" ];
      "dhcp-range" = [ settings.dhcpRange ];
      "domain" = [ settings.hostname ];
      "domain-needed" = [ true ];
      "interface" = [ settings.interface ];
      "local" = [ "/${settings.hostname}/" ];
      "no-resolv" = [ true ];
      "resolv-file" = [ "/etc/dnsmasq-resolv.conf" ];
      "server" = settings.upstreamServers;
    };
  };
}
