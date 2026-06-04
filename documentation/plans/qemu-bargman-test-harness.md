# Plan: QEMU Test Harness for Bargman Assets

**Date:** 2026-06-02
**Branch:** `feat/bargman-qemu-test-harness`
**Status:** Draft
**Objective:** Add a virtualised QEMU output to NixOS-Configuration that can boot the bargman-greeter theme in a VM for safe development and testing — preventing another black-screen incident on bare metal.

---

## Problem Statement

The bargman-cinematic LightDM webkit2 greeter theme was deployed to bare-metal machines (`LINDA`, `alpha-one`, `alpha-two`, `alpha-three`, `terminal-nx-01`) via `environments/i3wm_darthpjb.nix`. The greeter rendered a black screen at runtime — no login prompt, no error — locking the user out. There was no way to test the greeter in isolation before deploying.

---

## Design Pattern: QEMU VM Testing with NixOS

The approach follows the standard NixOS VM testing pattern:

```nix
# 1. Import "${modulesPath}/virtualisation/qemu-vm.nix" for QEMU support
# 2. Configure virtualisation.{memorySize, diskSize, cores, qemu.options}
# 3. Use system.build.vm to get a runnable QEMU VM
# 4. Use testers.runNixOSTest for automated integration tests with screenshot comparison
# 5. Expose as flake apps/packages/checks
```

Key NixOS modules and functions used:
- `<nixpkgs>/nixos/modules/virtualisation/qemu-vm.nix` — enables `system.build.vm`
- `testers.runNixOSTest` — NixOS integration test framework
- `pkgs.nixosTest` — alternative test runner
- `machine.screenshot()` — captures framebuffer as PNG
- `machine.wait_for_unit("display-manager.service")` — waits for LightDM

---

## Reference: bargman-assets Flake

**Remote:** `git+ssh://git@gitlab.com/mecha-team-zero/bargman-assets.git?ref=main`
**Locked in:** `/speed-storage/repo/DarthPJB/NixOS-Configuration/flake.lock`

### Available Packages (from bargman-assets flake.nix)

| Package | Purpose |
|---------|---------|
| `lightdm-theme-bargman-cinematic` | Webkit2 greeter theme (HTML/CSS/JS + background PNG + SVG logos) |
| `cinnamon-theme-bargman-cinematic` | Cinnamon desktop GTK theme (cinnamon.css, panel.css, gtk-3.0/, gtk-4.0/) |
| `cursor-theme-bargman-cinematic` | X cursor theme (SVG + PNG at 24px/48px) |
| `plymouth-theme-boot` | Boot splash (60 animation frames) |
| `plymouth-theme-shutdown` | Shutdown splash (36 animation frames) |
| `grub-theme-cinematic` | GRUB bootloader theme |
| `bargman-icon-theme` | Icon theme |
| `cinnamon-images` | Wallpapers, login background, menu icon, GRUB splash |
| `logos` | Brand logos (SVG + PNG) |

### LightDM Theme Structure

```
lightdm-theme-bargman-cinematic/
  default.nix          # stdenvNoCC.mkDerivation, installs to share/lightdm-webkit/themes/bargman-cinematic/
  index.html           # Login UI: username/password form, predefined user card, touch ID zone
  style.css            # Theme styling
  script.js            # Login logic, session switching, i18n (EN/中文)
  login-bg-4k.png      # Background image
  Bargman-Logo_Horizontal.svg
  Variant=Outline.svg
```

---

## Existing NixOS-Configuration Patterns

### Current Image Builder Infrastructure

