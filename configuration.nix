# This is the general configuration for all of my systems; anything in here will be found on every possible system I have.

{ config, pkgs, self, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./modifier_imports/flakes.nix
      ./modifier_imports/hosts.nix
      ./users/darthpjb.nix
      ./locale/en_gb.nix
      ./locale/home_networks.nix
      ./environments/sshd.nix
      ./environments/tools.nix
      #self.inputs.secrix.nixosModules.secrix
    ];
  environment.systemPackages = with pkgs;
    [
      pkgs.tmux
      pkgs.progress
      pkgs.parted
    ];
  security.acme =
    {
      acceptTerms = true;
      defaults.email = "darthpjb@gmail.com";
    };
  nix.settings.trusted-users = [ "root" "John88" ];
  secrix.defaultEncryptKeys = {
    John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ];
  };
  services.kmscon =
    {
      enable = true;
      hwRender = true;
    };
}
