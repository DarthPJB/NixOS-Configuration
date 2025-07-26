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
      pkgs.bottom
    ];
  security.acme =
    {
      acceptTerms = true;
      defaults.email = "darthpjb@gmail.com";
    };
  nix.settings = {

    trusted-substituters = [
      "https://cache.platonic.systems"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.platonic.systems:ePE43vrTvMW4177G3LfAYWCSdZkSBA5gY3WZCO1Y3ew="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    trusted-users = [ "root" "John88" ];
  };
  secrix.defaultEncryptKeys = {
    John88 = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5" ];
  };
  services.kmscon =
    {
      enable = true;
      hwRender = true;
      fonts = [{ name = "Source Code Pro"; package = pkgs.source-code-pro; }];
    };
}
