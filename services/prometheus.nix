{ fqdn, listen-addr }:
{ pkgs
, config
, lib
, self
, ...
}:
let
  inherit fqdn listen-addr;
  inherit (builtins) attrNames head filter;
  inherit (lib.strings) concatStringsSep;
  prometheus-dn = "prometheus.${fqdn}";
  graphana-dn = "grafana.${fqdn}";

  # Import topology registry to generate scrape targets
  registry = import ../lib/topology/mkRegistry.nix { inherit lib; };
  topology = registry.hosts;

  # Derive IP from a coordinate entry (subnet + peer_id)
  coordToIp = coord:
    let
      parts = lib.splitString "/" coord.subnet;
      networkIp = head parts;
      octets = lib.splitString "." networkIp;
      prefix = lib.concatStringsSep "." (lib.init octets);
    in
    "${prefix}.${toString coord.peer_id}";

  # Extract WG IP from a host entry
  getWgIp = host:
    let
      wgCoords = filter (c: c.plane_name == "wg") (host.coordinate or [ ]);
    in
    if wgCoords != [ ] then coordToIp (head wgCoords) else null;

  # Filter to hosts with WG coordinates and build deployment targets
  wgHosts = lib.filterAttrs (_name: host: getWgIp host != null) topology;
  deploymentExporterPort = toString config.services.nixos-deployment-exporter.port;
  deploymentTargets = map
    (name: "${getWgIp topology.${name}}:${deploymentExporterPort}")
    (attrNames wgHosts);
