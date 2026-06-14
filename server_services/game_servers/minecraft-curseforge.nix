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

  # squaremap configuration (YAML format)
  # https://github.com/jpenilla/squaremap/wiki/Default-config.yml
  # https://github.com/jpenilla/squaremap/wiki/Default-advanced.yml
  mkSquaremapConfig = name: instanceCfg:
    let
      yamlFormat = pkgs.formats.yaml { };
      configYml = yamlFormat.generate "squaremap-config-${name}.yml" {
        settings = {
          internal-webserver = {
            enabled = true;
            bind = instanceCfg.squaremapBind;
            port = instanceCfg.squaremapPort;
          };
        };
      };
      # advanced.yml: invisible-blocks prevents squaremap from calling
      # getMapColor() on blocks that NPE with null BlockGetter (e.g. FramedBlocks).
      # https://github.com/jpenilla/squaremap/blob/master/common/src/main/java/xyz/jpenilla/squaremap/common/data/MapWorldInternal.java
      advancedYml = yamlFormat.generate "squaremap-advanced-${name}.yml" {
        config-version = 1;
        settings = { };
        world-settings = {
          default = {
            invisible-blocks = [
              "framedblocks:framed_block"
              "framedblocks:framed_half_block"
              "framedblocks:framed_slab"
              "framedblocks:framed_stairs"
              "framedblocks:framed_wall"
              "framedblocks:framed_fence"
              "framedblocks:framed_gate"
              "framedblocks:framed_door"
              "framedblocks:framed_trapdoor"
              "framedblocks:framed_pressure_plate"
              "framedblocks:framed_button"
              "framedblocks:framed_lever"
              "framedblocks:framed_torch"
              "framedblocks:framed_soul_torch"
              "framedblocks:framed_redstone_torch"
              "framedblocks:framed_ladder"
              "framedblocks:framed_bars"
              "framedblocks:framed_panel"
              "framedblocks:framed_corner_pillar"
              "framedblocks:framed_post"
              "framedblocks:framed_rail_slope"
              "framedblocks:framed_powered_rail_slope"
              "framedblocks:framed_detector_rail_slope"
              "framedblocks:framed_activator_rail_slope"
              "framedblocks:framed_flat_slope"
              "framedblocks:framed_prism_corner"
              "framedblocks:framed_inner_prism_corner"
              "framedblocks:framed_threeway_corner"
              "framedblocks:framed_inner_threeway_corner"
              "framedblocks:framed_slab_corner"
              "framedblocks:framed_inner_slab_corner"
              "framedblocks:framed_pillar"
              "framedblocks:framed_fence_gate"
              "framedblocks:framed_lattice_block"
              "framedblocks:framed_collapsible_block"
              "framedblocks:framed_collapsible_copycat_block"
              "framedblocks:framed_content_obsidian"
              "framedblocks:framed_spectacle_frame"
              "framedblocks:framed_masonry_corner"
              "framedblocks:framed_inner_masonry_corner"
              "framedblocks:framed_double_slab"
              "framedblocks:framed_divider"
              "framedblocks:framed_double_panel"
              "framedblocks:framed_layered_block"
              "framedblocks:framed_bouncy_block"
              "framedblocks:framed_storage_block"
            ];
          };
        };
      };
    in
    pkgs.runCommand "squaremap-config-${name}" { } ''
      mkdir -p $out/squaremap
      cp ${configYml} $out/squaremap/config.yml
      cp ${advancedYml} $out/squaremap/advanced.yml
    '';
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

        # ── squaremap: web-based world map viewer ──────────────────────
        enableSquaremap = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable squaremap, a web-based world map viewer.";
        };

        squaremapPort = mkOption {
          type = types.port;
          default = 8080;
          description = "TCP port for the squaremap embedded web server.";
        };

        squaremapBind = mkOption {
          type = types.str;
          default = "0.0.0.0";
          description = "Bind address for the squaremap web server.";
        };

        openSquaremapFirewall = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to open the squaremap web port in the firewall.";
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
    assertions = concatLists (mapAttrsToList
      (name: instanceCfg:
        optionals (instanceCfg.enable && instanceCfg.enableSquaremap) [
          {
            assertion = instanceCfg.squaremapPort != instanceCfg.gamePort;
            message = "squaremap port (${toString instanceCfg.squaremapPort}) must differ from game port (${toString instanceCfg.gamePort}) for instance '${name}'.";
          }
          {
            assertion = instanceCfg.squaremapPort != instanceCfg.rconPort;
            message = "squaremap port (${toString instanceCfg.squaremapPort}) must differ from RCON port (${toString instanceCfg.rconPort}) for instance '${name}'.";
          }
        ]
      )
      cfg);

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
                ${lib.getExe' pkgs.coreutils "echo"} "eula=true" > "$out/eula.txt"
              ''}
              ${lib.getExe' pkgs.coreutils "cp"} ${serverPropertiesFile} "$out/server.properties"

              # squaremap: inject mod JAR and configuration
              ${optionalString instanceCfg.enableSquaremap ''
                ${lib.getExe' pkgs.coreutils "mkdir"} -p "$out/mods" "$out/squaremap"
                ${lib.getExe' pkgs.coreutils "cp"} \
                  ${pkgs.squaremap-neoforge}/mods/squaremap-neoforge-mc1.21.1-1.3.2.jar \
                  "$out/mods/"
                ${lib.getExe' pkgs.coreutils "cp"} -r \
                  ${mkSquaremapConfig name instanceCfg}/squaremap/* \
                  "$out/squaremap/"
              ''}
            '';
            passthru = instanceCfg.pack.passthru or { } // {
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

          # Graceful shutdown: warn players, flush world, stop server, backup after exit
          #
          # NOTE: systemd has NO ExecStopPre directive. Only ExecStop exists.
          # All graceful shutdown logic lives here in a single script.
          #
          # Ordering is critical:
          #   1. Countdown + save-all (flush world while server is alive)
          #   2. rcon stop (server begins graceful shutdown, flushes world again on exit)
          #   3. Poll MainPID until Java process exits (world is now frozen and consistent)
          #   4. tar --zstd backup (server is dead, world cannot change)
          #   5. Return — systemd finishes stopping the service
          #
          # The service does NOT finish stopping until the backup is written.
          execStopScript = pkgs.writeShellApplication {
            name = "${serviceName}-exec-stop";
            runtimeInputs = [ pkgs.coreutils pkgs.mcrcon pkgs.gnutar pkgs.findutils pkgs.systemd ];
            text = ''
              rcon() {
                ${lib.getExe pkgs.mcrcon} -H 127.0.0.1 -P ${toString instanceCfg.rconPort} -p '${instanceCfg.rconPassword}' "$@"
              }

              # ── Phase 1: Warn players ─────────────────────────────────
              rcon -w 5 "say §c[Server] §fServer shutting down in 30 seconds..." || echo "WARNING: RCON say failed" >&2
              ${lib.getExe' pkgs.coreutils "sleep"} 20
              rcon -w 5 "say §c[Server] §fShutting down in 10 seconds..." || echo "WARNING: RCON say failed" >&2
              ${lib.getExe' pkgs.coreutils "sleep"} 5
              rcon -w 5 "say §c[Server] §f5 seconds..." || echo "WARNING: RCON say failed" >&2
              ${lib.getExe' pkgs.coreutils "sleep"} 3
              rcon -w 5 "say §c[Server] §f2 seconds..." || echo "WARNING: RCON say failed" >&2
              ${lib.getExe' pkgs.coreutils "sleep"} 2

              # ── Phase 2: Flush world and stop server ──────────────────
              rcon -w 5 "say §c[Server] §eSaving world..." || echo "WARNING: RCON say failed" >&2
              rcon -w 30 "save-all" || echo "ERROR: RCON save-all failed — world may not be flushed" >&2
              ${lib.getExe' pkgs.coreutils "sleep"} 2
              rcon -w 5 "say §c[Server] §eGoodbye!" || echo "WARNING: RCON say failed" >&2
              rcon -w 5 "stop" || echo "ERROR: RCON stop failed — will SIGTERM" >&2

              # ── Phase 3: Wait for server to exit ──────────────────────
              # Poll MainPID — once the Java process is dead, the world is
              # frozen and consistent. No save-off tricks needed.
              MAINPID="$(systemctl show -p MainPID --value "${serviceName}.service")"
              if [ "$MAINPID" -gt 0 ] 2>/dev/null; then
                echo "Waiting for server process $MAINPID to exit..." >&2
                while kill -0 "$MAINPID" 2>/dev/null; do
                  ${lib.getExe' pkgs.coreutils "sleep"} 1
                done
                echo "Server process exited." >&2
              else
                echo "WARNING: Could not determine MainPID, sleeping 10s as fallback" >&2
                ${lib.getExe' pkgs.coreutils "sleep"} 10
              fi

              # ── Phase 4: Backup (server is dead, world is frozen) ─────
              if [ -d "${dataDir}/world" ]; then
                ${lib.getExe' pkgs.coreutils "mkdir"} -p "${dataDir}/backups"
                ${lib.getExe pkgs.gnutar} --zstd \
                  -cf "${dataDir}/backups/world-$(${lib.getExe' pkgs.coreutils "date"} +%Y%m%d-%H%M%S).tar.zst" \
                  -C "${dataDir}" \
                  --exclude='world/backups' \
                  --exclude='world/session.lock' \
                  world || echo "WARNING: tar backup had warnings" >&2
                # rotate: keep max 14 days of backups
                ${lib.getExe pkgs.findutils} "${dataDir}/backups" \
                  -name "world-*.tar.zst" -mtime +14 -delete || echo "WARNING: backup rotation failed" >&2
              fi
            '';
          };

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

          execStartPreScript = pkgs.writeShellApplication {
            name = "${serviceName}-exec-start-pre";
            runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.rsync ];
            text = ''
              FINAL_PACK="${finalPack}"
              # The store path basename is a content-addressed hash of ALL inputs
              # (pack source, squaremap JAR, squaremap config, JRE, etc.).
              # If anything changes, the path changes, rsync triggers.
              PACK_ID="$(${lib.getExe' pkgs.coreutils "basename"} "$FINAL_PACK")"
              ${lib.getExe' pkgs.coreutils "mkdir"} -p "${dataDir}"
              ${lib.getExe' pkgs.coreutils "chmod"} u+w "${dataDir}"
              # Ensure dataDir is writable even if rsync previously set store perms
              ${lib.getExe pkgs.findutils} "${dataDir}" -type d ! -writable -exec ${lib.getExe' pkgs.coreutils "chmod"} u+w {} + 2>/dev/null || true
              if [ ! -f "${dataDir}/.pack-id" ] || \
                 [ "$(${lib.getExe' pkgs.coreutils "cat"} "${dataDir}/.pack-id")" != "$PACK_ID" ]; then
                # Sync pack contents, dereference symlinks to writable copies
                ${lib.getExe pkgs.rsync} -rltD --delete \
                  --copy-links \
                  --exclude=/world \
                  --exclude=/backups \
                  --exclude=/squaremap/web \
                  --exclude=/squaremap/data \
                  --exclude=/squaremap/tiles \
                  --exclude=/squaremap/locale \
                  --chown="${user}:${group}" \
                  "$FINAL_PACK/" "${dataDir}/"
                # Ensure everything is writable by the service user
                ${lib.getExe' pkgs.coreutils "chmod"} -R u+w "${dataDir}"
                ${lib.getExe' pkgs.coreutils "echo"} "$PACK_ID" > "${dataDir}/.pack-id"
              fi
              # Write ops.json (declarative operator list)
              ${lib.getExe' pkgs.coreutils "cp"} ${opsJson} "${dataDir}/ops.json"
              ${lib.getExe' pkgs.coreutils "chown"} "${user}:${group}" "${dataDir}/ops.json"
              # Write server.properties with RCON and instance settings
              ${lib.getExe' pkgs.coreutils "cp"} ${serverPropertiesFile} "${dataDir}/server.properties"
              ${lib.getExe' pkgs.coreutils "chown"} "${user}:${group}" "${dataDir}/server.properties"
            '';
          };
        in
        if instanceCfg.enable then {
          "${serviceName}" = {
            description = "Minecraft CurseForge Server — ${name}";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            unitConfig = {
              StartLimitBurst = 5;
              StartLimitIntervalSec = 600;
            };

            serviceConfig = {
              Type = "simple";
              User = user;
              Group = group;
              WorkingDirectory = dataDir;
              ExecStop = lib.getExe execStopScript;
              # + prefix runs ExecStartPre as root (needed for chown, rsync, mkdir)
              ExecStartPre = "+${lib.getExe execStartPreScript}";
              ExecStart = "${lib.getExe pkgs.bash} ${dataDir}/start.sh";

              # Only SIGTERM the main Java process — don't kill ExecStopPre
              KillMode = "process";

              Environment = [
                "JAVA_MAX_MEM=${instanceCfg.maxMemory}"
                "JAVA_MIN_MEM=${instanceCfg.minMemory}"
              ] ++ optional (instanceCfg.jvmArgs != [ ])
                "JAVA_OPTS=${concatStringsSep " " instanceCfg.jvmArgs}";

              Restart = "on-failure";
              RestartSec = 15;
              TimeoutStopSec = 600;
            };
          };
        } else { }
      )
      cfg);

    networking.firewall = mkMerge (mapAttrsToList
      (name: instanceCfg:
        if instanceCfg.enable && (instanceCfg.openFirewall || instanceCfg.openSquaremapFirewall) then {
          allowedTCPPorts =
            optional instanceCfg.openFirewall instanceCfg.gamePort
            ++ optional instanceCfg.openSquaremapFirewall instanceCfg.squaremapPort;
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
