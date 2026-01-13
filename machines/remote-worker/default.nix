# ----------- Remote Worker -----------------

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix
    ../../locale/tailscale.nix
    ../../server_services/nextcloud.nix
    ../../users/build.nix
    ../../services/dynamic_domain_gandi.nix
    ../../lib/enable-wg.nix
    (import ../../services/acme_server.nix { fqdn = "johnbargman.net"; })
    (import ../../services/acme_server.nix { fqdn = "johnbargman.com"; })
  ];

  security.acme.defaults.email = "commander@johnbargman.net";
  /* trigger the actual certificate generation for your hostname */
  security.acme.certs."johnbargman.net" = {
    extraDomainNames = [ "*.johnbargman.net" ]; #johnbargman.com"];
  };
  security.acme.certs."johnbargman.com" = {
    extraDomainNames = [ "*.johnbargman.com" ]; #johnbargman.com"];
  };

  services.nginx = {
    enable = true;
    statusPage = true;
    virtualHosts = {
      "default" = {
        default = true;
        listenAddresses = [ "0.0.0.0" ];
        locations."/" = {
          return = "444"; # Close connection without response
        };
      };
      "johnbargman.net" = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "0.0.0.0" ];
        locations."/" = {
          root = ../../webroot;
          #proxyWebsockets = false; # needed if you need to use websocket
        };
      };
      "johnbargman.com" = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "0.0.0.0" ];
        locations."/" = {
          root = ../../webroot;
          #proxyWebsockets = false; # needed if you need to use websocket
        };
      };
    };
  };
  secrix.services.wireguard-wireg0.secrets.remote-worker.encrypted.file = ../../secrets/wiregaurd/wg_remote-worker;
  environment.vpn =
    {
      enable = true;
      postfix = 50;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.remote-worker.decrypted.path;
    };

  networking.hostId = "e3fabb5b";
  networking.hostName = "remote-worker";

  networking.firewall.allowedTCPPorts = [ 3105 3106 ];

  services.prometheus.exporters.nginx = {
    enable = true;
    port = 3105;
  };

  services.prometheus.exporters.nextcloud = {
    enable = true;
    port = 3106;
    url = "https://nextcloud.johnbargman.net";
    username = "admin";
    passwordFile = config.secrix.system.secrets.nextcloud_password_file.decrypted.path;
  };

}

