{ pkgs, config, lib, ... }:
{
  boot = {
    # Use mainline kernel
    loader.raspberryPi = {
        enable = true;
        version = 3;
        firmwareConfig = ''
          core_freq=250
        '';
    };
    kernelParams = [ "console=ttyS1,115200n8" ];
    initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = lib.mkForce [ "bridge" "macvlan" "tap" "tun" "loop" "atkbd" "ctr" ];
    supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" "ext4" "vfat" ];
  };
  # "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix" usually contains this
  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  boot.loader.raspberryPi.firmwareConfig = ''
    dtparam=audio=on

  environment.systemPackages = with pkgs; [ vim git ];
  services.openssh.enable = true;
  networking.hostName = "pi";
  users = {
    users.myUsername = {
      password = "myPassword";
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };
  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
}
