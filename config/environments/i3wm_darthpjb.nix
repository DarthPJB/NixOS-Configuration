{ config, pkgs, ... }:

{
  imports =
    [
      ./i3wm.nix
    ];
  services.picom =
    {
      enable = false;
      backend = "glx"; # try "glx" if xrender doesn't help
      shadow = true;
      inactiveOpacity = 0.95;
      activeOpacity = 1.0;
    };
  programs.dconf.enable = true;
  environment.systemPackages =
    [
      pkgs.betterlockscreen
      pkgs.brightnessctl
      pkgs.pavucontrol
      pkgs.volumeicon
      pkgs.enlightenment.terminology
      pkgs.conky
      pkgs.lxappearance
      pkgs.arandr
      #pkgs.nextcloud-client
    ];
}
