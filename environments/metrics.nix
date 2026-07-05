# environments/metrics.nix
# Shared Prometheus metrics exporters for all machines.
# Import from configuration.nix (fleet-wide) or individual machine configs
# (e.g., arm-builder which blocks configuration.nix via disabledModules).
#
# Port allocation (standardised across fleet):
#   9100 — node_exporter (system metrics)
#   3107 — smartctl_exporter (disk SMART data)
#
{ config, lib, ... }:
{
  # Node exporter — CPU, memory, disk, network, systemd
  services.prometheus.exporters.node = {
    enable = lib.mkDefault true;
    port = lib.mkDefault 9100;
    enabledCollectors = lib.mkDefault [
      "systemd"
      "hwmon"
      "cpu"
      "drm"
      "ethtool"
      "logind"
      "wifi"
      "diskstats"
      "meminfo"
      "loadavg"
      "filesystem"
    ];
    disabledCollectors = lib.mkDefault [ "textfile" ];
  };

  # Smartctl exporter — disk health, temperature, wear (USB-NVMe, SATA, NVMe)
  services.prometheus.exporters.smartctl = {
    enable = lib.mkDefault true;
    port = lib.mkDefault 3107;
    openFirewall = lib.mkDefault false; # opened per-interface below
  };

  # SMART monitoring daemon
  services.smartd = {
    enable = lib.mkDefault true;
    autodetect = lib.mkDefault true;
    notifications = {
      mail.enable = lib.mkDefault false;
      wall.enable = lib.mkDefault true;
    };
  };

  # Open exporter ports on WireGuard interface
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
    config.services.prometheus.exporters.smartctl.port
  ];
}
