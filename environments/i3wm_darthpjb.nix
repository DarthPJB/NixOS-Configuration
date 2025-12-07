{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./i3wm.nix
    ];

  systemd.user.services.xwinwrap = lib.mkDefault
    {
      description = "xwinwrap-desktop";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
             ${lib.getExe pkgs.xwinwrap}  -ni -fs -s -st -sp -b -nf -ov -- ${lib.getExe' pkgs.xterm "xterm"} -into WID -geometry 1920x1080 -bg black -e ${lib.getExe pkgs.bottom}
            # ${pkgs.xwinwrap}/bin/xwinwrap -ov -fs -- ${pkgs.xscreensaver}/libexec/xscreensaver/atlantis -root -window-id WID
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };

  # systemd.user.services.fastcompmgr =
  #   {
  #     description = "fastcompmgr";
  #     wantedBy = [ "graphical-session.target" ];
  #     serviceConfig =
  #       {
  #         Restart = "always";
  #         ExecStart = ''
  #           ${pkgs.fastcompmgr}/bin/fastcompmgr -i 0.95 -F
  #         '';
  #         PassEnvironment = "DISPLAY XAUTHORITY";
  #       };
  #   };

  services.picom =
    {
      enable = true;
      activeOpacity = 1;
      inactiveOpacity = 0.96;
      backend = "glx";
      fadeDelta = 5;

      #you can get the CLASS_NAME of any window by executing the following command and clicking on a window.
      #xprop | grep "CLASS"
      #Note: The CLASS_NAME value is actually the second one.
      vSync = true;
      #refreshRate = 60; # Enforce 60 FPS target
      settings = {
        shadow = false;
        fading = false;
        blur = false;
        unredir-if-possible = true;
        glx-no-stencil = true;
        glx-no-rebind-pixmap = true;
        detect-transient = true;
        detect-client-leader = true;
        use-damage = true;
        vsync-use-glfinish = true; # Optimize VSync for ARM
      };
      opacityRules = [
        "100:class_g = 'looking-glass-client'"
        "100:class_g = 'looking-glass-client' && focused"
        "100:class_g = 'betterlockscreen' && focused"
        "100:class_g = 'betterlockscreen' && !focused"
        "80:class_g = 'i3bar'"
        "80:class_g = 'Polybar'"
        "100:class_g = 'chromium'"
        "50:class_g = 'Alacritty' && focused"
        "50:class_g = 'Alacritty' && !focused"
        "100:class_g = 'Vivaldi-stable' && focused"
        "100:class_g = 'Brave-browser' && focused"
        "80:class_g = 'i3lock' && focused"
        "80:class_g = 'i3lock' && !focused"
        "80:class_g = 'i3lock-color' && focused"
        "80:class_g = 'i3lock-color' && !focused"
        "100:fullscreen"
      ];
    };
     environment.systemPackages = with pkgs; [
            papirus-icon-theme
            qt5ct
            lxappearance
          ];

          qt5 = {
            enable = true;
            style = "gtk2";
            platformTheme = "gtk2";
          };

          gtk = {
            enable = true;
            theme.name = "Adwaita-dark";
            iconTheme.name = "Papirus-Dark";
          };

          environment.variables = {
            QT_QPA_PLATFORMTHEME = "gtk2";
          };

  programs.dconf.enable = true;
}
