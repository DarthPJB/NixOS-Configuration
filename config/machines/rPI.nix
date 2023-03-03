{ pkgs, config, lib, ... }:
{
  boot = {
    # Cleanup tmp on startup
    cleanTmpDir = true;
    kernelParams = [ "console=ttyS1,115200n8" "cma=32M" ];
  };

  swapDevices = [ { device = "/swapfile"; size = 1024; } ];
  hardware.enableRedistributableFirmware = true;
  services.openssh.enable = true;
  networking = {
    hostName = "printcontroller";
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = true;
    };
  };
}
