# ATM 10 to the Sky — CurseForge Server Pack
#
# Mod loader: NeoForge
# CurseForge: https://www.curseforge.com/minecraft/modpacks/all-the-mods-10-to-the-sky
#
# TODO: Replace placeholder URL and hash with real values.
#   nix-prefetch-url --type sha256 '<url>' → base32 hash
#   nix hash to-sri --type sha256 <base32> → SRI hash for fetchurl

{ minecraft-curseforge
, fetchurl
}:

minecraft-curseforge {
  name = "atm10-to-the-sky";
  src = fetchurl {
    url = "https://example.com/atm10-to-the-sky-server-pack.zip";  # REPLACE
    hash = "sha256-0000000000000000000000000000000000000000000000000000";  # REPLACE
  };
}
