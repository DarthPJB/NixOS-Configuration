# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./ethan-net/hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostId = "e3fabb5b";

  boot.supportedFilesystems = [ "zfs" ];
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      flags = "-k -p --utc";
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    pkgs.gpp
    pkgs.emscripten
    pkgs.neovim
    pkgs.dnsutils
    pkgs.openssl
    pkgs.upterm
    pkgs.tmux
    pkgs.cmatrix
    pkgs.nms
    pkgs.chafa
    pkgs.lolcat
    pkgs.figlet
    pkgs.cowsay
    pkgs.nmap
    pkgs.tree
    pkgs.ripgrep
  ];

  programs.ssh.enableAskPassword = false;
#  programs.gnupg.agent =
#    {
#      pinentryPackage = pkgs.pinentry-tty;
#      enable = true;
#      enableSSHSupport = true;
#    };
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.John88 = {
    isNormalUser = true;
    uid = 1108;
    name = "John88";
    description = "Eighty Eight";
    createHome = true;
    home = "/home/pokej";
    hashedPassword = "$6$irFKKFRDPP$H5EaeHornoVvWcKtUBj.29tPvw.SspaSi/vOPGc3GG2bW//M.ld3E7E3XCevJ6vn175A/raHvNIotXayvMqzz0";
    openssh.authorizedKeys.keys =
      [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZ0k7iuFr6stY9bjMQRvpm+pgOH//2pIgZbfO218SdhZDsMxjWtAHqli9zBzGLVuIVsQlMtkhGoztdJNKNga0urZKghlZbKlaThThcdCMnJPx2MbQjU+gXsxaKzdHhMMKBEOZuVyAAmeu/lYT8/jtq3/GLQMV13gfXa02TTr+MEJ0pjFb1Q2SPItMqUSGIVVj1tJusvEteUOyaJI7jOHx+c8SNarg4/dmlCFLuWz5mug55k2j+bz2FeSdcOB+sb6lgkyl/rmsSay5N0v48JVHfWQFi9+w+UArFp2NPQE8kv0fPdIxTK1A7S7aaPR8yExVJFKZV5M/QoOu6mQx4ph1iSb6kiTNS0r8PsjXmzYrEnu1K/TqDBdQk/CbDdKZqHx/HJbPa73b/6Bkbo8pWVqB3Q/uW11oPOvbnBkLUVFNmqg7kyH3kl+Xrmy4FZRPoVldAkFrlQYApRFk3cZysoSSkMbwyq/BZqVvFi66STK/Njy7pzXatqNDdMRMavOG5/dE= DarthPJB@nixos"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5 darthpjb@gmail.com"
      ];
    extraGroups = [ "wheel" "libvirtd" "vboxusers" "dialout" "disk" "networkManager" ]; # Enable ‘sudo’ for the user.
  };

  fileSystems."/" =
    {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "size=2G" "mode=755" ];
    };

  fileSystems."/etc/ssh" =
    {
      device = "bulk-storage/etc-ssh";
      fsType = "zfs";
    };

  fileSystems."/var/log" =
    {
      device = "bulk-storage/var-log";
      fsType = "zfs";
    };

  fileSystems."/nix" =
    {
      device = "bulk-storage/nix-store";
      fsType = "zfs";
    };

  fileSystems."/etc/nixos" =
    {
      device = "bulk-storage/etc-nixos";
      fsType = "zfs";
    };

  systemd.mounts = [{
    where = "/var/tmp";
    what = "/bulk-storage/tmp";
    options = "bind";
  }];
  #nix.envVars.TMPDIR = "/var/tmp";
  fileSystems."/tmp" =
    {
      device = "bulk-storage/tmp";
      fsType = "zfs";
    };


  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.ports = [ 22 1108 ];
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = false;
  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 1108 ];
  networking.firewall.allowedUDPPorts = [ ];
  networking.hostName = "remote-worker-2"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;


  # Enable the Plasma 5 Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  #  services.xserver.desktopManager.plasma5.enable = true;



  system.stateVersion = "23.05"; # Did you read the comment?

}

