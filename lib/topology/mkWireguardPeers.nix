# lib/topology/mkWireguardPeers.nix
# Transforms topology wireguard config into NixOS wireguard interface config
{ lib, topology, self }:

let
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
    if ip == null then
      # Skip peers without IP (shouldn't happen, but handle gracefully)
      null
    else if !hasPublicKey then
      # Skip peers without public key file
      builtins.trace "WARNING: No public key found for WireGuard peer ${peerName}" null
    else
      {
        # Server-side peer config: only allow the peer's specific IP
        allowedIPs = [ "${ip}/32" ];
        # Read actual public key from file (same as original wg_peers.nix)
        publicKey = builtins.readFile publicKeyFile;
      }
  ) topology.wireguard.peers;

  # Filter out null entries
  validPeers = lib.filter (p: p != null) mkPeerList;

  # Deduplicate peers by first allowedIP while preserving order
  uniquePeers =
    let
      dedup =
        seen: peers:
        if peers == [ ] then
          [ ]
        else
          let
            h = builtins.head peers;
            t = builtins.tail peers;
            key = builtins.head h.allowedIPs;
          in
          if builtins.elem key seen then dedup seen t else [ h ] ++ dedup (seen ++ [ key ]) t;
    in
    dedup [ ] validPeers;

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
