# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./libvirt-qemu/hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  #special filesystems
  boot.initrd.supportedFilesystems = [ "overlay" ];
  boot.initrd.availableKernelModules = [ "overlay" ];

  #fileSystems."/nix/.rw-store" = { fsType = "tmpfs"; options = [ "mode=0755" "size=8G" ]; neededForBoot = true; };

  fileSystems =
  { 
    "/public_share" = {
      device = "public_share";
      fsType = "virtiofs";
    };
    "/rendercache" = {
      device = "rendercache";
      fsType = "virtiofs";
    };
    "/88_FS" = {
      device = "88_FS";
      fsType = "virtiofs";
    };
    "/nix/.ro-store" = {
      device = "nixstore";
      fsType = "virtiofs";
    };
fileSystems."/nix/store" =
    {
      fsType = "overlay";
      device = "overlay";
      neededForBoot = true;
      options = [
        "lowerdir=/nix/.ro-store"
        "upperdir=/nix/.rw-store/store"
        "workdir=/nix/.rw-store/work"
      ];
      depends = [
        "/nix/.ro-store"
        "/nix/.rw-store/store"
        "/nix/.rw-store/work"
      ];
    };
  };


  ### ------ VIRT BABY, YEAH!
  systemd.mounts = [
#    {
#      what = "public_share";
#      where = "/public_share";
#      type = "virtiofs";
#      wantedBy = [ "multi-user.target" ];
#      enable = true;
#    }
  ];

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  services.xserver =
  {
      libinput.enable = true;
      videoDrivers = [ "nvidia" ];
  };
  hardware = {
    nvidia = {
	      modesetting.enable = false;
        powerManagement.enable = true;
    };
  };

  system.stateVersion = "22.11"; # Did you read the comment?

}

