# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
{
  systemd.user.services.upDeck =
    let
      upDeck = builtins.fetchurl {
        url = "https://8up.uk/downloads/UPDeck_2-1-19.love";
        sha256 = "1m8s83hdmkxym2frcwbzhibkxa864dpsbpd2jsmn3gk2sc8xid89";
      };
    in
    {
      description = "upDeck";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig =
        {
          ExecStart = ''
            ${pkgs.love}/bin/love ${upDeck}
          '';
          #${pkgs.obs-studio}/bin/obs
          #${pkgs.coreutils-full}/bin/echo display: $DISPLAY
          #echo display is $DISPLAY
          #echo authority is $XAUTHORITY
          # 
          #${pkgs.x11vnc}/bin/x11vnc -ncache 10 -display :0 &
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
  systemd.user.services.obs-auto =
    {
      description = "obs-studio-autostart";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig =
        {
          ExecStart = ''
            ${pkgs.obs-studio}/bin/obs
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };
  systemd.user.services.x11vnc =
    {
      description = "run X11 vnc server";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig =
        {
          ExecStart = ''
            ${pkgs.x11vnc}/bin/x11vnc -ncache 10 -display $DISPLAY 
          '';
          PassEnvironment = "DISPLAY XAUTHORITY";
        };
    };

  imports =
    [
      # Include the results of the hardware scan.
      ./obs-box/hardware-configuration.nix
    ];
  security = {
    sudo = {
      wheelNeedsPassword = false;
      extraConfig = ''
        %psudo ALL=(ALL) PASSWD: ALL
      '';
    };
  };
  environment.extraInit = ''
    xset s off -dpms
  '';
  #services.xrdp.enable = true;
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
  networking.firewall.allowedTCPPorts = [ 1108 22 5901 ];

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
          displayManager = {
            defaultSession = "none+i3";
            autoLogin = {
              enable = true;
              user = "John88";
            };
          };
          windowManager.i3.enable = true;
        };
    };
}

