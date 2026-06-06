# Minecraft CurseForge Server Builder
#
# Takes a CurseForge server pack zip, extracts it, patches the start script
# to use a Nix JRE, and produces an immutable server fabric.
#
# This is a plain derivation — no fixed-output, no network access.
# The src zip is already fetched and verified by fetchurl.

{ stdenv
, lib
, pkgs
}:

{ name
, src
, jre ? pkgs.jdk21
}:

let
  imageId = builtins.baseNameOf src;
in
stdenv.mkDerivation {
  pname = "minecraft-server-builder-${name}";
  version = "unstable";

  inherit src;
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild

    # Extract modpack
    ${lib.getExe pkgs.unzip} "$src" -d "$out"

    # Patch start script to use Nix JRE and create canonical start.sh
    startScript=""
    for script in startserver.sh server-setup.sh ServerStart.sh LaunchServer.sh; do
      if [ -f "$out/$script" ]; then
        chmod +x "$out/$script"
        sed -i "1s|.*|#!${stdenv.shell}|" "$out/$script"
        sed -i "s|''${ATM10_JAVA:-java}|${lib.getExe jre}|g" "$out/$script"
        sed -i "s|\"java\"|\"${lib.getExe jre}\"|g" "$out/$script"
        startScript="$script"
        break
      fi
    done
    if [ -n "$startScript" ]; then
      ln -sf "./$startScript" "$out/start.sh"
    fi

    # Write image identity
    echo -n "${imageId}" > "$out/.image-id"

    runHook postBuild
  '';

  installPhase = "true";

  passthru = { inherit imageId jre; };

  meta = with lib; {
    description = "Builder for Minecraft CurseForge server packs";
    license = licenses.free;
    platforms = platforms.linux;
  };
}
