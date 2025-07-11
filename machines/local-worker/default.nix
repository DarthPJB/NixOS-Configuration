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

  hardware = {
    sane.enable = true;
    graphics.enable = true;
    pulseaudio.enable = true;
    graphics.enable32Bit = true;
    pulseaudio.support32Bit = true;
    nvidia = {
      open = false;
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };
  services =
    {
      libinput.enable = true;
      xserver =
        {
          videoDrivers = [ "nvidia" ];
          deviceSection = ''
            Option "Coolbits" "24"
          '';
        };
    };

  boot = {
    kernelParams = [
      "console=ttyS0,115200"
      "console=tty1"
    ];
    # Use the systemd-boot EFI boot loader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    #special filesystems
    initrd.supportedFilesystems = [ "overlay" "virtiofs" ];
    initrd.availableKernelModules = [ "overlay" "virtiofs" ];
  };

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
        neededForBoot = true;
        device = "nixstore";
        fsType = "virtiofs";
      };
      "/nix/store" =
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

  environment.systemPackages = with pkgs; [
    cudatoolkit
    linuxPackages.nvidia_x11
    cudaPackages.cudnn
    libGLU
    libGL
    xorg.libXi
    xorg.libXmu
    freeglut
    xorg.libXext
    xorg.libX11
    xorg.libXv
    xorg.libXrandr
    zlib
    ncurses5
    stdenv.cc
    binutils
    ffmpeg
    tmux
    btop
  ];

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

}

