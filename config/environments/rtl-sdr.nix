{ config, pkgs, ... }:

{
  boot.blacklistedKernelModules = [ "dvb_usb_rtl28xxu" ];
  services.udev.packages = [ pkgs.rtl-sdr ];
  environment.systemPackages = with pkgs; [
    usbutils
    rtl-sdr
    gqrx
  ];
}
