# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./terminal-zero-hardware.nix
      ./users/darthpjb.nix
      ./cachix.nix
      ./enviroments/sshd.nix
      ./locale/en_gb.nix
    ];

    nix = {
     trustedUsers = [ "root" "John88" ];
     package = pkgs.nixUnstable;
     extraOptions = ''
       experimental-features = nix-command flakes
     '';
    };
  # Use the GRUB 2 boot loader.
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
   # Per-interface useDHCP will be mandatory in the future, so this generated config
   # replicates the default behaviour.
   networking = {
      useDHCP = false;
      hostName = "Terminal-zero"; # Define your hostname.
      interfaces = {
        enp0s25.useDHCP = true;
        wlp3s0.useDHCP = true;
        wwp0s20u4i6.useDHCP = true;
      };
      wireless = {
      enable = true;  # Enables wireless support via wpa_supplicant.
      userControlled.enable = true;
      interfaces = [ "wwp0s20u4i6" ];
      networks = {
          "Astral_Ship" = {
            pskRaw = "ff866b7b9494bd6915c28a06c8604d1e2396e590e64f71b2fdf9c0c9709ec2c4";
          };
        };
      };
    };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  hardware.opengl.enable = true;
  programs.sway = {
  enable = true;
  wrapperFeatures.gtk = true; # so that gtk works properly
  #extraSessionCommands = "wpa_gui & nextcloud & parsecd & blueman-applet &";
  extraPackages = with pkgs; [
    swaylock
    swayidle
    wl-clipboard
    mako # notification daemon
    alacritty # Alacritty is the default terminal in the config
    dmenu # Dmenu is the default in the config but i recommend wofi since its wayland native
  ];
};

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;


  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

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
     #bluetooth
     #blueman
     #btlejack
   ];


  # This value determines the NixOS release from which the default
  # settings for stateful data
  system.stateVersion = "21.05"; # Did you read the comment?

}
