{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    pkgs.firefox
    pkgs.obsidian
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
