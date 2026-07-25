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
#
# v1.1.1: Aether moa_type egg.id bug is fixed upstream — moa patch
# no longer required. Aether 1.21.1-1.5.10-neoforge now ships correct
# egg.id values (aether:blue_moa_egg, etc.) in moa_type/*.json.

{ minecraft-curseforge
, fetchurl
, lib
}:

let
  version = "1.1.1";
  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8431/25/ServerFiles-${version}.zip";
    hash = "sha256-3+mw6yldX6EPTwBNTZqVbINnM0r24b583wb8FPYhxaQ=";
  };
in
minecraft-curseforge {
  name = "all-the-mons";
  inherit src;

  # Fixed-output hash of the built server directory.
  outputHash = "sha256-yBEEiPi0MBPW1ChnxnJI4Cr0EIOg5+YxafwdUjJbrFE=";
}
