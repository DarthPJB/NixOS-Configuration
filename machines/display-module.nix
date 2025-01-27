{ pkgs, config, lib, ... }:
let pkgs_arm = pkgs;
in
{

  networking =
    {
      hostName = "display-module";
    };
  boot = {
    initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
    kernelPackages = pkgs_arm.lib.mkDefault pkgs_arm.linuxKernel.packages.linux_rpi3;
    # Cleanup tmp on startup
    #tmp.cleanOnBoot = true;
    kernelParams = [
      "console=ttyS0,115200n8"
      "console=fb1"
    ];
  };
  hardware = {
    deviceTree =
      {
        /*          firmwareConfig = ''
        hdmi_force_hotplug=1
      dtparam=i2c_arm=on
      dtparam=spi=on
      enable_uart=1
      dtoverlay=piscreen,speed=18000000,drm,rotate=180
      hdmi_group=2
      hdmi_mode=1
      hdmi_mode=87
      hdmi_cvt 480 320 60 6 0 0 0
      hdmi_drive=2
        ''; */
      };
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
      #    displayManager.sddm.enable = pkgs.lib.mkForce false;
      # displayManager.lightdm.enable = pkgs.lib.mkForce true;
      xserver = {
        resolutions = [
          {
            x = 480;
            y = 320;
          }
        ];
        drivers = [
          {
            name = "FramebufferOne";
            driverName = "fbdev";
            deviceSection = ''
              Option "fbdev" "/dev/fb1"
            '';
            display = true;
          }
        ];
      };
    };
  #  fileSystems."/home/pokej/obisidan-archive" =
  #    {
  #      device = "/dev/disk/by-uuid/8c501c5c-9fbe-4e9d-b8fc-fbf2987d80ca";
  #      fsType = "ext4";
  #    };
}
