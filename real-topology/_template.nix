# Template for Topology-Driven Network Configuration
#
# Copy this file to real-topology/<machine-name>.nix and customize
# the values for your specific machine's network topology.
#
# This file defines the physical network reality for a machine,
# separate from NixOS configuration logic.

{ ... }:

{
  # Domain name for this network segment
  domain = "example.com"; # TODO: Replace with your domain

  # LAN (Local Area Network) configuration
  # This represents the primary internal network segment
  lan = {
    # Subnet in CIDR notation (e.g., "192.168.1.0/24")
    subnet = "10.0.0.0/24"; # TODO: Replace with actual subnet

    # Gateway IP address for this network
    gateway = "10.0.0.1"; # TODO: Replace with actual gateway

    # Host definitions for machines on this network
    hosts = {
      # Example host entry - copy and modify for each machine
      "machine-name" = {
        # Static IP address for this host
        ip = "10.0.0.XX"; # TODO: Replace with actual IP

        # MAC address of the network interface (optional but recommended)
        mac = "aa:bb:cc:dd:ee:ff"; # TODO: Replace with actual MAC

        # Routing features enabled for this host
        routing = {
          # Whether this host participates in Tailscale routing
          tailscale = false; # TODO: Set to true if using Tailscale

          # Whether this host has WireGuard interfaces
          wireguard = false; # TODO: Set to true if using WireGuard
        };
      };

      # Add more hosts as needed...
      # "another-host" = {
      #   ip = "10.0.0.YY";
      #   mac = "11:22:33:44:55:66";
      #   routing = {
      #     tailscale = true;
      #     wireguard = false;
      #   };
      # };
    };
  };

  # WAN (Wide Area Network) configuration (optional)
  # Use this for external network segments if needed
  # wan = {
  #   subnet = "203.0.113.0/24";  # TODO: Replace with actual WAN subnet
  #   gateway = "203.0.113.1";    # TODO: Replace with actual WAN gateway
  #
  #   hosts = {
  #     "external-host" = {
  #       ip = "203.0.113.XX";    # TODO: Replace with actual external IP
  #       mac = "aa:bb:cc:dd:ee:ff";  # TODO: Optional for WAN
  #       routing = {
  #         tailscale = false;
  #         wireguard = false;
  #       };
  #     };
  #   };
  # };

  # Additional network segments can be added as needed
  # (e.g., dmz, guest, iot networks)
}
