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

          serverPropertiesFile = pkgs.writeText "server.properties" (
            generators.toKeyValue
              {
                listsAsDuplicateKeys = true;
              }
              instanceCfg.serverProperties
          );

          execStopScript = pkgs.writeShellScript "${serviceName}-exec-stop" ''
            set -euo pipefail
            if [ -d "${dataDir}/world" ]; then
              mkdir -p "${dataDir}/backups"
              tar czf "${dataDir}/backups/world-$(date +%Y%m%d-%H%M%S).tar.gz" \
                -C "${dataDir}" world
              # rotate: keep max 14 days of backups
              ${lib.getExe pkgs.findutils} "${dataDir}/backups" \
                -name "world-*.tar.gz" -mtime +14 -delete
            fi
          '';

          execStartPreScript = pkgs.writeShellScript "${serviceName}-exec-start-pre" ''
            set -euo pipefail
            FINAL_PACK="${finalPack}"
            IMAGE_ID="$(cat "$FINAL_PACK/.image-id")"
            mkdir -p "${dataDir}"
            if [ ! -f "${dataDir}/.image-id" ] || \
               [ "$(cat "${dataDir}/.image-id")" != "$IMAGE_ID" ]; then
              ${lib.getExe pkgs.rsync} -a --delete \
                --exclude=/world \
                --exclude=/backups \
                --chown="${user}:${group}" \
                "$FINAL_PACK/" "${dataDir}/"
              echo "$IMAGE_ID" > "${dataDir}/.image-id"
            fi
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
              ExecStop = execStopScript;
              ExecStartPre = execStartPreScript;
              ExecStart = "${lib.getExe pkgs.bash} ${dataDir}/start.sh";

              Environment = [
                "JAVA_MAX_MEM=${instanceCfg.maxMemory}"
                "JAVA_MIN_MEM=${instanceCfg.minMemory}"
              ] ++ optional (instanceCfg.jvmArgs != [ ])
                "JAVA_OPTS=${concatStringsSep " " instanceCfg.jvmArgs}";

              Restart = "no";
              # RestartSec = 15;  # Re-enable after testing
              # StartLimitBurst = 5;
              # StartLimitIntervalSec = 600;
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
