# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = "1048576"; # 128 times the default 8192
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "archive" "bulk-storage" ];
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      flags = "-k -p --utc";
      enable = true;
    };
  };
  systemd.mounts = [
    {
      #depends = [ "/archive" "/bulk-storage" ];
      what = "/archive/general";
      where = "/bulk-storage/NAS-ARCHIVE/ARCHIVE";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" "zfs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
    }
    {
      #depends = [ "/archive" "/bulk-storage"];
      what = "/archive/astral";
      where = "/bulk-storage/NAS-ARCHIVE/remote.worker/Astralship Master Archive/ARCHIVE";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" "zfs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
    }
    {
      #depends = [ "/archive" "/bulk-storage"];
      what = "/archive/personal";
      where = "/bulk-storage/NAS-ARCHIVE/remote.worker/88/88-FS-V2/ARCHIVE";
      options = "bind";
      after = [ "systemd-tmpfiles-setup.service" "zfs-mount.service" ];
      wantedBy = [ "multi-user.target" ];
    }
  ];

  networking.hostId = "d5710c9a";
  networking.hostName = "DataStorage"; # Define your hostname.
  time.timeZone = "Etc/UTC";
  system.stateVersion = "22.11"; # Did you read the comment?

  environment.systemPackages = [ pkgs.rclone ];

  # Syncthing ports
  networking.firewall.allowedTCPPorts = [ 8080 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];
  services = {
    syncthing = {
      enable = false;
      dataDir = "/bulk-storage";
      configDir = "/syncthing";
      guiAddress = "0.0.0.0:8080";
      #TODO: add cert and pem files
      #overrideDevices = true;     # overrides any devices added or deleted through the WebUI
      #overrideFolders = true;     # overrides any folders added or deleted through the WebUI
    };
  };

}

