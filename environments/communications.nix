{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.element-desktop
    pkgs.discord
    pkgs.thunderbird
  ];
  systemd.user.services.mumble =
    {
      description = "mumble-autostart";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${pkgs.mumble}/bin/mumble
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
}
