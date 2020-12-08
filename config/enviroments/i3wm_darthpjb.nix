{ config, pkgs, ... }: 

{
    imports =
    [ # Include the results of the hardware scan.
        ./i3wm.nix
    ];
       environment.systemPackages = [pkgs.cool-retro-term pkgs.conky];
}