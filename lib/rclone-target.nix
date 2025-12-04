{ config, pkgs, lib, ... }:
{
  # imports = [ inputs.secrix.nixosModules.secrix ];

  options.environment.rclone-target = {
    enable = lib.mkEnableOption "enable rclone";
    configFile = lib.mkOption {
      type = lib.types.path;
      description = "path to secrix (age) encrypted configuration file";
    };
    targets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          filePath = lib.mkOption {
            type = lib.types.str;
            description = "Path to the file to sync.";
          };
          remoteName = lib.mkOption {
            type = lib.types.str;
            description = "Name of the remote target.";
          };
          syncInterval = lib.mkOption {
            type = lib.types.int;
            description = "Sync interval in seconds.";
          };
        };
      });
      default = { };
      description = "Attribute set of sync targets with file path, remote name, and sync interval.";
    };
  };

  config = lib.mkIf config.environment.rclone-target.enable {
    secrix.services = lib.mapAttrs'
      (name: target:
        lib.nameValuePair "rclone-sync-${name}" { secrets.config-file.encrypted.file = config.environment.rclone-target.configFile; })
      config.environment.rclone-target.targets // lib.mapAttrs'
      (name: target:
        lib.nameValuePair "rclone-sync-${name}-resync" { secrets.config-file.encrypted.file = config.environment.rclone-target.configFile; })
      config.environment.rclone-target.targets;
    # Create a systemd service for each sync target
    systemd.services = lib.mapAttrs'
      (name: target:
        lib.nameValuePair "rclone-sync-${name}" {
          description = "Rclone sync service for ${name}";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.rclone}/bin/rclone --config ${config.secrix.services."rclone-sync-${name}".secrets.config-file.decrypted.path} bisync --resilient --recover --max-lock 2m --conflict-resolve newer --check-access ${target.filePath} ${target.remoteName}";
            User = "John88"; # Adjust user as needed

          };
          onFailure = [ "rclone-sync-${name}-resync.service" ];
        }
      )
      config.environment.rclone-target.targets // lib.mapAttrs'
      (name: target:
        lib.nameValuePair "rclone-sync-${name}-resync" {
          description = "Rclone sync service for ${name}";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.rclone}/bin/rclone --config ${config.secrix.services."rclone-sync-${name}-resync".secrets.config-file.decrypted.path} bisync --resync --resilient --recover --max-lock 2m --conflict-resolve newer --check-access ${target.filePath} ${target.remoteName}";
            User = "John88"; # Adjust user as needed
          };
        }
      )
      config.environment.rclone-target.targets;

    # Create a systemd timer for each sync target
    systemd.timers = lib.mapAttrs'
      (name: target:
        lib.nameValuePair "rclone-sync-${name}" {
          description = "Timer for rclone sync service ${name}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "${toString target.syncInterval}s";
            Unit = "rclone-sync-${name}.service";
          };
        }
      )
      config.environment.rclone-target.targets;
  };
}
