{ pkgs, config, lib, ... }:
{
  imports = [ ./piscreen.nix ];

  environment.systemPackages = [ pkgs.mgba ];

  networking =
    {
      hostName = "display-module";
    };
  boot = {
    supportedFilesystems.zfs = lib.mkForce false;
    initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
    kernelParams = [
      "console=ttyS0,115200n8"
      "console=fb2"
    ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };
  hardware = {
    bluetooth.enable = false;
    enableRedistributableFirmware = true;
  };
  swapDevices = [{ device = "/swapfile"; size = 1024; }];
  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
  services =
    {
      displayManager = {
        defaultSession = "none+i3";
        autoLogin = {
          enable = true;
          user = "John88";
        };
      };
      xserver =
        {
          videoDrivers = [ "fbdevhw" "fbdev" ]; #"modesetting"]; #
          resolutions = [
            {
              x = 480;
              y = 320;
            }
          ];

          #fb1 if fkms present
          deviceSection = ''
            Option "fbdev" "/dev/fb2" 
          '';
        };
    };
}
#  fileSystems."/home/pokej/obisidan-archive" =
#    {
#      device = "/dev/disk/by-uuid/8c501c5c-9fbe-4e9d-b8fc-fbf2987d80ca";
#      fsType = "ext4";
#    };
