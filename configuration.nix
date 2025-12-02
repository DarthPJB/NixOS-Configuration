# This is the general configuration for all of my systems; anything in here will be found on every possible system I have.

{ config, pkgs, self, lib, ... }:
{
  imports =
    [
      ./locale/home_networks.nix
      ./modifier_imports/flakes.nix
      ./users/darthpjb.nix
      ./modifier_imports/hosts.nix
      ./modifier_imports/energy_saving.nix
      ./users/deployment.nix
      ./locale/en_gb.nix
      ./locale/home_networks.nix
      ./environments/sshd.nix
      ./environments/tools.nix
    ];
  environment.systemPackages = with pkgs;
    [
      pkgs.tmux
      pkgs.progress
      pkgs.parted
      pkgs.bottom
    ];
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ config.services.prometheus.exporters.node.port ];
  services.prometheus = {
    exporters.node = {
      enable = true;
      port = 3100;
      enabledCollectors = [
        "logind"
        "systemd"
        "hwmon"
        "cpu"
        "drm"
        "ethtool"
        "logind"
        "pcidevice"
        "wifi"
      ];
      disabledCollectors = [ "textfile" ];
    };
  };
  # This is all you actually need; just this - and.. that, and...
  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    settings = {
      experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" "cgroups" ];
      extra-experimental-features = [ "ca-derivations" ];
      auto-allocate-uids = true;
      max-jobs = lib.mkDefault "auto";
      cores = lib.mkDefault 0;
      auto-optimise-store = true;
      builders-use-substitutes = true;

      trusted-users = [ "root" "John88" "build" "deploy" ];
      trusted-substituters = [
        "https://cache.platonic.systems" #Building things has perks, having them in prod more so. ;)
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.platonic.systems:ePE43vrTvMW4177G3LfAYWCSdZkSBA5gY3WZCO1Y3ew="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };
  secrix.defaultEncryptKeys = {
    John88 = [ "${lib.readFile ./public_key/id_ed25519_master.pub}" ]; # Four years ago matthew croughan said "why bother putting that there?" so... This is why.
  };
  services.openssh.settings.AllowUsers = [ "John88" "build" "deploy" ];

  services.kmscon =
    {
      autologinUser = "John88";
      #  Alright, I know what you are thinking; For real? All I have to do is grab a John-tech and enter tty?
      #      Alright, so what? you have the damn thing in your hand anyway; I saved you what? Six hours to DD my disk
      #        and fuck about in a terminal?
      #      Compared to the 30,000+ hours to brute force some key? Doesn't matter.
      #    P.S. Thx to crash giving me wiregaurd, I look forward to your pinging my IPV4 range :)
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
