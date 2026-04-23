# lib/topology/mkWireguardPeers.nix
# Transforms topology wireguard config into NixOS wireguard interface config
{ lib, topology }:

let
  # Build peer list from host names in wireguard.peers
  # Each peer name is looked up in lan.hosts to get the WireGuard IP
  # Uses wireguardIp field if available, otherwise falls back to host IP
  # Public keys are expected to be in secrets/public_keys/wireguard/wg_<name>_pub
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
    in
    if ip == null then
      # Skip peers without IP (shouldn't happen, but handle gracefully)
      null
    else
      {
        # Server-side peer config: only allow the peer's specific IP
        allowedIPs = [ "${ip}/32" ];
        # Use a valid placeholder format for systemd unit names
        # Real public keys will be provided via secrix in production
        publicKey = "placeholder-${lib.replaceStrings [ "." ] [ "-" ] peerName}";
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
