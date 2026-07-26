# F6: Convert `${pkgs.foo}/bin/foo` → `lib.getExe` — Execution Plan

**Date:** 2026-07-25
**Status:** EXECUTING
**Audit:** `/speed-storage/opencode/documentation/2026-07-25-F6-REVIEW/getExe-audit.md`
**Scope:** 28 convertible instances (22 `lib.getExe`, 6 `lib.getExe'`). 7 NOT APPLICABLE excluded. No deduplication (deferred).

---

## Phase 1: Systemd ExecStart + Script Bodies (machines/)

**Goal:** Convert all instances in `machines/` directory.

### Step 1.1: LINDA machine (6 instances)

**Files:** `machines/LINDA/default.nix`
**Lines:** 153, 156, 212, 223, 234, 306
**Conversions:**
- 153,156: `${pkgs.iproute2}/bin/ip` → `${lib.getExe pkgs.iproute2}`
- 212: `${pkgs.obsidian}/bin/obsidian` → `${lib.getExe pkgs.obsidian}`
- 223: `${pkgs.dino}/bin/dino` → `${lib.getExe pkgs.dino}`
- 234: `${pkgs.discord}/bin/discord` → `${lib.getExe pkgs.discord}`
- 306: `${pkgs.xrandr}/bin/xrandr` → `${lib.getExe pkgs.xrandr}`

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/machines/LINDA/default.nix`. Convert 6 instances of `${pkgs.X}/bin/X` to `${lib.getExe pkgs.X}`. Lines 153, 156 (iproute2→ip), 212 (obsidian), 223 (dino), 234 (discord), 306 (xrandr). Verify `lib` is in scope. Commit with message "refactor: convert LINDA getExe patterns".

**Success criteria:** All 6 instances converted, file evaluates, no new warnings.

### Step 1.2: Other machines (4 instances)

**Files:**
- `machines/cortex-alpha/default.nix:125` — ethtool
- `machines/alpha-two/default.nix:40` — xwinwrap (script body)
- `environments/communications.nix:15` — mumble
- `modifier_imports/vnc-server.nix:10` — x11vnc

**Conversions:**
- cortex-alpha: `${pkgs.ethtool}/bin/ethtool` → `${lib.getExe pkgs.ethtool}`
- alpha-two: `${pkgs.xwinwrap}/bin/xwinwrap` → `${lib.getExe pkgs.xwinwrap}`
- communications: `${pkgs.mumble}/bin/mumble` → `${lib.getExe pkgs.mumble}`
- vnc-server: `${pkgs.x11vnc}/bin/x11vnc` → `${lib.getExe pkgs.x11vnc}`

**Prompt for bellana-deepseek:**
> Edit 4 files to convert `${pkgs.X}/bin/X` to `${lib.getExe pkgs.X}`. Ensure `lib` is in scope in each file. Commit with message "refactor: convert machine/environment getExe patterns".

**Success criteria:** All 4 instances converted, all files evaluate.

### Step 1.3: ExecStart definitions (2 instances)

**Files:**
- `locale/input-methods.nix:127` — fcitx5
- `machines/LINDA/default.nix:243` — scream (already in LINDA, do with Step 1.1)

**Conversions:**
- input-methods: `"${pkgs.fcitx5}/bin/fcitx5"` → `"${lib.getExe pkgs.fcitx5}"`
- LINDA:243: `"${pkgs.scream}/bin/scream"` → `"${lib.getExe pkgs.scream}"`

**Prompt for bellana-deepseek:**
> Edit `locale/input-methods.nix:127` to convert `${pkgs.fcitx5}/bin/fcitx5` to `${lib.getExe pkgs.fcitx5}`. Also convert LINDA:243 scream instance if not already done in Step 1.1. Commit with message "refactor: convert ExecStart getExe patterns".

**Success criteria:** All ExecStart instances converted.

### Phase 1 Verification Gate

**Validator:** tpol-minimax
**Criteria:**
- All 12 instances in machines/environments/modifier_imports converted
- `lib` is in scope in all edited files
- No functional changes (same binary paths produced)
- Files evaluate without error

---

## Phase 2: Game Servers + Core Router

**Goal:** Convert instances in `server_services/` and `modules/`.

### Step 2.1: Game servers (4 instances)

**Files:**
- `server_services/game_servers/dragonwilds.nix:57` — steam-run
- `server_services/game_servers/terratech.nix:336` — steam-run
- `server_services/game_servers/terratech.nix:337` — wineWow64Packages.stable → wine64 (default binary)
- `server_services/game_servers/terratech.nix:338` — wineWow64Packages.stable → wineboot (**needs `lib.getExe'`**)

