{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.element-desktop
    pkgs.discord
    pkgs.thunderbird
  ];
  systemd.user.services.mumble = {
    description = "mumble-autostart";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = ''
        ${lib.getExe pkgs.mumble}
      '';
      PassEnvironment = "DISPLAY XAUTHORITY";
    };
  };
}
