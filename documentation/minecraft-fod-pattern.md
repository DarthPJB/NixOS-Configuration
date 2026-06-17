# Minecraft CurseForge Builder — Fixed-Output Derivation Pattern

## Overview

The Minecraft CurseForge server builder (`pkgs/minecraft-curseforge/default.nix`) uses a **fixed-output derivation (FOD)** pattern. This document explains why, how it works, and the critical constraints that must not be violated.

## Why FOD?

NeoForge server packs require network access during build to download:
- Minecraft server JAR (from Mojang)
- NeoForge libraries (from Maven)
- Forge/MCP mappings

Nix derivations normally have no network access (sandboxed). A FOD is the **only** Nix mechanism that permits network access during build while maintaining reproducibility — the output hash is fixed and verified.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Fixed-Output Derivation (outputHashMode = "recursive")     │
│                                                             │
│  1. Extract CurseForge zip to $out                          │
│  2. Run NeoForge installer (ATM10_INSTALL_ONLY=true)        │
│     → Downloads Minecraft server + NeoForge libraries       │
│     → Creates libraries/ directory in $out                  │
│  3. Create start.sh wrapper (uses $ATM10_JAVA env var)      │
│  4. Apply pack-specific patches (moa fix, etc.)             │
│  5. Normalize timestamps (deterministic output)             │
│  6. Nix verifies output hash matches expected value         │
└─────────────────────────────────────────────────────────────┘
```

## Critical Constraints

### 1. NO Store Path References in Output

The FOD output **must not** contain any references to Nix store paths. Nix's post-build scanner detects store path substrings (including the 32-character hash without `/nix/store/` prefix) and rejects the output.

**What triggers this:**
- Embedding `${jre}/bin/java` in start.sh
- Writing `builtins.baseNameOf src` to `.image-id` (contains store path hash)
- Any file containing `/nix/store/...`
- Shebang rewriting by fixupPhase (`#!/nix/store/.../bash`)

**How we avoid it:**
- `start.sh` uses `$ATM10_JAVA` environment variable (set by service module)
- `dontFixup = true` prevents shebang rewriting
- `imageId` uses `builtins.hashFile "sha256" src` (content hash, no store path)

### 2. Deterministic Output

The output hash must be **identical** across builds. Non-determinism causes hash mismatches.

**Sources of non-determinism:**
- File timestamps (from zip extraction, installer output)
- Installer log files (contain timestamps)
- Temporary files

**How we ensure determinism:**
- `find "$out" -exec touch -t 198001010000 {} +` — normalize all timestamps
- `rm -f "$out"/*.log "$out"/neoforge-*-installer.jar` — remove installer artifacts
- `dontFixup = true` — prevents non-deterministic fixup operations

### 3. Output Hash Must Be Correct

The `outputHash` in pack definitions must match the actual build output. If it doesn't, Nix reports the correct hash on the first failed build.

**To update the outputHash:**
1. Set `outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";` (placeholder)
2. Run `nix build` — it will fail with `got: sha256-...`
3. Replace the placeholder with the reported hash
4. Run `nix build` again — should succeed
5. Run `nix build` a third time — should be cached (hash is stable)

**If the hash changes between builds:** The output is non-deterministic. Check for:
- Missing timestamp normalization
- Installer logs in output
- Store path references (causes different error, but check anyway)

## Updating the Builder

When modifying `pkgs/minecraft-curseforge/default.nix`:

### Safe Changes (No outputHash Update Needed)
- Changing comments
- Changing build script logic that doesn't affect output
- Adding/removing `nativeBuildInputs` that don't affect output

### Changes That Require outputHash Update
- Changing `start.sh` template
- Changing timestamp normalization
- Changing cleanup logic (what files are removed)
- Changing the imageId computation

### Changes That Break the FOD
- Embedding store paths in output (e.g., `${jre}/bin/java` in start.sh)
- Removing `dontFixup = true`
- Removing timestamp normalization
- Removing `dontUnpack = true`

## The imageId Problem

The original builder used `builtins.baseNameOf src` for imageId:
```nix
imageId = builtins.baseNameOf src;
# → "d5dl9s60s1x5pqapn9iy18za9q1q3ar3-ServerFiles-1.0.0-rc.7.zip"
```

This string contains the Nix store hash (`d5dl9s60s1x5pqapn9iy18za9q1q3ar3`). Nix's FOD reference scanner detects this hash in the output and rejects it — even without the `/nix/store/` prefix.

**The fix:** Use a content hash instead:
```nix
imageId = builtins.hashFile "sha256" src;
# → "0b4d9206b27ed6b5eb5a7d9720751821886efec165808880111265cd118f4e72"
```

This produces a deterministic hash of the source zip content, with no store path references.

## The start.sh Pattern

The start.sh wrapper uses environment variables instead of hardcoded store paths:

```bash
#!/bin/bash
set -eu
NEOFORGE_VERSION=$(ls libraries/net/neoforged/neoforge/ | head -1)
JAVA=${ATM10_JAVA:-java}

cd "$(dirname "$0")"
if [ ! -d libraries ]; then
  echo "ERROR: libraries/ not found — NeoForge not installed"
  exit 1
fi

exec "$JAVA" \
  @user_jvm_args.txt \
  @libraries/net/neoforged/neoforge/$NEOFORGE_VERSION/unix_args.txt \
  nogui
```

The service module sets `ATM10_JAVA` to the Nix JRE path:
```nix
Environment = [
  "ATM10_JAVA=${lib.getExe finalPack.passthru.jre}"
];
```

## References

- [Nix Manual: Fixed-Output Derivations](https://nixos.org/manual/nix/stable/advanced-topics/fixed-output-derivations)
- [Nix Pills: Fixed-Output Derivations](https://nixos.org/guides/nix-pills/fixed-output-derivations.html)
- Builder: `pkgs/minecraft-curseforge/default.nix`
- Pack definitions: `pkgs/minecraft-curseforge/packs/*.nix`
- Service module: `server_services/game_servers/minecraft-curseforge.nix`