**Conversions:**
- dragonwilds:57: `"${pkgs.steam-run}/bin/steam-run"` → `"${lib.getExe pkgs.steam-run}"`
- terratech:336: `"${pkgs.steam-run}/bin/steam-run"` → `"${lib.getExe pkgs.steam-run}"`
- terratech:337: `"${pkgs.wineWow64Packages.stable}/bin/wine64"` → `"${lib.getExe pkgs.wineWow64Packages.stable}"`
- terratech:338: `"${pkgs.wineWow64Packages.stable}/bin/wineboot"` → `"${lib.getExe' pkgs.wineWow64Packages.stable "wineboot"}"`

**Prompt for bellana-deepseek:**
> Edit `server_services/game_servers/dragonwilds.nix` and `server_services/game_servers/terratech.nix`. Convert 4 instances. CRITICAL: terratech:338 uses `wineboot` which is NOT the default binary — use `lib.getExe' pkgs.wineWow64Packages.stable "wineboot"` (with prime). Ensure `lib` is in scope. Commit with message "refactor: convert game server getExe patterns".

**Success criteria:** All 4 instances converted. `wineboot` uses `getExe'` not `getExe`.

### Step 2.2: Core router (1 instance)

**File:** `modules/core-router.nix:66`

**Conversion:**
- `"${pkgs.ethtool}/bin/ethtool"` → `"${lib.getExe pkgs.ethtool}"`

**Prompt for bellana-deepseek:**
> Edit `modules/core-router.nix:66` to convert `${pkgs.ethtool}/bin/ethtool` to `${lib.getExe pkgs.ethtool}`. Verify `lib` is in scope. Commit with message "refactor: convert core-router getExe pattern".

**Success criteria:** Instance converted, `lib` in scope.

### Step 2.3: Energy saving (1 instance)

**File:** `modifier_imports/energy_saving.nix:19`

**Conversion:**
- `"${pkgs.hdparm}/bin/hdparm"` → `"${lib.getExe pkgs.hdparm}"`

**Note:** This is inside a udev rule string. Verify the conversion works in that context.

**Prompt for bellana-deepseek:**
> Edit `modifier_imports/energy_saving.nix:19` to convert `${pkgs.hdparm}/bin/hdparm` to `${lib.getExe pkgs.hdparm}`. This is inside a udev RUN+ rule string — verify the Nix interpolation still produces a valid absolute path. Commit with message "refactor: convert energy_saving getExe pattern".

**Success criteria:** Instance converted, udev rule still produces valid path.

### Phase 2 Verification Gate

**Validator:** tpol-minimax
**Criteria:**
- All 6 instances converted
- `wineboot` correctly uses `getExe'`
- `energy_saving.nix` udev rule produces valid path
- Files evaluate without error

---

## Phase 3: Library Code + Credential Scripts

**Goal:** Convert instances in `lib/`, `services/`, and credential scripts.

### Step 3.1: Library code (4 instances)

**Files:**
- `lib/rclone-target.nix:127,129` — rclone (×2)
- `lib/make-storeless-image.nix:562,563` — qemu-img (×2)

**Conversions:**
- rclone-target:127: `"${pkgs.rclone}/bin/rclone` → `"${lib.getExe pkgs.rclone}`
- rclone-target:129: same
- make-storeless-image:562,563: `${pkgs.qemu-utils}/bin/qemu-img` → `${lib.getExe pkgs.qemu-utils}`

