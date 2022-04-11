{ config, pkgs, ... }:
{
    networking.extraHosts =
    ''
        144.126.215.24 mattermoist.platonic
    '';
}