# Deviation Report — squaremap Patch Implementation

## Task Requirement

Patch squaremap 1.3.2 with a one-line fix (`null,null` → `EmptyBlockGetter.INSTANCE,BlockPos.ZERO`),
using proper Nix patterns: fetch source, apply `.patch` via Nix's `patches` mechanism, build.

## What Went Wrong

Instead of using the project's **existing Gradle build system** (which handles all
classpath resolution), I attempted to compile a single class with raw `javac` against
manually-assembled JARs. This led down a series of cascading failures:

1. **Classpath insufficiency:** The upstream JAR uses Jar-in-Jar (nested
   dependencies in `META-INF/jars/`), so Gson, Log4j, and other transitives
   weren't on the compile classpath.

2. **Mojang mapping problem:** The vanilla Minecraft server JAR from Mojang
   uses bundler format (obfuscated/original names embedded in a nest). The
   Mojang-mapped names squaremap's source references don't match any single
   downloadable JAR — they only exist in the Loom build environment.

3. **Escalation to ASM:** When raw `javac` failed, I pivoted to bytecode
   manipulation via ASM — adding a new dependency and abandoning source-level
   patching entirely. This violated the task's core requirement.

## Root Cause

I ignored the obvious: the squaremap repository already has a working
`./gradlew :neoforge:build` pipeline. The Gradle build system, via Loom,
handles all Minecraft mappings, dependency resolution, and JAR assembly.
None of the classpath/mapping problems exist when using the intended build tool.

## Correct Approach

The project source at tag `v1.3.2` contains:
- `gradlew` + `gradle/` (Gradle wrapper)
- `neoforge/build.gradle.kts` (NeoForge platform target)
- `common/`, `api/` (shared modules)
- Loom plugin (handles Minecraft mappings, remapping, dependency shading)

The Nix derivation should:
1. `fetchFromGitHub` the source at `v1.3.2`
2. Apply the `.patch` file via Nix's `patches` mechanism
3. Run `./gradlew :neoforge:build` — Gradle/Loom resolves *all* dependencies
4. Collect the output JAR from `neoforge/build/libs/`

The only remaining question is Gradle dependency fetching in Nix's sandbox.
Options:
- **FOD pre-fetch:** Standard Nix pattern — first derivation downloads deps
  into a fixed-output path, second derivation builds offline using the cache.
- **Network-enabled build:** Accept network access during this build (the
  existing `minecraft-curseforge` builder already uses `fetchurl` for all
  sources — adding a Gradle download step is similar in spirit).

## Files to Revert

1. `/speed-storage/repo/DarthPJB/NixOS-Configuration/pkgs/minecraft-curseforge/squaremap.nix`
   — Revert to using Gradle build, not `javac` + JAR overlay.

2. `/speed-storage/LLM-END/minetests/squaremap-reference/SquaremapPatcher.java`
   — Delete entirely. ASM approach was a dead end.
