{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.firefox
    pkgs.brave
    pkgs.vivaldi
    pkgs.obsidian
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
