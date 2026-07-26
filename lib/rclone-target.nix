{ config
, pkgs
, lib
, ...
}:
{
  options.environment.rclone-target = {
    enable = lib.mkEnableOption "enable rclone";
    configFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to secrix (age) encrypted rclone configuration file.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "John88";
      description = "User to run rclone services as.";
    };
    targets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            filePath = lib.mkOption {
              type = lib.types.str;
              description = "Source path to sync.";
            };
            remoteName = lib.mkOption {
              type = lib.types.str;
              description = "Rclone remote destination (e.g. 'minio:bucket' or 'nas:/path').";
            };
            syncInterval = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Sync interval in seconds. Used with OnUnitActiveSec. Ignored if calendar is set.";
            };
            calendar = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = ''
                systemd calendar expression for scheduling (OnCalendar).
                If set, overrides syncInterval. Examples:
                  - "*-*-* 06:00:00" — daily at 6AM UTC
                  - "Mon *-*-* 09:00:00" — Mondays at 9AM UTC
                  - "hourly" — every hour
                If empty, syncInterval is used instead.
              '';
            };
            mode = lib.mkOption {
              type = lib.types.enum [ "bisync" "copy" ];
              default = "bisync";
              description = ''
                Sync mode:
                  - bisync: Bidirectional sync with conflict resolution. Uses --resilient --recover --conflict-resolve newer.
                  - copy: One-way copy from source to destination. Suitable for backups.
              '';
            };
            bwlimit = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = ''
                Bandwidth limit for rclone transfers. Examples:
                  - "10M" — 10 MB/s
                  - "500k" — 500 KB/s
                  - "08:00,512k 20:00,10M" — schedule-based limits
                  - "" — no limit (default)
              '';
            };
            preExec = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = ''
                Shell command to run before the rclone transfer. Useful for
                cleanup, rotation, or preparation. Runs as the configured user.
                Example: "find /path/to/backups -mtime +14 -delete"
              '';
            };
            excludePatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                List of rclone exclude patterns. Examples:
                  - ".cache/**"
                  - "Games/**"
                  - ".local/share/Steam/**"
              '';
            };
            filterRules = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                List of rclone filter rules (applied in order). Examples:
                  - "+ .config/vivaldi/**"
                  - "- .config/**"
                These take precedence over excludePatterns when set.
              '';
            };
          };
        }
      );
      default = { };
      description = "Attribute set of sync targets.";
    };
  };

  config = lib.mkIf config.environment.rclone-target.enable (
    let
      cfg = config.environment.rclone-target;

      baseFlags = name: target: isResync:
        let
          serviceName = if isResync then "rclone-sync-${name}-resync" else "rclone-sync-${name}";
          configPath = config.secrix.services.${serviceName}.secrets.config-file.decrypted.path;
          bwlimitFlag = lib.optionalString (target.bwlimit != "") " --bwlimit ${target.bwlimit}";
        in
        "--config ${configPath}${bwlimitFlag}";

      mkCommand = name: target: isResync:
        let
          flags = baseFlags name target isResync;
          resyncFlag = lib.optionalString isResync " --resync";
          excludeFlags = lib.concatMapStrings (p: " --exclude '${p}'") target.excludePatterns;
          filterFlags = lib.concatMapStrings (r: " --filter '${r}'") target.filterRules;
          skipLinksFlag = " --skip-links";
          # Use filter rules if set, otherwise use exclude patterns
          patternFlags = if target.filterRules != [ ] then filterFlags else excludeFlags;
        in
        if target.mode == "bisync" then
          "${lib.getExe pkgs.rclone} ${flags} bisync${resyncFlag} --resilient --recover --max-lock 2m --conflict-resolve newer --check-access${skipLinksFlag}${patternFlags} ${target.filePath} ${target.remoteName}"
        else
          "${lib.getExe pkgs.rclone} ${flags} copy${skipLinksFlag}${patternFlags} ${target.filePath} ${target.remoteName}";

      mkSecrets = lib.concatMapAttrs
        (name: target: {
          "rclone-sync-${name}" = {
            secrets.config-file.encrypted.file = cfg.configFile;
          };
        } // lib.optionalAttrs (target.mode == "bisync") {
          "rclone-sync-${name}-resync" = {
            secrets.config-file.encrypted.file = cfg.configFile;
          };
        })
        cfg.targets;

      mkServices = lib.concatMapAttrs
        (name: target: {
          "rclone-sync-${name}" = {
            description = "Rclone ${target.mode} service for ${name}";
            serviceConfig = {
              Type = "oneshot";
              ExecStartPre = lib.optionalString (target.preExec != "") (
                pkgs.writeShellScript "rclone-sync-${name}-pre" target.preExec
              );
              ExecStart = mkCommand name target false;
              User = cfg.user;
            };
            onFailure = lib.optionals (target.mode == "bisync") [ "rclone-sync-${name}-resync.service" ];
          };
        } // lib.optionalAttrs (target.mode == "bisync") {
          "rclone-sync-${name}-resync" = {
            description = "Rclone bisync resync service for ${name}";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = mkCommand name target true;
              User = cfg.user;
            };
          };
        })
        cfg.targets;

      mkTimers = lib.mapAttrs'
        (name: target:
          let
            useCalendar = target.calendar != "";
          in
          lib.nameValuePair "rclone-sync-${name}" {
            description = "Timer for rclone ${target.mode} service ${name}";
            wantedBy = [ "timers.target" ];
            timerConfig = lib.filterAttrs (_: v: v != null) (
              {
                OnBootSec = if useCalendar then null else "5m";
                OnUnitActiveSec = if useCalendar then null else "${toString target.syncInterval}s";
                OnCalendar = if useCalendar then target.calendar else null;
                Unit = "rclone-sync-${name}.service";
              }
            );
          })
        cfg.targets;
    in
    {
      secrix.services = mkSecrets;
      systemd.services = mkServices;
      systemd.timers = mkTimers;
    }
  );
}
