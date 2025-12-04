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

  /*usage: fastcompmgr [options]
    Options
     -d display
    Which display should be managed.
     -r radius
    The blur radius for shadows. (default 12)
     -o opacity
    The translucency for shadows. (default .75)
     -l left-offset
    The left offset for shadows. (default -15)
     -t top-offset
    The top offset for shadows. (default -15)
     -I fade-in-step
    Opacity change between steps while fading in. (default 0.028)
     -O fade-out-step
    Opacity change between steps while fading out. (default 0.03)
     -D fade-delta-time
    The time between steps in a fade in milliseconds. (default 10)
     -m opacity
    The opacity for menus. (default 1.0)
     -c
    Enabled client-side shadows on windows.
     -C
    Avoid drawing shadows on dock/panel windows.
     -f
    Fade windows in/out when opening/closing.
     -F
    Fade windows during opacity changes.
     -i opacity
    Opacity of inactive windows. (0.1 - 1.0)
     -e opacity
    Opacity of window titlebars and borders. (0.1 - 1.0)
     -S
    Enable synchronous operation (for debugging).
  */

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
  programs.dconf.enable = true;
}
