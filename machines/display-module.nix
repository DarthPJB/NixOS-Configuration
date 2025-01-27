{ pkgs, config, lib, ... }:
{

  networking.hostName = "display-module";
  boot = {
    initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
    kernelPackages = pkgs_arm.lib.mkDefault pkgs_arm.linuxKernel.packages.linux_rpi3;
    kernelParams = [
      "console=ttyS0,115200n8"
      "console=fb1"
    ];
    loader.raspberryPi.firmwareConfig = ''
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
    '';
  };
  services.openssh.ports = [ 22 ];
  networking.firewall.allowedTCPPorts = [ 22 ];
  fileSystems."/home/pokej/obisidan-archive" =
    {
      device = "/dev/disk/by-uuid/8c501c5c-9fbe-4e9d-b8fc-fbf2987d80ca";
      fsType = "ext4";
    };
  services.xserver = {
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
    displayManager.sddm.enable = nixpkgs.lib.mkForce false;
    displayManager.lightdm.enable = nixpkgs.lib.mkForce true;
  };
  #hardware.raspberry."3".
  hardware.bluetooth.enable = false;
  nixpkgs.config.allowUnfree = true;
  _module.args =
    {
      self = self;
      nixinate = {
        host = "192.168.0.115";
        sshUser = "John88";
        substituteOnTarget = true;
        hermetic = true;
        buildOn = "local";
      };
    };
  boot = {
    # Cleanup tmp on startup
    #tmp.cleanOnBoot = true;
    kernelParams = [ "console=ttyS1,115200n8" "cma=32M" ];
  };

  swapDevices = [{ device = "/swapfile"; size = 1024; }];
  hardware.enableRedistributableFirmware = true;
  services.openssh.enable = true;
  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
}
