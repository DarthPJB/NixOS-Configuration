{ pkgs, config, lib, self, ... }:
let
  hostname = "display-2";
in
{

  imports = [
    ../../lib/enable-wg.nix
    ../../environments/i3wm.nix
    ../../environments/browsers.nix
  ];
  system.name = "${hostname}";
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  sdImage.compressImage = false;
  secrix.services.wireguard-wireg0.secrets."${hostname}".encrypted.file = "${self}/secrets/wg_${hostname}";
  environment.vpn =
    {
      enable = true;
      postfix = 42;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets."${hostname}".decrypted.path;
    };

  hardware = {
    enableRedistributableFirmware = true;
    raspberry-pi."4" =
      {
        apply-overlays-dtmerge.enable = true;
        fkms-3d.enable = true;
      };
    deviceTree = {
      enable = true;
    };
  };

  boot = {
    initrd.kernelModules = [ "vc4" "snd_bcm2835" ];
    #  supportedFilesystems.zfs = lib.mkForce false;
    #  kernelPackages = pkgs.linuxPackages_rpi4;
    kernelParams = [ "video=HDMI-A-1:1920x1080@60" "console=ttyS1,115200n8" "cma=128M" ];
    extraModprobeConfig = ''
      options snd_bcm2835 enable_headphones=1 enable_hdmi=1
    '';
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };
  services.libinput.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };


  swapDevices = [{ device = "/swapfile"; size = 1024; }];
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
