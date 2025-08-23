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
      #autologinUser = "John88";
      enable = true;
      hwRender = true; # Enable hardware rendering
      extraConfig = ''
        font-size=16
        #xterm-resolution=1920x1080 # Set desired resolution
        font-name=Source Code Pro # Clear, monospaced font
        font-size=14 # Balanced size for readability
        palette=linux # Standard Linux console colors
        #scrollback=1000 # Scrollback buffer size
        drm # Use DRM backend for Raspberry Pi
      '';
      fonts = [{ name = "Source Code Pro"; package = pkgs.source-code-pro; }];
    };
}
