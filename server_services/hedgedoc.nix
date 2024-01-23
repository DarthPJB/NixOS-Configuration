{ pkgs, config, ... }:
let
  fqdn = "hedgedoc.johnbargman.com";
in
{
  services = {
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      virtualHosts."${fqdn}" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:3333";
        locations."/socket.io/" = {
          proxyPass = "http://localhost:3333";
          proxyWebsockets = true;
          extraConfig =
            "proxy_ssl_server_name on;"
          ;
        };
      };
    };
    # DNS ENTRY NEEDED
    hedgedoc = {
      enable = true;
      settings = {
        db = {
          dialect = "sqlite";
          storage = "/var/lib/hedgedoc/db.hedgedoc.sqlite";
        };
        domain = "${fqdn}";
        port = 3333;
        useSSL = false;
        protocolUseSSL = true;
      };
    };
  };
}
