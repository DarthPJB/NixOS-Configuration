{ config, pkgs, ... }:

{
    imports =
    [ # Include the results of the hardware scan.
        ./i3wm.nix
    ];
    services.compton =
    {
      enable = true;
      shadow = true;
      inactiveOpacity = 0.8;
      activeOpacity = 0.99;
    };
    programs.dconf.enable = true;
    services.gnome3.gnome-keyring.enable = true;
    environment.systemPackages = [
	pkgs.cool-retro-term
	pkgs.conky
	pkgs.lxappearance
	pkgs.arandr
	pkgs.brave];
}
