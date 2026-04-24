# modules/core-router.nix
# Consumes real-topology data and generates actual NixOS networking configuration
{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  # Import topology (pure data, no arguments needed beyond the function signature)
  topology = import ../real-topology/${config.networking.hostName}.nix { inherit lib self; };

  # Import transformation functions
  wireguardLib = (import ../lib/topology/mkWireguardPeers.nix) { inherit lib topology; };
  tailscaleLib = (import ../lib/topology/mkTailscaleConfig.nix) { inherit lib; } topology;
  dhcpDnsLib = (import ../lib/topology/mkDhcpDns.nix) { inherit lib; } topology;
  nginxLib = (import ../lib/topology/mkNginxProxies.nix) { inherit lib; };
in
{
  options.coreRouter.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable topology-driven core router configuration";
  };

  config = lib.mkMerge [
    # UDP GRO service (machine-specific, not topology-managed)
    # Note: ethtool package is added by the machine config, not here
    (lib.mkIf config.coreRouter.enable {
      systemd.services.tailscale-udp-gro = {
        description = "Enable UDP GRO forwarding for tailscale performance on enp2s0";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.ethtool}/bin/ethtool -K enp2s0 rx-udp-gro-forwarding on";
          RemainAfterExit = true;
        };
      };
    })

    # Topology-derived config (takes precedence over defaults via mkOverride 100)
    (lib.mkIf (config.coreRouter.enable && topology ? wireguard) {
      # Topology-managed: WireGuard VPN configuration
      networking.wireguard.enable = true;
      networking.wireguard.interfaces = lib.mkOverride 100 {
        ${topology.wireguard.interface} = wireguardLib.mkWireguardPeers;
      };
    })

    (lib.mkIf (config.coreRouter.enable && topology ? tailscale) {
      # Topology-managed: Tailscale VPN configuration
      # Set advertisedRoutes for locale/tailscale.nix to process
      networking.tailscale.advertisedRoutes = tailscaleLib.mkAdvertisedRoutes topology;
    })

    (lib.mkIf (config.coreRouter.enable && topology ? dns) {
      # Topology-managed: DNS/DHCP configuration
      services.dnsmasq = lib.mkOverride 100 {
        enable = true;
        settings = dhcpDnsLib.config;
      };
    })

    (lib.mkIf (config.coreRouter.enable && topology ? firewall) {
      # Topology-managed: Firewall configuration
      networking.firewall = lib.mkOverride 100 topology.firewall;
    })

    # Topology-managed: Nginx reverse proxy configuration
    # Uses ACME wildcard cert pattern from infrastructure-2
    # Note: topology proxies are added, inline config takes precedence for conflicts
    (lib.mkIf (config.coreRouter.enable && topology ? nginx && (topology.nginx.proxies or { }) != { }) {
      services.nginx.enable = lib.mkOverride 100 true;
      # Use mkMerge to combine topology proxies with inline config
      # Topology provides base, inline can override
      services.nginx.virtualHosts = lib.mkMerge [
        (nginxLib.mkAllProxies { inherit topology; })
      ];

      # Ensure nginx can read ACME certificates
      users.users.nginx.extraGroups = [ "acme" ];
    })
  ];
}
