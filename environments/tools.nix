{ config, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.btop
    pkgs.nano
    pkgs.wget
    pkgs.git
    pkgs.ranger
    pkgs.killall
    pkgs.magic-wormhole
    pkgs.wpa_supplicant_gui
    pkgs.dnsutils
    pkgs.pciutils
    pkgs.lshw
    pkgs.usbutils
  ];
}
