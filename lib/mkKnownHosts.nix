{ lib }:

let
  mkKnownHosts = { peerList, extraKnownHosts ? { } }:
    let
      knownFromPeers =
        lib.filterAttrs (_: v: v != { })
          (lib.mapAttrs
            (name: num:
              let
                pubKeyPath = ../secrets/ssh/public_key/${name}.pub;
              in
              if builtins.pathExists pubKeyPath then {
                hostNames = [ name "10.88.127.${num}" "10.88.128.${num}" ];
                publicKey = builtins.readFile pubKeyPath;
              } else { }
            )
            peerList);
    in
    knownFromPeers // extraKnownHosts;
in
mkKnownHosts;
