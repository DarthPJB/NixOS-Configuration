{ config, pkgs, ... }:
{
    networking.extraHosts =
    ''
        144.126.215.24 mattermoist.platonic
        193.16.42.101 remote.worker
        193.16.42.125 ark.server
	216.24.131.6 acropolis.platonic
        216.24.131.5 tumulus.platonic
        193.16.42.101 nextcloud.johnbargman.com
        192.168.1.104 nasa.astral
    '';
}
