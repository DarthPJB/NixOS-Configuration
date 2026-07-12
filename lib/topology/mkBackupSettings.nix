{ lib }:
# mkBackupSettings: per-machine topology -> { machines, warnings, errors }
# WIP: Extracts backup/rclone-sync settings from per-machine topology data.
#
# This is a FIRST-DRAFT WIP transformer. It is NOT wired into any module yet.
# Future integration: genBackup.nix will produce environment.rclone-target config
# from these settings, matching the rclone-target.nix module options.
#
# Expected topology shape (per-machine):
#   backup = {
#     configFile = ../../secrets/rclone/rclone.conf;  # secrix-encrypted
#     user = "John88";  # user to run rclone as
#     targets = {
#       daily-home = {
#         filePath = "/home/John88";
#         remoteName = "minio:bargman-daily";
#         calendar = "*-*-* 06:00:00";
#         mode = "bisync";
#         bwlimit = "10M";
#         preExec = "";
#         excludePatterns = [ ".cache/**" "Games/**" ];
#       };
#     };
#   };
topology:
let
  machines = lib.mapAttrs
    (hostname: machine:
      if !(machine ? backup) then null else
      let
        backup = machine.backup;
      in
      {
        inherit hostname;
        configFile = backup.configFile or null;
        user = backup.user or "John88";
        targets = backup.targets or { };
      }
    )
    topology;

  filteredMachines = lib.filterAttrs (_: v: v != null) machines;

  # Warn if configFile is missing
  warnings = lib.flatten (
    lib.mapAttrsToList
      (hostname: settings:
        if settings.configFile == null
        then [ "Backup configFile missing for ${hostname}" ]
        else [ ]
      )
      filteredMachines
  );

  errors = [ ];
in
{
  inherit warnings errors;
  machines = filteredMachines;
}