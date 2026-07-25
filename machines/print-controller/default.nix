# ------------------------ Print Controller ------------------------
{ pkgs
, config
, lib
, hostname
, ...
}:
{
  imports = [
    ../../configuration.nix
    ../../modifier_imports/zram.nix
    ../../modules/enable-wg-topology.nix
  ];
  enableWgTopology.enable = true;
  boot = {
    # Cleanup tmp on startup
    #tmp.cleanOnBoot = true;
    kernelParams = [
      "console=ttyS1,115200n8"
      "cma=32M"
    ];
  };
  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
    }
  ];
  hardware.enableRedistributableFirmware = true;
  services.openssh.enable = true;
  networking = {
    interfaces."wlan0".useDHCP = true;
    wireless = {
      interfaces = [ "wlan0" ];
      enable = false;
    };
  };

  # SD-card Pi / no reliable SMART devices — same pattern as arm-builder / display hosts.
  # Leaving smartd enabled causes switch-to-configuration to fail with exit 17.
  services.smartd.enable = lib.mkForce false;
  services.prometheus.exporters.smartctl.enable = lib.mkForce false;
}