**Prompt for bellana-deepseek:**
> Edit `lib/rclone-target.nix` (lines 127, 129) and `lib/make-storeless-image.nix` (lines 562, 563). Convert 4 instances of `${pkgs.X}/bin/X` to `${lib.getExe pkgs.X}`. Ensure `lib` is in scope in both files. Commit with message "refactor: convert lib getExe patterns".

**Success criteria:** All 4 instances converted, `lib` in scope.

### Step 3.2: Dynamic domain (1 instance)

**File:** `services/dynamic_domain_gandi.nix:31`

**Conversion:**
- `${pkgs.coreutils}/bin/cat` → `${lib.getExe' pkgs.coreutils "cat"}`

**Note:** `cat` is NOT the default binary of `coreutils`. Must use `getExe'`.

**Prompt for bellana-deepseek:**
> Edit `services/dynamic_domain_gandi.nix:31` to convert `${pkgs.coreutils}/bin/cat` to `${lib.getExe' pkgs.coreutils "cat"}`. CRITICAL: use `getExe'` (with prime) because `cat` is not the default binary of `coreutils`. Verify `lib` is in scope. Commit with message "refactor: convert dynamic_domain getExe pattern".

**Success criteria:** Instance uses `getExe'` with explicit `"cat"`.

### Step 3.3: Credential scripts — gnused→sed (6 instances)

**Files:**
- `services/gitlab-credentials.nix:14,17`
- `services/github-runner-nixos-config.nix:26,29`
- `services/mkRunners.nix:33,34`

**Conversions:**
- All 6: `${pkgs.gnused}/bin/sed` → `${lib.getExe' pkgs.gnused "sed"}`

**Note:** `sed` is NOT the default binary of `gnused`. Must use `getExe'`.

**Prompt for bellana-deepseek:**
> Edit 3 files to convert 6 instances of `${pkgs.gnused}/bin/sed` to `${lib.getExe' pkgs.gnused "sed"}`. CRITICAL: use `getExe'` (with prime) because `sed` is not the default binary of `gnused`. Files: `services/gitlab-credentials.nix` (lines 14, 17), `services/github-runner-nixos-config.nix` (lines 26, 29), `services/mkRunners.nix` (lines 33, 34). Verify `lib` is in scope in each file. Commit with message "refactor: convert credential script getExe patterns".

**Success criteria:** All 6 instances use `getExe'` with explicit `"sed"`. `lib` in scope in all 3 files.

### Phase 3 Verification Gate

**Validator:** tpol-minimax
**Criteria:**
- All 11 instances converted
- `coreutils→cat` and `gnused→sed` correctly use `getExe'`
- `rclone-target.nix` and `make-storeless-image.nix` evaluate
- No functional changes

---

## Phase 4: Test Assertions + Final Verification

**Goal:** Convert test instances and run full verification.

### Step 4.1: Test assertions (2 instances)

**File:** `tests/minecraft-server/default.nix:88,104`

**Conversions:**
- 88: `"${pkgs.mcrcon}/bin/mcrcon` → `"${lib.getExe pkgs.mcrcon}`
- 104: same

**Prompt for bellana-deepseek:**
> Edit `tests/minecraft-server/default.nix` (lines 88, 104) to convert `${pkgs.mcrcon}/bin/mcrcon` to `${lib.getExe pkgs.mcrcon}`. Verify `lib` is in scope. Commit with message "refactor: convert test assertion getExe patterns".

**Success criteria:** Both instances converted, `lib` in scope.

### Step 4.2: Final verification

**Validator:** tpol-minimax
**Criteria:**
- All 28 convertible instances confirmed converted
- `nix run .#checks.x86_64-linux.deadnix --option builders ''` passes
- `nix run .#checks.x86_64-linux.formatting --option builders ''` passes
- Spot-check 3 files produce identical binary paths before/after

---

## Execution Summary

| Phase | Instances | Files | Key Risk |
|-------|-----------|-------|----------|
| 1: Machines | 12 | 7 | `lib` scope in all files |
| 2: Services | 6 | 4 | `wineboot` needs `getExe'`, udev rule context |
| 3: Libraries | 11 | 5 | `cat` and `sed` need `getExe'` |
| 4: Tests | 2 | 1 | `lib` scope |
| **Total** | **28** | **14** | |
