# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./enviroments/i3wm.nix
    ];
	
  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.networkmanager.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.wifi.backend = "wpa_supplicant";
  networking.networkmanager.dhcp = "dhclient";

  # Set your time zone.
  time.timeZone = "Europe/London";

 #  Select internationalisation properties.
   i18n.defaultLocale = "en_GB.UTF-8";
   console = {
     font = "Lat2-Terminus16";
     keyMap = "uk";
   };

  # Configure keymap in X11
  services.xserver.layout = "gb";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
   environment.systemPackages = with pkgs; [
     wget nano git mkpasswd
   ];

  system.stateVersion = "20.09"; # Did you read the comment?
}
