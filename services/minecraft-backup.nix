# Example: Daily Minecraft Backup to local-nas
#
# This backs up gaming-host-1's minecraft backup folder to local-nas
# once a day at 06:00 UTC. It has NO systemd ties to the minecraft
# service — deploying this config creates independent timer/service
# units and will NOT restart the minecraft server.
#
# The rclone timer/service units are completely independent:
#   rclone-sync-mc-backups.service  — oneshot, runs the copy
#   rclone-sync-mc-backups.timer    — fires daily at 06:00 UTC
#
# Neither unit has After=, Requires=, or BindsTo= referencing
# any minecraft service. They only need read access to the
# backup directory.
#
# Prerequisites:
#   1. An rclone remote named "local-nas" must be defined in the
#      encrypted rclone config file (secrets/rclone-config-file).
#      Example remote definition for an NFS-mounted path:
#
#        [local-nas]
#        type = local
#
#      Or for SSH-based transfer:
#
#        [local-nas]
#        type = sftp
#        host = 10.88.127.3
#        port = 1108
#        user = deploy
#        key_file = /path/to/key
#
#   2. The rclone user must have read access to the minecraft
#      backup directory. We run as "mc-curseforge-all-the-mons"
#      (the minecraft service user) which owns the backups.
#
# To deploy:
#   1. Add the import and config to machines/gaming-host-1/default.nix
#   2. Ensure the rclone-config-file secret exists with the local-nas remote
#   3. Deploy — no minecraft restart will occur

{ pkgs, lib, self, ... }:

{
  environment.rclone-target = {
    enable = true;
    configFile = "${self}/secrets/rclone-config-file";

    # Run as the minecraft service user — backups are owned by this user
    user = "mc-curseforge-all-the-mons";

    targets.mc-backups = {
      # Source: minecraft's rotating backup directory
      # Default dataDir is /bulk-storage/minecraft/<name>/backups/
      filePath = "/bulk-storage/minecraft/all-the-mons/backups/";

      # Destination: local-nas bulk-storage, organized by machine
      remoteName = "local-nas:/bulk-storage/backups/gaming-host-1/minecraft/";

      # Daily at 06:00 UTC — calendar-based, not interval-based
      calendar = "*-*-* 06:00:00";

      # One-way copy — suitable for backups (not bidirectional sync)
      mode = "copy";

      # Rate limit to avoid saturating the WireGuard link
      bwlimit = "10M";

      # Rotate old backups before copying — keep 14 days
      # This runs as ExecStartPre, before the rclone transfer
      preExec = "find /bulk-storage/minecraft/all-the-mons/backups/ -name '*.tar.zst' -mtime +14 -delete";
    };
  };
}
