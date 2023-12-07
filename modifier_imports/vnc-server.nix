{ config, pkgs, ... }:
{

  systemd.user.services.x11vnc =
    {
      description = "run X11 vnc server";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${pkgs.x11vnc}/bin/x11vnc -display $DISPLAY
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
}
