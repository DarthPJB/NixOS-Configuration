# Denton-Glasses on LINDA — Deployment Reference

**Date:** 2026-06-17
**Machine:** LINDA (WireGuard: `10.75.69.88`, sshPort: `1108`)
**Status:** ✅ Voxtype operational (post-2026-07-04 intermittent typing fix)

---

## Overview

LINDA runs the `denton-glasses` NixOS modules for:
- **Voxtype** — push-to-talk speech-to-text (whisper via Vulkan GPU)
- **Eye-tracking** — OpenFace-based webcam tracking (manual start)

Both modules are imported via `flake.nix` → `extraModules` in the LINDA machine config.

---

## Voxtype Configuration

### Hotkey
- **Key:** `META + V` (LEFTMETA + V)
- **Evdev codes:** `EVTEST_125` (LEFTMETA) + `EVTEST_47` (V)
- **Mode:** `push_to_talk` (hold to record, release to transcribe)

### Audio
- **Device:** `default` (PipeWire-ALSA routing)
- **Sample rate:** 16000 Hz
- **Max duration:** 60 seconds
- **Microphone:** CMEDIA Q9-1 USB (ALSA card 3, `Q91`)

### Whisper Model
- **Model:** `base.en`
- **Backend:** Vulkan GPU (RTX 3060, device index 0)
- **Package:** `voxtype-vulkan` from `nixpkgs_llm` (nixpkgs-unstable)

### Service
- **Type:** systemd user service (`voxtype.service`)
- **User:** `John88`
- **Groups:** `audio`, `input`
- **Config:** `/etc/voxtype/config.toml` (declarative, from NixOS module)

### Verified Working
- [x] Hotkey detection (META+V) — verified working (was intermittent pre-fix due to driver_order + uinput)
- [x] Model loading (base.en, Vulkan GPU)
- [x] Audio recording (PipeWire-ALSA default device)
- [x] Transcription output (type mode)

---

## Eye-Tracking Configuration

### Hardware
- **Camera:** NewEye 60s USB webcam
- **V4L2 path:** `/dev/v4l/by-id/usb-NewEye_60s_NewEye_60s_20240131-video-index0`

### Service
- **Auto-start:** `false` (manual start until validated)
- **User:** `John88`
- **Output:** `/var/lib/denton-glasses/eye-tracking` (CSV format)

---

## Module Import (flake.nix)

```nix
LINDA = mkX86_64 "LINDA" {
  host = topoIp "LINDA";
  buildOn = "remote";
  extraModules = [
    ./users/build.nix
    denton-glasses.nixosModules.eye-tracking
    denton-glasses.nixosModules.voxtype
    # ...
  ];
};
```

---

## Environment File

`environments/denton-glasses.nix` contains:
- Voxtype service configuration (hotkey, audio, model)
- Eye-tracking hardware paths
- User group assignments (`input` group for hotkey detection)

---

## Flake Input

```nix
denton-glasses.url = "path:/speed-storage/LLM-END/denton-glasses";
```

**Update after local changes:**
```bash
nix flake update denton-glasses
```

---

## Known Issues

### Security Hardening Disabled
The following systemd service hardening is currently **commented out**:
- `ProtectSystem = "strict"`
- `ProtectHome = "read-only"`
- `PrivateTmp = true`
- `NoNewPrivileges = true`

**Root cause:** `ProtectSystem=strict` with `DeviceAllow` whitelist was causing status=101 (Rust panic). Needs incremental re-enabling to identify the specific blocker.

### OSD Not Available
`voxtype-osd-gtk4` and `voxtype-osd-native` are not included in the `voxtype-vulkan` package. The OSD child fails 3 times and gives up, but the daemon continues running. Non-functional — cosmetic only.

### ALSA Fallback
Voxtype uses ALSA directly (not libpulse). The `voxtype-vulkan` package is not linked against `libpulse`. Using `device = "default"` with PipeWire-ALSA routing works correctly.

### Intermittent Typing (Resolved 2026-07-04)
**Root cause:** /dev/uinput access was ACL-gated by logind active-session state
(revoked on VT switch / screen lock / session change). No `uinput` group existed.
dotool fell back to clipboard silently when the ACL was revoked.

**Driver chain fix:** voxtype's auto-detected driver_order tried `wtype`
(Wayland-only, always fails on X11) first, adding latency and a failure
point before dotool. Now set explicitly to `[dotool xclip]` via the
denton-glasses module's new `output.driverOrder` option.

**Fix:** denton-glasses module now creates a `uinput` group + udev rule
(`uinput.enable=true`, default). `driver_order` set to `[dotool xclip]`
(skips Wayland-only `wtype`). `modifier_release_timeout_ms` bumped
750→1500ms for slow META release on X11. `pre_type_delay_ms=50` added
for virtual keyboard init time.

### Empty Journal (Partially Resolved 2026-07-04)
**Root cause:** Per-UID journald namespace (`systemd-journald@1108.service`)
is inactive (dead) — systemd-258 / NixOS-25.11 regression. Affects all
user units, not just voxtype. Socket activation not firing; namespace
dir `/run/systemd/journal.1108/` doesn't exist.

**Workaround:** `RUST_LOG=voxtype=info` wired via `services.voxtype.logLevel`
(new denton-glasses module option). Logs route to journald stdout socket
but may not persist in `journalctl --user -u voxtype` until the namespace
journald issue is resolved (separate task, tracked as Phase 6).

For immediate debugging, run voxtype manually with full stderr:
```bash
systemctl --user stop voxtype
DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1108 VK_DEVICE_INDEX=0 RUST_LOG=voxtype=debug voxtype daemon 2>&1 | tee /tmp/voxtype-debug.log
```

---

## Troubleshooting

### Check Service Status
```bash
systemctl --user status voxtype
```

### Check Daemon State
```bash
DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1108 voxtype status
```

### List Audio Sources (PipeWire)
```bash
pw-cli ls Node | grep -A5 "Audio/Source"
```

### List ALSA Cards
```bash
cat /proc/asound/cards
```

### Manual Daemon Run (Debug)
```bash
systemctl --user stop voxtype
DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1108 voxtype daemon
```

### Enable Debug Logging (NixOS-level)
In `environments/denton-glasses.nix`:
```nix
services.voxtype.logLevel = "debug";  # or "trace" for maximum detail
```
Rebuild and deploy, then:
```bash
journalctl --user -u voxtype --since "5 min ago" --no-pager
```
Note: per-user journald namespace may be inactive (systemd-258 regression);
if journal shows empty, use the manual stderr method above.

### Verify Driver Chain (post-fix)
```bash
voxtype config | grep driver_order
# Expected: driver_order = [Dotool, Xclip] (X11-only, skips Wayland wtype)
```

### Verify /dev/uinput Access (post-fix)
```bash
getent group uinput
# Expected: group exists with John88 as member
getfacl /dev/uinput
# Expected: group::rw- (durable, not session-state ACL-gated)
```

### Re-download Model
```bash
voxtype setup --download --model base.en
```

---

## References

- [Denton-Glasses README](/speed-storage/LLM-END/denton-glasses/README.md)
- [Voxtype Module](/speed-storage/LLM-END/denton-glasses/modules/voxtype.nix)
- [Environments/denton-glasses.nix](../environments/denton-glasses.nix)
