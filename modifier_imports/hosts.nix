{ config, pkgs, ... }:
{
  networking.extraHosts =
    ''
              193.16.42.101 remote.worker
              193.16.42.125 ark.server
              100.127.45.55 propylaia.platonic
              100.107.101.14 hyperhyper.platonic
      	      100.91.247.95 acropolis.platonic
              100.75.142.109 tumulus.platonic
              100.105.114.89 springboard.platonic
              193.16.42.101 nextcloud.johnbargman.com
              192.168.1.104 nasa.astral
              167.235.2.58 tankles.server
              216.24.131.22 keyboardvideomouse.platonic.systems
    '';
}
