{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.nextcloud-client
    pkgs.rsync
  ];
  # ---- ADD SYSTEMD SERVICE HERE
    systemd.user.services.nextcloud-client =
    {
      description = "nextcloud-client";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${pkgs.nextcloud-client}/bin/nextcloud
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
}
