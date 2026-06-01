# Minecraft Hosting Module — 5-Phase Implementation Plan

**Companion to:** `session-status-2026-06-01.md`
**Date:** 2026-06-01
**Branch:** `feat/minecraft-hosting-module`
**Worktree:** `/tmp/nixos-minecraft-hosting`

## Status: PLANNING COMPLETE → READY FOR DEVELOPMENT

Planning reviews (4 agents) completed 2026-06-01. All critical structural
errors corrected (patchPhase ordering, JRE closure propagation). Major
concerns addressed and documented. Ready to begin Phase 1 implementation.

**Next action:** Create `pkgs/minecraft-curseforge/default.nix` with the
corrected builder derivation.

---

## Phase 1: Builder Derivation

**Goal:** Create the fixed-output derivation (`pkgs/minecraft-curseforge/default.nix`)
that fetches a CurseForge server pack, extracts it, runs setup, patches the
start script, and outputs the immutable server fabric.

### Step 1.1 — Scaffold the builder structure
- Create `pkgs/minecraft-curseforge/default.nix`
- Define the function signature: `{ stdenv, fetchurl, jdk21, lib }` → `{ name, src, jre ? jdk21, outputHash }`
- Set `outputHashMode = "recursive"` for fixed-output semantics
- Derive `imageId = builtins.baseNameOf src` and expose via `passthru = { inherit imageId; }`

### Step 1.2 — Implement buildPhase (single phase, correct ordering)
**CRITICAL NOTE:** In Nix's `mkDerivation`, `patchPhase` runs BEFORE `buildPhase`.
Therefore ALL work must go in `buildPhase` (with optional `postBuild` for
post-extraction steps). Do NOT use `patchPhase` for start.sh rewriting.

- `unzip "$src" -d "$out"` — extract the modpack zip
- Probe for setup script: try `server-setup.sh`, `ServerStart.sh`, `LaunchServer.sh`, etc.
  Fail with a clear error if no recognized setup script is found
- `bash <detected-setup-script>` — run setup (use `yes |` prefix for interactive scripts)
- `rm -f "$out/eula.txt" "$out/server.properties"` — strip module-owned files

### Step 1.3 — Implement postBuild (nix-aware start script + image-id)
**Uses `postBuild`** (runs after `buildPhase`, unlike `patchPhase` which runs before).

- Rewrite the modpack's `start.sh` as a wrapper that invokes `${jre}/bin/java`
  - Handle edge case: if `start.sh` doesn't exist, create it from scratch
  - If `ServerStart.sh` or other launcher is the entry point, patch that instead
- Accept `JAVA_MAX_MEM`, `JAVA_MIN_MEM`, `JAVA_OPTS` as environment variables
- Write `.image-id` file with `echo -n "${imageId}" > "$out/.image-id"`
- Parameterize setup script name as a builder argument: `setupScript ? "server-setup.sh"`

### Step 1.4 — Verify builder purity boundaries
- Confirm no eula.txt or server.properties leak into output
- Confirm JRE is in `buildInputs` (not `nativeBuildInputs`) so it's in the runtime closure
- Confirm `outputHash` is the sole network-escape mechanism
- Confirm passthru.imageId is accessible without building the derivation

### Step 1.5 — Write unit-level test for builder
- Create `tests/minecraft-curseforge-builder.nix`
- Test with a minimal dummy zip (not a real modpack) to verify the build structure
- Verify `.image-id` content matches `builtins.baseNameOf src`
- Verify `start.sh` contains the nix store path to the JRE

---

## Phase 2: Module Overlay Derivation

**Goal:** Implement the pure derivation within the NixOS module that takes
the builder output and overlays `eula.txt` + `server.properties`, producing
the final deployable server image.

### Step 2.1 — Define the overlay function
- Create a function `mkFinalPack = { name, pack, jre, acceptEula, serverProperties }:`
- Use `stdenv.mkDerivation` (pure, no fixed-output)
- `src = pack` — the builder's output is the input
- **CRITICAL: Add `buildInputs = [ jre ]`** — even though this is a "pure copy,"
  `start.sh` contains a text reference to `${jre}/bin/java` (embedded by the builder).
  Nix's reference scanner finds this in the copied output, but adding `jre` to
  `buildInputs` makes the dependency explicit and ensures closure propagation.
