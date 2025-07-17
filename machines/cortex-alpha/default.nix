# ------------------ CORTEX ALPHA -------------------

{ config, lib, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  boot = {
  #  zfs.extraPools = [ "external" ];
    supportedFilesystems = [ "zfs" ];
    kernel = {
      sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = true; #TODO: v6 please god
      };
    };
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };
  services.nginx = {
    enable = true;
    virtualHosts."ap.local" = {
      enableACME = false;
      forceSSL = false;
      listenAddresses = [ "10.88.127.1" "10.88.128.1" ];
      locations."~/" = {
        proxyPass = "http://10.88.128.2:80";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
        /*                    proxy_set_header Upgrade $http_upgrade;
                    proxy_set_header Connection $connection_upgrade;*/
        proxyWebsockets = true; # needed if you need to use WebSocket
      };
    };
  };


  # Set your time zone.
  time.timeZone = "Etc/UTC";
  secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file = ../../secrets/wg_cortex-alpha;
  networking = {
    wireguard = {
      enable = true;
      interfaces = {
        wireg0 =
          {
            ips = [ "10.88.127.0/24" ];
            listenPort = 2108;

            /* postSetup = ''
            ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.88.127.0/24 -o enp2s0 -j MASQUERADE
          '';
          postShutdown = ''
            ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.88.127.0/24 -o enp2s0 -j MASQUERADE
            '';*/
            privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
            peers = [
            {
              # Public key of the peer (not a file path).
              publicKey = builtins.readFile ../../secrets/wg_LINDA_pub;
              # list of ips assigned to this peer within the tunnel subnet. used to configure routing.
              allowedIPs = [ "10.88.127.88/32" ];
            }
            {
              publicKey = builtins.readFile ../../secrets/wg_terminal-nx-01_pub;
              # list of ips assigned to this peer within the tunnel subnet. used to configure routing.
              allowedIPs = [ "10.88.127.21/32" ];
            }
            ];
          };
      };
    };
    hostName = "cortex-alpha"; # Define your hostname.
    hostId = "c043a1fa";
    interfaces.enp3s0 = {
      useDHCP = lib.mkDefault false;
      # Network output
      ipv4.addresses = [{
        address = "10.88.128.1";
        prefixLength = 24;
      }];
    };
    interfaces.enp2s0 = {
      useDHCP = lib.mkDefault true;
    };
    firewall.interfaces = {
      "wireg0".allowedTCPPorts = [ 80 ];
      "enp3s0".allowedTCPPorts = [ 80 ];

      "wireg0".allowedUDPPorts = [ 1108 ];
      "enp2s0".allowedUDPPorts = [ 1108 2108 ];
      "enp3s0".allowedUDPPorts = [ 2108 /*WG*/ 67 /* DHCP */ 53 /*DNS*/ ];
    };
    nat = {
      enable = true;
      internalIPs = [ "10.88.128.0/24" ];
      externalInterface = "enp2s0";
      internalInterfaces = [ "eno3" ];
    };
    nameservers = [ "127.0.0.1" ];
  };
  services.dnsmasq = {
    enable = true;
    settings = {
      # upstream DNS servers
      # sensible behaviours
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      # Cache dns queries.
      cache-size = 1000;
      server = [
        "208.67.220.220"
        "208.67.222.222"
        "1.0.0.1"
        "8.8.8.8"
      ];
      dhcp-range = [ "enp3s0,10.88.128.50,10.88.128.254,24h" ];
      interface = "enp3s0";
      dhcp-host = "10.88.128.1";

      # local domains
      local = "/local/";
      domain = "local";
      expand-hosts = true;
      
      no-hosts = true;
      address = [ 
      "/${config.networking.hostName}.local/10.88.128.1"
      "/cortex-alpha.johnbargman.net/10.88.128.1"
      "/ap.local/10.88.128.1"
      ];
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

}

