{ lib }:
# genNginx: settings -> hostname -> NixOS services.nginx config
# settings is the output of mkNginxSettings
# Generates config if hostname has nginx settings
settings: hostname:
let
  machineSettings = settings.machines.${hostname} or null;
in
if machineSettings == null then { } else {
  services.nginx = {
    enable = true;
    defaultRoot = "/var/empty";
    virtualHosts = lib.mapAttrs
      (domain: proxy: {
        enableACME = false;
        forceSSL = false;
        listenAddresses = machineSettings.listenAddresses;
        locations."/" = {
          proxyPass = "http://${proxy.backend}";
          proxyWebsockets = true; # Common for web apps
        };
      })
      machineSettings.proxies;
  };
}
