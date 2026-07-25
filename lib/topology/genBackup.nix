{ lib }:
# genBackup: settings -> hostname -> NixOS environment.rclone-target config
# Produces config for the rclone-target module from mkBackupSettings output.
# Maps transformer settings directly to environment.rclone-target options.
settings: hostname:
let
  machineSettings = settings.machines.${hostname} or null;
in
if machineSettings == null then { } else
{
  environment.rclone-target = {
    enable = true;
    inherit (machineSettings) configFile user targets;
  };
}
