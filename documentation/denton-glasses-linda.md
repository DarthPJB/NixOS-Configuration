# Denton-Glasses on LINDA — Deployment Reference

**Date:** 2026-06-17
**Machine:** LINDA (WireGuard: `10.75.69.88`, sshPort: `1108`)
**Status:** ✅ Voxtype operational, eye-tracking configured (manual start)

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
- [x] Hotkey detection (META+V)
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

### Re-download Model
```bash
voxtype setup --download --model base.en
```

---

## References

- [Denton-Glasses README](/speed-storage/LLM-END/denton-glasses/README.md)
- [Voxtype Module](/speed-storage/LLM-END/denton-glasses/modules/voxtype.nix)
- [Environments/denton-glasses.nix](../environments/denton-glasses.nix)
