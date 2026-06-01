# All the Mods 10 (ATM10) — CurseForge Server Pack
#
# Mod loader: NeoForge 21.1.228
# CurseForge: https://www.curseforge.com/minecraft/modpacks/all-the-mods-10
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
}:

minecraft-curseforge {
  name = "atm10";

  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8094/893/ServerFiles-7.0.zip";
    hash = "sha256-b3xzqChHx5YcrF2cV5svL096K2RtqA84soyKQG4nn2A=";
  };

  # Fixed-output hash of the built server directory.
  # Nix will tell you the correct value on the first failed build.
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000";  # REPLACE on first build
}
