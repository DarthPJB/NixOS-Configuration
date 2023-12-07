{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./i3wm.nix
    ];

  systemd.user.services.mumble =
    {
      description = "mumble-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart="always";
          ExecStart = ''
            ${pkgs.mumble}/bin/mumble
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };

  systemd.user.services.xwinwrap =
    {
      description = "xwinwrap-glmatrix";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart="always";
          ExecStart = ''
             ${pkgs.xwinwrap}/bin/xwinwrap -ov -fs -- ${pkgs.xscreensaver}/libexec/xscreensaver/glmatrix -root -window-id WID
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
  services.picom =
    {
      enable = true;
      package = pkgs.picom;
      backend = "xrender";
      vsync = true;
      settings = {
        experimental-backends = true;
        xrender-sync-fence = true;
        blur = {
          method = "dual_kawase";
          strength = 7;
        };
        inactiveOpacity=0.95;
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
