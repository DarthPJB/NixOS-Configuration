# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./machines/megajohn.nix
    ];

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.

  networking =
  {
    useDHCP = false;
    networkmanager = {
      enable = true;  # Enables wireless support via wpa_supplicant.
      wifi.backend = "wpa_supplicant";
      dhcp = "dhclient";
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
   environment.systemPackages = [
     pkgs.wget
     pkgs.nano
     pkgs.git
     pkgs.mkpasswd
     pkgs.htop
     pkgs.vim
     pkgs.tmux
     pkgs.pciutils
   ];

  system.stateVersion = "20.09"; # Did you read the comment?
}
