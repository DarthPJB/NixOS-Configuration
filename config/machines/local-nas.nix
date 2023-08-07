# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./local-nas/hardware-configuration.nix
    ];

  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "archive" "bulk-storage"];

  networking.hostId = "d5710c9a";
  networking.hostName = "DataStorage"; # Define your hostname.
  time.timeZone = "Europe/London";
  system.stateVersion = "22.11"; # Did you read the comment?

  environment.systemPackages = [ pkgs.rclone ];

  # Syncthing ports
  networking.firewall.allowedTCPPorts = [ 8080 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];
  services = {
    syncthing = {
      enable = true;
      dataDir = "/bulk-storage";
      configDir = "/syncthing";
      guiAddress = "0.0.0.0:8080";
      #TODO: add cert and pem files
      #overrideDevices = true;     # overrides any devices added or deleted through the WebUI
      #overrideFolders = true;     # overrides any folders added or deleted through the WebUI
    };
  };

}

