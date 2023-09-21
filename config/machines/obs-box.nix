# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./obs-box/hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostId = "1d2797ef"; # Define your hostname.
  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  # Set your time zone.
  time.timeZone = "Europe/London";

  #  Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "uk";
  };
  # Enable the OpenSSH daemon.
  services.openssh.ports = [ 1108 22 ];
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 1108 22 ];

  # Configure keymap in X11

  system.stateVersion = "22.11";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  hardware = {
    sane.enable = true;
    opengl.enable = true;
    #pulseaudio.enable = true;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    opengl.driSupport32Bit = true;
    #pulseaudio.support32Bit = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;
  environment.systemPackages =
    [
      pkgs.love
    ];
  services =
    {
      xserver =
        {
          libinput.enable = true;
          videoDrivers = [ "nvidia" ];
          layout = "gb";
          #	deviceSection = ''
          #	  Option "Coolbits" "24"
          #	'';
        };
    };
}

