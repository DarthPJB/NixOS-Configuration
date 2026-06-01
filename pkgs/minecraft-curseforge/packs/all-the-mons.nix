# All the Mons — CurseForge Server Pack
#
# Mod loader: Forge/NeoForge
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
}:

minecraft-curseforge {
  name = "all-the-mons";

  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8120/605/ServerFiles-1.0.0-rc.6.zip";
    hash = "sha256-58i7bAvr1KXFciihjA6/kFKIzZGbR5idRLkOw0zxtf0=";
  };

  # Fixed-output hash of the built server directory.
  # Nix will tell you the correct value on the first failed build.
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000";  # REPLACE on first build

  setupScripts = [
    "server-setup.sh"
    "ServerStart.sh"
    "LaunchServer.sh"
  ];
}
