{ minecraft-curseforge, fetchurl, lib }:

let
  version = "1.0.0-rc.7";
  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8249/958/ServerFiles-${version}.zip";
    hash = "sha256-C02SBrJ+1rXrWn2XIHUYIYhu/sFlgIiAERJlzRGPTnI=";
  };
  moaPatch = import ../patches/rc7-moa-patch.nix { inherit lib version; };
in
minecraft-curseforge {
  name = "all-the-mons";
  inherit src;
  postBuild = moaPatch;
}
