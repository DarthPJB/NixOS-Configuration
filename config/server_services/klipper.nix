{ config, pkgs, ... }: {
  services = {
    klipper = {
      enable = true;
      configFile = ./klipper/skr-e3.cfg;
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
            [ "*.local" "*.lan" "*://app.fluidd.xyz" "*://my.mainsail.xyz" ];
          trusted_clients = [ "127.0.0.0/8" "192.168.1.0/24" ];
        };
      };
    };
  };
}
