# This is the general configuration for all of my systems; anything in here will be found on every possible system I have.

{ inputs, config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./modifier_imports/flakes.nix
      ./modifier_imports/hosts.nix
      ./users/darthpjb.nix
      ./locale/en_gb.nix
      ./locale/home_networks.nix
      ./cachix.nix
      ./environments/sshd.nix
      ./environments/tools.nix
    ];
  nix.settings.trusted-users = [ "root" "John88" ];
  nixpkgs.config =
    {
      allowUnfree = true;
    };

}
