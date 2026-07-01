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
  services.prometheus.exporters.smartctl = {
    enable = true;
    port = 3102;
    openFirewall = false;
  };

  # Open port on WireGuard interface
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [
    config.services.prometheus.exporters.smartctl.port
  ];
}
