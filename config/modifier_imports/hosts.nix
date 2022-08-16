{ config, pkgs, ... }:
{
    networking.extraHosts =
    ''
        144.126.215.24 mattermoist.platonic
        193.16.42.101 remote.worker
        193.16.42.125 ark.server
    '';
}