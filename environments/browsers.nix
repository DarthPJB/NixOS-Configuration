{ config, pkgs, self, ... }:

{
  #nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    pkgs.firefox
    pkgs.obsidian
    pkgs.vivaldi
    #pkgs.google-chrome
    #pkgs.brave
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
