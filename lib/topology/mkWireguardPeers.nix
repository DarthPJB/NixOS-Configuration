/*
Purpose: Transform topology wireguard config into NixOS wireguard interface config

Inputs:
- topology.wireguard.peers: list of peer names
- topology.lan.hosts: host definitions with IPs and other attributes
- secrets/public_keys/wireguard/wg_<name>_pub: public key files for each peer

Output: NixOS networking.wireguard.interfaces config
*/

# lib/topology/mkWireguardPeers.nix
# Transforms topology wireguard config into NixOS wireguard interface config
{ lib }:

topology:

self:

let
  utils = import ./utils.nix { inherit lib; };

  # Build peer list from host names in wireguard.peers
  # Each peer name is looked up in lan.hosts to get the WireGuard IP
  # Public keys are read from secrets/public_keys/wireguard/wg_<name>_pub
  mkPeerList = map (
    peerName:
    let
      host = topology.lan.hosts.${peerName} or null;
      # Use wireguardIp if available, otherwise use the host's IP
      ip =
        if host != null then
          (host.wireguardIp or host.ip or null)
        else
          null;
      # Read public key from secrets directory (same as original wg_peers.nix)
      publicKeyFile = "${self}/secrets/public_keys/wireguard/wg_${peerName}_pub";
      hasPublicKey = builtins.pathExists publicKeyFile;
    in
    if host == null then
      # TG-002: Fail loudly on missing host
      throw "WireGuard peer '${peerName}' not found in lan.hosts. Valid hosts: ${builtins.concatStringsSep ", " (builtins.attrNames topology.lan.hosts)}"
    else if ip == null then
      # TG-002: Fail loudly on missing IP
      throw "WireGuard peer '${peerName}' has no IP address (missing ip and wireguardIp fields)"
    else if !hasPublicKey then
      # TG-002: Fail loudly on missing public key
      throw "WireGuard peer '${peerName}' has no public key file at ${publicKeyFile}"
    else
      {
        # Server-side peer config: only allow the peer's specific IP
        allowedIPs = [ "${ip}/32" ];
        # Read actual public key from file (same as original wg_peers.nix)
        publicKey = builtins.readFile publicKeyFile;
      }
  ) topology.wireguard.peers;

  # Deduplicate peers by first allowedIP while preserving order
  uniquePeers = utils.dedupPreserveOrder (p: builtins.head p.allowedIPs) mkPeerList;

  # Main function to create WireGuard interface configuration
  mkWireguardPeers = {
    ips = topology.wireguard.ips;
    listenPort = topology.wireguard.listenPort;
    peers = uniquePeers;
  };
in
{
  inherit mkPeerList mkWireguardPeers;
}