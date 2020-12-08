{ config, pkgs, ... }: 

{
    imports =
    [ # Include the results of the hardware scan.
        ./i3wm.nix
    ];
    programs.dconf.enable = true;
    services.gnome3.gnome-keyring.enable = true;
    services.gnome3.seahorse.enable = true;
    environment.systemPackages = [pkgs.cool-retro-term pkgs.conky pkgs.lxappearance];
}