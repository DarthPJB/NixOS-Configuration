# Minecraft CurseForge Server — NixOS Module
#
# Deploys a Minecraft server from a CurseForge modpack builder derivation.
# Supports multiple instances via `services.minecraft-curseforge.<name>`.
#
# Usage:
#   services.minecraft-curseforge.all-the-mons = {
#     enable = true;
#     pack = pkgs.minecraft-curseforge-all-the-mons;
#     acceptEula = true;
#     serverProperties = { ... };
#   };

{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.services.minecraft-curseforge;

  # systemd enforces a 31-character limit on user and group names
  # (UT_NAMESIZE from `/usr/include/limits.h`).
  # Shorten the service name prefix to stay safely under this limit.
  #
  # Example: instance "all-the-mons" → user "mc-curseforge-all-the-mons" (24 chars)
  mkUserGroupName = name: "mc-curseforge-${name}";
  mkServiceName = name: "mc-curseforge-${name}";
in

{
  options.services.minecraft-curseforge = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        enable = mkEnableOption "Minecraft CurseForge server instance '${name}'";

        pack = mkOption {
          type = types.package;
          description = "Builder derivation for the CurseForge modpack.";
        };

        acceptEula = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to accept the Minecraft EULA.";
        };

        serverProperties = mkOption {
          type = types.attrsOf (types.oneOf [ types.str types.int types.bool ]);
          default = { };
          description = "Server properties written to server.properties.";
        };

        maxMemory = mkOption {
          type = types.str;
          default = "4G";
          description = "Maximum JVM heap size.";
        };

        minMemory = mkOption {
          type = types.str;
          default = "2G";
          description = "Minimum JVM heap size.";
        };

        jvmArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional JVM arguments.";
        };

        dataDir = mkOption {
          type = types.path;
          default = "/bulk-storage/minecraft/${name}";
          description = "Directory for mutable server state (world, backups, logs).";
        };

        openFirewall = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to open the game port in the firewall.";
        };

        gamePort = mkOption {
          type = types.port;
          default = 25565;
          description = "TCP port for Minecraft game traffic.";
        };

        rconPort = mkOption {
          type = types.port;
          default = 25575;
          description = "TCP port for RCON remote console.";
        };

        rconPassword = mkOption {
          type = types.str;
          default = "";
          description = "RCON password. Used internally for graceful shutdown via mcrcon (localhost only).";
        };

        ops = mkOption {
          type = types.listOf (types.submodule {
            options = {
              uuid = mkOption {
                type = types.str;
                description = "Player UUID (e.g. 069a79f4-44e9-4726-a5be-fca90e38aaf5).";
              };
              name = mkOption {
                type = types.str;
                description = "Player name.";
              };
              level = mkOption {
                type = types.int;
                default = 4;
                description = "Op level (1-4). 4 = full access.";
              };
              bypassesPlayerLimit = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the player can join when server is full.";
              };
            };
          });
          default = [ ];
          description = "List of server operators. Written to ops.json on start.";
        };
      };
    }));
    default = { };
    description = "Minecraft CurseForge server instances.";
  };

  # ── Config: generate NixOS settings for each enabled instance ──────
  # IMPORTANT: Each top-level attribute (users, systemd, networking, environment)
  # is assigned separately using mkMerge/mapAttrsToList to avoid infinite recursion.
  # Using `config = mkMerge (mapAttrsToList ... cfg)` would cause a cycle because
  # the module system must evaluate the entire dynamic expression to determine
  # what attributes it defines. Per-attribute assignments have statically known
  # target paths, so the RHS is evaluated lazily.
  #
  # For attrset-valued options we use `if ... then ... else { }` as the conditional.
  # For list-valued options we use `optionals` (returns [] for false conditions).
  # This avoids mkIf, which mkMerge/concatLists don't process.

  config = {
    users.users = mkMerge (mapAttrsToList
      (name: instanceCfg:
        let
          user = mkUserGroupName name;
          dataDir = instanceCfg.dataDir;
        in
        if instanceCfg.enable then {
          "${user}" = {
            isSystemUser = true;
            group = user;
            home = dataDir;
            createHome = true;
            description = "Minecraft server '${name}' service user";
          };
        } else { }
      )
      cfg);

    users.groups = mkMerge (mapAttrsToList
      (name: instanceCfg:
        let
          group = mkUserGroupName name;
        in
        if instanceCfg.enable then {
          "${group}" = { };
        } else { }
      )
      cfg);

    systemd.tmpfiles.rules = concatLists (mapAttrsToList
      (name: instanceCfg:
        let
          dataDir = instanceCfg.dataDir;
          user = mkUserGroupName name;
          group = user;
        in
        optionals instanceCfg.enable [
          "d ${dataDir} 0755 ${user} ${group} -"
          "d ${dataDir}/backups 0755 ${user} ${group} -"
          "d ${dataDir}/logs 0755 ${user} ${group} -"
        ]
      )
      cfg);

    systemd.services = mkMerge (mapAttrsToList
      (name: instanceCfg:
        let
          serviceName = mkServiceName name;
          user = mkUserGroupName name;
          group = user;
          dataDir = instanceCfg.dataDir;

          finalPack = pkgs.symlinkJoin {
            name = "mc-server-final-${name}";
            paths = [ instanceCfg.pack ];
            postBuild = ''
              ${optionalString instanceCfg.acceptEula ''
                echo "eula=true" > "$out/eula.txt"
              ''}
              cp ${serverPropertiesFile} "$out/server.properties"
            '';
            passthru = instanceCfg.pack.passthru or { } // {
              imageId = instanceCfg.pack.passthru.imageId or (builtins.baseNameOf instanceCfg.pack.src);
              jre = instanceCfg.pack.passthru.jre or pkgs.jdk21;
            };
          };

          # Merge RCON settings into serverProperties
          serverPropertiesWithRcon = instanceCfg.serverProperties // {
            "enable-rcon" = true;
            "rcon.port" = instanceCfg.rconPort;
            "rcon.password" = instanceCfg.rconPassword;
          };

          serverPropertiesFile = pkgs.writeText "server.properties" (
            generators.toKeyValue
              {
                listsAsDuplicateKeys = true;
              }
              serverPropertiesWithRcon
          );

          # Graceful shutdown via RCON: warn players, save world, then stop server
          execStopPreScript = pkgs.writeShellScript "${serviceName}-exec-stop-pre" ''
            set -euo pipefail
            SLEEP="${lib.getExe' pkgs.coreutils "sleep"}"
            MCRCON="${lib.getExe pkgs.mcrcon} -H 127.0.0.1 -P ${toString instanceCfg.rconPort} -p '${instanceCfg.rconPassword}'"

            # Warn players with countdown
            $MCRCON -w 5 "say §c[Server] §fServer shutdown in 30 seconds..." || true
            $SLEEP 20
            $MCRCON -w 5 "say §c[Server] §fServer shutdown in 10 seconds..." || true
            $SLEEP 5
            $MCRCON -w 5 "say §c[Server] §fServer shutdown in 5 seconds..." || true
            $SLEEP 3
            $MCRCON -w 5 "say §c[Server] §fServer shutdown in 2 seconds..." || true
            $SLEEP 2
            $MCRCON -w 5 "say §c[Server] §eSaving world and shutting down..." || true

            # Flush world to disk
            $MCRCON -w 5 "save-all" || true
            $SLEEP 2

            # Graceful stop
            $MCRCON -w 5 "stop" || true

            # Wait for process to exit (systemd will SIGTERM after TimeoutStopSec)
            $SLEEP 5
          '';

          execStopScript = pkgs.writeShellScript "${serviceName}-exec-stop" ''
            set -euo pipefail
            if [ -d "${dataDir}/world" ]; then
              ${lib.getExe' pkgs.coreutils "mkdir"} -p "${dataDir}/backups"
              ${lib.getExe pkgs.gnutar} czf "${dataDir}/backups/world-$(${lib.getExe' pkgs.coreutils "date"} +%Y%m%d-%H%M%S).tar.gz" \
                -C "${dataDir}" world
              # rotate: keep max 14 days of backups
              ${lib.getExe pkgs.findutils} "${dataDir}/backups" \
                -name "world-*.tar.gz" -mtime +14 -delete
            fi
          '';

          # Generate ops.json from declared ops list
          opsJson = pkgs.writeText "ops.json" (builtins.toJSON (map
            (op: {
              uuid = op.uuid;
              name = op.name;
              level = op.level;
              bypassesPlayerLimit = op.bypassesPlayerLimit;
            })
            instanceCfg.ops
          ));

          execStartPreScript = pkgs.writeShellScript "${serviceName}-exec-start-pre" ''
            set -euo pipefail
            CAT="${lib.getExe' pkgs.coreutils "cat"}"
            MKDIR="${lib.getExe' pkgs.coreutils "mkdir"}"
            CHMOD="${lib.getExe' pkgs.coreutils "chmod"}"
            FIND="${lib.getExe pkgs.findutils}"
            CP="${lib.getExe' pkgs.coreutils "cp"}"
            CHOWN="${lib.getExe' pkgs.coreutils "chown"}"
            ECHO="${lib.getExe' pkgs.coreutils "echo"}"
            FINAL_PACK="${finalPack}"
            IMAGE_ID="$($CAT "$FINAL_PACK/.image-id")"
            $MKDIR -p "${dataDir}"
            $CHMOD u+w "${dataDir}"
            # Ensure dataDir is writable even if rsync previously set store perms
            $FIND "${dataDir}" -type d ! -writable -exec $CHMOD u+w {} + 2>/dev/null || true
            if [ ! -f "${dataDir}/.image-id" ] || \
               [ "$($CAT "${dataDir}/.image-id")" != "$IMAGE_ID" ]; then
              # Sync pack contents, dereference symlinks to writable copies
              ${lib.getExe pkgs.rsync} -rltD --delete \
                --copy-links \
                --exclude=/world \
                --exclude=/backups \
                --chown="${user}:${group}" \
                "$FINAL_PACK/" "${dataDir}/"
              # Ensure everything is writable by the service user
              $CHMOD -R u+w "${dataDir}"
              $ECHO "$IMAGE_ID" > "${dataDir}/.image-id"
            fi
            # Write ops.json (declarative operator list)
            $CP ${opsJson} "${dataDir}/ops.json"
            $CHOWN "${user}:${group}" "${dataDir}/ops.json"
            # Write server.properties with RCON and instance settings
            $CP ${serverPropertiesFile} "${dataDir}/server.properties"
            $CHOWN "${user}:${group}" "${dataDir}/server.properties"
          '';
        in
        if instanceCfg.enable then {
          "${serviceName}" = {
            description = "Minecraft CurseForge Server — ${name}";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              Type = "simple";
              User = user;
              Group = group;
              WorkingDirectory = dataDir;
              ExecStopPre = execStopPreScript;
              ExecStop = execStopScript;
              ExecStartPre = execStartPreScript;
              ExecStart = "${lib.getExe pkgs.bash} ${dataDir}/start.sh";

              Environment = [
                "JAVA_MAX_MEM=${instanceCfg.maxMemory}"
                "JAVA_MIN_MEM=${instanceCfg.minMemory}"
              ] ++ optional (instanceCfg.jvmArgs != [ ])
                "JAVA_OPTS=${concatStringsSep " " instanceCfg.jvmArgs}";

              Restart = "on-failure";
              RestartSec = 15;
              StartLimitBurst = 5;
              StartLimitIntervalSec = 600;
              TimeoutStopSec = 300;
            };
          };
        } else { }
      )
      cfg);

    networking.firewall = mkMerge (mapAttrsToList
      (name: instanceCfg:
        if instanceCfg.enable && instanceCfg.openFirewall then {
          allowedTCPPorts = [ instanceCfg.gamePort ];
        } else { }
      )
      cfg);

    environment.systemPackages = concatLists (mapAttrsToList
      (name: instanceCfg:
        optionals instanceCfg.enable [ pkgs.mcrcon ]
      )
      cfg);
  };
}
