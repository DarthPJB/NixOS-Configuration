# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "storage-array"; # Define your hostname.
  networking.hostId =  "b4120de6";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # networking.interfaces.enp1s0f0.useDHCP = lib.mkDefault true;

  services.dnsmasq.enable = true;
  services.dnsmasq.settings = {
    domain-needed = true;
    bogus-priv = true;
    interface = "enp2s0f0";
    dhcp-range = "192.168.2.1,192.168.2.16,24h";
    #dhcp-range="::f,::ff,constructor:enp2s0f0";
  };
  services.dnsmasq.resolveLocalQueries = false;

networking = {
  interfaces = {
    enp1s0f1.useDHCP = true; # main network connection
    enp2s0f0 = {
        ipv4.addresses = [ { 
            address = "192.168.2.1"; 
            prefixLength = 24;}];
        ipv6.addresses = [{
      address = "2a01:4f8:1c1b:16d0::1";
      prefixLength = 64;
     }];
    };
  };
  defaultGateway6 = {
    address = "fe80::1";
    interface = "enp2s0f0";
  };
};
  #networking.interfaces.enp2s0f0.useDHCP =  false; #secondary link for local.nas
  # networking.interfaces.enp2s0f1.useDHCP = lib.mkDefault true;


  system.stateVersion = "24.11"; # Did you read the comment?

}
