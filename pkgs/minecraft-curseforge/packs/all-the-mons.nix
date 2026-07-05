# All the Mons — CurseForge Server Pack
#
# Mod loader: NeoForge 21.1.233
# CurseForge: https://www.curseforge.com/minecraft/modpacks/all-the-mons
#
# CurseForge rotates download URLs — once fetched into the nix store with
# a correct hash, the content persists regardless of URL changes.
#
# ── Setup workflow ───────────────────────────────────────────────────
#
# 1. Grab the server pack download URL from CurseForge (browser).
# 2. nix-prefetch-url --type sha256 '<url>' → base32 hash
#    nix hash to-sri --type sha256 <base32> → SRI hash for fetchurl
# 3. Fill in `url` and `hash` below.
# 4. nix build → fails with correct outputHash → plug it in.
# 5. nix build again → success. Cached permanently.
# ──────────────────────────────────────────────────────────────────────

{ minecraft-curseforge
, fetchurl
, lib
}:

let
  version = "1.0.1";
  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8360/850/ServerFiles-${version}.zip";
    hash = "sha256-FXK/iFkcwAJJwnZTnzvmzvKb9a8YM6KZfpJjPHxtLck=";
  };
  moaPatch = import ../patches/v1.0.1-moa-patch.nix { inherit lib version; };
in
minecraft-curseforge {
  name = "all-the-mons";
  inherit src;
  postBuild = moaPatch;

  # Fixed-output hash of the built server directory.
  # Nix will tell you the correct value on the first failed build.
  outputHash = "sha256-1bDkPWWq8zknj0EJsXN4VLwsZygzLTHFU7WW/nH590A=";
}
