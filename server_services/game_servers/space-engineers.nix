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
      description = "Directory to store game server";
      default = "/bulk-storage/server/SE-${cfg.serverName}";
    };
    
    launchOptions = mkOption {
      type = types.str;
      description = "Launch options to use.";
      default = "-console";
    };
    serverName = mkOption {
      type = types.str;
      default = "SpaceEngineers";
      description = "Server instance name for log/save paths";
    };
    worldName = mkOption {
      type = types.str;
      default = "Survival";
      description = "World name for log init";
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
        steamRun = "${lib.getExe pkgs.steam-run}";
        goscript = pkgs.writeShellApplication {
          meta.description = "launch SE dedicated server using Proton";
          name = "SE-Dedicated";
          runtimeInputs = [ pkgs.python3 pkgs.protontricks ];
          text = ''
            set -x
            # SteamCMD layout (this is what actually gets created)
            export WINEDEBUG=-all
            export PROTON_USE_WINED3D=1
            export STEAM_COMPAT_CLIENT_INSTALL_PATH="${cfg.dataDir}"
            export STEAM_COMPAT_DATA_PATH="${cfg.dataDir}/steamapps/compatdata/${builtins.toString cfg.gameID}"
            export PROTON_CONTENT_DIR="${cfg.dataDir}"
            export WINEPREFIX="${cfg.dataDir}/steamapps/compatdata/${builtins.toString cfg.gameID}/pfx"
            export PROTON="${cfg.dataDir}/proton-experimental/proton"
            mkdir -p ${cfg.gameDataDir}
            # Make sure the prefix directory exists (Proton will initialize it on first run)
            ${getExe' pkgs.coreutils "mkdir"} -p "$STEAM_COMPAT_DATA_PATH"


            
            echo "=== Starting Space Engineers Dedicated Server with Proton ==="
            echo "Prefix: $STEAM_COMPAT_DATA_PATH"
            echo "Proton: $PROTON"

            # Use waitforexitandrun (standard for servers) + your launchOptions
            # Add -console if you want console mode (recommended for headless)
            exec ${steamRun} "$PROTON" waitforexitandrun \
              "${cfg.dataDir}/DedicatedServer64/SpaceEngineersDedicated.exe" \
              "-path \"Z:\\\\bulk-storage\\\\server\\\\SE-${cfg.serverName}\"" \
              "${config.services.space-engineers-servers.serverName}" \
              ${cfg.launchOptions} -worldName "${config.services.space-engineers-servers.worldName}"

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
          #Restart = "always";
          User = "spaceengineers";
          WorkingDirectory = cfg.dataDir;

          preStart = ''
            set -x
            
            PFX="${cfg.dataDir}/steamapps/compatdata/${builtins.toString cfg.gameID}/pfx"
            ${lib.getExe pkgs.protontricks} --no-runtime ${builtins.toString cfg.gameID} prefixcreate || true
            # Install dependencies 
            ${lib.getExe pkgs.protontricks} ${builtins.toString cfg.gameID} dotnet48 vcrun2013 vcrun2017 || true

            ${getExe' pkgs.coreutils "chown"} -R spaceengineers:spaceengineers /bulk-storage/spaceengineers

            ${steamcmd} +force_install_dir "${cfg.dataDir}" +login anonymous +app_update ${builtins.toString cfg.gameID} validate +quit
            ${steamcmd} +force_install_dir "${cfg.dataDir}/proton-experimental/" +login anonymous +app_update 1493710 validate +quit
          '';
        };
      };
    systemd.tmpfiles.rules = [
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
