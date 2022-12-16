{ config, pkgs, ... }:

{
    imports =
    [ # Include the results of the hardware scan.
    ];
    services.picom =
    {
      enable = true;
      backend = "glx"; # try "glx" if xrender doesn't help
    };
    programs.dconf.enable = true;
    environment.systemPackages =
      [
      pkgs.neovim
      pkgs.firefox
    ];
   services.xserver.enable = true;
   services.xserver.desktopManager.xfce.enable = true;
}
