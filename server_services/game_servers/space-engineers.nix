{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.space-engineers-servers;
in {
  options.services.space-engineers-servers = {
    enable = mkEnableOption "Space Engineers Dedicated Server";

    steamcmdPackage = mkOption {
      type = types.package;
      default = pkgs.steamcmd;
      defaultText = "pkgs.steamcmd";
      description = ''
        The package implementing SteamCMD
      '';
    };

    dataDir = mkOption {
      type = types.path;
      description = "Directory to store game server";
      default = "/bulk-storage/spaceengineers";
    };

    launchOptions = mkOption {
      type = types.str;
      description = "Launch options to use.";
      default = "";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to open ports in the firewall for the server
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.space-engineers-servers = let
      steamcmd = "${cfg.steamcmdPackage}/bin/steamcmd";
      steam-run = "${pkgs.steam-run}/bin/steam-run";
    in {
      description = "Space Engineers Dedicated Server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        TimeoutSec = "15min";
        ExecStart = "${getExe' pkgs.coreutils "echo"} ${steam-run} ${cfg.dataDir}/FactoryServer.sh ${cfg.launchOptions}";
        #Restart = "always";
        User = "spaceengineers";
        WorkingDirectory = cfg.dataDir;
      };

      preStart = ''
        ${steamcmd} +force_install_dir "${cfg.dataDir}" +login anonymous +app_update 298740 validate +quit
      '';
    };

    users.users.spaceengineers = {
      description = "Space Engineers server service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "spaceengineers";
    };
    users.groups.spaceengineers = {};

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        27016
      ];
      allowedUDPPorts = [
        27016
      ];
    };
  };
}
