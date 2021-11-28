# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./modifier_imports/flakes.nix
      ./users/darthpjb.nix
      ./cachix.nix
      ./environments/sshd.nix
      ./locale/en_gb.nix
      ./locale/astralship.nix
    ];



  # Enable the X11 windowing system.
  services.xserver.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  hardware.opengl.enable = true;
  programs.sway =
  {
    enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
    #extraSessionCommands = "wpa_gui & nextcloud & parsecd & blueman-applet &";
    extraPackages = with pkgs;
    [
      swaylock
      swayidle
      wl-clipboard
      mako # notification daemon
      alacritty # Alacritty is the default terminal in the config
      dmenu # Dmenu is the default in the config but i recommend wofi since its wayland native
    ];
  };




  #  List packages installed in system profile. To search, run:
  # $ nix search wget
   environment.systemPackages = with pkgs; [
     nano
     wget
     firefox
     brightnessctl
     atom
     alacritty
     git
     ranger
     killall
     bpytop
     nextcloud-client
#     inputs.croughanator.packages.x86_64-linux.parsecgaming
     #development
     cmatrix
     magic-wormhole
     emscripten
     wasm3
     brave
     wpa_supplicant_gui
   ];


  # This value determines the NixOS release from which the default
  # settings for stateful data
  system.stateVersion = "21.05"; # Did you read the comment?

}
