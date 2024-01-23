{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./i3wm.nix
    ];

  systemd.user.services.xwinwrap =
    {
      description = "xwinwrap-glmatrix";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${pkgs.xwinwrap}/bin/xwinwrap -ov -fs -- ${pkgs.xscreensaver}/libexec/xscreensaver/glmatrix -root -window-id WID
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
  services.picom =
    {
      enable = true;
      activeOpacity = 1;
      inactiveOpacity = 0.96;
      backend = "glx";
      fade = true;
      fadeDelta = 5;

      #you can get the CLASS_NAME of any window by executing the following command and clicking on a window.
      #xprop | grep "CLASS"
      #Note: The CLASS_NAME value is actually the second one.

      opacityRules = [
        "100:class_g = 'looking-glass-client'"
        "100:class_g = 'looking-glass-client' && focused"
        "100:class_g = 'betterlockscreen' && focused"
        "100:class_g = 'betterlockscreen' && !focused"
        "80:class_g = 'i3bar'"
        "80:class_g = 'Polybar'"
        "100:class_g = 'firefox'"
        "50:class_g = 'Alacritty' && focused"
        "50:class_g = 'Alacritty' && !focused"
        "100:class_g = 'Vivaldi-stable' && focused"
        "100:class_g = 'Brave-browser' && focused"
        "100:fullscreen"
        "80:class_g = 'i3lock' && focused"
        "80:class_g = 'i3lock' && !focused"
        "80:class_g = 'i3lock-color' && focused"
        "80:class_g = 'i3lock-color' && !focused"
      ];
      shadow = true;
      shadowOpacity = 0.75;
      settings = {
        #blur = { 
        #method = "gaussian";
        #blur-strength = "10";
        #size = 20;
        #deviation = 5.0;
        #blur-background = true;
        #};
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
