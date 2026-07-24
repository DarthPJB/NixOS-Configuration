# OpenStack Virtual Machine Hardware Configuration
# Imports OpenStack module for dynamic configuration while maintaining VM harness compatibility
{ config
, lib
, pkgs
, modulesPath
, ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/virtualisation/openstack-config.nix")
  ];

  # Hardware detection for virtualized environment
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "ums_realtek"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # 300GB virtual disk for /nix store (OpenStack-attached)
  # UUID: f6cfb652-67b5-4b0e-8354-3bbf038dc63c
  # Live-migrated from /dev/vda1 on 2026-07-16
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nix-store";
    fsType = "ext4";
  };

  swapDevices = [{ device = "/dev/disk/by-uuid/2804001e-160b-46be-aa72-8f956156cd88"; }];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
