# real-topology/cortex-alpha.nix
# This file represents the physical network reality for cortex-alpha.
# It is the single source of truth for all routing, addressing, and capabilities.
{ ... }:
{
  domain = "johnbargman.net";
  hostname = "cortex-alpha";

  lan = {
    subnet = "10.88.128.0/24";
    gateway = "10.88.128.1";
    interface = "enp3s0";
    wanInterface = "enp2s0";

    hosts = {
      lindacore-88 = {
        ip = "10.88.128.88";
        mac = "18:c0:4d:8d:53:6d";
        hostname = "LINDACORE";
        routing = {
          tailscale = true;
          wireguard = false;
        };
        services = [
          "gaming"
          "high-bandwidth"
        ];
      };

      nas = {
        ip = "10.88.128.3";
        mac = "f8:32:e4:b9:77:0b";
        hostname = "local-nas";
        wireguardIp = "10.88.127.3";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [
          "storage"
          "monitoring"
        ];
      };

      alpha-one = {
        ip = "10.88.128.108";
        mac = "f8:32:e4:b9:77:0d";
        hostname = "alpha-one";
        wireguardIp = "10.88.127.108";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      print-controller = {
        ip = "10.88.128.10";
        mac = "b8:27:eb:7f:f0:38";
        hostname = "print-controller";
        wireguardIp = "10.88.127.30";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ "printing" ];
      };

      terminal-zero-1 = {
        ip = "10.88.128.20";
        mac = "10:0b:a9:7e:cc:8c";
        hostname = "terminal-zero";
        wireguardIp = "10.88.127.20";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      terminal-zero-2 = {
        ip = "10.88.128.21";
        mac = "f0:de:f1:c7:fe:30";
        hostname = "terminal-zero";
        wireguardIp = "10.88.127.20";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      terminal-nx-01-1 = {
        ip = "10.88.128.22";
        mac = "dc:85:de:86:a8:77";
        hostname = "terminal-nx-01";
        wireguardIp = "10.88.127.21";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      terminal-nx-01-2 = {
        ip = "10.88.128.23";
        mac = "70:54:d2:17:d1:c4";
        hostname = "terminal-nx-01";
        wireguardIp = "10.88.127.21";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      linda-wm = {
        ip = "10.88.128.24";
        mac = "52:54:00:e9-4a:af";
        hostname = "LINDA-WM";
        routing = {
          tailscale = false;
          wireguard = false;
        };
        services = [ ];
      };

      lindacore-87 = {
        ip = "10.88.128.87";
        mac = "18:c0:4d:8d:53:6c";
        hostname = "LINDACORE";
        routing = {
          tailscale = false;
          wireguard = false;
        };
        services = [ ];
      };

      lindacore-89 = {
        ip = "10.88.128.89";
        mac = "18:26:49:c5:48:24";
        hostname = "LINDACORE";
        routing = {
          tailscale = false;
          wireguard = false;
        };
        services = [ ];
      };

      # WireGuard only hosts
      alpha-three = {
        ip = "10.88.127.107";
        hostname = "alpha-three";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      cortex-alpha = {
        ip = "10.88.127.1";
        hostname = "cortex-alpha";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [
          "router"
          "gateway"
        ];
      };

      display-1 = {
        ip = "10.88.127.41";
        hostname = "display-1";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      display-2 = {
        ip = "10.88.127.42";
        hostname = "display-2";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      local-nas = {
        ip = "10.88.127.3";
        hostname = "local-nas";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      print-controller-wg = {
        ip = "10.88.127.30";
        hostname = "print-controller";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      remote-builder = {
        ip = "10.88.127.51";
        hostname = "remote-builder";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      gaming-host-1 = {
        ip = "10.88.127.52";
        hostname = "gaming-host-1";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      remote-worker = {
        ip = "10.88.127.50";
        hostname = "remote-worker";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      storage-array = {
        ip = "10.88.127.4";
        hostname = "storage-array";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      terminal-zero = {
        ip = "10.88.127.20";
        hostname = "terminal-zero";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      terminal-nx-01 = {
        ip = "10.88.127.21";
        hostname = "terminal-nx-01";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      display-0 = {
        ip = "10.88.127.40";
        hostname = "display-0";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      LINDA = {
        ip = "10.88.127.88";
        hostname = "LINDA";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      dlyon = {
        ip = "10.88.127.210";
        hostname = "dlyon";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      grimterm = {
        ip = "10.88.127.212";
        hostname = "grimterm";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      cluster-box = {
        ip = "10.88.127.211";
        hostname = "cluster-box";
        routing = {
          tailscale = false;
          wireguard = true;
        };
        services = [ ];
      };

      # Add more hosts as reality expands
    };
  };

  forwarding = {
    tcp = [
      {
        from = "wan";
        port = 2208;
        to = "10.88.128.3:22";
      }
      {
        from = "wan";
        port = 27015;
        to = "10.88.128.88:27015";
      }
      {
        from = "wan";
        port = 4549;
        to = "10.88.128.88:4549";
      }
    ];
    udp = [
      {
        from = "wan";
        port = 17780;
        to = "10.88.128.88:17780";
      }
      {
        from = "wan";
        port = 17781;
        to = "10.88.128.88:17781";
      }
      {
        from = "wan";
        port = 17782;
        to = "10.88.128.88:17782";
      }
      {
        from = "wan";
        port = 17783;
        to = "10.88.128.88:17783";
      }
      {
        from = "wan";
        port = 17784;
        to = "10.88.128.88:17784";
      }
      {
        from = "wan";
        port = 17785;
        to = "10.88.128.88:17785";
      }
      {
        from = "wan";
        port = 27015;
        to = "10.88.128.88:27015";
      }
      {
        from = "wan";
        port = 2207;
        to = "10.88.127.88:2207";
      }
      {
        from = "wan";
        port = 4175;
        to = "10.88.128.88:4175";
      }
      {
        from = "wan";
        port = 4179;
        to = "10.88.128.88:4179";
      }
      {
        from = "wan";
        port = 4171;
        to = "10.88.128.88:4171";
      }
    ];
  };

  tailscale = {
    subnetRouter = true;
    advertisedHosts = [ "lindacore-88" ];
    advertisedRoutes = [
      "10.88.128.88/32"
      "10.88.128.248/32"
    ];
  };

  dns = {
    interface = "enp3s0";
    static = [
      {
        domain = "git.johnbargman.net";
        ip = "10.88.128.1";
      }
      {
        domain = "code.johnbargman.net";
        ip = "10.88.128.1";
      }
      {
        domain = "cortex-alpha.johnbargman.net";
        ip = "10.88.128.1";
      }
      {
        domain = "ap.johnbargman.net";
        ip = "10.88.128.1";
      }
      {
        domain = "prometheus.johnbargman.net";
        ip = "10.88.128.1";
      }
      {
        domain = "grafana.johnbargman.net";
        ip = "10.88.128.1";
      }
      {
        domain = "print-controller.johnbargman.net";
        ip = "10.88.128.1";
      }
      {
        domain = "minio.johnbargman.net";
        ip = "10.88.128.1";
      }
    ];
    dhcp = {
      range = "10.88.128.128,10.88.128.254,24h";
      interface = "enp3s0";
    };
    servers = [
      "208.67.220.220"
      "208.67.222.222"
      "1.0.0.1"
      "8.8.8.8"
    ];
  };

  nginx = {
    # ACME configuration - uses wildcard cert for johnbargman.net
    acmeHost = "johnbargman.net";
    listenAddresses = [
      "10.88.128.1"  # LAN gateway
      "10.88.127.1"  # WireGuard IP
    ];

    # Proxy definitions with full configuration
    # Pattern inspired by infrastructure-2/modules/proxy-host.nix
    proxies = {
      "print-controller.johnbargman.net" = {
        backend = "http://10.88.127.30:80";
        forceSSL = false;
        websockets = true;
      };
      "code.johnbargman.net" = {
        backend = "http://10.88.127.3:80";
        forceSSL = false;
        websockets = true;
      };
      "git.johnbargman.net" = {
        backend = "http://10.88.127.3:80";
        forceSSL = false;
        websockets = true;
      };
      "prometheus.johnbargman.net" = {
        backend = "http://10.88.127.3:8080";
        forceSSL = false;
        websockets = true;
      };
      "grafana.johnbargman.net" = {
        backend = "http://10.88.127.3:3101";
        forceSSL = false;
        websockets = true;
      };
      "ap.johnbargman.net" = {
        backend = "http://10.88.128.2:80";
        forceSSL = false;
        websockets = true;
      };
    };
  };

  wireguard = {
    interface = "wireg0";
    ips = [
      "10.88.127.1/32"
      "10.88.127.0/24"
    ];
    listenPort = 2108;
    peers = [
      # Order matches original peer list for golden test compatibility
      # Names must match secrets/public_keys/wireguard/wg_<name>_pub files
      "LINDA"
      "alpha-one"
      "alpha-three"
      "cluster-box"
      "cortex-alpha"
      "display-0"
      "display-1"
      "display-2"
      "dlyon"
      "gaming-host-1"
      "grimterm"
      "local-nas"
      "print-controller"
      "remote-builder"
      "remote-worker"
      "storage-array"
      "terminal-nx-01"
      "terminal-zero"
    ];
  };

  firewall = {
    allowedTCPPorts = [
      22
      636
      1108
    ];
    allowedUDPPorts = [ ];
    interfaces = {
      wireg0 = {
        allowedUDPPorts = [ 1108 ];
        allowedTCPPorts = [
          443
          3100
          3101
          3102
        ];
      };
      enp3s0 = {
        allowedTCPPorts = [
          443
          2208
        ];
        allowedUDPPorts = [
          1108
          2108
          67
          53
        ];
      };
      enp2s0 = {
        allowedTCPPorts = [ 2208 ];
        allowedUDPPorts = [
          1108
          443
          2108
          4549
          4175
          4179
          4171
          41641
        ];
      };
    };
  };
}