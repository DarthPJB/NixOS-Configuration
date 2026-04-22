# lib/topology/mkWireguardPeers.nix
# Transforms topology wireguard config into NixOS wireguard interface config
{ lib, topology }:

let
  # Build peer list from host names in wireguard.peers
  # Each peer name is looked up in lan.hosts to get the IP
  # Public keys are expected to be in secrets/public_keys/wireguard/wg_<name>_pub
  mkPeerList = map
    (peerName:
      let
        host = topology.lan.hosts.${peerName} or null;
        ip = if host != null then (host.ip or null) else null;
      in
      if ip == null then
      # Skip peers without IP (shouldn't happen, but handle gracefully)
        null
      else {
        allowedIPs = [ "${ip}/32" ] ++ (if lib.hasSuffix ".1" ip then [ "${lib.removeSuffix ".1" ip}.0/24" ] else [ ]);
        # Use a valid placeholder format for systemd unit names
        # Real public keys will be provided via secrix in production
        publicKey = "placeholder-${lib.replaceStrings ["."] ["-"] peerName}";
      }
    )
    topology.wireguard.peers;

  # Filter out null entries
  validPeers = lib.filter (p: p != null) mkPeerList;

  # Main function to create WireGuard interface configuration
  mkWireguardPeers = {
    ips = topology.wireguard.ips;
    listenPort = topology.wireguard.listenPort;
    peers = validPeers;
  };
in
{
  inherit mkPeerList mkWireguardPeers;
}
