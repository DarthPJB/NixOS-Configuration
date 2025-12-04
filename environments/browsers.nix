{ config, pkgs, unstable, ... }:
{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    #  pkgs.firefox
    pkgs.obsidian
    unstable.vivaldi
    pkgs.chromium
    pkgs.brave
  ];

  services = {
    syncthing = {
      enable = false;
      user = "John88";
      group = "users";
      dataDir = "/home/pokej";
    };
  };
}
