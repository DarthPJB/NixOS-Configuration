# Minecraft CurseForge Server Builder — Fixed-Output Derivation
#
# This builder fetches a CurseForge server pack zip, extracts it, runs the
# modpack's setup script (including NeoForge installer), patches the start
# script to use a Nix-aware JRE, and produces an immutable server fabric.
#
# The output is a fixed-output derivation: network access is allowed during
# the build (for the setup script to download dependencies), but the output
# hash must match exactly.
#
# CurseForge packs come in two flavors:
#   1. Simple — config/mods only, no setup script needed
#   2. NeoForge/Forge — has startserver.sh that installs the mod loader
#
# This builder handles both patterns.
#
# Usage:
#   minecraft-curseforge {
#     name = "atm10";
#     src = fetchurl { url = "..."; hash = "sha256-..."; };
#     outputHash = "sha256-...";
#   }
#
# The `outputHash` is the hash of the FINAL output directory contents. On
# first build, Nix will suggest the correct hash after a failed attempt.

{ stdenv
, lib
, unzip
, jdk21
}:

# Curried: outer args are build-time deps, inner args are per-pack config
{ name
, src
, jre ? jdk21
, outputHash
, # Names of setup scripts to probe for, in priority order.
  # The first existing script found will be executed.
  setupScripts ? [
    "startserver.sh"
    "server-setup.sh"
    "ServerStart.sh"
    "LaunchServer.sh"
    "start_server.sh"
  ]
, postBuild ? ""
}:

let
  # Image identity: content-addressed hash of the source zip.
  # Cannot use builtins.baseNameOf src — the store path hash triggers
  # FOD reference scanner violations at evaluation time.
  imageId = builtins.hashFile "sha256" src;
in
stdenv.mkDerivation {
  pname = "minecraft-server-builder-${name}";
  version = "unstable";

  inherit src;
  dontUnpack = true;
  dontFixup = true;

  nativeBuildInputs = [
    unzip
  ];

  # JRE in buildInputs (not nativeBuildInputs) — ensures it's in the
  # runtime closure. The patched start.sh references ${jre}/bin/java,
  # and Nix's reference scanner finds this text reference in the output.
  buildInputs = [
    jre
  ];

  # Fixed-output: network access allowed during build
  outputHashMode = "recursive";
  inherit outputHash;

  # Expose imageId and jre without building the derivation
  passthru = { inherit imageId jre; };

  # CRITICAL: Single buildPhase — patchPhase runs BEFORE buildPhase in
  # Nix's mkDerivation, so it cannot reference files that don't exist yet.
  # All work happens here: extract, setup, strip, patch, identity.
  buildPhase = ''
    runHook preBuild

    # ── Extract modpack ──────────────────────────────────────────────
    unzip "$src" -d "$out"
    cd "$out"

    # ── Probe for setup script ───────────────────────────────────────
    setupScript=""
    for script in ${lib.concatStringsSep " " setupScripts}; do
      if [ -f "$script" ]; then
        setupScript="$script"
        break
      fi
    done

    if [ -z "$setupScript" ]; then
      echo "ERROR: No recognized setup script found in modpack!"
      echo "Searched for: ${lib.concatStringsSep ", " setupScripts}"
      echo "Files in archive:"
      ls -la "$out/"
      exit 1
    fi

    echo "Using setup script: $setupScript"

    # ── Run setup ────────────────────────────────────────────────────
    # For NeoForge/Forge packs (startserver.sh):
    #   - ATM10_INSTALL_ONLY=true skips the server launch loop
    #   - The script installs NeoForge by running the included installer jar
    #   - The installer downloads additional libraries from maven (network OK)
    # For simple packs:
    #   - Run the setup script directly
    if [ "$setupScript" = "startserver.sh" ]; then
      echo "Detected NeoForge/Forge pack — running installer..."
      ATM10_INSTALL_ONLY=true JAVA="${jre}/bin/java" bash "$setupScript"
    else
      echo "Running setup script..."
      yes | bash "$setupScript"
    fi

    # ── Strip module-owned files ─────────────────────────────────────
    # These will be provided by the overlay derivation (Phase 2).
    rm -f "$out/eula.txt" "$out/server.properties"

    # ── Strip CurseForge metadata if present ─────────────────────────
    rm -rf "$out/.curseforge" "$out/overrides" 2>/dev/null || true

    # ── Strip installer logs and temporaries ─────────────────────────
    rm -f "$out"/*.log "$out"/neoforge-*-installer.jar 2>/dev/null || true

    # ── Pack-specific post-build patches ─────────────────────────────
    ${postBuild}

    runHook postBuild
  '';

  # postBuild runs AFTER buildPhase — safe to rewrite start.sh here.
  # This ensures the script exists (created by setup or by us).
  #
  # CRITICAL: start.sh must NOT embed nix store paths — FOD outputs cannot
  # reference store paths. The service module provides the JRE via ATM10_JAVA
  # environment variable.
  postBuild = ''
        # ── Rewrite start script ─────────────────────────────────────────
        # For NeoForge packs, the launcher uses @user_jvm_args.txt and
        # @libraries/net/neoforged/neoforge/<version>/unix_args.txt.
        # The service module sets ATM10_JAVA to the Nix JRE path.

        # Check if this is a NeoForge pack (has unix_args.txt after install)
        neoForgeArgs=$(find "$out/libraries/net/neoforged" -name "unix_args.txt" 2>/dev/null | head -1)

        if [ -n "$neoForgeArgs" ]; then
          echo "NeoForge pack detected — creating launcher wrapper"
          cat > "$out/start.sh" << 'STARTSCRIPT'
    #!/bin/bash
    set -eu
    NEOFORGE_VERSION=$(ls libraries/net/neoforged/neoforge/ | head -1)
    JAVA=''${ATM10_JAVA:-java}

    cd "$(dirname "$0")"
    if [ ! -d libraries ]; then
      echo "ERROR: libraries/ not found — NeoForge not installed"
      exit 1
    fi

    exec "$JAVA" \
      @user_jvm_args.txt \
      @libraries/net/neoforged/neoforge/$NEOFORGE_VERSION/unix_args.txt \
      nogui
    STARTSCRIPT
        else
          # Simple pack — find the server jar
          cat > "$out/start.sh" << 'STARTSCRIPT'
    #!/bin/bash
    set -eu
    JAVA=''${ATM10_JAVA:-java}

    cd "$(dirname "$0")"
    JAR=$(find . -maxdepth 1 -name "*.jar" -type f | head -1)
    if [ -z "$JAR" ]; then
      echo "ERROR: No .jar files found"
      exit 1
    fi

    exec "$JAVA" \
      -Xmx''${JAVA_MAX_MEM:-4G} \
      -Xms''${JAVA_MIN_MEM:-2G} \
      ''${JAVA_OPTS:-} \
      -jar "$JAR" nogui
    STARTSCRIPT
        fi

        chmod +x "$out/start.sh"

        # ── Normalize timestamps for deterministic output ────────────────
        find "$out" -exec touch -t 198001010000 {} + 2>/dev/null || true

        # ── Write image identity ─────────────────────────────────────────
        echo -n "${imageId}" > "$out/.image-id"
  '';

  # No installPhase — the entire $out directory IS the output.
  installPhase = "true";

  meta = with lib; {
    description = "Builder for Minecraft CurseForge server packs";
    license = licenses.free; # CurseForge packs have their own licenses
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
