{ pkgs, config, lib, ... }:
{
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  imports = [ ./piscreen.nix ];
  swapDevices =
    [{ device = "/dev/disk/by-uuid/ea2a84bb-a66c-4291-ac03-597999559a5d"; }];
  #swapDevices = [{ device = "/swapfile"; size = 1024; }];
  fileSystems."/home" =
    {
      device = "/dev/disk/by-uuid/b3c6f24a-010d-4f16-a3b6-37859054234d";
      fsType = "ext4";
    };
  environment.systemPackages = [ pkgs.rtl-sdr ];

  networking =
    {
      hostName = "display-zero";
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

