{ config, pkgs, ... }: {
  networking.firewall.allowedTCPPorts = [ 80 8080 443 7125 ];
  security.polkit.enable = true;
  services = {
    klipper = {
      enable = true;
      configFile = ./klipper/skr-e3.cfg;
      mutableConfig = true;
      #mutableConfigFolder = true;
    };
    fluidd = {
      enable = true;
      nginx.locations."/webcam".proxyPass = "http://127.0.0.1:8080/stream";
    };
    nginx.clientMaxBodySize = "1000m";
    moonraker = {
      user = "root";
      enable = true;
      address = "0.0.0.0";
      settings = {
        octoprint_compat = { };
        history = { };
        authorization = {
          force_logins = true;
          cors_domains =
            [ "*.local" "*.lan" ];
          trusted_clients = [ "127.0.0.0/8" "10.88.128.0/24" "10.88.127.0/24" ];
        };
      };
    };
  };
}
