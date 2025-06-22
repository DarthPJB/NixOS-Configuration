{ config, pkgs, ... }:

{
  hardware.rtl-sdr.enable = true;
  users.users.John88.extraGroups = [ "plugdev" ];
  #boot.blacklistedKernelModules = [ "dvb_usb_rtl28xxu" ];
  services.udev.packages = [ pkgs.rtl-sdr ];
  environment.systemPackages = with pkgs; [
    usbutils
    rtl-sdr
    # Frequency scanners
    gqrx # older but cool
    sdrpp # sweeter 
#    sdrangel # minimal  lightweight
    gnuradio # powerhouse
  ];
}
