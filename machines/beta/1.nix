{ pkgs, config, lib, self, ... }:
let
  hostname = "beta-one";
in
{

  imports = [
    #    ../../lib/enable-wg.nix
    #    ../../configuration.nix
  ];
  system.name = "${hostname}";
  system.stateVersion = "25.11";
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  sdImage.compressImage = false;
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  boot = {
    kernelParams = [ "console=ttyS1,115200n8" "cma=32M" ];
  };
  # pick the right kernel
  #boot.kernelPackages = pkgs.linuxPackages_5_0;
  nixpkgs.buildPlatform = "x86_64-linux"; # build arch - not compatible with more complex systems, but good for bootstrap images.
  nixpkgs.hostPlatform = "armv7l-linux"; # target run arch
  # boot.kernelPackages = lib.mkForce pkgs.linuxKernel.packages.linux_rpi2;
  # set cross compiling
  #nixpkgs.crossSystem = nixpkgs.crossSystems.armv7l-hf-multiplatform;
  /* nixpkgs.crossSystem = lib.systems.elaborate {
    config = "armv7l-unknown-linux-gnueabihf";
    platform = {
      name = "raspberrypi2";
      kernelMajor = "2.6";
      kernelBaseConfig = "multi_v7_defconfig";
      kernelArch = "arm";
      kernelDTB = true;
      kernelAutoModules = true;
      kernelPreferBuiltin = true;
      kernelTarget = "zImage";
      gcc = {
        cpu = "cortex-a7";
        fpu = "neon-vfpv4";
      };
    }; 
  }; */
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  #sdImage.bootSize = lib.mkOverride 1050 32;
  documentation = { dev.enable = false; man.enable = false; info.enable = false; enable = false; };
  disabledModules = [
    "profiles/all-hardware.nix"
    "profiles/base.nix"
  ];
  swapDevices = [{ device = "/swapfile"; size = 1024; }];
}
