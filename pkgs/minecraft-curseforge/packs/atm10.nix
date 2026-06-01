# All the Mods 10 (ATM10) — CurseForge Server Pack
#
# Mod loader: NeoForge
# CurseForge: https://www.curseforge.com/minecraft/modpacks/all-the-mods-10
#
# CurseForge rotates download URLs, so once this file is fetched into the
# nix store with a correct hash, it persists regardless of URL changes.
# The fetchurl hash is content-addressed — the URL is just the initial seed.
#
# ── Setup workflow ───────────────────────────────────────────────────
#
# 1. Visit the CurseForge page in a browser and grab the server pack
#    download URL (right-click → Copy link, after the redirect settles).
#
# 2. Compute the src hash:
#      nix-prefetch-url --type sha256 '<download-url>'
#
#    This gives you a base32 hash. Convert to SRI format:
#      nix hash to-sri --type sha256 <base32-hash>
#
# 3. Fill in `url` and `hash` below with the values from step 1-2.
#
# 4. Run `nix build .#minecraft-curseforge-atm10` — it WILL fail on the
#    first attempt with the correct `outputHash`. The error message will
#    contain the hash string. Copy it into `outputHash` below.
#
# 5. Run `nix build` again — it should now succeed. The zip is cached
#    in the nix store permanently. CurseForge can rotate the URL all
#    they want — we already have the content.
#
# ──────────────────────────────────────────────────────────────────────

{ minecraft-curseforge
, fetchurl
}:

minecraft-curseforge {
  name = "atm10";

  src = fetchurl {
    # CurseForge server pack download URL (rotate-safe once hashed)
    url = "https://example.com/atm10-server-pack.zip";  # REPLACE
    hash = "sha256-0000000000000000000000000000000000000000000000000000";  # REPLACE
  };

  # Fixed-output hash of the built server directory.
  # Nix will tell you the correct value on the first failed build.
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000";  # REPLACE

  # Setup scripts to probe for (first found wins)
  setupScripts = [
    "server-setup.sh"
    "ServerStart.sh"
  ];
}
