# moonrise — Server-side chunk optimization mod for Minecraft
#
# Builds the NeoForge variant for MC 1.21.1 from source at tag v0.1.0-beta.15.
# Used as a compileOnly dependency by squaremap (replaces CurseForge Maven source).
#
# MIT License
# https://github.com/Tuinity/Moonrise

{ stdenv
, stdenvNoCC
, fetchFromGitHub
, git
, lib
, jdk21
}:

let
  version = "0.1.0-beta.15";

  src = fetchFromGitHub {
    owner = "Tuinity";
    repo = "Moonrise";
    rev = "v${version}";
    hash = "sha256-aScB2NshYo5q9IwBe4hxuKHzgdAKrV1UXxh0CdczE/c=";
  };

  # FOD: downloads all Gradle/Maven dependencies into a fixed-output path.
  gradleDeps = stdenvNoCC.mkDerivation {
    name = "moonrise-${version}-gradle-deps";
    inherit src;
    nativeBuildInputs = [ jdk21 ];
    buildInputs = [ git ];

    # Strip Fabric subproject — only NeoForge is needed
    postPatch = ''
      sed -i '/include("fabric")/d' settings.gradle
      sed -i '/findProject(":fabric")/d' settings.gradle
    '';

    buildPhase = ''
      git init
      git config user.email "nix@build.local"
      git config user.name "Nix"
      git add -A
      git commit -q -m "moonrise ${version}"

      export GRADLE_USER_HOME=$TMPDIR/gradle-cache
      export HOME=$TMPDIR

      chmod +x ./gradlew
      ./gradlew :moonrise-neoforge:build -x test --no-daemon --stacktrace
    '';

    installPhase = ''
      rm -rf $TMPDIR/gradle-cache/daemon
      rm -rf $TMPDIR/gradle-cache/notifications
      rm -rf $TMPDIR/gradle-cache/kotlin-profile
      rm -rf $TMPDIR/gradle-cache/caches/journal-1
      rm -rf $TMPDIR/gradle-cache/caches/build-cache-1
      find $TMPDIR/gradle-cache -name '*.lock' -type f -delete

      mkdir -p $out
      cp -r $TMPDIR/gradle-cache/* $out/
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-s9zb8q2pHMbeCV1ZeZcdPoZOZOd2TMR5p3jqWQpLe6E=";

    dontFixup = true;
  };
in
stdenv.mkDerivation {
  pname = "moonrise-neoforge";
  inherit version src;

  nativeBuildInputs = [ jdk21 git ];

  postPatch = ''
    sed -i '/include("fabric")/d' settings.gradle
    sed -i '/findProject(":fabric")/d' settings.gradle
  '';

  buildPhase = ''
    git init
    git config user.email "nix@build.local"
    git config user.name "Nix"
    git add -A
    git commit -q -m "moonrise ${version}"

    GRADLE_CACHE=$TMPDIR/gradle-cache
    mkdir -p "$GRADLE_CACHE"
    cp -r --no-preserve=mode ${gradleDeps}/* "$GRADLE_CACHE/"
    export GRADLE_USER_HOME=$GRADLE_CACHE
    export HOME=$TMPDIR

    chmod +x ./gradlew
    ./gradlew :moonrise-neoforge:build --no-daemon --offline --stacktrace
  '';

  installPhase = ''
    mkdir -p "$out"
    # Copy the NeoForge JAR
    cp neoforge/build/libs/*.jar "$out/" 2>/dev/null || {
      echo "ERROR: No JAR found in neoforge/build/libs/" >&2
      ls -la neoforge/build/libs/ >&2 || echo "(directory missing)" >&2
      exit 1
    }
  '';

  meta = with lib; {
    description = "Moonrise server-side chunk optimization for Minecraft (NeoForge)";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
