{ config, pkgs, ... }:
{
  boot.supportedFilesystems = [ "zfs" ];
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      flags = "-k -p --utc";
      enable = true;
    };
  };
}
