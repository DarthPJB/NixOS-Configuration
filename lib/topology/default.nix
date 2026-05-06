# lib/topology/default.nix
# Topology transformation library entry point
#
# Individual transformation functions are in separate files:
#   mkWireguardPeers.nix  - WireGuard peer configuration
#   mkTailscaleConfig.nix - Tailscale subnet router config
#   mkDhcpDns.nix         - DNS/DHCP (dnsmasq) configuration
#   mkNginxProxies.nix    - Nginx reverse proxy configuration
#   mkForwarding.nix      - nftables DNAT/masquerade rules
#   validate.nix          - Topology structural validation
#   utils.nix             - Shared utility functions
#
# These are imported directly by modules/core-router.nix.
{ lib }:

{
  # Re-export all transformation functions for convenience
  mkWireguardPeers = import ./mkWireguardPeers.nix { inherit lib; };
  mkTailscaleConfig = import ./mkTailscaleConfig.nix { inherit lib; };
  mkDhcpDns = import ./mkDhcpDns.nix { inherit lib; };
  mkNginxProxies = import ./mkNginxProxies.nix { inherit lib; };
  mkForwarding = import ./mkForwarding.nix { inherit lib; };
  validate = import ./validate.nix { inherit lib; };
  utils = import ./utils.nix { inherit lib; };
}
