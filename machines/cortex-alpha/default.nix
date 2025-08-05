# ------------------ CORTEX ALPHA -------------------

{ config, lib, pkgs, self, ... }:
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
        "net.ipv6.conf.all.forwarding" = false; #TODO: v6 please god
      };
    };
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };
  services.nginx = {
    enable = true;
    virtualHosts = {
      "minio.local" = {
        enableACME = false;
        forceSSL = false;
        listenAddresses = [ "10.88.127.1" "10.88.128.1" ];
        locations."~/" = {
          proxyPass = "http://10.88.127.3:80";
          extraConfig = ''
            proxy_set_header host $host;
            proxy_set_header x-real-ip $remote_addr;
            proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
            proxy_set_header x-forwarded-proto $scheme;
          '';
          proxyWebsockets = true; # needed if you need to use websocket
        };
      };
      "ap.local" = {
        enableACME = false;
        forceSSL = false;
        listenAddresses = [ "10.88.127.1" "10.88.128.1" ];
        locations."~/" = {
          proxyPass = "http://10.88.128.2:80";
          extraConfig = ''
            proxy_set_header host $host;
            proxy_set_header x-real-ip $remote_addr;
            proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
            proxy_set_header x-forwarded-proto $scheme;
          '';
          proxyWebsockets = true; # needed if you need to use websocket
        };
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
            #persistentKeepalive = 25;
            ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
            listenPort = 2108;
            /* postSetup = ''
            ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.88.127.0/24 -o enp2s0 -j MASQUERADE
          '';
          postShutdown = ''
            ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.88.127.0/24 -o enp2s0 -j MASQUERADE
            '';*/
            privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
            peers = (import ../../lib/wg_peers.nix { inherit self; });
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
    firewall =
      {
        interfaces = {
          "wireg0".allowedUDPPorts = [ 1108 ];
          "wireg0".allowedTCPPorts = [ 80 ];
          "enp3s0".allowedTCPPorts = [ 80 ];
          "enp3s0".allowedUDPPorts = [ 1108 2108 /*WG*/ 67 /* DHCP */ 53 /*DNS*/ ];


          #         "enp2s0".allowedTCPPorts = [ 27000 27003 ];
          "enp2s0".allowedUDPPorts = [ 1108 2108 ]; # 27000 27003 ];
          #          "enp2s0".allowedTCPPortRanges = [{ from = 27020; to = 27021; }];
          #          "enp2s0".allowedUDPPortRanges = [{ from = 27020; to = 27021; }];
        };
      };
    #    nftables = {
    #      enable = true;
    #      ruleset = ''
    #        table ip nat {
    #          chain PREROUTING {
    #            type nat hook prerouting priority dstnat; policy accept;
    #            iifname "enp2s0" tcp dport 27000 dnat to 10.88.128.24:27000
    #            iifname "enp2s0" tcp dport 27003 dnat to 10.88.128.24:27003
    #            iifname "enp2s0" tcp dport 27020 dnat to 10.88.128.24:27020
    #            iifname "enp2s0" tcp dport 27021 dnat to 10.88.128.24:27021
    #          }
    #        }
    #      '';
    #    };
    nat = {
      enable = true;
      internalIPs = [ "10.88.128.0/24" ];
      externalInterface = "enp2s0";
      internalInterfaces = [ "eno3" ];
      forwardPorts = [
        /*        {
          sourcePort = 27000;
          proto = "udp";
          destination = "10.88.128.24:27000";
        }
        {
          sourcePort = 27003;
          proto = "udp";
          destination = "10.88.128.24:27003";
        }
        {
          sourcePort = 27020;
          proto = "udp";
          destination = "10.88.128.24:27020";
        }
        {
          sourcePort = 27021;
          proto = "udp";
          destination = "10.88.128.24:27021";
        }
        {
          sourcePort = 27000;
          proto = "tcp";
          destination = "10.88.128.24:27000";
        }
        {
          sourcePort = 27003;
          proto = "tcp";
          destination = "10.88.128.24:27003";
        }
        {
          sourcePort = 27020;
          proto = "tcp";
          destination = "10.88.128.24:27020";
        }
        {
          sourcePort = 27021;
          proto = "tcp";
          destination = "10.88.128.24:27021";
        }*/
      ];
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
      # Addressable range
      dhcp-range = [ "enp3s0,10.88.128.128,10.88.128.254,24h" ];
      # Static hosts
      dhcp-host = [
        "f8:32:e4:b9:77:0b,DataStorage,10.88.128.3,infinite"
        "b8:27:eb:7f:f0:38,printcontroller,10.88.128.10,infinite"
        "10:0b:a9:7e:cc:8c,terminal-zero,10.88.128.20,infinite"
        "f0:de:f1:c7:fe:30,terminal-zero,10.88.128.21,infinite"
        "dc:85:de:86:a8:77,terminal-nx-01,10.88.128.22,infinite"
        "70:54:d2:17:d1:c4,terminal-nx-01,10.88.128.23,infinite"
        "52:54:00:e9:4a:af,LINDA-WM,10.88.128.24,infinite"
        "18:c0:4d:8d:53:6c,LINDACORE,10.88.128.87,infinite"
        "18:c0:4d:8d:53:6d,LINDACORE,10.88.128.88,infinite"
        "18:26:49:c5:48:24,LINDACORE,10.88.128.89,infinite"
      ];
      interface = "enp3s0";

      # local domains
      local = "/local/";
      domain = "local";
      expand-hosts = true;

      no-hosts = true;
      address = [
        "/${config.networking.hostName}.local/10.88.128.1"
        "/cortex-alpha.johnbargman.net/10.88.128.1"
        "/ap.local/10.88.128.1"
        "/minio.local/10.88.128.1"
      ];
    };
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?

}

