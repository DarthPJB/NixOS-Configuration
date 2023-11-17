{ config, pkgs, ... }:

{
  imports =
    [
      ./i3wm.nix
    ];
  services.picom =
    {
      enable = true;
      package = pkgs.picom-jonaburg;
      backend = "glx";
      settings = {
        experimental-backends = true;
        xrender-sync-fence = true;
        blur = {
          method = "dual_kawase";
          strength = 7;
        };
        fading = true;
        fade-in-step = 0.1;
        fade-out-step = 0.1;
        transition-length = 100;
        transition-pow-x = 0.5;
        transition-pow-y = 0.5;
        transition-pow-w = 0.5;
        transition-pow-h = 0.5;
        size-transition = true;
      };
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
