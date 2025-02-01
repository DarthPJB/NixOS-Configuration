{ pkgs, config, lib, ... }:
let pkgs_arm = pkgs;
in
{
  imports = [ ./piscreen.nix ];
 
environment.systemPackages = [pkgs.mgba ];

 networking =
    {
      hostName = "display-module";
    };
  boot = {
    supportedFilesystems.zfs = lib.mkForce false;
    initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
    #kernelPackages = pkgs_arm.lib.mkDefault pkgs_arm.linuxKernel.packages.linux_rpi3;
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
    firewall.allowedTCPPorts = [ 22 ];
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
  services =
    {
      openssh =
        {
          enable = true;
          ports = [ 22 ];
        };
        libinput.enable = true;
        displayManager = {
            defaultSession = "none+i3";
            autoLogin = {
              enable = true;
              user = "John88";
            };
          };
        xserver =
        {
          xkb.layout = "gb";
          videoDrivers = [ "fbdevhw" "fbdev" ];#"modesetting"]; #
          windowManager.i3.enable = true;
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
