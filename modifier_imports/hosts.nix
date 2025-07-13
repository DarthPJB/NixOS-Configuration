{ config, pkgs, ... }:
{
  networking.extraHosts =
    ''
              193.16.42.101 remote.worker
              100.127.45.55 propylaia.platonic
              100.107.101.14 hyperhyper.platonic
      	      100.91.247.95 acropolis.platonic
              100.75.142.109 tumulus.platonic
              100.105.114.89 springboard.platonic
              167.235.2.58 tankles.server

              
              10.88.127.1 ap.local
              10.88.127.1 router.local
    '';
}
