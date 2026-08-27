# Do not modify this file!  It was generated from a hardware scan of the
# assimilator-probe (x86-bootstrap) deployment on 2026-08-27.
#
# Target hardware: ASUS NUC14RVH-B (Intel Core Ultra 5 125H, 18 cores, 16 GiB)
# Boot medium:     USB flash drive (sda) — the assimilator-probe bootstrap image
# Target storage:  addlink M.2 PCIe NVMe (nvme0n1) — migration is a follow-up
#
# The partition UUIDs below were read from the running probe via
# /dev/disk/by-uuid (read-only inspect access, port 1108).
{ config
, lib
, pkgs
, modulesPath
, ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Kernel modules required to reach the root device on the USB boot medium
  # (xhci/ehci for the USB controller, usb_storage/uas/sd_mod/sr_mod for the
  # flash drive, ahci/ata_piix for SATA, nvme/nvme-pci for the M.2 drive).
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "ata_piix"
    "nvme"
    "nvme-pci"
    "usb_storage"
    "uas"
    "sd_mod"
    "sr_mod"
    "usbhid"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # EFI System Partition (sda1, 1 GiB vfat) — GRUB EFI removable
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/12CE-A600";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # Root filesystem (sda3, 11 GiB ext4) — the bootstrap image root
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/793f5bea-fb84-4c96-a832-3a8b287a760a";
    fsType = "ext4";
  };

  # Swap (sda2, 8 GiB)
  swapDevices = [{ device = "/dev/disk/by-uuid/851d149e-df1d-4dea-9253-fb64340d714d"; }];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp86s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
