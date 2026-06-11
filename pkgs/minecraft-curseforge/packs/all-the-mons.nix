{ minecraft-curseforge, fetchurl, lib }:

let
  version = "1.0.0-rc.6";
  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8120/605/ServerFiles-${version}.zip";
    hash = "sha256-58i7bAvr1KXFciihjA6/kFKIzZGbR5idRLkOw0zxtf0=";
  };
  moaPatch = import ../patches/rc6-moa-patch.nix { inherit lib version; };
in
minecraft-curseforge {
  name = "all-the-mons";
  inherit src;
  postBuild = moaPatch;
}
