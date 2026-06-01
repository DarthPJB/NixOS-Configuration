# Minecraft Hosting Module — Session Planning

**Date:** 2026-06-01
**Branch:** `feat/minecraft-hosting-module`
**Worktree:** `/tmp/nixos-minecraft-hosting`

## Objective

Develop a specialised, extensible NixOS module for hosting Minecraft servers.
This is **not** a vanilla Minecraft server — it is a derivation basis/framework
for creating Minecraft server instances supporting common patterns.

## Target Modpacks (Initial)

| Pack | Mod Loader | Source |
|---|---|---|
| All the Mods 10 (ATM10) | NeoForge | CurseForge |
| ATM 10 to the Sky | NeoForge | CurseForge |
| All the Mons | (likely Forge/NeoForge) | CurseForge |

## Derivation Chain

```
Step 1: Builder (fixed-output derivation — network allowed)
─────────────────────────────────────────────────────────────
inputs: { name, src (fetchurl), outputHash, jre }

  fetchurl → extract → run server-setup.sh → remove eula.txt + server.properties
  ↓
  patchPhase: rewrite start.sh as nix-aware wrapper (JRE from runtime closure)
             write .image-id from zip-hash ($(basename $src))
  ↓
output: /nix/store/...-minecraft-server-builder-<name>/
         ├── server.jar
         ├── mods/
         ├── libraries/
         ├── config/
         ├── start.sh             ← patched, uses nix JRE
         ├── launcher.jar         ← whatever server-setup.sh produces
         └── .image-id            ← zip content hash

passthru: { imageId = "<zip-hash>-source.zip"; }

Step 2: Module overlay (pure derivation — no network)
──────────────────────────────────────────────────────
inputs: { src = builder, serverProperties, acceptEula }

  cp -ra builder/* → $out
  write eula.txt  (only if acceptEula = true)
  write server.properties (from module options)
  ↓
output: /nix/store/...-minecraft-server-final-<name>/
         ├── server.jar
         ├── mods/
         ├── libraries/
         ├── config/
         ├── start.sh             ← same patched script
         ├── .image-id            ← same marker, propagated
         ├── eula.txt             ← MODULE-OWNED
         └── server.properties    ← MODULE-OWNED

This is the artifact that gets deployed.

Step 3: Deploy (systemd service)
─────────────────────────────────
  ExecStop:    world backup (tar.gz, date-stamped)
  ExecStartPre: rsync final derivation → dataDir (--exclude=/world --exclude=/backups)
                compare .image-id to detect derivation changes
  ExecStart:   ${dataDir}/start.sh
```

## Responsibility Split

| Derivation Step | Concern | Ownership |
|---|---|---|
| Step 1 (Builder) | server.jar, mods, libraries, config, start.sh | Modpack author + Nix fetcher |
| Step 2 (Overlay) | eula.txt, server.properties | NixOS module user |
| Step 3 (Deploy) | world, backups, logs, service lifecycle | systemd + NixOS module |

## State Retention Boundary

| Preserved on update | Replaced on update |
|---|---|
| `world/` | Everything from the final derivation (server.jar, mods, libraries, config, start.sh, server.properties, eula.txt) |
| `backups/` | |

## EULA Handling

`acceptEula` is a module option, **default false**. The overlay derivation
produces a derivation without `eula.txt` unless the user explicitly sets
`acceptEula = true`. The Minecraft server refuses to start without this file,
enforcing legal acceptance.

## Image Identity (Zip-Hash Propagation)

The `.image-id` marker is derived from the fetchurl store path:

```
src = fetchurl { url = "..."; hash = "sha256-<zip-hash>"; }
  → store path: /nix/store/<zip-hash>-source.zip
  → basename:   <zip-hash>-source.zip
  → imageId:    <zip-hash>-source.zip
```

This propagates through the chain:
1. **Builder** writes `$(basename $src)` to `$out/.image-id`
2. **Overlay** copies `.image-id` unchanged (part of cp -ra)
3. **ExecStartPre** reads stored `.image-id` vs current derivation's `.image-id`
4. **Mismatch** → modpack changed → rsync recopy

