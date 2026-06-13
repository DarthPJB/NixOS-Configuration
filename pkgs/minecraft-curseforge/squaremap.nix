# squaremap — Minimalistic live world map viewer for Minecraft
#
# Builds the NeoForge variant for MC 1.21.1 from source at tag v1.3.2,
# applying a patch to fix the FramedBlocks getMapColor NPE.
#
# Two-step fixed-output derivation:
#   1. gradleDeps: FOD downloads all Gradle/Loom/Minecraft dependencies
#   2. Main build: applies patch, builds offline, outputs the mod JAR
#
# Upstream fix (1.3.13+) backported: passes EmptyBlockGetter.INSTANCE +
# BlockPos.ZERO instead of (null, null) to BlockState.getMapColor().
#
# MIT License
# https://github.com/jpenilla/squaremap

{ stdenv
, stdenvNoCC
, fetchFromGitHub
, git
, lib
, jdk21
}:

let
  version = "1.3.2";

  src = fetchFromGitHub {
    owner = "jpenilla";
    repo = "squaremap";
    rev = "v${version}";
    hash = "sha256-EcBroXoWqAl2EPV7bscWY0EMZ+cySIhtSuyoiGlDA9A=";
  };

  # FOD: downloads all Gradle/Maven dependencies (Minecraft via Loom,
  # NeoForge, Gson, Log4j, Adventure, Cloud, etc.) into a fixed-output
  # path. The build runs in network-enabled mode once; subsequent builds
  # use the cached output identified by the hash below.
  gradleDeps = stdenvNoCC.mkDerivation {
    name = "squaremap-${version}-gradle-deps";
    inherit src;
    nativeBuildInputs = [ jdk21 ];

    # FOD mechanism grants network access to download Gradle/Maven deps.
    # All downloads are captured in $out and verified by the fixed outputHash.

    buildInputs = [ git ];

    buildPhase = ''
      # Squaremap build uses net.kyori.indra.git to embed commit hash.
      # Source from fetchFromGitHub has no .git — create a minimal one.
      git init
      git config user.email "nix@build.local"
      git config user.name "Nix"
      git add -A
      git commit -q -m "squaremap ${version}"

      export GRADLE_USER_HOME=$TMPDIR/gradle-cache
      export HOME=$TMPDIR

      chmod +x ./gradlew
      ./gradlew :squaremap-neoforge:build -x test --no-daemon --stacktrace
    '';

    installPhase = ''
      # Remove non-deterministic Gradle state (daemon, journals, build cache)
      rm -rf $TMPDIR/gradle-cache/daemon
      rm -rf $TMPDIR/gradle-cache/notifications
      rm -rf $TMPDIR/gradle-cache/kotlin-profile
      rm -rf $TMPDIR/gradle-cache/caches/journal-1
      rm -rf $TMPDIR/gradle-cache/caches/build-cache-1

      # Strip lock files (non-deterministic)
      find $TMPDIR/gradle-cache -name '*.lock' -type f -delete

      mkdir -p $out
      cp -r $TMPDIR/gradle-cache/* $out/
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-GHUaZ0cGcwNp7IYf2gqcUfS8OjL1R0qz8eql59wYxfo=";

    # FOD caches are unmodified binary artifacts — skip fixup
    dontFixup = true;
  };
in
stdenv.mkDerivation {
  pname = "squaremap-neoforge";
  inherit version src;

  patches = [ ./patches/squaremap-framedblocks-npe.patch ];

  nativeBuildInputs = [ jdk21 git ];

  # Ensure the patch applied correctly — guards against source drift
  postPatch = ''
    grep -q 'return Colors.rgb(state.getMapColor(EmptyBlockGetter.INSTANCE, BlockPos.ZERO));' \
      common/src/main/java/xyz/jpenilla/squaremap/common/data/MapWorldInternal.java \
      || {
        echo "ERROR: squaremap NPE patch did not apply — MapWorldInternal.java missing expected fix" >&2
        exit 1
      }
  '';

  buildPhase = ''
    # Create minimal .git repo — IndraGit plugin needs commit hash
    git init
    git config user.email "nix@build.local"
    git config user.name "Nix"
    git add -A
    git commit -q -m "squaremap ${version}"

    # Copy Gradle cache to writable location (Nix store output is read-only)
    GRADLE_CACHE=$TMPDIR/gradle-cache
    mkdir -p "$GRADLE_CACHE"
    cp -r --no-preserve=mode ${gradleDeps}/* "$GRADLE_CACHE/"
    export GRADLE_USER_HOME=$GRADLE_CACHE
    export HOME=$TMPDIR

    chmod +x ./gradlew
    ./gradlew :squaremap-neoforge:build --no-daemon --offline --stacktrace
  '';

  installPhase = ''
    mkdir -p "$out/mods"

    # Loom remapped JAR is in neoforge/build/libs/
    cp neoforge/build/libs/*.jar "$out/mods/" 2>/dev/null || {
      echo "ERROR: No JAR found in neoforge/build/libs/" >&2
      ls -la neoforge/build/libs/ >&2 || echo "(directory missing)" >&2
      exit 1
    }
  '';

  meta = with lib; {
    description = "Squaremap web map viewer for Minecraft (NeoForge, patched for FramedBlocks compat)";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
