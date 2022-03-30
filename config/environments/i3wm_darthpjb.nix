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
    environment.systemPackages =
    [
      pkgs.brightnessctl
      pkgs.pavucontrol
      pkgs.volumeicon
      pkgs.enlightenment.terminology
    	pkgs.conky
    	pkgs.lxappearance
    	pkgs.arandr
      pkgs.nextcloud-client
      inputs.parsecgaming.packages.x86_64-linux.parsecgaming
    ];
}
