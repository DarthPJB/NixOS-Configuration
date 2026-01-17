# WireGuard Peer Management Guide

## Adding Internal Peers
- Create encrypted private key in `secrets/wireguard/wg_<name>` via secrix.
- Generate and add public key file `secrets/wiregaurd/wg_<name>_pub` (plaintext, committed).
- Assign unique postfix (e.g., 10.88.127.X) in `lib/wg_peers.nix` attrset, e.g.:
  ```nix
  \"new-machine\" = \"X\";
  ```
- Peers auto-generated with publicKey and allowedIPs [ \"10.88.127.${postfix}/32\" ].
- Import in machine config: `peers = import ../../lib/wg_peers.nix { inherit self; };`.
- Cortex-alpha (postfix 1) excluded to avoid self-peer.

## Adding External Peers
- For point-to-point links (e.g., to cortex-alpha), add entry in `lib/wg_peers.nix` attrset with descriptive name and arbitrary postfix (e.g., 128+ for non-internal):
  ```nix
  \"External_Peer-acropolis\" = \"128\";
  ```
- Add corresponding public key file `secrets/wiregaurd/wg_External_Peer-acropolis_pub`.
- This generates peer with hardcoded /32 allowedIPs (10.88.127.128); override in cortex-alpha `default.nix` if needed (e.g., custom allowedIPs, endpoint, persistentKeepalive).
- No endpoint in generator (internal mesh assumption); add manually in interface config:
  ```nix
  peers = (import ../../lib/wg_peers.nix { inherit self; }) ++ [
    { publicKey = \"...\"; endpoint = \"EXTERNAL_IP:PORT\"; allowedIPs = [ \"EXTERNAL_SUBNET\" ]; persistentKeepalive = 25; }
  ];
  ```
- Firewall: Update `networking.firewall.interfaces.wireg0.allowedUDPPorts` for external port if !=2108.
- Secrets: External private key managed externally; only public key needed here.
- Validation: `nix flake check`; test deploy `nix run .#cortex-alpha`.

## Notes
- Dir typo: `wiregaurd` (fix to `wireguard` for consistency?).
- Centralized in `wg_peers.nix` for cortex-alpha hub; other machines may differ.
- Post-add: Rebuild/test connectivity (e.g., `wg show wireg0`; ping external IP).