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
      type = types.str;
      default = "/bulk-storage/terratech-worlds/config/dedicated_server_config.json";
      description = "Path to dedicated_server_config.json on the host";
    };

    slotCount = mkOption {
      type = types.ints.between 1 8;
      default = 6;
      description = "Maximum number of players (TerraTech Worlds supports up to 8)";
    };

    # TODO: Password is stored in plaintext in the Nix store via pkgs.writeText.
    # Migrate to secrix or agenix for runtime secret injection.
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

    saveSlot = mkOption {
      type = types.str;
      default = "default";
      description = "Name of the save slot to create/resume from";
    };

    map = mkOption {
      type = types.enum [ "Nibiru" "Phaeton" ];
      default = "Nibiru";
      description = "Map to launch";
    };

    maxBackupCount = mkOption {
      type = types.int;
      default = 5;
      description = "Maximum number of backup saves generated for a world";
    };

    backupInterval = mkOption {
      type = types.int;
      default = 300;
      description = "Number of seconds between each backup save";
    };

    replacePlanetSettings = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to modify planet settings of existing saves";
    };

    planetSettings = mkOption {
      type = types.submodule {
        options = {
          presetID = mkOption {
            type = types.enum [ "ID_Easy" "ID_Default" "ID_Hard" "ID_Veteran" ];
            default = "ID_Default";
            description = "Base difficulty level for planet settings";
          };

          isCustomised = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to apply customised settings from details";
          };

          details = mkOption {
            type = types.submodule {
              options = {
                isCreative = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Disable objectives, add creative-only blocks, and give access to creative-only options";
                };

                dayLength = mkOption {
                  type = types.enum [ 1200 1800 2700 3600 7200 14400 ];
                  default = 2700;
                  description = "Duration in seconds of a day";
                };

                weatherEvents = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Multiplier for frequency of weather events (0.5=low, 1.0=normal, 2.0=high)";
                };

                hazardsEnabled = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Creative mode only: whether hazards are dangerous";
                };

                hazardTargetingMode = mkOption {
                  type = types.enum [ 0 1 3 ];
                  default = 1;
                  description = "What hazards will target (0=no techs, 1=player techs, 3=player and enemy techs)";
                };

                resourceYield = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Multiplier for yield of resources (0.5=less, 1=normal, 2=more, 3=lots)";
                };

                enemiesEnabled = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Creative mode only: whether enemies spawn";
                };

                enemyDangerLevel = mkOption {
                  type = types.enum [ 0 1 2 3 ];
                  default = 1;
                  description = "Strength of enemy (0=tame, 1=standard, 2=dangerous, 3=savage)";
                };

                enemyRespawnRate = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Multiplier for enemy respawn frequency (0=never, 0.5=slow, 1=normal, 2=fast, 3=extreme)";
                };

                enemyBlockDropRate = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Multiplier for enemy block drop frequency (0=none, 0.5=less, 1=normal, 1.5=more, 2=most)";
                };

                structuresRequirePower = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether structures need power to operate";
                };

                structurePowerGeneration = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Multiplier for power generated by structures (supported values: 1.0/1.5/2.0)";
                };

                playerUnlimitedAmmo = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether ammo is unlimited";
                };

                playerUnlimitedBoosterFuel = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether booster fuel is unlimited";
                };

                playerUnlimitedOtherConsumables = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether consumables are unlimited";
                };

                blocksUnlimited = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Creative only: whether all blocks are immediately available";
                };

                blockLicensingEnabled = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether blocks require licensing when found";
                };

                staticBlockPurchaseProgression = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether blocks keep same price regardless of quantity bought";
                };

                blockPurchaseDiscountPercent = mkOption {
                  type = types.ints.between 0 100;
                  default = 0;
                  description = "How much block purchases are discounted by (0-100)";
                };

                blocksGloballyAccessible = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether block inventory can be accessed from anywhere";
                };

                playerTechUsesPower = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether the blocks of a tech need power";
                };

                playerTechPowerRegen = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Multiplier for power generated by player's tech reactor (supported values: 1.0/2.0)";
                };

                playerTakesDamage = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Creative only: whether player takes damage";
                };

                playerTechAutoRepair = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Multiplier for auto-repair rate (0=disabled, 0.75=slow, 1=normal, 1.5=fast)";
                };

                playerTechRepairCharges = mkOption {
                  type = types.ints.between 0 6;
                  default = 3;
                  description = "Number of times tech can auto-repair before visiting a tech yard (0-6)";
                };

                playerTechLimit = mkOption {
                  type = types.number;
                  default = 1.0;
                  description = "Tech reactor max capacity multiplier (supported values: 1.0/1.1/1.25/1.5/2.0)";
                };

                playerTechyardStorage = mkOption {
                  type = types.enum [ 1 2 ];
                  default = 1;
                  description = "Multiplier for block capacity of a tech yard (1 or 2)";
                };
              };
            };
            default = { };
          };
        };
      };
      default = { };
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
        steamRun = "${pkgs.steam-run}/bin/steam-run";
        wine64 = "${pkgs.wineWowPackages.stable}/bin/wine64";
        wineboot = "${pkgs.wineWowPackages.stable}/bin/wineboot";
        configDir = builtins.dirOf (toString cfg.configFile);
        generatedConfig = pkgs.writeText "terratech-dedicated_server_config.json" (builtins.toJSON {
          Port = cfg.port;
          SlotCount = cfg.slotCount;
          Password = cfg.password;
          MaxBackupCount = cfg.maxBackupCount;
          BackupInterval = cfg.backupInterval;
          Slot = cfg.saveSlot;
          Map = cfg.map;
          ReplacePlanetSettings = cfg.replacePlanetSettings;
          PlanetSettings = {
            PresetID = cfg.planetSettings.presetID;
            IsCustomised = cfg.planetSettings.isCustomised;
            Details = {
              IsCreative = cfg.planetSettings.details.isCreative;
              DayLength = cfg.planetSettings.details.dayLength;
              WeatherEvents = cfg.planetSettings.details.weatherEvents;
              HazardsEnabled = cfg.planetSettings.details.hazardsEnabled;
              HazardTargetingMode = cfg.planetSettings.details.hazardTargetingMode;
              ResourceYield = cfg.planetSettings.details.resourceYield;
              EnemiesEnabled = cfg.planetSettings.details.enemiesEnabled;
              EnemyDangerLevel = cfg.planetSettings.details.enemyDangerLevel;
              EnemyRespawnRate = cfg.planetSettings.details.enemyRespawnRate;
              EnemyBlockDropRate = cfg.planetSettings.details.enemyBlockDropRate;
              StructuresRequirePower = cfg.planetSettings.details.structuresRequirePower;
              StructurePowerGeneration = cfg.planetSettings.details.structurePowerGeneration;
              PlayerUnlimitedAmmo = cfg.planetSettings.details.playerUnlimitedAmmo;
              PlayerUnlimitedBoosterFuel = cfg.planetSettings.details.playerUnlimitedBoosterFuel;
              PlayerUnlimitedOtherConsumables = cfg.planetSettings.details.playerUnlimitedOtherConsumables;
              BlocksUnlimited = cfg.planetSettings.details.blocksUnlimited;
              BlockLicensingEnabled = cfg.planetSettings.details.blockLicensingEnabled;
              StaticBlockPurchaseProgression = cfg.planetSettings.details.staticBlockPurchaseProgression;
              BlockPurchaseDiscountPercent = cfg.planetSettings.details.blockPurchaseDiscountPercent;
              BlocksGloballyAccessible = cfg.planetSettings.details.blocksGloballyAccessible;
              PlayerTechUsesPower = cfg.planetSettings.details.playerTechUsesPower;
              PlayerTechPowerRegen = cfg.planetSettings.details.playerTechPowerRegen;
              PlayerTakesDamage = cfg.planetSettings.details.playerTakesDamage;
              PlayerTechAutoRepair = cfg.planetSettings.details.playerTechAutoRepair;
              PlayerTechRepairCharges = cfg.planetSettings.details.playerTechRepairCharges;
              PlayerTechLimit = cfg.planetSettings.details.playerTechLimit;
              PlayerTechyardStorage = cfg.planetSettings.details.playerTechyardStorage;
            };
          };
        });
      in
      {
        description = "TerraTech Worlds Dedicated Server";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "systemd-tmpfiles-setup.service"
        ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          Restart = "always";
          RestartSec = 6;
          StartLimitBurst = 10;
          StartLimitIntervalSec = 60;
          TimeoutStopSec = 60;
          Environment = [
            "WINEARCH=win64"
            "WINEPREFIX=${cfg.winePrefix}"
            "WINEDEBUG=fixme-all,err+module"
          ];
          ExecStartPre = [
            "${mkdir} -p ${cfg.dataDir}"
            "${mkdir} -p ${cfg.winePrefix}"
            "${mkdir} -p ${configDir}"
            "${cp} ${generatedConfig} ${cfg.configFile}"
            "${chmod} 0640 ${cfg.configFile}"
            "${cp} ${cfg.configFile} ${cfg.dataDir}/dedicated_server_config.json"
            "${bash} -c 'if [ ! -d \"${cfg.winePrefix}/drive_c/windows\" ]; then ${steamRun} ${wineboot} -i; fi'"
          ]
          ++ optional cfg.autoUpdate "${steamcmd} +@sSteamCmdForcePlatformType windows +force_install_dir ${cfg.dataDir} +login anonymous +app_update ${builtins.toString cfg.gameID} validate +quit"
          ++ optional (cfg.autoUpdate && cfg.installSteamSdk) "${steamcmd} +@sSteamCmdForcePlatformType windows +force_install_dir ${cfg.dataDir}/TT2/Binaries/Win64 +login anonymous +app_update 1007 validate +quit";

          ExecStart = "${bash} -euc 'if [ -f \"${cfg.dataDir}/TT2/Binaries/Win64/TT2Server-Win64-Shipping.exe\" ]; then exec ${steamRun} ${wine64} ${cfg.dataDir}/TT2/Binaries/Win64/TT2Server-Win64-Shipping.exe -log; elif [ -f \"${cfg.dataDir}/TT2Server.exe\" ]; then exec ${steamRun} ${wine64} ${cfg.dataDir}/TT2Server.exe -log; else echo \"terratech-worlds-server: no server executable found in ${cfg.dataDir}\" >&2; exit 1; fi'";
        };
      };

    systemd.timers.terratech-worlds-restart = {
      description = "Daily restart timer for TerraTech Worlds server (triggers update)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 08:00:00 UTC";
        Persistent = true;
        Unit = "terratech-worlds-server.service";
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
