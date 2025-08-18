{ pkgs, config, lib, ... }:
let
  hostname = "display-1";
in
{

  imports = [
    ../../lib/enable-wg.nix
  ];
  system.name = "${hostname}";
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  sdImage.compressImage = false;
  #secrix.services.wireguard-wireg0.secrets."${hostname}".encrypted.file = "../../secrets/wg_${hostname}";
  #environment.vpn =
  #  {
  #    enable = true;
  #    postfix = 30;
  #    privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
  #  };
  boot = {
    kernelPackages = nixpkgs.legacyPackages.aarch64-linux.linuxPackages_rpi4;
    kernelParams = [ "console=ttyS1,115200n8" "cma=128M" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };
  swapDevices = [{ device = "/swapfile"; size = 1024; }];
  hardware.enableRedistributableFirmware = true;
  services.openssh.enable = true;
  networking = {
    hostname = "${hostname}"
      interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
}
