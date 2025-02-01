{ config, pkgs, ... }:
{
  networking.extraHosts =
    ''
              193.16.42.101 remote.worker
              193.16.42.125 ark.server
      	      216.24.131.6 acropolis.platonic
              216.24.131.5 tumulus.platonic
              216.24.131.4 springboard.platonic
              193.16.42.101 nextcloud.johnbargman.com
              192.168.1.104 nasa.astral
              167.235.2.58 tankles.server
    '';
}
