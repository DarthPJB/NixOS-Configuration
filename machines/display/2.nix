{ pkgs, config, lib, self, ... }:
let
  hostname = "display-1";
in
{

  imports = [
    ../../lib/enable-wg.nix
    ../../environments/jwm.nix
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
    kernelModules = [ "bcm2835-v4l2" ];
    initrd.availableKernelModules = lib.mkForce [ "bcm2835" ];
    supportedFilesystems.zfs = lib.mkForce false;
    kernelPackages = pkgs.linuxPackages_rpi4;
    kernelParams = [ "console=ttyS1,115200n8" "cma=128M" "snd_bcm2835.enable_hdmi=1" "snd_bcm2835.enable_headphones=1" ];
    extraModprobeConfig = ''
      options snd_bcm2835 enable_headphones=1
      options snd_bcm2835 enable_hdmi=1
    '';
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  hardware.pulseaudio.enable = true;
  services.pipewire.enable = false;

  #services.pipewire = {
  #  enable = true;
  #  alsa.enable = true;
  #  alsa.support32Bit = true;
  #  pulse.enable = true;
  #};
  hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];

  swapDevices = [{ device = "/swapfile"; size = 1024; }];
  hardware.enableRedistributableFirmware = true;
  services.openssh.enable = true;
  networking = {
    hostName = "${hostname}";
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
}
