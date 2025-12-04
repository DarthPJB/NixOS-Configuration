{ config, pkgs, ... }:
{

  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ config.services.prometheus.exporters.zfs.port ];
  services.prometheus = {
    exporters.zfs = {
      enable = true;
      port = 3102;
    };
  };

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