- Output should be named `minecraft-server-final-${name}`

### Step 2.2 — Implement overlay buildPhase
- `cp -ra "$src" "$out"` — replicate everything from the builder
- `echo eula=true > "$out/eula.txt"` — only when `acceptEula = true`
- Write `server.properties` from the module options using `lib.generators.toKeyValue`
- Confirm `.image-id` propagates (it's part of the `cp -ra` from the builder)

### Step 2.3 — Handle EULA edge cases
- When `acceptEula = false`: do NOT write eula.txt at all. Server will refuse to start, which is correct behavior
- When `acceptEula = true`: write `eula=true` (Mojang's required format)
- Consider logging/warning when a Minecraft server is enabled but EULA not accepted

### Step 2.4 — Handle server.properties parameterization
- Map module-level `serverProperties` attrs to INI-style key=value pairs
- Ensure `server.properties` uses `\n` line endings (Minecraft is lenient, but some mods may care)
- Ensure rcon settings are included: `enable-rcon=true`, `rcon.port`, `rcon.password`

### Step 2.5 — Verify the overlay derivation
- Confirm the overlay produces a derivation distinct from the builder
- Confirm `builtins.readFile "${finalPack}/.image-id"` matches the original
- Confirm `builtins.readFile "${finalPack}/eula.txt"` exists only when acceptEula
- Confirm the derivation builds without network access (pure)

---

## Phase 3: Systemd Service — Deployment Lifecycle

**Goal:** Implement the NixOS module's systemd service configuration covering
world backup (ExecStop), image instantiation (ExecStartPre), server launch
(ExecStart), and state retention.

### Step 3.1 — Define the systemd service skeleton
- `systemd.services.minecraft-curseforge-${name}` with standard game server pattern:
  - `wantedBy = [ "multi-user.target" ]`
  - `after = [ "network-online.target" ]`
  - `wants = [ "network-online.target" ]`
  - `Restart = "always"`, `RestartSec = 15`
- Reference `finalPack` (from Phase 2), not `pack` (from Phase 1)

### Step 3.2 — Implement ExecStart: server launch
- `ExecStart = "${dataDir}/start.sh"`
- Pass `JAVA_MAX_MEM`, `JAVA_MIN_MEM`, `JAVA_OPTS` as environment variables
- Set `WorkingDirectory = dataDir` so world/ and logs/ land correctly
- Set `User` and `Group` to the instance-specific service user

### Step 3.3 — Implement ExecStartPre: image instantiation
- Read `.image-id` from the final derivation in the nix store
- Compare against `dataDir/.image-id`
- First-deploy case: `mkdir -p "${dataDir}"` before anything else
- On mismatch: `rsync -a --delete --exclude=/world --exclude=/backups --chown=<user>:<group> "${finalPack}/" "${dataDir}/"`
- Write the new `.image-id` to `dataDir/.image-id`
- Note: rsync race on restart is accepted (re-running is idempotent)
- Note: `string interpolation of "\${finalPack}"` in ExecStartPre scripts works correctly
  in NixOS — the derivation path is baked into the unit at build time.

### Step 3.4 — Implement ExecStop: world backup
- `ExecStop` runs a bash script that:
  - Checks `dataDir/world` exists
  - Creates `dataDir/backups/` if absent
  - `tar czf "dataDir/backups/world-$(date +%Y%m%d-%H%M%S).tar.gz" -C dataDir world`
- **Does NOT run on:** crash, OOM kill, SIGKILL, power loss — document this gap
- **100% retention, no rotation** — module owner manages disk externally
- **Performance note:** Large worlds may exceed systemd's default ExecStop timeout (90s).
  Consider `TimeoutStopSec` configuration.

### Step 3.5 — System user + tmpfiles + firewall + assertions
- `users.users.minecraft-${name}` with `isSystemUser = true`, `home = dataDir`, `createHome = true`
- `users.groups.minecraft-${name}` matching
- `systemd.tmpfiles.rules` for `dataDir`, `dataDir/backups`
- `networking.firewall` rules when `openFirewall = true` (game port)
- `environment.systemPackages` to include `mcrcon` on the target machine
- **Module assertions:**
  - AcceptEula must be true when enable is true
  - No duplicate gamePort across instances on same machine
  - No duplicate dataDir across instances on same machine

---

## Phase 4: NixOS Integration

**Goal:** Wire the module into the NixOS flake, register the builder package,
and create the per-machine configuration that consumes both.

### Step 4.1 — Register builder in flake.nix
- Add `minecraft-curseforge = nixpkgs.callPackage ./pkgs/minecraft-curseforge { };` to the package exports
- Ensure it's in the `packages.x86_64-linux` attribute set
- Confirm it's callPackage-compatible: `{ stdenv, fetchurl, jdk21, lib }` → function

### Step 4.2 — Create initial modpack definitions
- Create `pkgs/minecraft-curseforge/packs/atm10.nix`:
  ```nix
  { minecraft-curseforge, fetchurl }:
  minecraft-curseforge {
    name = "atm10";
    src = fetchurl { url = "https://..."; hash = "..."; };
    outputHash = "sha256-...";
  }
  ```
- Follow the same pattern for other target modpacks
- Leave hashes as placeholders (to be filled when URLs are obtained)

### Step 4.3 — Wire module into target machine config
- On the gaming host machine, add:
  ```nix
  imports = [ ../../server_services/game_servers/minecraft-curseforge.nix ];
  ```
- Configure an instance with the modpack derivation, EULA acceptance, server properties
- Set `dataDir`, `maxMemory`, `gamePort`, etc.

### Step 4.4 — Test the full build chain
- `nix build .#nixosConfigurations.<gaming-host>.config.services.minecraft-curseforge.<name>.finalPack`
- Verify the builder builds (network fetch, fixed-output)
- Verify the overlay builds (pure, no network)
- Verify `.image-id` consistency across the chain

### Step 4.5 — Document the modpack-add workflow
- Write concise instructions for adding a new modpack:
  1. Find the CurseForge server pack URL
  2. `nix run nixpkgs#nix-prefetch-url -- <url>` to get the hash
  3. Create a new pack file following the template
  4. First build will fail with the output hash — use the suggested hash
  5. Set `acceptEula = true`, configure server.properties
  6. Deploy

---

## Phase 5: Modpack Definitions & Validation

**Goal:** Build and validate three real modpack definitions, test the
deployment lifecycle (including update scenarios), and confirm world
preservation.

### Step 5.1 — Resolve CurseForge URLs for all three target packs
- Obtain direct download URLs for:
  - All the Mods 10 (server pack)
  - ATM 10 to the Sky (server pack)
  - All the Mons (server pack)
- Prefetch each URL to get the `sha256` hash
- Create pack files with real hashes

### Step 5.2 — Build all three modpacks
- `nix build .#minecraft-curseforge-atm10`
- `nix build .#minecraft-curseforge-atm10-to-the-sky`
- `nix build .#minecraft-curseforge-all-the-mons`
- Verify each produces a valid server directory with `server.jar`, `mods/`, etc.
- Verify each has `.image-id`, patched `start.sh`, no `eula.txt`/`server.properties`

### Step 5.3 — Simulate first-deploy lifecycle
- Deploy a test machine with one modpack
- Verify ExecStartPre creates dataDir and populates it
- Verify server starts and generates `world/`
- Verify `world/` is in dataDir, not in nix store
- Verify ExecStop creates a `.tar.gz` in `backups/`

### Step 5.4 — Simulate update lifecycle
- Change a server.properties option and rebuild
- Verify new overlay derivation is built
- Verify ExecStartPre detects `.image-id` change and reruns rsync
- Verify `world/` and `backups/` survive the rsync sweep
- Verify the server starts with the new server.properties

### Step 5.5 — Final integration validation
- Run the golden test suite (if applicable to the target machine)
- Verify `nix flake check` passes
- Verify `nix build .#nixosConfigurations.<machine>.config.system.build.toplevel`
- Commit all changes to the `feat/minecraft-hosting-module` branch

---

## Summary Table

| Phase | Focus | Key Output | Build Type |
|---|---|---|---|
| 1 | Builder Derivation | `pkgs/minecraft-curseforge/default.nix` | Fixed-output (network) |
| 2 | Module Overlay | Overlay function in NixOS module | Pure (no network) |
| 3 | Systemd Service | ExecStop/ExecStartPre/ExecStart | Deploy-time |
| 4 | NixOS Integration | flake.nix wiring + machine config | Build-time |
| 5 | Modpack Definitions | Three real modpack files + validation | Build + Deploy |

