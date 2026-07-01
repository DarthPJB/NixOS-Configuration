# modules/smart-monitoring.nix
# SMART disk health monitoring with Prometheus exporter
# Import in configuration.nix for fleet-wide deployment
{ config, lib, pkgs, ... }:
{
  # Enable smartmontools for disk health monitoring
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      mail.enable = false;
      wall.enable = true;
    };
  };

  # Prometheus exporter for SMART metrics
  # Port allocation: 3100=node, 3101=dnsmasq/grafana, 3102=zfs, 3103=nvidia, 3104=klipper, 3105-3106=remote-worker
  services.prometheus.exporters.smartctl = {
    enable = true;
    port = 3107;
    openFirewall = false;
  };

  # Open port on WireGuard interface
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [
    config.services.prometheus.exporters.smartctl.port
  ];
}
