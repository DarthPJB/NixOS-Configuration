# Minecraft CurseForge Server — NixOS Module
#
# Deploys a Minecraft server from a CurseForge modpack builder derivation.
# The module handles:
#   - Overlay derivation (eula.txt + server.properties baked in)
#   - Systemd service with world backup (ExecStop), image sync (ExecStartPre),
#     and server launch (ExecStart)
#   - Dedicated system user, tmpfiles, firewall rules
#
# Usage:
#   services.minecraft-curseforge.atm10 = {
#     enable = true;
#     pack = pkgs.minecraft-curseforge-atm10;
#     acceptEula = true;
#     serverProperties = {
#       server-port = 25565;
#       motd = "All the Mods 10";
#       max-players = 10;
#     };
#     maxMemory = "8G";
#     minMemory = "4G";
#   };

{ config
, lib
, pkgs
, ...
}:

with lib;

let
  # The full system config is needed for cross-instance assertions
  cfg = config.services.minecraft-curseforge;
in
{
  # ── Options ────────────────────────────────────────────────────────
  options.services.minecraft-curseforge = mkOption {
    type = types.attrsOf (types.submodule ({ name, config, ... }: {
      options = {
        enable = mkEnableOption "Minecraft CurseForge server instance '${name}'";

        pack = mkOption {
          type = types.package;
          description = ''
            Builder derivation for the CurseForge modpack.
            Typically created with pkgs.minecraft-curseforge { ... }.
          '';
        };

        acceptEula = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to accept the Minecraft EULA. The server will refuse
            to start without this set to true.
          '';
        };

        serverProperties = mkOption {
          type = types.attrsOf (types.oneOf [ types.str types.int types.bool ]);
          default = { };
          example = {
            "server-port" = 25565;
            "motd" = "My Minecraft Server";
            "max-players" = 10;
            "difficulty" = "normal";
            "gamemode" = "survival";
            "enable-rcon" = true;
            "rcon.port" = 25575;
          };
          description = ''
            Server properties written to server.properties.
            Uses Nix attribute set; keys use the exact Minecraft property names.
          '';
        };

        maxMemory = mkOption {
          type = types.str;
          default = "4G";
          description = "Maximum JVM heap size (e.g., '4G', '8192M').";
        };

        minMemory = mkOption {
          type = types.str;
          default = "2G";
          description = "Minimum JVM heap size (e.g., '2G', '4096M').";
        };

        jvmArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "-XX:+UseG1GC" "-XX:+ParallelRefProcEnabled" ];
          description = "Additional JVM arguments passed to the Java process.";
        };

        dataDir = mkOption {
          type = types.path;
          default = "/bulk-storage/minecraft/${name}";
          description = ''
            Directory for mutable server state (world, backups, logs).
            This directory persists across modpack updates.
          '';
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
          description = "TCP port for RCON (if enabled in serverProperties).";
        };

        rconPasswordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Path to a file containing the RCON password.
            If null, RCON password is not managed by the module.
          '';
        };
      };

      # Inside the submodule, `config` refers to THIS instance's config.
      # We use it to access option values (config.enable, config.pack, etc.)
      config = mkIf config.enable (
        let
          serviceName = "minecraft-curseforge-${name}";
          user = serviceName;
          group = serviceName;
          dataDir = config.dataDir;

          # ── Phase 2: Overlay derivation ────────────────────────────
          # symlinkJoin creates a directory of symlinks to the builder
          # output, then writes real files for eula.txt and server.properties.
          # Near-instant, no 1GB+ copy. rsync -a handles symlinks correctly
          # on NixOS targets (builder store path is in the system closure).
          finalPack = pkgs.symlinkJoin {
            name = "minecraft-server-final-${name}";
            paths = [ config.pack ];

            postBuild = ''
              ${lib.optionalString config.acceptEula ''
                echo "eula=true" > "$out/eula.txt"
              ''}
              printf '%s' ${
                lib.generators.toKeyValue {
                  listsAsDuplicateKeys = true;
                } config.serverProperties
              } > "$out/server.properties"
            '';

            passthru = config.pack.passthru or { } // {
              imageId = config.pack.passthru.imageId or (builtins.baseNameOf config.pack.src);
              jre = config.pack.passthru.jre or pkgs.jdk21;
            };
          };

          # ── Phase 3: Systemd scripts ──────────────────────────────

          # ExecStop: world backup before planned stops
          execStopScript = pkgs.writeShellScript "${serviceName}-exec-stop" ''
            set -euo pipefail

            DATA_DIR="${dataDir}"

            if [ -d "$DATA_DIR/world" ]; then
              mkdir -p "$DATA_DIR/backups"
              echo "Backing up world..."
              tar czf "$DATA_DIR/backups/world-$(date +%Y%m%d-%H%M%S).tar.gz" \
                -C "$DATA_DIR" world
              echo "World backup complete."
            else
              echo "No world directory found, skipping backup."
            fi
          '';

          # ExecStartPre: instantiate final derivation into dataDir
          execStartPreScript = pkgs.writeShellScript "${serviceName}-exec-start-pre" ''
            set -euo pipefail

            FINAL_PACK="${finalPack}"
            DATA_DIR="${dataDir}"
            IMAGE_ID="$(cat "$FINAL_PACK/.image-id")"

            # Ensure dataDir exists
            mkdir -p "$DATA_DIR"

            # Check if image has changed
            if [ ! -f "$DATA_DIR/.image-id" ] || \
               [ "$(cat "$DATA_DIR/.image-id")" != "$IMAGE_ID" ]; then
              echo "Image changed or first deploy. Syncing to dataDir..."
              rsync -a --delete \
                --exclude=/world \
                --exclude=/backups \
                --chown="${user}:${group}" \
                "$FINAL_PACK/" "$DATA_DIR/"

              echo "$IMAGE_ID" > "$DATA_DIR/.image-id"
              echo "Sync complete."
            else
              echo "Image unchanged, skipping sync."
            fi
          '';

        in
        {
          # ── Assertions ───────────────────────────────────────────────
          assertions = [
            {
              assertion = config.acceptEula;
              message = ''
                Minecraft EULA must be accepted for instance '${name}'.
                Set services.minecraft-curseforge.${name}.acceptEula = true;
              '';
            }
          ] ++ (mapAttrsToList (otherName: otherCfg: {
            assertion = otherName == name || config.gamePort != otherCfg.gamePort;
            message = ''
              Port conflict: gamePort ${toString config.gamePort} is used by
              both minecraft-curseforge instances '${name}' and '${otherName}'.
            '';
          }) (filterAttrs (n: v: v.enable && n != name) cfg))
          ++ (mapAttrsToList (otherName: otherCfg: {
            assertion = otherName == name || toString config.dataDir != toString otherCfg.dataDir;
            message = ''
              dataDir conflict: both minecraft-curseforge instances '${name}' and
              '${otherName}' use the same data directory '${toString config.dataDir}'.
            '';
          }) (filterAttrs (n: v: v.enable && n != name) cfg));

          # ── System user ──────────────────────────────────────────────
          users.users.${user} = {
            isSystemUser = true;
            group = group;
            home = dataDir;
            createHome = true;
            description = "Minecraft server '${name}' service user";
          };

          users.groups.${group} = { };

          # ── Tmpfiles ─────────────────────────────────────────────────
          systemd.tmpfiles.rules = [
            "d ${dataDir} 0755 ${user} ${group} -"
            "d ${dataDir}/backups 0755 ${user} ${group} -"
            "d ${dataDir}/logs 0755 ${user} ${group} -"
          ];

          # ── Systemd service ──────────────────────────────────────────
          systemd.services.${serviceName} = {
            description = "Minecraft CurseForge Server — ${name}";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            serviceConfig = {
              Type = "simple";
              User = user;
              Group = group;
              WorkingDirectory = dataDir;

              # World backup on planned stop
              ExecStop = execStopScript;

              # Image sync before start
              ExecStartPre = execStartPreScript;

              # Server launch
              ExecStart = "${dataDir}/start.sh";

              # Environment
              Environment = [
                "JAVA_MAX_MEM=${config.maxMemory}"
                "JAVA_MIN_MEM=${config.minMemory}"
              ] ++ lib.optional (config.jvmArgs != [ ])
                "JAVA_OPTS=${lib.concatStringsSep " " config.jvmArgs}";

              # Restart policy
              Restart = "on-failure";
              RestartSec = 15;

              # Timeout for large world backups
              TimeoutStopSec = 300;
            };
          };

          # ── Firewall ─────────────────────────────────────────────────
          networking.firewall = mkIf config.openFirewall {
            allowedTCPPorts = [ config.gamePort ];
          };

          # ── System packages ──────────────────────────────────────────
          environment.systemPackages = [
            pkgs.mcrcon
          ];
        }
      );
    }));
    default = { };
    description = ''
      Minecraft CurseForge server instances. Each attribute name is
      an instance identifier (e.g., 'atm10', 'all-the-mons').
    '';
  };
}
