# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).


# -------------------------- ALPHA TWO --------------------------
{ config, lib, pkgs, ... }:
{
  #boot.kernelPackages = pkgs.linuxPackages_latest;

  systemd.user.services.xwinwrap =
    {
      description = "xwinwrap-glmatrix";
      wantedBy = [ "graphical-session.target" ];
      serviceConfig =
        {
          Restart = "always";
          ExecStart = ''
            ${pkgs.xwinwrap}/bin/xwinwrap -ov -fs -- ${pkgs.xscreensaver}/libexec/xscreensaver/galaxy --count 5 --no-tracks --cycles 1000 --delay 20000 --no-spin -root -window-id WID
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };


  #    boot.extraModulePackages = [    
  # (config.boot.kernelPackages."rtw88".overrideAttrs (old: {
  #    prePatch = old.prePatch + ''
  #      substituteInPlace Makefile --replace "CONFIG_CONCURRENT_MODE = n" "CONFIG_CONCURRENT_MODE = y"
  #    '';
  #  }))
  #];
  #boot.extraModulePackages = with config.boot.kernelPackages; [ rtl8812au ];
  #boot.kernelModules = [ "rtw88" ];
  # boot.blacklistedKernelModules = [ "rtl8xxxu" ];
  boot.kernelModules = [ "rtl88x2bu" ];
  boot.kernelParams = [
    "video=DP-1:1920x1080@60"
    "video=DP-3:1920x1080@60"
  ];
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; #

  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
    amdvlk
  ];
  # For 32 bit applications 
  hardware.graphics.extraPackages32 = with pkgs; [
    driversi686Linux.amdvlk
  ];
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "alpha-two"; # Define your hostname.
  # Pick only one of the below networking options.
  networking.wireless =
    {
      enable = true; # Enables wireless support via wpa_supplicant.
      userControlled.enable = true;
      interfaces = [ "wlp9s0u1u4" ];
    };
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = lib.mkForce "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = lib.mkForce "us";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];

  services.kmscon.enable = true;

  # Configure keymap in X11
  services.xserver.xkb.layout = lib.mkForce "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;
  hardware.graphics.enable32Bit = true; # For 32 bit applications
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.John88 = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
      tmux
      btop
      git
      clinfo
    ];
  };

  # programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 1108 ];
  networking.firewall.allowedUDPPorts = [ 1108 ];

  system.stateVersion = "24.11"; # Did you read the comment?

}