| File | Purpose |
|------|---------|
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/flake.nix` (line 124) | `mkLibVirtImage` — wraps `make-disk-image.nix` for qcow2 output |
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/lib/make-storeless-image.nix` | Custom disk image builder with LKL, partition support, deterministic builds |
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/modifier_imports/virtualisation-libvirtd.nix` | libvirtd + QEMU config (swtpm, runAsRoot) |

### Current Bargman Greeter Chain

| File | Status | Purpose |
|------|--------|---------|
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/bargman-greeter.nix` | **DISABLED** (commented out) | Configures lightdm-webkit2 with bargman-cinematic theme |
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/i3wm_darthpjb.nix` | Active (greeter disabled) | Imports bargman-greeter.nix — currently commented out |
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/i3wm.nix` | Active | Base i3wm + lightdm enable |
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/modules/lightdm-webkit2-greeter.nix` | Active | Custom NixOS module for webkit2 greeter options |
| `/speed-storage/repo/DarthPJB/NixOS-Configuration/pkgs/lightdm-webkit2-greeter.nix` | Active | MerkeX fork v2.2.5 package |

### Machines Using i3wm_darthpjb (Affected by Bargman Greeter)

- `LINDA` — `/speed-storage/repo/DarthPJB/NixOS-Configuration/machines/LINDA/default.nix`
- `alpha-one` — `/speed-storage/repo/DarthPJB/NixOS-Configuration/machines/alpha-one/default.nix`
- `alpha-two` — `/speed-storage/repo/DarthPJB/NixOS-Configuration/machines/alpha-two/default.nix`
- `alpha-three` — `/speed-storage/repo/DarthPJB/NixOS-Configuration/machines/alpha-three/default.nix`
- `terminal-nx-01` — `/speed-storage/repo/DarthPJB/NixOS-Configuration/machines/terminal-nx-01/default.nix`

---

## Proposed Architecture

### Data Flow

```
environments/bargman-greeter.nix  (theme config — re-enabled for VM only)
         ↓
environments/bargman-greeter-vm.nix  (NEW: imports bargman-greeter + qemu-vm.nix)
         ↓
flake.nix → nixosConfigurations.bargman-greeter-vm  (NEW)
         ↓
├── packages.x86_64-linux.bargman-greeter-vm            → system.build.vm
├── packages.x86_64-linux.bargman-greeter-vm-bootloader  → system.build.vmWithBootLoader
├── apps.x86_64-linux.bargman-greeter-vm                 → nix run .#bargman-greeter-vm
└── checks.x86_64-linux.bargman-greeter-login-test       → NixOS integration test with screenshot golden
```

---

## Implementation Phases

### Phase 1: Minimal VM Boot (Verify Theme Renders)

**Goal:** `nix run .#bargman-greeter-vm` boots a QEMU VM with the bargman-cinematic greeter visible.

| Step | Action | File |
|------|--------|------|
| 1.1 | Create VM test accounts module (test user with password, wheel group) | `environments/bargman-greeter-vm-accounts.nix` |
| 1.2 | Create VM virtualisation module (qemu-vm.nix import, virtio-gpu, 4GB RAM, 8GB disk, 4 cores) | `environments/bargman-greeter-vm.nix` |
| 1.3 | Add `nixosConfigurations.bargman-greeter-vm` to flake (mkX86_64 with bargman-greeter-vm.nix, dt=false) | `flake.nix` |
| 1.4 | Add `packages.x86_64-linux.bargman-greeter-vm` exposing `system.build.vm` | `flake.nix` |
| 1.5 | Add `apps.x86_64-linux.bargman-greeter-vm` so `nix run .#bargman-greeter-vm` works | `flake.nix` |

**Exit criteria:** VM boots to a visible login prompt with bargman-cinematic theme.

---

### Phase 2: Serial Console Debugging

**Goal:** Capture boot/greeter logs for diagnosing rendering failures without a display.

| Step | Action | File |
|------|--------|------|
| 2.1 | Add `console=ttyS0,115200` kernel params to the VM module | `environments/bargman-greeter-vm.nix` |
| 2.2 | Add QEMU serial options (`-serial mon:stdio`) to VM config | `environments/bargman-greeter-vm.nix` |
| 2.3 | Create headless VM app variant that passes `--display none` by default | `flake.nix` (apps) |
| 2.4 | Create serial-capture shell script that runs VM with timeout and captures logs to file | `shell/vm-serial-capture.sh` |
| 2.5 | Test: `timeout 60 nix run .#bargman-greeter-vm-serial 2>&1 \| tee /tmp/greeter-boot.log` | manual verification |

**Exit criteria:** Can capture LightDM/greeter startup logs without a physical display.

---

### Phase 3: Integration Test with Golden Screenshot

**Goal:** Automated visual regression test catches greeter rendering failures before deployment.

| Step | Action | File |
|------|--------|------|
| 3.1 | Create shared test helpers (node.pkgsReadOnly=false, globalTimeout, skipTypeCheck) | `tests/helpers.nix` |
| 3.2 | Create greeter login test module (testers.runNixOSTest, wait for display-manager, screenshot, Pillow pixel diff) | `tests/bargman-greeter-login/default.nix` |
| 3.3 | Create golden resources directory and capture initial golden screenshot from working VM | `tests/bargman-greeter-login/resources/` |
| 3.4 | Add `checks.x86_64-linux.bargman-greeter-login-test` to flake | `flake.nix` (checks) |
| 3.5 | Test: `nix build .#checks.x86_64-linux.bargman-greeter-login-test -L` passes | manual verification |

