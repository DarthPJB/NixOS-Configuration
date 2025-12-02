{ fqdn, listen-addr }: { pkgs, config, lib, ... }:
let
  inherit fqdn listen-addr;
  inherit (builtins) toJSON;
  inherit (pkgs) writeText;
  inherit (lib.modules) mkIf;

  prometheus-dn = "prometheus.${fqdn}";
  graphana-dn = "grafana.${fqdn}";
in
{
  services.prometheus = {
    enable = true;
    listenAddress = "${listen-addr}";
    port = 8080;
    globalConfig.scrape_interval = "5s";
    exporters.node = {
      enable = true;
      port = 3100;
      enabledCollectors = [
        "logind"
        "systemd"
      ];
      disabledCollectors = [ "textfile" ];
      openFirewall = true;
      firewallFilter = "-i br0 -p tcp -m tcp --dport 9100";
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [
              "localhost:${toString config.services.prometheus.exporters.node.port}"
            ];
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
    provision.datasources.settings.datasources = [{
      name = "prometheus";
      type = "prometheus";
      uid = "prometheus01";
      url = config.services.prometheus.webExternalUrl;
    }];
  };
  networking.firewall.allowedTCPPorts = [ config.services.prometheus.port config.services.grafana.settings.server.http_port ];
}
