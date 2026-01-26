{ self, peerList ? {} }:
let
  wg-peer = name: postfix:
  {
    publicKey = builtins.readFile "${self}/secrets/wiregaurd/wg_${name}_pub";
    allowedIPs = [ "10.88.127.${postfix}/32" ];
  };
in
builtins.attrValues (builtins.mapAttrs wg-peer peerList)
