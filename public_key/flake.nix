{
  inputs.keyFlake.url = "github:pinktrink/keyFlake.nix";
  outputs = { self, keyFlake, ... }:
    let
      inherit (keyFlake.lib) mkKeyFlake;
    in
    mkKeyFlake {
      "johnbargman.net" = {
        users.John88 = [ (builtins.readFile ./id_ed25519_master.pub) ];
      };
    };
}
