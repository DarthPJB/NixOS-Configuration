{ config
, lib
, pkgs
, ...
}:
with lib;
let
  cfg = config.services.terratech-worlds-server;
in
{
  options.services.terratech-worlds-server = {
    enable = mkEnableOption "TerraTech Worlds dedicated server";

    steamcmdPackage = mkOption {
      type = types.package;
      default = pkgs.steamcmd;
      defaultText = "pkgs.steamcmd";
      description = "The package implementing SteamCMD";
    };

    gameID = mkOption {
      type = types.int;
      default = 2533070;
      description = "Steam app ID for TerraTech Worlds dedicated server";
    };

    installSteamSdk = mkOption {
      type = types.bool;
      default = true;
      description = "Install/update Steamworks SDK redistributable app 1007 on startup";
    };

    autoUpdate = mkOption {
      type = types.bool;
      default = true;
      description = "Run SteamCMD update on startup";
    };

    uid = mkOption {
      type = types.int;
      default = 29987;
      description = "Host user id for service user and server files";
    };

    gid = mkOption {
      type = types.int;
      default = 29987;
      description = "Host group id for service user and server files";
    };

    user = mkOption {
      type = types.str;
      default = "terratech";
      description = "Host system user that owns mounted TerraTech data";
    };

    group = mkOption {
      type = types.str;
      default = "terratech";
      description = "Host system group that owns mounted TerraTech data";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/bulk-storage/terratech-worlds";
      description = "Base directory where server files are installed";
    };

    configFile = mkOption {
      type = types.path;
      default = "/bulk-storage/terratech-worlds/config/dedicated_server_config.json";
      description = "Path to dedicated_server_config.json on the host";
    };

    slotCount = mkOption {
      type = types.ints.between 1 8;
      default = 6;
      description = "Maximum number of players (TerraTech Worlds supports up to 8)";
    };

    password = mkOption {
      type = types.str;
      default = "";
      description = "Server password (empty string for public server)";
    };

    winePrefix = mkOption {
      type = types.path;
      default = "/bulk-storage/terratech-worlds/wine64";
      description = "Persistent WINEPREFIX directory for TerraTech Worlds";
    };

    port = mkOption {
      type = types.port;
      default = 7777;
      description = "Game port (UDP)";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open ports in the firewall for the server";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.terratech-worlds-server =
      let
        steamcmd = lib.getExe cfg.steamcmdPackage;
        bash = lib.getExe pkgs.bash;
        mkdir = lib.getExe' pkgs.coreutils "mkdir";
        cp = lib.getExe' pkgs.coreutils "cp";
        chmod = lib.getExe' pkgs.coreutils "chmod";
        tail = lib.getExe' pkgs.coreutils "tail";
        steamRun = "${pkgs.steam-run}/bin/steam-run";
        wine64 = "${pkgs.wineWowPackages.stable}/bin/wine64";
        wineboot = "${pkgs.wineWowPackages.stable}/bin/wineboot";
        configDir = builtins.dirOf (toString cfg.configFile);
        logFile = "${cfg.dataDir}/TT2/Saved/Logs/TT2.log";
        generatedConfig = pkgs.writeText "terratech-dedicated_server_config.json" (builtins.toJSON {
          Port = cfg.port;
          SlotCount = cfg.slotCount;
          Password = cfg.password;
        });
      in
      {
        description = "TerraTech Worlds Dedicated Server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          Restart = "always";
          RestartSec = 15;
          Environment = [
            "WINEARCH=win64"
            "WINEPREFIX=${cfg.winePrefix}"
            "WINEDEBUG=-all"
          ];
          ExecStartPre = [
            "${mkdir} -p ${cfg.dataDir}"
            "${mkdir} -p ${cfg.winePrefix}"
            "${mkdir} -p ${configDir}"
            "${cp} ${generatedConfig} ${cfg.configFile}"
            "${chmod} 0640 ${cfg.configFile}"
            "${cp} ${cfg.configFile} ${cfg.dataDir}/dedicated_server_config.json"
            "${bash} -c 'if [ ! -d \"${cfg.winePrefix}/drive_c/windows\" ]; then ${steamRun} ${wineboot} -u >/dev/null 2>&1; fi'"
          ]
          ++ optional cfg.autoUpdate "${steamcmd} +@sSteamCmdForcePlatformType windows +force_install_dir ${cfg.dataDir} +login anonymous +app_update ${builtins.toString cfg.gameID} validate +quit"
          ++ optional (cfg.autoUpdate && cfg.installSteamSdk) "${steamcmd} +@sSteamCmdForcePlatformType windows +force_install_dir ${cfg.dataDir}/TT2/Binaries/Win64 +login anonymous +app_update 1007 validate +quit";

          ExecStart = "${bash} -euc 'if [ -f \"${cfg.dataDir}/TT2/Binaries/Win64/TT2Server-Win64-Shipping.exe\" ]; then ${steamRun} ${wine64} ${cfg.dataDir}/TT2/Binaries/Win64/TT2Server-Win64-Shipping.exe -log & TT2_PID=$!; elif [ -f \"${cfg.dataDir}/TT2Server.exe\" ]; then ${steamRun} ${wine64} ${cfg.dataDir}/TT2Server.exe -log & TT2_PID=$!; else echo \"terratech-worlds-server: no server executable found in ${cfg.dataDir}\" >&2; exit 1; fi; exec ${tail} -c0 -F ${logFile} --pid=$TT2_PID'";
        };
      };

    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.port
      ];
    };

    users.groups.${cfg.group} = {
      gid = cfg.gid;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      uid = cfg.uid;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "TerraTech Worlds service account";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.winePrefix} 0755 ${cfg.user} ${cfg.group} -"
      "d ${builtins.dirOf (toString cfg.configFile)} 0755 ${cfg.user} ${cfg.group} -"
      "f ${cfg.configFile} 0640 ${cfg.user} ${cfg.group} -"
    ];
  };
}