in
{
  # TODO: with convergence style, automate scraper addition.
  services.prometheus = {
    enable = true;
    listenAddress = "${listen-addr}";
    port = 8080;
    retentionTime = "0d";
    globalConfig.scrape_interval = "30s";
    scrapeConfigs = [
      {
        job_name = "postgres";
        scrape_interval = "10s";
        static_configs = [
          {
            targets = [
              "${config.services.prometheus.exporters.postgres.listenAddress}:${toString config.services.prometheus.exporters.postgres.port}"
            ];
          }
        ];
      }
      {
        job_name = "nvidia";
        scrape_interval = "5s";
        static_configs = [
          {
            labels = {
              hostname = config.networking.hostName;
              #terminal ghost is fun
              wgip = concatStringsSep "," config.networking.wireguard.interfaces.wireg0.ips;
            };
            targets = [
              "10.88.127.88:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.nvidia-gpu.port}"
              "10.88.127.107:${toString self.nixosConfigurations.alpha-three.config.services.prometheus.exporters.nvidia-gpu.port}"
              "10.88.127.108:${toString self.nixosConfigurations.alpha-one.config.services.prometheus.exporters.nvidia-gpu.port}"
              "10.88.127.21:${toString self.nixosConfigurations.terminal-nx-01.config.services.prometheus.exporters.nvidia-gpu.port}"
            ];
          }
        ];
      }
      {
        scrape_interval = "15s";
        job_name = "klipper";
        static_configs = [
          {
            targets = [
              "10.88.127.30:${toString self.nixosConfigurations.print-controller.config.services.prometheus.exporters.klipper.port}"
            ];
          }
        ];
      }
      {
        job_name = "dnsmasq";
        static_configs = [
          {
            targets = [
              "10.88.127.1:${toString self.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.dnsmasq.port}"
            ];
          }
        ];
      }
      {
        job_name = "node";
        scrape_interval = "30s";
        static_configs = [
          {
            targets = [
              "10.88.127.3:${toString self.nixosConfigurations.local-nas.config.services.prometheus.exporters.node.port}"
              "10.88.127.1:${toString self.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.node.port}"
              "10.88.127.20:${toString self.nixosConfigurations.terminal-zero.config.services.prometheus.exporters.node.port}"
              "10.88.127.21:${toString self.nixosConfigurations.terminal-nx-01.config.services.prometheus.exporters.node.port}"
              "10.88.127.30:${toString self.nixosConfigurations.print-controller.config.services.prometheus.exporters.node.port}"
              # display-0 moved to dormantConfigurations
              "10.88.127.50:${toString self.nixosConfigurations.remote-worker.config.services.prometheus.exporters.node.port}"
              "10.88.127.51:${toString self.nixosConfigurations.remote-builder.config.services.prometheus.exporters.node.port}"
              "10.88.127.52:${toString self.nixosConfigurations.gaming-host-1.config.services.prometheus.exporters.node.port}"
              "10.88.127.88:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.node.port}"
              "10.88.127.41:${toString self.nixosConfigurations.display-1.config.services.prometheus.exporters.node.port}"
              "10.88.127.42:${toString self.nixosConfigurations.display-2.config.services.prometheus.exporters.node.port}"
              "10.88.127.43:${toString self.nixosConfigurations.arm-builder.config.services.prometheus.exporters.node.port}"
              "10.88.127.108:${toString self.nixosConfigurations.alpha-one.config.services.prometheus.exporters.node.port}"
              "10.88.127.107:${toString self.nixosConfigurations.alpha-three.config.services.prometheus.exporters.node.port}"
              # display-0 dormant
            ];
          }
        ];
      }
      {
        job_name = "zfs";
        static_configs = [
          {
            targets = [
              "10.88.127.3:${toString self.nixosConfigurations.local-nas.config.services.prometheus.exporters.zfs.port}"
              "10.88.127.1:${toString self.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.zfs.port}"
              "10.88.127.51:${toString self.nixosConfigurations.remote-builder.config.services.prometheus.exporters.zfs.port}"
              "10.88.127.88:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.zfs.port}"
            ];
          }
        ];
      }
      {
        job_name = "nginx";
        static_configs = [
          {
            targets = [
              "10.88.127.50:${toString self.nixosConfigurations.remote-worker.config.services.prometheus.exporters.nginx.port}"
            ];
          }
        ];
      }
      {
        job_name = "nextcloud";
        static_configs = [
          {
            targets = [
              "10.88.127.50:${toString self.nixosConfigurations.remote-worker.config.services.prometheus.exporters.nextcloud.port}"
            ];
          }
        ];
      }
      {
        job_name = "nixos-deployment";
        scrape_interval = "5m";
        static_configs = [
          {
            targets = deploymentTargets;
          }
        ];
      }
      {
        job_name = "smartctl";
        scrape_interval = "60s";
        static_configs = [
          {
            targets = [
              "10.88.127.3:${toString self.nixosConfigurations.local-nas.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.1:${toString self.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.88:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.52:${toString self.nixosConfigurations.gaming-host-1.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.50:${toString self.nixosConfigurations.remote-worker.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.51:${toString self.nixosConfigurations.remote-builder.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.20:${toString self.nixosConfigurations.terminal-zero.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.21:${toString self.nixosConfigurations.terminal-nx-01.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.108:${toString self.nixosConfigurations.alpha-one.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.107:${toString self.nixosConfigurations.alpha-three.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.30:${toString self.nixosConfigurations.print-controller.config.services.prometheus.exporters.smartctl.port}"
              # display-0 moved to dormantConfigurations
              "10.88.127.41:${toString self.nixosConfigurations.display-1.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.42:${toString self.nixosConfigurations.display-2.config.services.prometheus.exporters.smartctl.port}"
              "10.88.127.43:${toString self.nixosConfigurations.arm-builder.config.services.prometheus.exporters.smartctl.port}"
              # display-0 dormant; arm-builder: smartctl not yet configured (USB-NVMe)
            ];
          }
        ];
      }
      # Malayalam (cluster-box) — CUDA inference machine, 4x Quadro M4000
      # Source: /speed-storage/bargman-tech/Malayalam/
      {
        job_name = "malayalam-node";
        scrape_interval = "30s";
        static_configs = [
          {
            labels = {
              hostname = "cluster-box";
              role = "cuda-inference";
            };
            targets = [
              "10.88.127.211:3100"
            ];
          }
        ];
      }
      {
        job_name = "malayalam-nvidia";
        scrape_interval = "10s";
        static_configs = [
          {
            labels = {
              hostname = "cluster-box";
              role = "cuda-inference";
            };
            targets = [
              "10.88.127.211:3103"
            ];
          }
        ];
      }
      # hyperhyper — CI build machine (100+ cores, 1TB RAM)
      # Source: /speed-storage/repo/platonic.systems/infrastructure-2/
      # Exporters rebound to Tailscale IP for cross-network scraping
      {
        job_name = "hyperhyper-node";
        scrape_interval = "30s";
        static_configs = [
          {
            labels = {
              hostname = "hyperhyper";
              role = "ci-builder";
            };
            targets = [
              "100.107.101.14:9100"
            ];
          }
        ];
      }
      {
        job_name = "hyperhyper-systemd";
        scrape_interval = "15s";
        static_configs = [
          {
            labels = {
              hostname = "hyperhyper";
              role = "ci-builder";
            };
            targets = [
              "100.107.101.14:9558"
            ];
          }
        ];
      }
      {
        job_name = "hyperhyper-zfs";
        scrape_interval = "30s";
        static_configs = [
          {
            labels = {
              hostname = "hyperhyper";
              role = "ci-builder";
            };
            targets = [
              "100.107.101.14:9134"
            ];
          }
        ];
      }
    ];
    webExternalUrl = "https://${prometheus-dn}";
  };

  # Grafana secret_key — encrypted via secrix, decrypted at runtime
  secrix.system.secrets.grafana_secret_key = {
    encrypted.file = ../secrets/grafana_secret_key;
    decrypted = {
      user = "grafana";
      group = "grafana";
      mode = "0400";
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      # secret_key is required since nixpkgs 26.05 — no default provided.
      # Uses Grafana's file:// provider to read from secrix-managed secret.
      security.secret_key = "file://${config.secrix.system.secrets.grafana_secret_key.decrypted.path}";
      server = {
        protocol = "http";
        http_addr = "10.88.127.3";
        http_port = 3101;
        enable_gzip = true;
        domain = "${graphana-dn}";
      };
      analytics.reporting_enabled = false;
    };
    provision = {
      enable = true;
      dashboards.settings.providers = [
        {
          name = "default";
          type = "file";
          updateIntervalSeconds = 300; # 5m — standard poll duration
          allowUiUpdates = false;
          disableDeletion = false;
          options = {
            path = ./graphana_dashboards;
            foldersFromFilesStructure = true;
          };
        }
      ];
      datasources.settings = {
        apiVersion = 1;
        prune = true;
        datasources = [
          {
            name = "prometheus";
            type = "prometheus";
            uid = "prometheus01";
            access = "proxy";
            editable = false;
            url = config.services.prometheus.webExternalUrl;
          }
        ];
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    config.services.prometheus.port
    config.services.grafana.settings.server.http_port
  ];
}
