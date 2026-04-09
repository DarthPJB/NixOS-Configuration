{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.services.dragonwilds-server;
in
{
  options.services.dragonwilds-server = {
    enable = mkEnableOption "Dragonwilds Dedicated Server";

    steamcmdPackage = mkOption {
      type = types.package;
      default = pkgs.steamcmd;
      defaultText = "pkgs.steamcmd";
      description = ''
        The package implementing SteamCMD
      '';
    };

    gameID = mkOption {
      type = types.int;
      description = "gameID";
      default = 4019830;
    };

    dataDir = mkOption {
      type = types.path;
      description = "Directory to store game server";
      default = "/bulk-storage/dragonwilds";
    };

    backupDir = mkOption {
      type = types.path;
      description = "Directory to store config backups";
      default = "/home/dragonwilds/dragonwilds_backups";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to open ports in the firewall for the server
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.dragonwilds-server =
      let
        steamcmd = lib.getExe cfg.steamcmdPackage;
        bash = lib.getExe' pkgs.bash;
        mkdir = lib.getExe' pkgs.coreutils "mkdir";
      in
      {
        description = "RuneScape Dragonwilds Dedicated Server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          User = "dragonwilds";
          Group = "dragonwilds";
          WorkingDirectory = cfg.dataDir;
          Restart = "always";
          RestartSec = 15;

          ExecStartPre = ''
            ${mkdir} -p ${cfg.dataDir}
            ${mkdir} -p ${cfg.backupDir}
            cp ${cfg.dataDir}/RSDragonwilds/Saved/Config/LinuxServer/DedicatedServer.ini ${cfg.backupDir}/DedicatedServer.ini.bak || true
            ${steamcmd} +force_install_dir ${cfg.dataDir} +login anonymous +app_update ${builtins.toString cfg.gameID} +quit
            cp ${cfg.backupDir}/DedicatedServer.ini.bak ${cfg.dataDir}/RSDragonwilds/Saved/Config/LinuxServer/DedicatedServer.ini || true && chmod +x ${cfg.dataDir}/RSDragonwildsServer.sh
          '';

          ExecStart = '' ${cfg.dataDir}/RSDragonwildsServer.sh -log -NewConsole -Port=7777 '';
        };
      };

    users.users.dragonwilds = {
      description = "Dragonwilds server service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "dragonwilds";
    };
    users.groups.dragonwilds = { };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        7777
      ];
      allowedUDPPorts = [
        7777
      ];
    };
  };
}
