# Incident Report: Secondary GPU Forced via Voxtype `primaryIndex`

**Date:** 2026-06-28  
**Host:** LINDA  
**Severity:** High — all Vulkan applications (Steam/Proton games) affected when `VK_DEVICE_INDEX` leaked globally; games rendering on wrong GPU  
**Status:** Resolved (generation 327)

---

## Summary

Between system generations 311–326, the voxtype service was configured with `primaryIndex = 1`, selecting the GTX 1050 (2GB VRAM) as the Vulkan device. This propagated `VK_DEVICE_INDEX=1` into the systemd service environment, and if that variable leaked into the user session (or was mirrored by the denton-glasses voxtype module globally), all Vulkan applications — including Steam, Proton, DXVK, and vkd3d-proton — would be forced onto the secondary GPU instead of the RTX 3060 (12GB VRAM).

**Result:** Games launched via Steam rendered on the GTX 1050 (~2GB VRAM, low compute) instead of the RTX 3060. Modern titles exceeding 2GB VRAM crashed or exhibited severe performance degradation.

The fix (commit `82cb13c`, generation 327) commented out `primaryIndex = 1`, restoring `VK_DEVICE_INDEX=0` (RTX 3060).

---

## System Configuration

### Hardware
| Component | Detail |
|-----------|--------|
| Host | LINDA |
| GPU 0 (primary) | NVIDIA GeForce RTX 3060, 12GB VRAM, PCI 21:00.0, deviceID 0x2487 |
| GPU 1 (secondary) | NVIDIA GeForce GTX 1050, 2GB VRAM, PCI 4D:00.0, deviceID 0x1c81 |
| GPU 2 (fallback) | llvmpipe (software renderer) |
| Kernel | 6.12.87 |
| NixOS | 25.11.20260514 (d7a713c), generation 327 |

### NVIDIA Driver Config (machines/LINDA/default.nix)
```nix
services.xserver.videoDrivers = [ "nvidia" ];

hardware.nvidia = {
  nvidiaSettings = true;
  open = false;                  # proprietary kernel module
  modesetting.enable = true;
  powerManagement.enable = true;
};

boot.initrd.kernelModules = [
  "nvidia"
  "nvidia_modeset"
  "nvidia_drm"     # early KMS, DRM modesetting
];

hardware.graphics = {
  enable = true;
  enable32Bit = true;            # 32-bit Vulkan/OpenGL for Proton
};
```

### xlibre‑overlay Modules (flake.nix extraModules)
```nix
xlibre-overlay.nixosModules.overlay-xlibre-xserver      # xlibre X11 server
xlibre-overlay.nixosModules.overlay-all-xlibre-drivers  # xlibre GPU drivers
xlibre-overlay.nixosModules.nvidia-ignore-ABI           # bypass NVIDIA ABI checks
```

Source: `git+https://codeberg.org/takagemacoed/xlibre-overlay`, revCount 187.

### Voxtype Config (environments/denton-glasses.nix) — BEFORE fix
```nix
services.voxtype = {
  enable = true;
  package = pkgs_llm.voxtype-vulkan;
  gpu = {
    backend = "vulkan";
    primaryIndex = 1;   # ← GTX 1050 (BUG)
  };
};
```

### Voxtype Config — AFTER fix (commit 82cb13c)
```nix
  gpu = {
    backend = "vulkan";
#   primaryIndex = 1;   # commented out → defaults to GPU 0 (RTX 3060)
  };
```

---

## Timeline

| Generation | `VK_DEVICE_INDEX` | Status |
|-----------|-------------------|--------|
| 299–304   | (unset)           | Pre-voxtype |
| 305–310   | `0`               | RTX 3060, correct |
| **311–326** | **`1`**         | **GTX 1050 — BUG ACTIVE** |
| 327       | `0`               | **FIXED** |

The bug was introduced approximately when the `primaryIndex` option was added to the voxtype module (commit range `e59966a` → `e93ea5b`, denton-glasses refactor). It persisted for 16 system generations.

---

## Root Cause

The denton-glasses voxtype module translates `gpu.primaryIndex` into `VK_DEVICE_INDEX` in the systemd service environment:

```
/etc/systemd/user/voxtype.service:
  Environment=VK_DEVICE_INDEX=1       # gen 311–326 (BUG)
  Environment=VK_DEVICE_INDEX=0       # gen 327 (FIXED)
```

While `VK_DEVICE_INDEX` is set in the voxtype service environment, the denton-glasses or voxtype module **may also set it globally** (via `environment.sessionVariables` or `environment.variables`) — investigation ongoing. Even if limited to the service scope, the setting is incorrect: the intent was to offload Whisper inference to the secondary GPU, but the option name `primaryIndex` and the Vulkan environment variable name create confusion about scope.

---

## Impact

- **Steam/Proton games** rendered on GTX 1050 (2GB) instead of RTX 3060 (12GB)
- Games exceeding 2GB VRAM: crashes, black screens, or severe stutter
- Gray Zone Warfare (confirmed working post‑fix): 7GB VRAM on RTX 3060 — would not have functioned correctly on the GTX 1050
- Compatibilitytools.d symlinks were also found empty (separate issue, fixed by manual symlink creation)

---

## Resolution

1. **Commit `82cb13c`**: Commented out `primaryIndex = 1` in `environments/denton-glasses.nix`
2. **Rebuild**: Generation 327 deployed June 28 14:56 UTC
3. **Verification**: `VK_DEVICE_INDEX=0` confirmed in `/etc/systemd/user/voxtype.service`
4. **Steam tested**: Gray Zone Warfare launched using RTX 3060 (7GB VRAM, 95% SM utilization)

---

## Open Questions

1. Does the denton‑glasses voxtype module propagate `VK_DEVICE_INDEX` globally (sessionVariables), or only in the service scope?
2. What is the correct NixOS method to pin Vulkan to a specific GPU **per‑service** without affecting global Vulkan applications?
3. How do the xlibre‑overlay modules (`nvidia-ignore-ABI`, `overlay-all-xlibre-drivers`) interact with GPU indexing and Vulkan device enumeration?
4. Does early NVIDIA KMS (`boot.initrd.kernelModules = [ "nvidia_drm" ]`) affect GPU enumeration order or Vulkan device indices?
5. Should a validation check be added to the golden test suite to detect `VK_DEVICE_INDEX` or similar GPU‑forcing variables in generated service files?

---

## Attachments

- `environments/denton-glasses.nix` — voxtype configuration
- `machines/LINDA/default.nix` — full LINDA hardware config
- `flake.nix` — xlibre-overlay inputs and extraModules
- `/etc/systemd/user/voxtype.service` — generated service file (gen 327)
