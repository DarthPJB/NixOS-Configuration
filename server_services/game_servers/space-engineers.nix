{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.services.space-engineers-servers;
in
{
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

    winePackage = mkOption {
      type = types.package;
      description = "Wine package to use";
      default = pkgs.winePackages.staging;
      defaultText = "pkgs.winePackages.staging";
    };

    winetricksPackage = mkOption {
      type = types.package;
      default = pkgs.winetricks;
      description = "Winetricks package";
    };

    gameID = mkOption {
      type = types.int;
      description = "gameID";
      default = 298740;
    };

    dataDir = mkOption {
      type = types.path;
      description = "Directory to store game server";
      default = "/bulk-storage/spaceengineers";
    };

    gameDataDir = mkOption {
      type = types.path;
      description = "Directory for game instance data";
      default = "/bulk-storage/spaceengineers/instances/${cfg.serverName}";
    };

    launchOptions = mkOption {
      type = types.str;
      description = "Launch options to use.";
      default = "-console -noconsole";
    };
    serverName = mkOption {
      type = types.str;
      default = "SpaceEngineers";
      description = "Server instance name";
    };
    worldName = mkOption {
      type = types.str;
      default = "Survival";
      description = "World name";
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
    systemd.services.space-engineers-servers =
      let
        steamcmd = "${cfg.steamcmdPackage}/bin/steamcmd";
        wine = "${cfg.winePackage}/bin/wine";
        wine64 = "${cfg.winePackage}/bin/wine64";
        winetricks = "${cfg.winetricksPackage}/bin/winetricks";
        goscript = pkgs.writeShellApplication {
          meta.description = "launch SE dedicated server using Wine";
          name = "SE-Dedicated";
          runtimeInputs = [
            pkgs.python3
            pkgs.xorg.xvfb
            pkgs.cabextract
            pkgs.winePackages.staging
            pkgs.winetricks
          ];
          text = ''
            set -x

            GAME_DIR="${cfg.dataDir}/SpaceEngineersDedicated"
            INSTANCE_DIR="${cfg.gameDataDir}"
            PREFIX="${cfg.dataDir}/wineprefix"
            export STEAMCMD_DIR="${cfg.dataDir}/steamcmd"

            mkdir -p "$INSTANCE_DIR"
            mkdir -p "$PREFIX"

            echo "=== Installing game files ==="
            ${steamcmd} +force_install_dir ''${GAME_DIR} +login anonymous +@sSteamCmdForcePlatformType windows +app_update ${toString cfg.gameID} validate +quit

            echo "=== Checking wine prefix ==="
            export WINEARCH=win64
            export WINEDEBUG=-all
            export WINEPREFIX="$PREFIX"

            if [ -d "$PREFIX" ]; then
              echo "Removing old wine prefix..."
              rm -rf "$PREFIX"
            fi

            echo "Initializing wine prefix..."
            export DISPLAY=:5

            Xvfb :5 -screen 0 1024x768x16 &
            XVFB_PID=$!
            sleep 1

            wineboot --init /nogui
            winecfg -v win10

            kill $XVFB_PID 2>/dev/null || true

            echo "=== Installing winetricks dependencies ==="
            export WINEARCH=win64
            export WINEDEBUG=-all
            export WINEPREFIX="$PREFIX"
            export DISPLAY=:5

            if [ ! -f "$PREFIX/.winetricks_done" ]; then
              Xvfb :5 -screen 0 1024x768x16 &
              XVFB_PID=$!
              sleep 1

              ${winetricks} corefonts
              ${winetricks} sound=disabled
              ${winetricks} -q vcrun2019
              ${winetricks} -q --force dotnet48

              touch "$PREFIX/.winetricks_done"

              kill $XVFB_PID 2>/dev/null || true
            fi

            echo "=== Creating config ==="
            mkdir -p "$INSTANCE_DIR"
            cat > "$INSTANCE_DIR/SpaceEngineers-Dedicated.cfg" << CFGEOF
<?xml version="1.0"?>
<MyConfigDedicated>
  <ServerName>${cfg.serverName}</ServerName>
  <WorldName>${cfg.worldName}</WorldName>
  <GameMode>SURVIVAL</GameMode>
  <MaxPlayers>8</MaxPlayers>
  <Port>27016</Port>
  <IP>0.0.0.0</IP>
  <Ping>0</Ping>
  <OnlineMode>PUBLIC</OnlineMode>
  <AutoRestart>true</AutoRestart>
  <LoadWorld />
</MyConfigDedicated>
CFGEOF

            chown -R spaceengineers:spaceengineers "${cfg.dataDir}"

            echo "=== Starting Space Engineers Dedicated Server ==="
            echo "Game dir: $GAME_DIR"
            echo "Instance dir: $INSTANCE_DIR"
            echo "Prefix: $PREFIX"

            export WINEARCH=win64
            export WINEDEBUG=-all
            export WINEPREFIX="$PREFIX"

            WINE_PATH="Z:\\\\${lib.strings.replaceStrings ["/"] ["\\\\"] cfg.dataDir}\\\\${lib.strings.replaceStrings ["/"] ["\\\\"] cfg.serverName}"
            exec ${wine64} "$GAME_DIR/DedicatedServer64/SpaceEngineersDedicated.exe" \
              -path "$WINE_PATH" \
              ${cfg.launchOptions}
          '';
        };
      in
      {
        description = "Space Engineers Dedicated Server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          TimeoutSec = "15min";
          ExecStart = lib.getExe goscript;
          User = "spaceengineers";
          WorkingDirectory = cfg.dataDir;
          Environment = [
            "WINEARCH=win64"
            "WINEDEBUG=-all"
          ];
        };
      };
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 spaceengineers spaceengineers -"
      "d ${cfg.dataDir}/steamcmd 0755 spaceengineers spaceengineers -"
      "d ${cfg.dataDir}/wineprefix 0755 spaceengineers spaceengineers -"
      "d ${cfg.gameDataDir} 0755 spaceengineers spaceengineers -"
    ];
    users.users.spaceengineers = {
      description = "Space Engineers server service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "spaceengineers";
    };
    users.groups.spaceengineers = { };

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
