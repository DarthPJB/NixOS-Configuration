{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.firefox
    pkgs.brave
    pkgs.vivaldi
  ];

  services = {
  syncthing = {
    enable = true;
    user = "John88";
    group = "users";
    dataDir = "/home/pokej";
    };
  };
}
