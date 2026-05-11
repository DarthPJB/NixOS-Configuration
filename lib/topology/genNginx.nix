{ lib }:
# genNginx: settings -> hostname -> NixOS services.nginx config
# settings is the output of mkNginxSettings
# Only generates config if hostname matches hubName
settings: hostname:
let
  isHub = hostname == settings.hubName;
in
if !isHub then { } else {
  services.nginx = {
    enable = true;
      virtualHosts = lib.mapAttrs
        (domain: proxy: {
          enableACME = true;
          forceSSL = true;
          useACMEHost = settings.acmeHost;
          listenAddresses = settings.listenAddresses;
          locations."/" = {
            proxyPass = "http://${proxy.backend}";
            proxyWebsockets = true; # Common for web apps
          };
        })
        settings.proxies;
  };
}
