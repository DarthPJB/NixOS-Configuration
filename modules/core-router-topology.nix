# modules/core-router-topology.nix
# Topology-driven configuration using new generators
{ config
, lib
, pkgs
, self
, ...
}:

let
  # Import topology (all machines)
  topology = import ../topology.nix { inherit lib; };

  # Compute settings for all services
  wireguardSettings = (import ../lib/topology/mkWireguardSettings.nix { inherit lib; }) topology;
  nginxSettings = (import ../lib/topology/mkNginxSettings.nix { inherit lib; }) topology;
  firewallSettings = (import ../lib/topology/mkFirewallSettings.nix { inherit lib; }) topology;
  dnsSettings = (import ../lib/topology/mkDnsSettings.nix { inherit lib; }) topology;

  # Generate configs for current machine
  hostname = config.networking.hostName;
  wireguardConfig = (import ../lib/topology/genWireguard.nix { inherit lib; }) wireguardSettings hostname;
  nginxConfig = (import ../lib/topology/genNginx.nix { inherit lib; }) nginxSettings hostname;
  firewallConfig = (import ../lib/topology/genFirewall.nix { inherit lib; }) firewallSettings hostname;
  dnsConfig = (import ../lib/topology/genDns.nix { inherit lib; }) dnsSettings hostname;

  # Collect all warnings and errors
  allWarnings = wireguardSettings.warnings ++ nginxSettings.warnings ++ dnsSettings.warnings;
  allErrors = wireguardSettings.errors ++ nginxSettings.errors ++ firewallSettings.errors ++ dnsSettings.errors;

  # Is this machine the hub?
  isHub = hostname == wireguardSettings.hubName;
in
{
  options.coreRouterTopology.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable topology-driven configuration using new generators";
  };

  config = lib.mkMerge [
    # Assertions for validation
    {
      assertions = [
        {
          assertion = config.coreRouterTopology.enable -> (builtins.elem hostname (builtins.attrNames wireguardSettings.machines));
          message = "Machine ${hostname} not found in WireGuard topology";
        }
      ] ++ builtins.map
        (warning: {
          assertion = false;
          message = "Topology warning: ${warning}";
        })
        allWarnings ++ builtins.map
        (error: {
          assertion = false;
          message = "Topology validation error: ${error}";
        })
        allErrors;
    }

    # WireGuard configuration (hub and client)
    (lib.mkIf (config.coreRouterTopology.enable && wireguardSettings.machines ? ${hostname}) {
      networking.wireguard.enable = true;
      networking.wireguard.interfaces = lib.mkOverride 100 wireguardConfig.networking.wireguard.interfaces;
      # Set private key via secrix
      secrix.services.wireguard-wireg0.secrets.${hostname}.encrypted.file =
        ../../secrets/private_keys/wireguard/wg_${hostname};
      networking.wireguard.interfaces.wireg0.privateKeyFile =
        config.secrix.services.wireguard-wireg0.secrets.${hostname}.decrypted.path;
    })

    # Nginx configuration (hub only)
    (lib.mkIf (config.coreRouterTopology.enable && isHub) {
      services.nginx = lib.mkOverride 100 nginxConfig.services.nginx;
      # Ensure nginx can read ACME certificates
      users.users.nginx.extraGroups = [ "acme" ];
    })

    # Firewall configuration
    (lib.mkIf config.coreRouterTopology.enable {
      networking.firewall = lib.mkOverride 100 firewallConfig.networking.firewall;
    })

    # DNS/DHCP configuration (hub only)
    (lib.mkIf (config.coreRouterTopology.enable && isHub) {
      services.dnsmasq = lib.mkOverride 100 dnsConfig.services.dnsmasq;
    })

    # UDP GRO service for Tailscale (hub only, assuming cortex-alpha has it)
    (lib.mkIf (config.coreRouterTopology.enable && isHub && hostname == "cortex-alpha") {
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
  ];
}
