# squaremap — Minimalistic live world map viewer for Minecraft
#
# Fetches the NeoForge variant for MC 1.21.1.
# The JAR is placed in $out/mods/ for integration into the server image.
#
# MIT License
# https://github.com/jpenilla/squaremap

{ fetchurl
, runCommand
}:

let
  version = "1.3.2";
  jar = fetchurl {
    url = "https://github.com/jpenilla/squaremap/releases/download/v${version}/squaremap-neoforge-mc1.21.1-${version}.jar";
    hash = "sha256-FRhPcfFSUNGZ4D0HpoIgW3+dmSKZyuINtKn2E5ZsxHo=";
  };
in
runCommand "squaremap-neoforge-${version}" { } ''
  mkdir -p "$out/mods"
  cp ${jar} "$out/mods/squaremap-neoforge-mc1.21.1-${version}.jar"
''
