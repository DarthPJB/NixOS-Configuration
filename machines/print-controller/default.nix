{ pkgs, config, lib, ... }:
{
  imports = [
    ../../lib/enable-wg.nix
  ];
  secrix.services.wireguard-wireg0.secrets.print-controller.encrypted.file = ../../secrets/wg_print-controller;
  environment.vpn =
    {
      enable = true;
      postfix = 30;
      privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.print-controller.decrypted.path;
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
      enable = false;
    };
  };
}
