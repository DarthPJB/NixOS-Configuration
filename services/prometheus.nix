{ fqdn, listen-addr }: { pkgs, config, lib, self, ... }:
let
  inherit fqdn listen-addr;
  inherit (builtins) toJSON;
  inherit (pkgs) writeText;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) concatStringsSep;
  prometheus-dn = "prometheus.${fqdn}";
  graphana-dn = "grafana.${fqdn}";
in
{
  # TODO: with convergence style, automate scraper addition.
  services.prometheus = {
    enable = true;
    listenAddress = "${listen-addr}";
    port = 8080;
    globalConfig.scrape_interval = "5s";
    scrapeConfigs = [
      {
        job_name = "nvidia";
        static_configs = [
          {
            labels = {
              hostname = config.networking.hostName;
              #terminal ghost is fun
              wgip = concatStringsSep "," config.networking.wireguard.interfaces.wireg0.ips;
            };
            targets = [
              "10.88.127.88:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.nvidia-gpu.port}"
              "10.88.127.107:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.nvidia-gpu.port}"
              "10.88.127.108:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.nvidia-gpu.port}"
              "10.88.127.21:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.nvidia-gpu.port}"
            ];
          }
        ];
      }
      {
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
            targets = [ "10.88.127.1:${toString self.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.dnsmasq.port}" ];
          }
        ];
      }
      {
        job_name = "node";
        static_configs = [
          {
            targets = [
              "10.88.127.3:${toString self.nixosConfigurations.data-storage.config.services.prometheus.exporters.node.port}"
              "10.88.127.1:${toString self.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.node.port}"
              "10.88.127.4:${toString self.nixosConfigurations.storage-array.config.services.prometheus.exporters.node.port}"
              "10.88.127.20:${toString self.nixosConfigurations.terminal-zero.config.services.prometheus.exporters.node.port}"
              "10.88.127.21:${toString self.nixosConfigurations.terminal-nx-01.config.services.prometheus.exporters.node.port}"
              "10.88.127.30:${toString self.nixosConfigurations.print-controller.config.services.prometheus.exporters.node.port}"
              "10.88.127.40:${toString self.nixosConfigurations.display-0.config.services.prometheus.exporters.node.port}"
              "10.88.127.50:${toString self.nixosConfigurations.remote-worker.config.services.prometheus.exporters.node.port}"
              "10.88.127.51:${toString self.nixosConfigurations.remote-builder.config.services.prometheus.exporters.node.port}"
              "10.88.127.88:${toString self.nixosConfigurations.LINDA.config.services.prometheus.exporters.node.port}"
              "10.88.127.41:${toString self.nixosConfigurations.display-1.config.services.prometheus.exporters.node.port}"
              "10.88.127.108:${toString self.nixosConfigurations.display-1.config.services.prometheus.exporters.node.port}"
              "10.88.127.107:${toString self.nixosConfigurations.display-1.config.services.prometheus.exporters.node.port}"
              "10.88.127.42:${toString self.nixosConfigurations.display-2.config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
      {
        job_name = "zfs";
        static_configs = [
          {
            targets = [
              "10.88.127.3:${toString self.nixosConfigurations.data-storage.config.services.prometheus.exporters.zfs.port}"
              "10.88.127.1:${toString self.nixosConfigurations.cortex-alpha.config.services.prometheus.exporters.zfs.port}"
              "10.88.127.4:${toString self.nixosConfigurations.storage-array.config.services.prometheus.exporters.zfs.port}"
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
            targets = [ "10.88.127.50:3105" ];
          }
        ];
      }
      {
        job_name = "nextcloud";
        static_configs = [
          {
            targets = [ "10.88.127.50:3106" ];
          }
        ];
      }
      {
        job_name = "minio";
        metrics_path = "/minio/v2/metrics/cluster";
        static_configs = [
          {
            targets = [ "10.88.127.3:2222" ];
          }
        ];
      }
    ];
    webExternalUrl = "https://${prometheus-dn}";
  };

  services.grafana = {

    enable = true;
    settings =
      {
        server =
          {
            protocol = "http";
            http_addr = "10.88.127.3";
            http_port = 3101;
            enable_gzip = true;
            domain = "${graphana-dn}";
          };
        analytics.reporting_enabled = false;
      };
    provision.dashboards.settings.providers = [{
      updateInterfalSeconds = 5;
      options = {
        path = ./graphana_dashboards;
        foldersFromFilesStructure = true;
      };
    }];
    provision.datasources.settings.datasources = [{
      name = "prometheus";
      type = "prometheus";
      uid = "prometheus01";
      url = config.services.prometheus.webExternalUrl;
    }];
  };
  networking.firewall.allowedTCPPorts = [ config.services.prometheus.port config.services.grafana.settings.server.http_port ];
}
