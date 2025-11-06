{ config, pkgs, ... }:
{
  networking.extraHosts =
    ''
              167.172.199.21 forme.prod
              193.16.42.101 remote.worker
              100.68.215.11 propylaia.platonic
              100.107.101.14 hyperhyper.platonic
      	      100.91.247.95 acropolis.platonic
              100.75.142.109 tumulus.platonic
              100.105.114.89 springboard.platonic
              193.16.42.95 entrypoint.pinkerton
    '';
}
