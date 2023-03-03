{ pkgs, config, lib, ... }:
{
  boot = {
#    loader.raspberryPi = {
#      enable = true;
#      version = 3;
#      firmwareConfig = ''
#        core_freq=250
#      '';
#    };
    # Cleanup tmp on startup
    cleanTmpDir = true;
    kernelParams = [ "console=ttyS1,115200n8" "cma=32M" ];
    #initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
  };

  swapDevices = [ { device = "/swapfile"; size = 1024; } ];
    
  system.stateVersion = "22.05";
  services.openssh.enable = true;
  networking.hostName = "pi";
  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
}
