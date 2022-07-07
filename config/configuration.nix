# This is the general configuration for all of my systems; anything in here will be found on every possible system I have.

{ inputs, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./modifier_imports/flakes.nix
      ./users/darthpjb.nix
      ./locale/en_gb.nix
      ./locale/astralship.nix
      ./locale/home_networks.nix
      ./cachix.nix
      ./environments/sshd.nix
      ./environments/browsers.nix
      ./environments/tools.nix
    ];
  nixpkgs.config =
  {
    allowUnfree = true;
  };
  #  List packages installed in system profile. To search, run:
  # $ nix search wget
   environment.systemPackages = [
      #inputs.parsecgaming.packages.x86_64-linux.parsecgaming
   ];

}