**Exit criteria:** `nix flake check` catches greeter rendering regressions automatically.

---

### Phase 4: VM Session Management

**Goal:** Persistent tmux sessions for interactive VM development and debugging.

| Step | Action | File |
|------|--------|------|
| 4.1 | Create VM session manager script (tmux-based: start/attach/send/kill/status/logs/list) | `shell/vm-session-manager.sh` |
| 4.2 | Add `vmSessions` output to flake with session name, tmux socket, vm type, action map | `flake.nix` |
| 4.3 | Add devShell with aliases (startBargmanVM, attachBargmanVM, stopBargmanVM, listVMs) | `flake.nix` (devShells) |
| 4.4 | Create VM launch wrapper script that handles disk image cleanup (overlay recreation) | `shell/launch-bargman-vm.sh` |
| 4.5 | Test: `shell/vm-session-manager.sh bargman-greeter start` → `attach` → `send "whoami"` → `kill` | manual verification |

**Exit criteria:** `vm-session-manager.sh bargman-greeter start/attach/send/kill/status/logs` all work.

---

### Phase 5: Re-Enable on Bare Metal with Confidence

**Goal:** Re-enable the bargman greeter on bare-metal machines, guarded by the VM test.

| Step | Action | File |
|------|--------|------|
| 5.1 | Verify golden test passes on branch before merge | `nix build .#checks.x86_64-linux.bargman-greeter-login-test -L` |
| 5.2 | Verify serial console shows clean LightDM startup (no errors in boot log) | `/tmp/greeter-boot.log` |
| 5.3 | Uncomment `./bargman-greeter.nix` import in i3wm_darthpjb.nix | `environments/i3wm_darthpjb.nix` |
| 5.4 | Run golden test again after re-enabling to confirm no regression | `nix build .#checks.x86_64-linux.bargman-greeter-login-test -L` |
| 5.5 | Deploy to one machine (e.g., `alpha-one`) and verify login works on bare metal | `nix run .#deploy-alpha-one` |

**Exit criteria:** Bargman greeter re-enabled on bare metal, guarded by automated VM test.

---

## Success Criteria

1. `nix run .#bargman-greeter-vm` boots a VM with the bargman-cinematic greeter visible
2. `nix build .#checks.x86_64-linux.bargman-greeter-login-test -L` passes
3. Deliberately breaking the theme (e.g., bad JS, missing asset) causes the test to fail
4. The bargman-greeter can be re-enabled on bare metal machines with confidence after passing VM tests

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Theme renders in VM but not on bare metal (GPU/driver difference) | VM uses virtio-gpu (software rendering) — if it works here, it's a driver issue, not a theme issue. Serial console logs will reveal the difference. |
| bargman-assets flake SSH access required for CI | The flake is already locked in `flake.lock` — CI can use the locked revision via substituter. |
| VM disk image too large for CI caching | Use `diskSize = "auto"` with minimal `additionalSpace`. The test VM doesn't need the full machine closure. |
| Golden screenshots drift with QEMU/font rendering changes | Use a loose threshold (6.3 mean pixel diff) and `skipTypeCheck = true` in test helpers. |

---

## File Reference Summary

### Files to Create
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/bargman-greeter-vm.nix`
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/bargman-greeter-vm-accounts.nix`
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/tests/helpers.nix`
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/tests/bargman-greeter-login/default.nix`
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/tests/bargman-greeter-login/resources/` (golden PNGs)
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/shell/vm-session-manager.sh`
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/shell/vm-serial-capture.sh`
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/shell/launch-bargman-vm.sh`

### Files to Modify
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/flake.nix` — add VM config, packages, apps, checks, modules, devShell
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/i3wm_darthpjb.nix` — uncomment bargman-greeter import (Phase 5)

### Existing Repo Files (Read-Only Context)
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/bargman-greeter.nix` — existing greeter config
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/environments/i3wm.nix` — base i3wm config
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/modules/lightdm-webkit2-greeter.nix` — existing module
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/pkgs/lightdm-webkit2-greeter.nix` — existing package
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/lib/make-storeless-image.nix` — existing image builder
- `/speed-storage/repo/DarthPJB/NixOS-Configuration/modifier_imports/virtualisation-libvirtd.nix` — libvirtd config
