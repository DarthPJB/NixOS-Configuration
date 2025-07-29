{ self }:
let
  wg-peer = name: postfix:
    {
      publicKey = builtins.readFile "${self}/secrets/wg_${name}_pub";
      allowedIPs = [ "10.88.127.${postfix}/32" ];
    };
in
builtins.attrValues (builtins.mapAttrs wg-peer {
  #  "cortex-alpha"    = "1";
  "local-nas" = "3";
  "storage-array" = "4";
  "terminal-zero" = "20";
  "terminal-nx-01" = "21";
  "print-controller" = "30";
  "display-module" = "40";
  "remote-worker" = "50"
  "remote-builder" = "51";
  "LINDA" = "88";
})
