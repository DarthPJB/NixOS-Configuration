# --------------------- STORAGE ARRAY -------------------- #

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../lib/enable-wg.nix
    ];

  secrix.services.wireguard-wireg0.secrets.storage-array.encrypted.file = ../../secrets/wg_storage-array;
  environment = {
    vpn =
      {
        enable = true;
        postfix = 4;
        privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.storage-array.decrypted.path;
      };
  };
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      flags = "-k -p --utc";
      enable = true;
    };
  };
  environment.systemPackages = [ pkgs.fdupes ];
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "storage-array"; # Define your hostname.
  networking.hostId = "b4120de6";
  networking = {
    defaultGateway = "192.168.88.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    interfaces = {

      enp1s0f1.useDHCP = true; # main network connection
      enp1s0f0 = {
        ipv4.addresses = [{
          address = "181.215.32.40";
          prefixLength = 27;
        }];
      };
      enp2s0f1 = {
        ipv4.addresses = [{
          address = "10.88.128.4";
          prefixLength = 27;
        }];
      };
      enp2s0f0 = {
        /*        ipv4.addresses = [{
          address = "192.168.2.1";
          prefixLength = 24;
        }];
        ipv6.addresses = [{
          address = "2a01:4f8:1c1b:16d0::1";
          prefixLength = 64;
        }]; */
      };
    };
  };


  system.stateVersion = "24.11"; # Did you read the comment?

}
