# ------------------ CORTEX ALPHA -------------------
# this is my router gateway everything its bad plz look

# YEEEEEEEEEEE PAAAAINN :)
{ config, lib, pkgs, self, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      (import ../../services/acme_server.nix { fqdn = "johnbargman.net"; })
      ../../server_services/ldap.nix
      ../../configuration.nix
      ./hardware-configuration.nix
      ../../modifier_imports/zfs.nix
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
  security.acme = {
    defaults.email = "commander@johnbargman.net";
    certs."johnbargman.net" = {
      extraDomainNames = [ "*.johnbargman.net" ]; #johnbargman.com"];
    };
  };
  # - here is my ideal senario
  # each system will, spread throughout the day, ipferf each other system.
  # just a small burst, so A ->B C->E etc
  # > "the iperf3 exporter does this it looks like, it will run iperf on demand" ~ @chloe.kever
  services.prometheus.exporters.dnsmasq = {
    enable = true;
    listenAddress = "10.88.127.1";
    port = 3101;
    leasesPath = "/dev/null";
    dnsmasqListenAddress = "10.88.128.1:53";
  };
  services.nginx = {
    enable = true;
    virtualHosts = {
      "_" = {
        default = true;
        listenAddresses = [ "10.88.128.1" "10.88.127.1" "82.5.173.252" ];
        locations."/" = {
          return = "444"; # Close connection without response
        };
      };
      "johnbargman.net" = {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
        listenAddresses = [ "10.88.128.1" "10.88.127.1" "82.5.173.252" ];
        locations."/" = {
          root = ../../webroot;
          proxyWebsockets = false; # needed if you need to use websocket
        };
      };
      "cortex-alpha.johnbargman.net" = {
        useACMEHost = "johnbargman.net";
        forceSSL = true;
        listenAddresses = [ "10.88.128.1" "10.88.127.1" "82.5.173.252" ]; #TODO: handle this assignment in a fixed fashion 82.5.173.252
        locations."/" = {
          root = ../../webroot;
          #proxyWebsockets = false; # needed if you need to use websocket
        };
      };
      "print-controller.johnbargman.net" = {
        useACMEHost = "johnbargman.net";
        addSSL = true;
        listenAddresses = [ "10.88.128.1" "10.88.127.1" ];
        locations."~/" = {
          proxyPass = "http://10.88.127.30:80";
          extraConfig = ''
            proxy_set_header host $host;
            proxy_set_header x-real-ip $remote_addr;
            proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
            proxy_set_header x-forwarded-proto $scheme;
          '';
          proxyWebsockets = true; # needed if you need to use websocket
        };
      };
      "prometheus.johnbargman.net" = {
        useACMEHost = "johnbargman.net";
        addSSL = true;
        listenAddresses = [ "10.88.128.1" "10.88.127.1" ];
        locations."~/" = {
          proxyPass = "http://10.88.127.3:${builtins.toString self.nixosConfigurations.data-storage.config.services.prometheus.port}";
          extraConfig = ''
            proxy_set_header host $host;
            proxy_set_header x-real-ip $remote_addr;
            proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
            proxy_set_header x-forwarded-proto $scheme;
          '';
          proxyWebsockets = true; # needed if you need to use websocket
        };
      };
      "grafana.johnbargman.net" = {
        useACMEHost = "johnbargman.net";
        addSSL = true; # Senpai teaches this
        listenAddresses = [ "10.88.128.1" "10.88.127.1" ];
        locations."~/" = {
          proxyPass = "http://10.88.127.3:${builtins.toString self.nixosConfigurations.data-storage.config.services.grafana.settings.server.http_port}";
          extraConfig = ''
            proxy_set_header host $host;
            proxy_set_header x-real-ip $remote_addr;
            proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
            proxy_set_header x-forwarded-proto $scheme;
          '';
          proxyWebsockets = true; # needed if you need to use websocket
        };
      };
      "ap.johnbargman.net" = {
        useACMEHost = "johnbargman.net";
        addSSL = true;
        listenAddresses = [ "10.88.128.1" "10.88.127.1" ];
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
  # so i'm thinking a 'port proxy' mother of all modules
  #  - TODO: the dream here is that i can have a list of source -> destination - type
  # - and map over that, outputting nginx proxies, port forwards, or port proxies
  #  - The possibilitites here are truely beyond imagining. 
  #  > "I would just converge the config of each system and map that in the module" ~ @Chloe.kever

  # Set your time zone.
  time.timeZone = "Etc/UTC";
  secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file = ../../secrets/wiregaurd/wg_cortex-alpha;
  networking = {
    nat.enable = lib.mkForce false;
    nftables =
      {
        enable = true;
        ruleset =
          (import ../../lib/mkNftables.nix lib).mkNftables {
            enp2s0.tcp = [ 2208 27015 4549 ];
            enp2s0.udp = [ 17780 17781 17782 17783 17784 17785 27015 4175 4179 4171 ];
          };
      };
    wireguard = {
      enable = true;
      interfaces.wireg0 = {
        ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
        listenPort = 2108;
        privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
        peers = (import ../../lib/wg_peers.nix { inherit self; });
      };
    };
    hostName = "cortex-alpha";
    hostId = "c043a1fa";
    interfaces.enp3s0 = {
      useDHCP = lib.mkDefault false;
      ipv4.addresses = [{
        address = "10.88.128.1";
        prefixLength = 24;
      }];
    };
    interfaces.enp2s0 = {
      useDHCP = lib.mkDefault true;
    };
    firewall = {
      allowedTCPPorts = [ 22 1108 ];
      interfaces = {
        "wireg0".allowedUDPPorts = [ 1108 ];
        "wireg0".allowedTCPPorts = [ 443 config.services.prometheus.exporters.dnsmasq.port ];
        "enp3s0".allowedTCPPorts = [ 443 2208 ];
        "enp3s0".allowedUDPPorts = [ 1108 2108 67 53 ];
        "enp2s0".allowedTCPPorts = [ 2208 ];
        "enp2s0".allowedUDPPorts = [ 1108 443 2108 4549 4175 4179 4171 ];
      };
    };
  };
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "enp3s0";
      address = [
        "/git.johnbargman.net/10.88.128.1"
        "/${config.networking.hostName}.johnbargman.net/10.88.128.1"
        "/ap.johnbargman.net/10.88.128.1"
        "/prometheus.johnbargman.net/10.88.128.1"
        "/grafana.johnbargman.net/10.88.128.1"
        "/print-controller.johnbargman.net/10.88.128.1"
        "/minio.johnbargman.net/10.88.128.1"
      ];
      local = "/cortex-alpha/";
      domain = "cortex-alpha";
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      cache-size = 1000;
      server = [
        "208.67.220.220"
        "208.67.222.222"
        "1.0.0.1"
        "8.8.8.8"
      ];
      dhcp-range = [ "enp3s0,10.88.128.128,10.88.128.254,24h" ];
      dhcp-host = [
        "f8:32:e4:b9:77:0d,alpha-one,10.88.128.108,infinite"
        "f8:32:e4:b9:77:0b,data-storage,10.88.128.3,infinite"
        "b8:27:eb:7f:f0:38,print-controller,10.88.128.10,infinite"
        "10:0b:a9:7e:cc:8c,terminal-zero,10.88.128.20,infinite"
        "f0:de:f1:c7:fe:30,terminal-zero,10.88.128.21,infinite"
        "dc:85:de:86:a8:77,terminal-nx-01,10.88.128.22,infinite"
        "70:54:d2:17:d1:c4,terminal-nx-01,10.88.128.23,infinite"
        "52:54:00:e9:4a:af,LINDA-WM,10.88.128.24,infinite"
        "18:c0:4d:8d:53:6c,LINDACORE,10.88.128.87,infinite"
        "18:c0:4d:8d:53:6d,LINDACORE,10.88.128.88,infinite"
        "18:26:49:c5:48:24,LINDACORE,10.88.128.89,infinite"
      ];
    };
  };
}
