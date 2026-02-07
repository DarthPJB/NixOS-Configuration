{ self, peerList ? { } }:
let
  wg-peer = name: postfix:
    {
      publicKey = builtins.readFile "${self}/secrets/public_keys/wireguard/wg_${name}_pub";
      allowedIPs = [ "10.88.127.${postfix}/32" ];
    };
in
builtins.attrValues (builtins.mapAttrs wg-peer peerList)