## Backup Semantics & Gaps

**ExecStop captures world on PLANNED stops only**:
- Runs on: `systemctl stop`, `systemctl restart`, `nixos-rebuild switch` (when unit restarts)
- Does NOT run on: crash, OOM kill, `SIGKILL`, power loss, `systemctl kill`
- This is a convenience hook, NOT a backup solution — critical worlds need external backup

**100% retention by default** — no rotation. The module owner must manage disk space
externally (e.g., systemd timer + retention cleanup, or external backup system).

### ExecStop (world backup)
```bash
if [ -d "${dataDir}/world" ]; then
  mkdir -p "${dataDir}/backups"
  tar czf "${dataDir}/backups/world-$(date +%Y%m%d-%H%M%S).tar.gz" \
    -C "${dataDir}" world
fi
```

**Performance note:** Large worlds (10GB+) may exceed systemd's default ExecStop timeout
(90s). Consider increasing `TimeoutStopSec` or adding `Type=exec` for immediate handoff.

### ExecStartPre (instantiate final derivation)
```bash
imageId="$(cat "${finalPack}/.image-id")"

if [ ! -f "${dataDir}/.image-id" ] ||
   [ "$(cat "${dataDir}/.image-id")" != "${imageId}" ]; then

  # Ensure dataDir exists (first deploy or after data loss)
  mkdir -p "${dataDir}"

  rsync -a --delete \
    --exclude=/world \
    --exclude=/backups \
    --chown="${user}:${group}" \
    "${finalPack}/" "${dataDir}/"

  echo "${imageId}" > "${dataDir}/.image-id"
fi
```

### ExecStart (server launch)
```bash
exec ${dataDir}/start.sh
```

## Builder: `pkgs/minecraft-curseforge/default.nix`

```nix
{ stdenv, fetchurl, jdk21, lib }:
{ name, src, jre ? jdk21, outputHash }:

let
  # image-id = zip content hash from fetchurl store path
  imageId = builtins.baseNameOf src;
in
stdenv.mkDerivation {
  name = "minecraft-server-builder-${name}";
  inherit src;
  buildInputs = [ jre ];
  outputHashMode = "recursive";
  inherit outputHash;
  passthru = { inherit imageId; };

  buildPhase = ''
    # Extract modpack
    unzip "$src" -d "$out"
    cd "$out"

    # Run setup script (probe for common names, fail if none found)
    if [ -f server-setup.sh ]; then
      yes | bash server-setup.sh
    elif [ -f ServerStart.sh ]; then
      bash ServerStart.sh
    elif [ -f LaunchServer.sh ]; then
      bash LaunchServer.sh
    else
      echo "ERROR: No recognized setup script found in modpack!"
      echo "Expected: server-setup.sh, ServerStart.sh, or LaunchServer.sh"
      exit 1
    fi

    # Strip module-owned files
    rm -f "$out/eula.txt" "$out/server.properties"
  '';

  # NOTE: postBuild, NOT patchPhase — patchPhase runs BEFORE buildPhase in Nix
  postBuild = ''
    # Rewrite start script to use nix JRE from closure
    cat > "$out/start.sh" << WRAPPER
    #!${stdenv.shell}
    exec ${jre}/bin/java \
      -Xmx''${JAVA_MAX_MEM:-4G} \
      -Xms''${JAVA_MIN_MEM:-2G} \
      ''${JAVA_OPTS:-} \
      -jar "$out/server.jar" nogui
    WRAPPER
    chmod +x "$out/start.sh"
    echo -n "${imageId}" > "$out/.image-id"
  '';

  installPhase = "true";
}
```

## NixOS Module: `server_services/game_servers/minecraft-curseforge.nix`

### Module overlay (Step 2)
The module produces the final derivation by overlaying eula + server.properties
onto the builder output. This runs at build time, pure (no network).

