{ config
, pkgs
, unstable
, ...
}:
{
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    #  pkgs.firefox
    pkgs.obsidian
    pkgs.vivaldi
    pkgs.chromium
    pkgs.brave
    pkgs.jq
    pkgs.ffmpeg-full
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
