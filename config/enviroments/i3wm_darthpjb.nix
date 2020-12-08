{ config, pkgs, ... }: 

{
    imports =
    [ # Include the results of the hardware scan.
        ./enviroments/i3wm_darthpjb.nix
    ];
       environment.systemPackages = [pkgs.cool-retro-term pkgs.conky];
}