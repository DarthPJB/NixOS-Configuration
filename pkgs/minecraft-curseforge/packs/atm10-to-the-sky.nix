# ATM 10 to the Sky — CurseForge Server Pack
#
# Mod loader: NeoForge
# CurseForge: https://www.curseforge.com/minecraft/modpacks/all-the-mods-10-to-the-sky
#
# NOTE: Replace placeholder hashes with real values:
#   1. Get the server pack download URL from CurseForge
#   2. nix run nixpkgs#nix-prefetch-url -- <url> for src hash
#   3. First build will fail with the correct outputHash — use its suggestion

{ minecraft-curseforge
, fetchurl
}:

minecraft-curseforge {
  name = "atm10-to-the-sky";

  src = fetchurl {
    # TODO: Replace with real CurseForge server pack URL
    url = "https://example.com/atm10-to-the-sky-server-pack.zip";
    # TODO: Replace with real hash from nix-prefetch-url
    hash = "sha256-0000000000000000000000000000000000000000000000000000";
  };

  # TODO: Replace with real output hash (Nix will suggest the correct value on first build)
  outputHash = "sha256-0000000000000000000000000000000000000000000000000000";

  # ATM10 Sky uses similar setup script pattern
  setupScripts = [
    "server-setup.sh"
    "ServerStart.sh"
  ];
}
