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
      inherit (settings) interface;
      "dhcp-range" = settings.dhcpRange;
      "dhcp-host" = settings.dhcpHosts; # List of host entries, empty for now
      "server" = settings.upstreamServers;
      "domain" = settings.hostname;
      "local" = "/${settings.hostname}/";
    } // lib.listToAttrs (
      map
        (entry: {
          name = "address";
          value = "/${entry.domain}/${entry.ip}";
        })
        settings.dnsEntries
    );
  };
}
