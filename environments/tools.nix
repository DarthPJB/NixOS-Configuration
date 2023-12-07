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
    pkgs.freemind
    pkgs.dnsutils
    pkgs.pciutils
  ];
}
