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
    ];

  # Use the GRUB 2 boot loader.
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
 
# boot.loader.grub.enable = true;
# boot.loader.grub.version = 2;
# boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
 # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "Terminal-zero"; # Define your hostname.
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.userControlled.enable = true;
  networking.wireless.interfaces = [ "wlp3s0" ];
  networking.wireless.networks = {
    "Astral_Ship" = {
      pskRaw = "ff866b7b9494bd6915c28a06c8604d1e2396e590e64f71b2fdf9c0c9709ec2c4";
  };
};
  # Set your time zone.
   time.timeZone = "Europe/London";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.enp0s25.useDHCP = true;
  networking.interfaces.wlp3s0.useDHCP = true;
  networking.interfaces.wwp0s29u1u4i6.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
   i18n.defaultLocale = "en_GB.UTF-8";
   console = {
     font = "Lat2-Terminus16";
     keyMap = "uk";
   };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
 #  services.xserver.windowManager.i3.enable = true;

  hardware.opengl.enable = true;
 #programs.sway.enable = true;
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


  # Configure keymap in X11
  services.xserver.layout = "gb";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.

  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;


  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
   users.users.darthpjb = {
     isNormalUser = true;
     extraGroups = [ "wheel" "video" "dailout" ]; # Enable ‘sudo’ for the user.
     password= "godlet";
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
     #wifi
     wpa_supplicant_gui
     #bluetooth
     #blueman
     #btlejack
   ];
    nix.trustedUsers = [ "root" "darthpjb" ];
   nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
   };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
   programs.gnupg.agent = {
     enable = true;
     enableSSHSupport = true;
   };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}
