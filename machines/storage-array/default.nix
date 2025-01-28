# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "storage-array"; # Define your hostname.
  networking.hostId =  "b4120de6";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  programs.ssh.enableAskPassword = false;
  programs.gnupg.agent =
    {
      pinentryPackage = pkgs.pinentry-tty;

      enable = true;
      enableSSHSupport = true;
    };
  nix.settings.trusted-users = [ "root" "John88" ];
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


  system.stateVersion = "24.11"; # Did you read the comment?

}
