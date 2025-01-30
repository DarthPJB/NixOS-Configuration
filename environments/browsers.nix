{ config, pkgs, self, ... }:

{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    self.un_pkgs.firefox
    pkgs.obsidian
    pkgs.vivaldi
    #pkgs.google-chrome
    #pkgs.brave
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