```nix
let
  instanceOverlay = { name, pack, jre, acceptEula, serverProperties }:
    stdenv.mkDerivation {
      name = "minecraft-server-final-${name}";
      src = pack;
      # JRE in buildInputs ensures closure propagation — start.sh references
      # ${jre}/bin/java which the scanner finds via text reference in cp'd files
      buildInputs = [ jre ];

      buildPhase = ''
        cp -ra "$src" "$out"
        ${lib.optionalString acceptEula "echo eula=true > $out/eula.txt"}
        cat > "$out/server.properties" << PROPEOF
        ${lib.generators.toKeyValue {} serverProperties}
        PROPEOF
      '';

      installPhase = "true";
    };
in
```

### User-facing options
```nix
services.minecraft-curseforge."<name>" = {
  enable = false;
  pack = mkOption { type = types.package; };    # Builder derivation
  acceptEula = false;
  serverProperties = { };
  maxMemory = "8G";
  minMemory = "4G";
  jvmArgs = [ ];
  dataDir = "/bulk-storage/minecraft/<name>";
  openFirewall = false;
  gamePort = 25565;
  rconPasswordFile = "";
};
```

### Module assertions (to add)
```nix
assertions =
  [ { assertion = cfg.acceptEula || !cfg.enable;
      message = "Minecraft EULA must be accepted (services.minecraft-curseforge.${name}.acceptEula = true)";
    }
    { assertion = lib.all (n: n == name || cfg.dataDir != instanceConfig.dataDir)
        (lib.attrNames config.services.minecraft-curseforge);
      message = "Duplicate dataDir for minecraft-curseforge instances ${name} and ...";
    }
    { assertion = lib.all (n: n == name || cfg.gamePort != instanceConfig.gamePort)
        (lib.attrNames config.services.minecraft-curseforge);
      message = "Port conflict: gamePort ${toString cfg.gamePort} used by multiple instances";
    }
  ];
```

The systemd service references `finalPack` (the overlay), not `pack` (the builder).

## File Structure

```
pkgs/
  minecraft-curseforge/
    default.nix                   # Builder (callPackage-able)

server_services/
  game_servers/
    minecraft-curseforge.nix      # NixOS module (overlay + service)
```

## Decision Log

| Date | Decision | Rationale |
|---|---|---|
| 2026-06-01 | Project initiated | |
| 2026-06-01 | Generic module, not per-pack | Reusability |
| 2026-06-01 | **Builder (fixed-output)**: mods, libraries, patched start.sh | Network setup, immutable server fabric |
| 2026-06-01 | **Overlay (pure derivation)**: eula.txt + server.properties | Module options baked in at build time |
| 2026-06-01 | **Deploy (systemd)**: instantiate final derivation | Runtime lifecycle |
| 2026-06-01 | patchPhase rewrites start.sh with nix-aware wrapper | Uses JRE from runtime closure |
| 2026-06-01 | Zip-hash propagation via passthru.imageId + .image-id file | Derivation identity for update detection |
| 2026-06-01 | `acceptEula` default false | Legal requirement |
| 2026-06-01 | `world/` and `backups/` preserved on rsync | Runtime state retention |
| 2026-06-01 | ExecStop world backup before every planned stop | 100% retention, date-stamped |
| 2026-06-01 | `/bulk-storage/` for mutable runtime data | Existing convention |

---

# Agent Review Compilation — 2026-06-01

Four agents reviewed the architecture and implementation plan (1 June 2026).
The issue categories are: **CRITICAL** (blocks implementation), **MAJOR** (significant risk), **MEDIUM** (important but not blocking), **MINOR** (polish).

## 1. Structural Error: patchPhase Order (CRITICAL)

**Finding (tuvok-deepseek):** In Nix's `mkDerivation`, the phase ordering is:

1. `patchPhase` ← runs BEFORE unpack/extract
2. `buildPhase` ← actual build

The document's builder has them **reversed**: `buildPhase` extracts and runs `server-setup.sh`, and `patchPhase` attempts to rewrite `start.sh`. But `patchPhase` runs first — `start.sh` won't exist yet, and `$src` won't be extracted to `$out` yet.

