# modules/core-router-topology.nix
# Topology-driven configuration using WIP two-layer architecture (transformers -> generators).
#
# Architecture:
#   - WireGuard (hub): uses production mkWireguardPeers.nix (reads explicit peer list from per-machine file)
#   - WireGuard (clients): uses WIP mkWireguardSettings.nix via enable-wg-topology.nix (not this module)
#   - DNS/Firewall/Nginx: uses WIP transformers + generators from per-machine topology
#   - Forwarding/Tailscale/Monitoring: uses production transformers directly (no WIP pair needed)
#
# Must produce byte-identical golden output to modules/core-router.nix (production path).
{ config
, lib
, pkgs
, self
, ...
}:

let
  hostname = config.networking.hostName;

  # --- Per-machine topology: read from registry (new) or .nix file (legacy) ---
  machineTopology =
    if (config.topology.useNewPipeline or false) then
      let
        registry = import ../lib/topology/mkRegistry.nix { inherit lib self; };
      in
        registry.hosts.${hostname} or { }
    else
      import ../topology/${hostname}.nix { inherit lib self; };

  # Wrap per-machine topology for transformer iteration pattern: { ${hostname} = topology; }
  perMachineTopology = { ${hostname} = machineTopology; };

  # --- Validation (same as production core-router.nix) ---
  validator = import ../lib/topology/validate.nix { inherit lib; };
  validation = validator.validateTopology machineTopology;
  crossValidation = validator.validateCrossReferences machineTopology;

  # --- WireGuard (production path — reads explicit peer list from per-machine file) ---
  wireguardLib = (import ../lib/topology/mkWireguardPeers.nix) { inherit lib; } machineTopology self;

  # --- WIP transformers (from per-machine topology) ---
  dnsSettings = (import ../lib/topology/mkDnsSettings.nix { inherit lib; }) perMachineTopology;
  firewallSettings = (import ../lib/topology/mkFirewallSettings.nix { inherit lib; }) perMachineTopology;
  nginxSettings = (import ../lib/topology/mkNginxSettings.nix { inherit lib; }) perMachineTopology;

  # --- WIP generators (settings + hostname -> NixOS config) ---
  dnsConfig = (import ../lib/topology/genDns.nix { inherit lib; }) dnsSettings hostname;
  firewallConfig = (import ../lib/topology/genFirewall.nix { inherit lib; }) firewallSettings hostname;
  nginxConfig = (import ../lib/topology/genNginx.nix { inherit lib; }) nginxSettings hostname;

  # --- Production transformers (used directly — no WIP pair needed) ---
  tailscaleLib = (import ../lib/topology/mkTailscaleConfig.nix { inherit lib; }) machineTopology;
  forwardingLib = (import ../lib/topology/mkForwarding.nix { inherit lib; }) machineTopology;
  monitoringLib = (import ../lib/topology/mkMonitoringSettings.nix { inherit lib; }) machineTopology;

  # --- Collect all warnings and errors ---
  allWarnings =
    (lib.optionals (validation.warnings != [ ]) (map (w: "topology: ${w}") validation.warnings))
    ++ (lib.optionals (crossValidation.warnings != [ ]) (map (w: "cross-ref: ${w}") crossValidation.warnings))
    ++ nginxSettings.warnings
    ++ dnsSettings.warnings;
  allErrors =
    (lib.optionals (!validation.valid) [ "Invalid topology: ${builtins.concatStringsSep "; " validation.errors}" ])
    ++ (lib.optionals (!crossValidation.valid) [ "Cross-ref failed: ${builtins.concatStringsSep "; " crossValidation.errors}" ])
    ++ nginxSettings.errors
    ++ firewallSettings.errors
    ++ dnsSettings.errors;
in
{
  options = {
    topology = {
      useNewPipeline = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "When true, the registry (lib/topology/mkRegistry.nix) is the source of truth for machine topology. When false, the original .nix file in topology/ is used. Default is false (legacy).";
      };
    };
    coreRouterTopology = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable topology-driven configuration using WIP two-layer generators";
      };
    };
  };

  config = lib.mkMerge [
    # --- Validation assertions (match production core-router.nix) ---
    {
      assertions = [
        {
          assertion = config.coreRouterTopology.enable -> validation.valid;
          message = "Invalid topology for ${hostname}: ${builtins.concatStringsSep "; " validation.errors}";
        }
        {
          assertion = config.coreRouterTopology.enable -> crossValidation.valid;
          message = "Cross-reference validation failed for ${hostname}: ${builtins.concatStringsSep "; " crossValidation.errors}";
        }
      ] ++ builtins.map
        (warning: {
          assertion = false;
          message = "Topology warning: ${warning}";
        })
        allWarnings
      ++ builtins.map
        (error: {
          assertion = false;
          message = "Topology validation error: ${error}";
        })
        allErrors;
    }

    # --- UDP GRO service (machine-specific, same as production) ---
    (lib.mkIf config.coreRouterTopology.enable {
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

    # --- WireGuard configuration (hub — production path, reads explicit peer list) ---
    # Note: privateKeyFile and secrix secrets are set in the machine's default.nix
    (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? wireguard) {
      networking.wireguard.enable = true;
      networking.wireguard.interfaces = lib.mkOverride 100 {
        ${machineTopology.wireguard.interface} = wireguardLib.mkWireguardPeers;
      };
    })

    # --- Tailscale configuration ---
    (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? tailscale) {
      services.tailscale = lib.mkOverride 100 tailscaleLib.config;
      networking.tailscale.advertisedRoutes = tailscaleLib.mkAdvertisedRoutes;
    })

    # --- DNS/DHCP configuration ---
    (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? dns) {
      services.dnsmasq = lib.mkOverride 100 dnsConfig.services.dnsmasq;
    })

    # --- Firewall configuration ---
    (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? firewall) {
      networking.firewall = lib.mkOverride 100 firewallConfig.networking.firewall;
    })

    # --- Port forwarding (nftables) ---
    (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? forwarding) {
      networking.nftables.enable = lib.mkOverride 100 true;
      networking.nftables.ruleset = lib.mkOverride 100 forwardingLib.nftablesRuleset;
    })

    # --- Nginx reverse proxy configuration (if proxies exist) ---
    (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? nginx && (machineTopology.nginx.proxies or { }) != { }) {
      services.nginx.enable = lib.mkOverride 100 true;
      services.nginx.virtualHosts = lib.mkOverride 100 nginxConfig.services.nginx.virtualHosts;
      # Ensure nginx can read ACME certificates
      users.users.nginx.extraGroups = [ "acme" ];
    })

    # --- Prometheus exporters configuration ---
    (lib.mkIf (config.coreRouterTopology.enable && machineTopology ? monitoring) {
      services.prometheus.exporters = lib.mkOverride 100 (monitoringLib.mkMonitoringConfig { });
    })
  ];
}
