# Squaremap FramedBlocks NPE — Patch Implementation Plan

## Problem

`squaremap 1.3.2` calls `BlockState.getMapColor(null, null)` which triggers an NPE in
FramedBlocks' `IFramedBlock.getMapColor()` when it dereferences the null `level`
parameter via `level.getBlockEntity(pos)`. This crashes entire chunk column renders,
leaving permanent unrendered holes in the map.

The upstream fix landed in squaremap 1.3.13 (passes `EmptyBlockGetter.INSTANCE,
BlockPos.ZERO` instead of `null, null`), but 1.3.13 targets NeoForge 26.1.x
(MC 1.21.5+) and is incompatible with this modpack (NeoForge 21.1.229, MC 1.21.1).

## Approach

Backport the 1-line fix to squaremap 1.3.2 using proper Nix source-based patching.

### Architecture

| Nix primitive | Role |
|---|---|
| `stdenv.mkDerivation` | Full phase pipeline (unpack → patch → build → install) |
| `fetchFromGitHub` | Reproducible source fetch at tag `v1.3.2`, pinned by hash |
| `patches = [...]` | Nix auto-applies `.patch` files during `patchPhase` |
| `fetchurl` for classpath JARs | Reproducible binary dependencies (hashed) |
| `javac` | Compile single patched class against upstream JARs |
| `jar uf` | Overlay compiled `.class` into output JAR |

### Files Changed

1. **NEW: `pkgs/minecraft-curseforge/patches/squaremap-framedblocks-npe.patch`**
   Standard unified diff against `MapWorldInternal.java` at v1.3.2.

2. **REWRITE: `pkgs/minecraft-curseforge/squaremap.nix`**
   From `runCommand` + `fetchurl` (JAR copier) → `stdenv.mkDerivation` + `fetchFromGitHub` (source build).

### Derivation Pseudocode

```nix
{ stdenv, fetchFromGitHub, fetchurl, jdk21 }:

let
  version = "1.3.2";

  src = fetchFromGitHub {
    owner = "jpenilla";
    repo = "squaremap";
    rev = "v${version}";
    hash = "<TBD>";       # computed from actual fetch
  };

  # Upstream JAR serves as classpath (contains all squaremap API + common classes)
  upstreamJar = fetchurl {
    url = "https://github.com/jpenilla/squaremap/releases/download/v${version}/squaremap-neoforge-mc1.21.1-${version}.jar";
    hash = "sha256-FRhPcfFSUNGZ4D0HpoIgW3+dmSKZyuINtKn2E5ZsxHo=";  # unchanged
  };

  # Mojang vanilla server JAR for MC classpath (EmptyBlockGetter, BlockPos, BlockState)
  mcServer = fetchurl {
    url = "https://piston-data.mojang.com/v1/objects/<TBD>/server.jar";
    hash = "<TBD>";       # MC 1.21.1 vanilla server
  };
in
stdenv.mkDerivation {
  pname = "squaremap-neoforge";
  inherit version src;

  patches = [ ./patches/squaremap-framedblocks-npe.patch ];

  nativeBuildInputs = [ jdk21 ];

  buildPhase = ''
    javac -cp "${upstreamJar}:${mcServer}" \
      -d build \
      common/src/main/java/xyz/jpenilla/squaremap/common/data/MapWorldInternal.java
  '';

  installPhase = ''
    mkdir -p "$out/mods"
    cp ${upstreamJar} "$out/mods/squaremap-neoforge-mc1.21.1-${version}.jar"
    jar uf "$out/mods/squaremap-neoforge-mc1.21.1-${version}.jar" \
      -C build xyz/jpenilla/squaremap/common/data/MapWorldInternal.class
  '';
}
```

### Key Design Decisions

1. **Minimal compilation** — only the single changed file. No Gradle, no Loom,
   no full build toolchain. The classpath is satisfied by the upstream JARs.

2. **Output path unchanged** — `$out/mods/squaremap-neoforge-mc1.21.1-1.3.2.jar`.
   Zero consumer changes in `flake.nix`, `minecraft-curseforge.nix`, or any
   machine config.

3. **Reproducible** — all inputs are hashed (`fetchFromGitHub`, `fetchurl`).
   Same inputs → same output byte-for-byte.

4. **No intermediate build tools** — `javac` and `jar` are in `jdk21`, no extra
   dependencies needed.

### Patch Content (conceptual)

```diff
--- a/common/src/main/java/xyz/jpenilla/squaremap/common/data/MapWorldInternal.java
+++ b/common/src/main/java/xyz/jpenilla/squaremap/common/data/MapWorldInternal.java
@@ -1,5 +1,7 @@
 package xyz.jpenilla.squaremap.common.data;

+import net.minecraft.core.BlockPos;
+import net.minecraft.world.level.EmptyBlockGetter;
 import net.minecraft.world.level.block.state.BlockState;
 ...
     public int getMapColor(final BlockState state) {
         final int special = this.blockColors.color(state);
         if (special != -1) {
             return special;
         }
-        return Colors.rgb(state.getMapColor(null, null));
+        return Colors.rgb(state.getMapColor(EmptyBlockGetter.INSTANCE, BlockPos.ZERO));
     }
```

### Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| MC 1.21.1 server JAR unavailable from Mojang | Low | Use `pkgs.minecraft-server` (1.21.10) — class signatures unchanged |
| `javac` fails due to missing transitive dependencies | Low | `MapWorldInternal` only references squaremap API types + vanilla MC types, all in classpath JARs |
| Compiled class binary-incompatible at runtime | Very Low | Same source language (Java 21), same target JVM, same method signatures |
| `jar uf` path mismatch | Low | Verified against JAR listing from upstream build |
| Patch context drifts on squaremap update | Medium | Version assertion in derivation; update requires re-validation |

### Verification

After build, the patched JAR can be diffed against the original:
- Only `MapWorldInternal.class` should differ
- The class's `getMapColor` method should reference `EmptyBlockGetter.INSTANCE`
  and `BlockPos.ZERO` instead of `null`

## References

- Squaremap source: `/speed-storage/LLM-END/minetests/squaremap-reference` (tag `v1.3.2`, commit `7157ae6`)
- FramedBlocks source: `/speed-storage/LLM-END/minetests/framedblocks-reference` (commit `9856bf62`, version `10.5.2`)
- Upstream fix: squaremap 1.3.13, issue [#514](https://github.com/jpenilla/squaremap/issues/514)
- Error analysis: `documentation/plans/squaremap-render-failure-2026-06-13.md`
- Patch data: `/speed-storage/LLM-END/minetests/squaremap-framedblocks-patch-data.md`
