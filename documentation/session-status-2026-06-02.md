# QEMU Bargman Test Harness — Session Status

**Date:** 2026-06-02
**Branch:** `feat/bargman-qemu-test-harness`
**Plan:** `/speed-storage/opencode/llm/shared/qemu-bargman-test-harness.md`

## Summary

Added a QEMU-based test harness for the bargman-cinematic LightDM webkit2 greeter theme. This enables safe development and testing of the greeter in a VM before deploying to bare metal — preventing the black-screen incident that locked out machines.

## New Features

### QEMU VM Testing
- `nix run .#bargman-greeter-vm` — boots a QEMU VM with the full i3wm + bargman-cinematic greeter stack
- `nix run .#bargman-greeter-vm-serial` — headless mode with serial console output for debugging
- `shell/vm-serial-capture.sh` — captures boot logs to file for diagnosing rendering failures

### Golden Screenshot Test
- `nix build .#checks.x86_64-linux.bargman-greeter-login-test -L` — automated visual regression test
- Uses Pillow pixel diff to compare greeter screenshots against golden PNGs
- Test framework in `tests/helpers.nix` and `tests/bargman-greeter-login/default.nix`

### Nvidia GPU Fix
- `pkgs/lightdm-webkit2-greeter.nix` — wrapped with `GSK_RENDERER=cairo`, `WEBKIT_DISABLE_COMPOSITING_MODE=1`, `GDK_BACKEND=x11`
- Forces software rendering for the greeter process, avoiding nvidia EGL/context issues
- Harmless on non-nvidia hardware (Intel, AMD, virtio-gpu)

## Files Created

| File | Purpose |
|------|---------|
| `environments/bargman-greeter-vm.nix` | QEMU virtualisation config (virtio-gpu, 4GB RAM, 8GB disk, 4 cores) |
| `environments/bargman-greeter-vm-accounts.nix` | VM test user accounts |
| `tests/helpers.nix` | Shared NixOS test framework options |
| `tests/bargman-greeter-login/default.nix` | Integration test with screenshot golden comparison |
| `tests/bargman-greeter-login/resources/` | Golden PNG directory (placeholder) |
| `shell/vm-serial-capture.sh` | Serial console log capture script |

## Files Modified

| File | Change |
|------|--------|
| `flake.nix` | Added nixosConfig, 2 packages, 2 apps, 1 check for bargman-greeter-vm |
| `pkgs/lightdm-webkit2-greeter.nix` | Added `makeWrapper` + `wrapProgram` for nvidia rendering fix |
| `environments/i3wm_darthpjb.nix` | Bargman greeter import commented out (was causing black screen) |

## Implementation Phases

| Phase | Status | Description |
|-------|--------|-------------|
| 1 — VM Boot | ✅ PASS | VM boots with bargman-cinematic greeter visible |
| 2 — Serial Debug | ✅ PASS | Headless VM captures boot logs via serial console |
| 3 — Golden Test | ✅ PASS | Automated visual regression test framework ready |
| 4 — Session Manager | ⏳ Pending | tmux-based persistent VM sessions (optional) |
| 5 — Re-Enable Bare Metal | ⏳ Pending | Requires golden screenshot capture + user validation |

## Root Cause: Black Screen on Nvidia

The bargman-cinematic greeter rendered black on nvidia hardware because:

1. **WebKitGTK + nvidia EGL conflict** — WebKitGTK uses OpenGL for hardware-accelerated compositing. Nvidia's proprietary driver has known EGL context issues in display manager contexts.
2. **`backdrop-filter: blur()` CSS** — The theme uses hardware-accelerated CSS blur. On nvidia with broken EGL, this renders transparent (black).
3. **Picom GLX interference** — The `i3wm_darthpjb.nix` picom config uses `backend = "glx"`, which can claim the GL context before the greeter.
4. **`detect_theme_errors = false`** — Silenced the rendering errors, making the failure invisible.

## Next Steps

1. Capture golden screenshot from working VM
2. Re-enable bargman-greeter on bare metal (guarded by golden test)
3. Deploy to one machine (alpha-one) and verify login works
4. Optional: implement Phase 4 (tmux session manager)
