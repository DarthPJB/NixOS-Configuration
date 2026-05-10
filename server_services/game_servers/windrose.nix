{ config
, lib
, pkgs
, ...
}:
with lib;
let
  cfg = config.services.windrose-docker;
in
{
  options.services.windrose-docker = {
    enable = mkEnableOption "Windrose Dedicated Server Docker Container";

    image = mkOption {
      type = types.str;
      default = "ghcr.io/uberdudepl/windrose-dedicated-server-docker:v1.6.2";
      description = "Docker image to use";
    };

    containerName = mkOption {
      type = types.str;
      default = "windrose";
      description = "Container name";
    };

    serverName = mkOption {
      type = types.str;
      default = "My Windrose Server";
      description = "Server display name";
    };

    serverNote = mkOption {
      type = types.str;
      default = "Friendly co-op server";
      description = "Short public server note/description";
    };

    serverPassword = mkOption {
      type = types.str;
      default = "";
      description = "Server password (empty for public server)";
    };

    maxPlayers = mkOption {
      type = types.int;
      default = 4;
      description = "Maximum number of simultaneous players";
    };

    inviteCode = mkOption {
      type = types.str;
      default = "";
      description = "Invite code for players to join. Leave empty to auto-generate on first start.";
    };

    useDirectConnection = mkOption {
      type = types.bool;
      default = false;
      description = "Allow players to connect directly via IP instead of invite code. Requires port forwarding.";
    };

    directConnectionServerPort = mkOption {
      type = types.port;
      default = 7777;
      description = "Port used for direct connection (TCP and UDP). Only applies when useDirectConnection is true.";
    };

    directConnectionProxyAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Proxy address for direct connection. Only applies when useDirectConnection is true.";
    };

    userSelectedRegion = mkOption {
      type = types.str;
      default = "";
      description = "Connection service region: SEA, CIS, EU. Leave empty for auto-detect. EU covers both EU and NA regions.";
    };

    updateOnStart = mkOption {
      type = types.bool;
      default = true;
      description = "Update and validate server files on startup";
    };

    generateSettings = mkOption {
      type = types.bool;
      default = true;
      description = "Auto-patch ServerDescription.json from environment values";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/bulk-storage/windrose";
      description = "Base directory for game data";
    };

    steamcmdDir = mkOption {
      type = types.path;
      default = "/bulk-storage/windrose/steamcmd";
      description = "Persistent SteamCMD directory mounted at /opt/steamcmd";
    };

    puid = mkOption {
      type = types.int;
      default = 29987;
      description = "Host user id for mounted files";
    };

    pgid = mkOption {
      type = types.int;
      default = 29987;
      description = "Host group id for mounted files";
    };

    port = mkOption {
      type = types.port;
      default = 7777;
      description = "Game port (UDP)";
    };

    queryPort = mkOption {
      type = types.port;
      default = 7778;
      description = "Query port (UDP)";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open ports in the firewall for the server";
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional environment variables to pass to the container";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers.${cfg.containerName} = {
      autoStart = true;
      image = cfg.image;
      environment = {
        PUID = toString cfg.puid;
        PGID = toString cfg.pgid;
        WINDROSE_APP_ID = "4129620";
        STEAM_LOGIN = "anonymous";
        STEAM_PASS = "";
        UPDATE_ON_START = boolToString cfg.updateOnStart;
        GENERATE_SETTINGS = boolToString cfg.generateSettings;
        INVITE_CODE = cfg.inviteCode;
        SERVER_NAME = cfg.serverName;
        SERVER_NOTE = cfg.serverNote;
        SERVER_PASSWORD = cfg.serverPassword;
        MAX_PLAYERS = toString cfg.maxPlayers;
        P2P_PROXY_ADDRESS = "127.0.0.1";
        USE_DIRECT_CONNECTION = boolToString cfg.useDirectConnection;
        DIRECT_CONNECTION_SERVER_PORT = toString cfg.directConnectionServerPort;
        DIRECT_CONNECTION_PROXY_ADDRESS = cfg.directConnectionProxyAddress;
        USER_SELECTED_REGION = cfg.userSelectedRegion;
        MULTIHOME = "0.0.0.0";
        WINEARCH = "win64";
        STEAM_HOME = "/data/steam-home";
        WINEPREFIX = "/data/steam-home/.wine";
        WINEDEBUG = "-all";
        DISPLAY = ":99";
        PORT = toString cfg.port;
        QUERYPORT = toString cfg.queryPort;
      } // cfg.extraEnvironment;
      volumes = [
        "${cfg.dataDir}:/data"
        "${cfg.steamcmdDir}:/opt/steamcmd"
      ];
      extraOptions = [
        "--network=host"
        "--stop-timeout=90"
      ];
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.port
        cfg.queryPort
      ];
    };

    systemd.services.windrose-steamcmd-bootstrap = {
      description = "Bootstrap SteamCMD into host directory for Windrose";
      requiredBy = [ "docker-windrose.service" ];
      before = [ "docker-windrose.service" ];
      serviceConfig = {
        Type = "oneshot";
      };
      path = with pkgs; [ curl gnutar gzip coreutils ];
      script = ''
        install -d -m 0755 "${cfg.steamcmdDir}"

        if [ ! -f "${cfg.steamcmdDir}/steamcmd.sh" ]; then
          tmpdir=$(mktemp -d)
          trap 'rm -rf "$tmpdir"' EXIT
          curl -fsSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -o "$tmpdir/steamcmd_linux.tar.gz"
          tar -xzf "$tmpdir/steamcmd_linux.tar.gz" -C "${cfg.steamcmdDir}"
          chmod +x "${cfg.steamcmdDir}/steamcmd.sh"
        fi
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.steamcmdDir} 0755 root root -"
      "d ${cfg.dataDir}/steam-home 0755 root root -"
      "d ${cfg.dataDir}/data 0755 root root -"
      "d ${cfg.dataDir}/backups 0755 root root -"
      "d ${cfg.dataDir}/logs 0755 root root -"
      "d ${cfg.dataDir}/state 0755 root root -"
      "d ${cfg.dataDir}/diagnostics 0755 root root -"
    ];
  };
}
