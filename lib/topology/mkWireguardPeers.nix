{ topology }:

let
  # Helper function to extract the list of peers from topology
  mkPeerList = topology: builtins.map (peer: {
    inherit (peer) allowedIPs publicKey;
  }) topology.wireguard.peers;

  # Main function to create WireGuard interface configuration
  mkWireguardPeers = { topology }: {
    ips = topology.wireguard.ips;
    listenPort = topology.wireguard.listenPort;
    peers = mkPeerList topology;
  };
in
{
  inherit mkPeerList mkWireguardPeers;
}