**Fix:** Merge everything into `buildPhase` (remove `patchPhase` entirely), or use `postBuild` / `installPhase` for `start.sh` rewriting. The cleanest approach: put ALL work in `buildPhase` — extract, run setup, strip files, rewrite start.sh, write .image-id — in sequence. This is correct because `buildPhase` runs AFTER `unpackPhase` (which extracts `$src` for tarballs — but for a `.zip`, we need manual extraction). The builder needs a custom `buildPhase` that does everything: `unzip`, `bash server-setup.sh`, `rm eula.txt server.properties`, `cat start.sh > ...`, `echo image-id > ...`.

## 2. JRE Closure Propagation (CRITICAL)

**Finding (tpol-xai):** The overlay derivation has `buildInputs = [ ]`. However, the start.sh references `${jre}/bin/java` from the **builder** — a store path that was a build input of the builder, NOT of the overlay. Nix's reference scanner walks `buildInputs` to determine runtime dependencies. The overlay's `cp -ra "$src" "$out"` copies everything including the patched start.sh, BUT the scanner will find the `${jre}` reference embedded in start.sh and keep the closure alive... wait — actually, `cp -ra` copies files. If start.sh contains a literal store path like `/nix/store/abc...-jdk21/bin/java`, then `cp -ra` preserves that string, and Nix's output scanning WILL find it in the output. So the JRE closure IS propagated through the text reference. 

**BUT:** This is fragile. If `cp -ra` changes to `cp -r` or if the reference is in a binary (e.g., a shell script vs a binary ELF), the scanner behavior differs. For safety, the overlay should also have `buildInputs = [ jre ]` to guarantee closure propagation.

**Fix:** Add `buildInputs = [ jre ]` to the overlay derivation, even though it's "just a copy." This ensures the JRE closure is explicitly declared.

## 3. image-id: Build-Time vs Run-Time Path Resolution (CRITICAL)

**Finding (tpol-xai):** The ExecStartPre script currently does:
```bash
imageId="$(cat "${finalPack}/.image-id")"
```

But `finalPack` is a Nix derivation. In NixOS module context, `"${finalPack}"` interpolates to the store path at **build time** and is hardcoded into the systemd unit. This is actually **correct** for NixOS — the derivation path is baked into the unit at build time. The question is how this works:

Actually, in NixOS module system: `config.services.minecraft-curseforge.<name>.finalPack` is a derivation. When used in `script` or `ExecStartPre`, the string context is captured and the derivation becomes a build dependency. The string interpolation `${cfg.finalPack}/.image-id` happens at eval time and produces a literal store path. This IS correct.

But wait — tpol-xai's concern might be different: if the module uses `"${finalPack}"` in a shell script that's itself a derivation (like `pkgs.writeShellScript`), then the path is captured at build time of that script. If it's used inline in the systemd unit definition, NixOS handles it.

**Assessment:** This should work correctly in NixOS since NixOS's module system handles derivation-to-string conversion properly. But worth verifying during implementation.

## 4. Hardcoded Filenames (MAJOR)

**Finding (tuvok-deepseek, bellana-minimax):** The builder assumes:
- `server-setup.sh` exists and is the setup script
- `start.sh` exists and is the launcher
- `server.jar` exists and is the server binary

**Reality:** Modpacks vary wildly:
- Setup scripts may be: `ServerStart.sh`, `LaunchServer.sh`, `start_server.sh`, or may not exist (some need manual setup)
- Some modpacks are Windows-only (no `.sh` at all — `ServerStart.bat`, `start.ps1`)
- Launcher JARs may be `forge.jar`, `neoforge.jar`, `fabric-server-launch.jar`, etc.
- Some modpacks use a bundled Java runtime

**Fix options:**
- (A) Make these filenames configurable as builder parameters
- (B) Probe for common patterns in the build script and fail with a clear error if none found
- (C) Require a patches directory where the user can override any file

**Recommended:** Start with option (B) for simplicity — probe for common filenames, fail with clear diagnostics. Option (A) can be added later. Option (C) is over-engineering at this stage.

## 5. rsync Semantics & Edge Cases (MAJOR)

