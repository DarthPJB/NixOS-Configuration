{ fqdn, listen-addr }:
{ pkgs
, config
, lib
, self
, ...
}:
let
  inherit fqdn listen-addr;
  inherit (builtins) toJSON attrNames;
  inherit (pkgs) writeText;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatStringsSep;
  prometheus-dn = "prometheus.${fqdn}";
  graphana-dn = "grafana.${fqdn}";

  # Import topology to generate scrape targets
  topology = import ../topology/shared.nix { inherit lib; };
  deploymentExporterPort = toString config.services.nixos-deployment-exporter.port;
  deploymentTargets = map
    (name: "${topology.${name}.wireguard}:${deploymentExporterPort}")
    (attrNames topology);
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
