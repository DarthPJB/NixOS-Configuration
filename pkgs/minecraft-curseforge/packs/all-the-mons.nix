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

  # Fixed-output hash of the built server directory.
  # Nix will tell you the correct value on the first failed build.
  outputHash = "sha256-9tId0CJfRlwA/ch1nNkJkYktul4Im3XdqHCN0sBc6/g=";
}