**Findings (tpol-xai, tuvok-deepseek, bellana-minimax):**

**5a. rsync --delete with exclusions:** The `--exclude=/world --exclude=/backups` pattern with `--delete` means:
- If `world/` doesn't exist in the source (it won't — we excluded it), it won't be deleted on the target. Correct.
- BUT: leading `/` means anchored to the transfer root. With `"${finalPack}/" "${dataDir}/"`, the transfer root is effectively `$dataDir`. So `--exclude=/world` correctly anchors to `$dataDir/world`. This is correct.

**5b. First-deploy directory creation:** If `dataDir` doesn't exist yet, `rsync` will error. Need `mkdir -p "$dataDir"` in the script BEFORE `rsync`.

**5c. rsync ownership:** Files created by rsync will have the user's default (root on the initial run, since ExecStartPre runs as root). The service runs as a dedicated user. Need `--chown` or a `chown -R` after rsync, OR ensure rsync runs as the service user via `User=` in the systemd unit... but ExecStartPre inherits the unit's user. If the unit has `User=minecraft-<name>`, then rsync runs as that user. But `dataDir` needs to be writable by that user, which tmpfiles handles.

**5d. rsync race condition (tuvok-deepseek):** If the service restarts mid-rsync, `dataDir` is in an inconsistent state. Systemd's `ExecStartPre` isn't atomic. Mitigation: use a temp dir and `mv` for atomic swap, OR accept the risk (re-running rsync is idempotent).

## 6. ExecStop Backup Gaps (MAJOR)

**Findings (tpol-xai, tpol-gpt):**
- ExecStop runs on `systemctl stop`, `restart`, and `nixos-rebuild switch` (if the unit is restarted)
- ExecStop does NOT run on: crash, OOM kill, `SIGKILL`, power loss
- 100% retention with no rotation will fill the disk
- Large worlds + `tar czf` during ExecStop may hit systemd's default timeout (90s)

**Fixes:**
- Document the backup gap explicitly — this is not a backup solution, it's a convenience hook
- Add a warning or documentation note about disk usage
- Consider adding an option for max backups to keep
- Consider using `ExecStopPost` instead (runs on all stops including failure, but still not on hard crash)

## 7. Arbitrary Code Execution in Builder (CRITICAL)

