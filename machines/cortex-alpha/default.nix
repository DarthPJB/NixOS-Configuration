# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  boot = {
    kernel = {
      sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = false; #TODO: v6 please god
      };
    };
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };
  networking.hostName = "cortex-alpha"; # Define your hostname.
  # Set your time zone.
  time.timeZone = "Etc/UTC";

  networking.interfaces.enp3s0 = {
    useDHCP = lib.mkDefault false;
    # Network output
    ipv4.addresses = [{
      address = "10.88.128.1";
      prefixLength = 24;
    }];
  };
  networking.interfaces.enp2s0 = {
    # Modem input
    useDHCP = lib.mkDefault true;
  };
  networking.firewall.allowedUDPPorts = [
    67 # DHCP
  ];
  services.dnsmasq = {
    enable = true;
    settings = {
      # upstream DNS servers
      server = [ "9.9.9.9" "8.8.8.8" "1.1.1.1" ];
      # sensible behaviours
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;

      # Cache dns queries.
      cache-size = 1000;

      dhcp-range = [ "enp3s0,10.88.128.50,10.88.128.254,24h" ];
      interface = "enp3s0";
      dhcp-host = "10.88.128.1";

      # local domains
      local = "/local/";
      domain = "local";
      expand-hosts = true;

      # don't use /etc/hosts as this would advertise surfer as localhost
      no-hosts = true;
      address = "/${config.networking.hostName}.local/10.88.128.1";
    };
  };


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
      neovim
    ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

}

