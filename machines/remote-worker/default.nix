# ----------- Remote Worker -----------------

{ config
, pkgs
, lib
, hostname
, self
, ...
}:
let
  personal-site = self.inputs.personal-site;
in
{
  imports = [
    ./hardware-configuration.nix
    # ../../configuration.nix — already in commonModules (flake.nix), do not duplicate
    ../../server_services/nextcloud.nix
    ../../users/build.nix
    ../../services/dynamic_domain_gandi.nix
    ../../modules/enable-wg-topology.nix
    (import ../../services/acme_server.nix { fqdn = "johnbargman.net"; })
    (import ../../services/acme_server.nix { fqdn = "johnbargman.com"; })
  ];

  security.acme.defaults.email = "commander@johnbargman.net";
  # trigger the actual certificate generation for your hostname
  security.acme.certs."johnbargman.net" = {
    # dnsProvider must be explicit — nginx module's mkOverride 2000 null
    # overrides the inherited default. See acme_server.nix for rationale.
    dnsProvider = "gandiv5";
    environmentFile = config.secrix.system.secrets.dns01.decrypted.path;
    webroot = null;
    extraDomainNames = [ "*.johnbargman.net" ]; # johnbargman.com"];
  };
  security.acme.certs."johnbargman.com" = {
    dnsProvider = "gandiv5";
    environmentFile = config.secrix.system.secrets.dns01.decrypted.path;
    webroot = null;
    extraDomainNames = [ "*.johnbargman.com" ]; # johnbargman.com"];
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
        # External IP 193.16.42.101 NATs to 10.0.1.42 (ens3)
        listenAddresses = [ "10.0.1.42" "10.88.127.50" ];
        locations."/" = {
          root = ../../webroot;
        };
      };
      # johnbargman.com — split-horizon
      # Public: serves release site on external IP
      # TODO: switch to personal-site.packages once input is stable
      "johnbargman.com" = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
        # External IP 193.16.42.101 NATs to 10.0.1.42 (ens3)
        listenAddresses = [ "10.0.1.42" ];
        locations."/" = {
          # root = personal-site.packages.${pkgs.stdenv.hostPlatform.system}.personal-site;
          root = ../../webroot;
        };
      };
      # WireGuard: serves staging site on WG IP only
      "johnbargman.com-lan" = {
        serverName = "johnbargman.com";
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "10.88.127.50" ];
        locations."/" = {
          root = personal-site.packages.${pkgs.stdenv.hostPlatform.system}.personal-site-staging;
        };
      };
    };
  };
  # Virtual disk devices — smartctl/smartd not applicable
  services.smartd.enable = lib.mkForce false;
  services.prometheus.exporters.smartctl.enable = lib.mkForce false;

  enableWgTopology.enable = true;

  networking.hostId = "e3fabb5b";
  #networking.hostName = "remote-worker";

  networking.firewall.allowedTCPPorts = [
    3105
    3106
    80
    443
  ];

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
    user = "nextcloud";
  };

  # OpenCode fleet configuration
  # DISABLED for overlord-I — re-enable and test as part of overlord-II
  # services.opencode-fleet = {
  #   enable = true;
  #   voyagerOnly = true; # Client machine — deploy Voyager only
  #   user = "John88";
  # };

}
