# ------------------ CORTEX ALPHA -------------------
# this is my router gateway everything its bad plz look

# YEEEEEEEEEEE PAAAAINN :)
{ config, lib, pkgs, self, hostname, ... }:
let
  proxyConfigs = {
    "print-controller.johnbargman.net" = "http://10.88.127.30:80";
    "prometheus.johnbargman.net" = "http://10.88.127.3:${builtins.toString self.nixosConfigurations.local-nas.config.services.prometheus.port}";
    "grafana.johnbargman.net" = "http://10.88.127.3:${builtins.toString self.nixosConfigurations.local-nas.config.services.grafana.settings.server.http_port}";
    "ap.johnbargman.net" = "http://10.88.128.2:80";
  };
  peerList = {
    "alpha-one" = "108";
    "alpha-three" = "107";
    "cortex-alpha" = "1";
    "display-1" = "41";
    "display-2" = "42";
    "local-nas" = "3";
    "print-controller" = "30";
    "remote-builder" = "51";
    "remote-worker" = "50";
    "storage-array" = "4";
    "terminal-zero" = "20";
    "terminal-nx-01" = "21";
    "display-0" = "40";
    "LINDA" = "88";
    "dlyon" = "210";
    "cluster-box" = "211";
  };

  nftableAttrs = {
    enp2s0.tcp = [
      { port = 2208; dest = "10.88.127.3:22"; }
      { port = 27015; dest = "10.88.128.88:27015"; }
      { port = 4549; dest = "10.88.128.88:4549"; }
    ];
    enp2s0.udp = [
      { port = 17780; dest = "10.88.128.88:17780"; }
      { port = 17781; dest = "10.88.128.88:17781"; }
      { port = 17782; dest = "10.88.128.88:17782"; }
      { port = 17783; dest = "10.88.128.88:17783"; }
      { port = 17784; dest = "10.88.128.88:17784"; }
      { port = 17785; dest = "10.88.128.88:17785"; }
      { port = 27015; dest = "10.88.128.88:27015"; }
      { port = 2207; dest = "10.88.127.88:2207"; }
      { port = 4175; dest = "10.88.128.88:4175"; }
      { port = 4179; dest = "10.88.128.88:4179"; }
      { port = 4171; dest = "10.88.128.88:4171"; }
    ];
  };
  dhcpHosts = {
    "f8:32:e4:b9:77:0d" = { hostname = "alpha-one"; ip = "10.88.128.108"; lease = "infinite"; };
    "f8:32:e4:b9:77:0b" = { hostname = "local-nas"; ip = "10.88.128.3"; lease = "infinite"; };
    "b8:27:eb:7f:f0:38" = { hostname = "print-controller"; ip = "10.88.128.10"; lease = "infinite"; };
    "10:0b:a9:7e:cc:8c" = { hostname = "terminal-zero"; ip = "10.88.128.20"; lease = "infinite"; };
    "f0:de:f1:c7:fe:30" = { hostname = "terminal-zero"; ip = "10.88.128.21"; lease = "infinite"; };
    "dc:85:de:86:a8:77" = { hostname = "terminal-nx-01"; ip = "10.88.128.22"; lease = "infinite"; };
    "70:54:d2:17:d1:c4" = { hostname = "terminal-nx-01"; ip = "10.88.128.23"; lease = "infinite"; };
    "52:54:00:e9-4a:af" = { hostname = "LINDA-WM"; ip = "10.88.128.24"; lease = "infinite"; };
    "18:c0:4d:8d:53:6c" = { hostname = "LINDACORE"; ip = "10.88.128.87"; lease = "infinite"; };
    "18:c0:4d:8d:53:6d" = { hostname = "LINDACORE"; ip = "10.88.128.88"; lease = "infinite"; };
    "18:26:49:c5:48:24" = { hostname = "LINDACORE"; ip = "10.88.128.89"; lease = "infinite"; };
  };
  mkDhcpReservations = import ../../lib/mkDhcpReservations.nix { inherit dhcpHosts; };
  mkNftables = import ../../lib/mkNftables.nix { inherit lib nftableAttrs; };
  mkProxyPass = import ../../lib/mkProxyPass.nix { inherit proxyConfigs; };
  wgPeers = import ../../lib/wg_peers.nix { inherit self peerList; };
in

{
  imports =
    [
      #  ../../lib/network-interfaces.nix
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
    virtualHosts = mkProxyPass // {
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
    };
  };
  # so i'm thinking a 'port proxy' mother of all modules
  #  - TODO: the dream here is that i can have a list of source -> destination - type
  # - and map over that, outputting nginx proxies, port forwards, or port proxies
  #  - The possibilitites here are truely beyond imagining. 
  #  > "I would just converge the config of each system and map that in the module" ~ @Chloe.kever

  # Set your time zone.
  time.timeZone = "Etc/UTC";
  secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file = ../../secrets/private_keys/wireguard/wg_cortex-alpha;
  networking = {
    nat.enable = lib.mkForce false;
    nftables =
      {
        enable = true;
        ruleset = mkNftables;
      };
    wireguard = {
      enable = true;
      interfaces.wireg0 = {
        ips = [ "10.88.127.1/32" "10.88.127.0/24" ];
        listenPort = 2108;
        privateKeyFile = config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
        peers = wgPeers;
      };
    };
    #hostName = "cortex-alpha";
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
      dhcp-host = mkDhcpReservations;
    };
  };
}
