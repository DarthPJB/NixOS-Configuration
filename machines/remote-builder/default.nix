{ config
, pkgs
, lib
, self
, hostname
, ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix
    ../../users/darthpjb.nix
    ../../modifier_imports/flakes.nix
    ../../environments/sshd.nix
    ../../environments/tools.nix
    ../../services/dynamic_domain_gandi.nix
    ../../services/github_runners.nix
    ../../users/build.nix
    ../../modules/enable-wg-topology.nix
  ];
  enableWgTopology.enable = true;
}
