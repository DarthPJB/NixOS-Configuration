{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.space-engineers-docker;
in
{
  options.services.space-engineers-docker = {
    enable = mkEnableOption "Space Engineers Docker Container";

    image = mkOption {
      type = types.str;
      default = "devidian/spaceengineers:winestaging";
      description = "Docker image to use";
    };

    instanceName = mkOption {
      type = types.str;
      default = "SpaceEngineers";
      description = "Instance name for the game server";
    };

    worldName = mkOption {
      type = types.str;
      default = "Survival";
      description = "World name";
    };

    gameMode = mkOption {
      type = types.str;
      default = "SURVIVAL";
      description = "Game mode: SURVIVAL or CREATIVE";
    };

    publicIP = mkOption {
      type = types.str;
      description = "Public IP for server discovery";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/bulk-storage/spaceengineers";
      description = "Base directory for game data";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open ports in the firewall for the server";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers.se-ds = {
      autoStart = true;
      image = cfg.image;
      environment = {
        INSTANCE_NAME = cfg.instanceName;
        PUBLIC_IP = cfg.publicIP;
      };
      volumes = [
        "${cfg.dataDir}/plugins:/appdata/space-engineers/plugins"
        "${cfg.dataDir}/instances:/appdata/space-engineers/instances"
        "${cfg.dataDir}/SpaceEngineersDedicated:/appdata/space-engineers/SpaceEngineersDedicated"
        "${cfg.dataDir}/steamcmd:/root/.steam"
      ];
      extraOptions = [ "--network=host" ];
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = [
        27016
        27015
      ];
      #      allowedTCPPorts =
    };

    users.users.spaceengineers = {
      description = "Space Engineers server service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "spaceengineers";
    };
    users.groups.spaceengineers = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 spaceengineers spaceengineers -"
      "d ${cfg.dataDir}/plugins 0755 spaceengineers spaceengineers -"
      "d ${cfg.dataDir}/instances 0755 spaceengineers spaceengineers -"
      "d ${cfg.dataDir}/instances/${cfg.instanceName} 0755 spaceengineers spaceengineers -"
      "d ${cfg.dataDir}/instances/${cfg.instanceName}/Saves 0755 spaceengineers spaceengineers -"
    ];
  };
}
