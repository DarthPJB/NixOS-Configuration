# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./LINDA-CLONE/hardware-configuration.nix
    ];
  environment.systemPackages = [
    inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.looking-glass-client
    inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.scream
    pkgs.virtiofsd
    pkgs.gwe
    pkgs.nvtop
    pkgs.virt-manager
    pkgs.tigervnc
  ];
  boot =
    {

      tmp.useTmpfs = false;
      #tmpOnTmpfs = false;
      supportedFilesystems = [ "zfs" "ntfs" ];
      loader =
        {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      initrd =
        {
          availableKernelModules = [ "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "uas" "sd_mod" ];
          kernelModules = [ "vfio_pci" ];
        };
      #kernelPackages= pkgs.linuxPackages_5_18;
      kernelModules = [ "kvm-amd" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
      kernelParams = [
        "amd_iommu=on"
      ];
      extraModulePackages = [ ];
    };

  # Set your time zone.
  time.timeZone = "Europe/London";
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  sound.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware = {
    sane.enable = true;
    opengl.enable = true;
    cpu.amd.updateMicrocode = config.hardware.enableRedistributableFirmware;
    opengl.driSupport32Bit = true;
    nvidia = {
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };
  networking =
    {
      firewall.allowedUDPPorts = [ 4010 ];
      hostName = "LINDACLONE";
      hostId = "b4122de6";
      useDHCP = false;
      interfaces =
        {
          enp69s0f0.useDHCP = true;
          enp69s0f1.useDHCP = true;
        };
      wireless =
        {
          enable = false; # Enables wireless support via wpa_supplicant.
          userControlled.enable = true;
          interfaces = [ "wlp72s0" ];
        };
    };
  system.stateVersion = "21.11"; # Did you read the comment?

}