**Finding (tuvok-deepseek):** `bash server-setup.sh` runs code downloaded from CurseForge. While fixed-output derivation mitigates this (the output hash must match), during the build the script has arbitrary network access (by design — it's a fixed-output derivation) and can do anything.

**Mitigation:** This is an accepted risk of the fixed-output derivation model. The output hash verification ensures you get exactly what you expect. Document this as a trust boundary — the user must verify the `outputHash` matches a trusted source.

## 8. Multiple Instances & Resource Conflicts (MEDIUM)

**Findings (tpol-xai, tuvok-deepseek):**
- Port conflicts: default `25565` for all instances. Need cross-instance port validation.
- DataDir uniqueness: need to assert `dataDir` values are unique across instances on the same machine.
- Memory oversubscription: multiple instances could sum to more memory than available. This is a user responsibility, but worth documenting.

**Recommended fixes:**
- Add a module assertion to warn on conflicting ports and dataDirs
- Document memory planning guidelines

## 9. Patch Phase vs ExecStart JRE Strategy (MEDIUM)

**Findings (tpol-gpt, tpol-xai cross-discussion):** Two competing approaches:

**A (Current):** Hardcode JRE path in start.sh at build time (`${jre}/bin/java` in patchPhase → becomes a store path in the script).
**B (Alternative):** Use JRE from PATH at runtime (add JRE to systemd unit's `PATH` or use an environment variable).

**Trade-off:**
- (A) Explicit closure = guaranteed JRE availability, but fragile (relies on text reference scanning)
- (B) Runtime PATH = cleaner separation, but JRE is a runtime dependency of the systemd unit (handled through NixOS module options)

**Recommendation:** Keep (A) for now — it's the standard Nix approach. But ensure the overlay also has `jre` in `buildInputs` for explicit closure propagation.

## 10. cp -ra Store Duplication (MEDIUM)

**Finding (bellana-minimax, tpol-gpt):** The overlay's `cp -ra "$src" "$out"` creates a full copy of the builder output in the store. For large modpacks (5GB+), this doubles the store size.

**Alternatives:**
- `symlinkJoin` — creates a symlink tree referencing the original store path. Cheaper but more complex.
- `buildEnv` — similar to symlinkJoin.
- Keep `cp -ra` until optimization is needed. Store deduplication via hardlinks means nix may already handle this efficiently (nix uses hardlinks in the store).

**Recommendation:** Keep `cp -ra` for now. If store bloat becomes an issue, switch to `symlinkJoin`.

## 11. Miscellaneous MINOR Issues

| Issue | Agent | Description |
|-------|-------|-------------|
| EULA assertion | tpol-xai | Warn when `enable = true` but `acceptEula = false` |
| Module naming | tpol-gpt | `minecraft-curseforge` may be too specific; consider `minecraft-server` |
| Interactive scripts | tuvok-deepseek | Some server-setup.sh need `yes y | ...` or `DEBIAN_FRONTEND=noninteractive` |
| image-id collision | tuvok-deepseek | `basename $src` from fetchurl — collisions improbable but possible |
| Builder timeout | bellana-minimax | Nix sandbox has build timeout; large modpacks may exceed it |
| Output hash workflow | bellana-minimax | Chicken-and-egg for first fixed-output build; document the workflow |
| backup retention | tpol-gpt | Need a max-backups option or external cleanup strategy |
| Topology integration | tpol-gpt | Future: wire into topology system |
| State beyond world/ | tuvok-deepseek | Some mods write state to config/, logs/, etc. at runtime |

---

---

## Planning Session Complete

**Date:** 2026-06-01
**Outcome:** All four agent reviews compiled, critical structural errors corrected,
major concerns addressed in documentation. The architecture is now ready for
implementation.

**Objective for Development:** Implement the 5-phase plan in order, beginning
with Phase 1 (`pkgs/minecraft-curseforge/default.nix` builder derivation).
Key architectural invariants to preserve:
- Single `buildPhase` (no `patchPhase` — patchPhase runs before buildPhase in Nix)
- JRE in `buildInputs` of BOTH builder and overlay for closure propagation
- `.image-id` marker for update detection (passthru + file)
- Module assertions for port/dataDir uniqueness and EULA acceptance
- ExecStop as convenience hook only (document the gap)
- rsync with `--chown` and `--exclude=/world --exclude=/backups`

## Updated Fix-Action Plan (Priority Order)

### BLOCKING (must fix before any implementation)

1. **patchPhase ordering** — Replace `patchPhase` with `postBuild` or merge into `buildPhase`
2. **JRE closure** — Add `jre` to overlay's `buildInputs`

### PRE-IMPLEMENTATION (fix in documents before coding)

3. **Hardcoded filenames** — Make setup script/start script configurable or probe for patterns
4. **rsync directory creation** — Add `mkdir -p "$dataDir"` before rsync
5. **ExecStop documentation** — Document backup gaps (crash, OOM, SIGKILL, power loss)
6. **Builder builder code example** — Fix the example to have correct phase ordering (single buildPhase)

### IMPLEMENTATION-TIME (address while coding)

7. **Port conflict assertion** — Module assertion for unique ports across instances
8. **DataDir uniqueness assertion** — Module assertion for unique dataDirs 
9. **EULA warning** — Module assertion when enable=true but acceptEula=false
10. **rsync ownership** — `--chown` or `chown` after rsync, or run as service user
11. **Backup timeout** — Consider increasing ExecStop timeout or using background tar

### POST-IMPLEMENTATION (optimization/extension)

12. **Modpack filename probing** — Auto-detect setup/start script patterns
13. **symlinkJoin optimization** — Replace `cp -ra` if store bloat is an issue
14. **Backup retention policy** — Add `maxBackups` option
15. **Topology integration** — Wire into topology system

