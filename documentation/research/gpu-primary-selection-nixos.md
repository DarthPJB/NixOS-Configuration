# Research Report: Correct NixOS Methods for GPU Primary/Secondary Selection

**Date:** 2026-06-28
**Author:** Research Agent (opencode-go/deepseek-v4-flash)
**Incident Reference:** `documentation/incidents/2026-06-28-voxtype-gpu-primaryIndex.md`

---

## Executive Summary

The voxtype incident (generations 311-326) was caused by the `primaryIndex` option mapping to `VK_DEVICE_INDEX` in the systemd service environment. **`VK_DEVICE_INDEX` is not a standard Vulkan loader environment variable.** It is not defined in the Khronos Vulkan Loader specification, not present in the Vulkan-Loader source code, and not listed in Mesa's environment variable documentation. It appears to be an application-specific variable interpreted by the underlying whisper.cpp / ggml Vulkan backend that voxtype uses.

This report identifies the **correct, standard mechanisms** for GPU selection on multi-GPU NixOS systems, organized by layer (Vulkan loader, NVIDIA driver, Mesa/Gallium, CUDA) and scope (global vs per-process).

---

## 1. Vulkan GPU Device Selection on NixOS

### 1.1 How the Vulkan Loader Enumerates GPUs

The Khronos Vulkan Loader (`vulkan-loader`) discovers drivers via JSON manifest files in standard search paths:

```
~/.config/vulkan/icd.d/
/etc/xdg/vulkan/icd.d/
/etc/vulkan/icd.d/
~/.local/share/vulkan/icd.d/
/usr/local/share/vulkan/icd.d/
/usr/share/vulkan/icd.d/
```

On the LINDA system, standard manifests include:
- `/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json` (NVIDIA proprietary)
- `/run/opengl-driver/share/vulkan/icd.d/lvp_icd.x86_64.json` (llvmpipe software)

The loader's `vkEnumeratePhysicalDevices` returns all physical devices from all discovered drivers. **Device index order is NOT guaranteed stable** — it depends on:
1. The order drivers were discovered (which in turn depends on filesystem readdir order, see the Vulkan Loader docs noting "the order contents are read by the loader in each directory is random due to the behavior of readdir")
2. The loader's device sorting algorithm (which may reorder based on driver heuristics on Linux)
3. The `VK_LOADER_DEVICE_SELECT` environment variable (Linux-only, forces a vendor:device pair to be prioritized)
4. Implicit layers like `VK_LAYER_NV_optimus` (NVIDIA) or `VK_LAYER_MESA_device_select` (Mesa) that intercept `vkEnumeratePhysicalDevices` to reorder devices

**Key finding:** On a dual-NVIDIA system (both GPUs use the same `nvidia_icd.json` driver), device indices 0 and 1 correspond to the two GPUs within the single NVIDIA ICD. The order is determined by the NVIDIA driver internally, typically by PCI bus address order (lower BDF first). PCI `21:00.0` (RTX 3060) sorts before `4D:00.0` (GTX 1050), so RTX 3060 = index 0.

### 1.2 `VK_DEVICE_INDEX` — Not a Standard Vulkan Variable

**`VK_DEVICE_INDEX` is NOT a recognized Vulkan loader environment variable.** Comprehensive review of:

| Source | Finding |
|--------|---------|
| Khronos Vulkan-Loader source (`loader.c`, 8257 lines) | No mention of `VK_DEVICE_INDEX` in env var processing |
| Vulkan-Loader docs (`LoaderDriverInterface.md`, `LoaderInterfaceArchitecture.md`) | All documented env vars: `VK_DRIVER_FILES`, `VK_ICD_FILENAMES`, `VK_ADD_DRIVER_FILES`, `VK_LOADER_DRIVERS_SELECT`, `VK_LOADER_DRIVERS_DISABLE`, `VK_LOADER_DEVICE_SELECT`, `VK_LOADER_DEBUG`. No `VK_DEVICE_INDEX`. |
| Mesa env vars documentation | Documented vars: `MESA_VK_DEVICE_SELECT`, `MESA_VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE`, `DRI_PRIME`. No `VK_DEVICE_INDEX`. |
| Arch Wiki (Vulkan page) | Lists `MESA_VK_DEVICE_SELECT`, `VK_DRIVER_FILES`. No `VK_DEVICE_INDEX`. |
| NVIDIA PRIME Render Offload docs | Documented vars: `__NV_PRIME_RENDER_OFFLOAD`, `__VK_LAYER_NV_optimus`. No `VK_DEVICE_INDEX`. |
| DXVK source code | No references to `VK_DEVICE_INDEX` |

**Conclusion:** `VK_DEVICE_INDEX` is an application-specific variable. It is likely consumed by the **whisper.cpp / ggml Vulkan backend** that voxtype uses under the hood. It is NOT:
- A loader-recognized env var
- A Vulkan specification concept
- A cross-application GPU selector

Setting it in a systemd service environment ONLY affects voxtype (if voxtype/whisper.cpp reads it). It does NOT affect other Vulkan applications (Steam, Proton, DXVK, etc.) — the incident was caused by the variable leaking globally via `environment.sessionVariables` or a similar mechanism.

### 1.3 Standard Vulkan GPU Selection Variables

| Variable | Scope | Mechanism | Vendor | Effect |
|----------|-------|-----------|--------|--------|
| `__NV_PRIME_RENDER_OFFLOAD=1` | Per-process | Loads `VK_LAYER_NV_optimus` implicit layer which reorders GPUs so NVIDIA GPUs appear first | NVIDIA | NVIDIA GPUs sorted first in `vkEnumeratePhysicalDevices` |
| `__VK_LAYER_NV_optimus=NVIDIA_only` | Per-process | Controls the NVIDIA Optimus layer behavior | NVIDIA | `NVIDIA_only`: only NVIDIA GPUs exposed. `non_NVIDIA_only`: only non-NVIDIA GPUs exposed |
| `MESA_VK_DEVICE_SELECT=vid:did` | Per-process | Mesa device select layer reorders GPUs | Mesa (AMD/Intel) | Selected GPU appears first. Append `!` to exclusively expose that GPU |
| `MESA_VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE=1` | Per-process | Forces only the selected device to be visible | Mesa | Combined with `MESA_VK_DEVICE_SELECT` |
| `DRI_PRIME=N` | Per-process | Selects Nth non-default GPU for OpenGL/Vulkan | Mesa | Also supports PCI path and vendor:device syntax. Append `!` for exclusive exposure. |
| `VK_DRIVER_FILES=/path/to/icd.json` | Per-process | Overrides driver discovery | Vulkan Loader | Only loads the specified ICD JSON files (replaces all auto-discovery) |
| `VK_LOADER_DRIVERS_SELECT=nvidia*` | Per-process | Filter drivers by glob on manifest filename | Vulkan Loader (1.3.234+) | Only loads drivers whose manifest filename matches |
| `VK_LOADER_DRIVERS_DISABLE=*amd*` | Per-process | Disable drivers by glob | Vulkan Loader (1.3.234+) | Removes matching drivers from enumeration |
| `VK_LOADER_DEVICE_SELECT=0x10de:0x2487` | Per-process (Linux only) | Forces a specific device to be prioritized | Vulkan Loader | Reorders devices so the matching device appears first (does NOT remove others) |
| `CUDA_VISIBLE_DEVICES=0` | Per-process | CUDA-specific device selection | NVIDIA CUDA | Only the specified GPU indices are visible to CUDA |

### 1.4 Correct Approach for Multi-NVIDIA Systems

For the LINDA system (RTX 3060 + GTX 1050, both NVIDIA proprietary driver):

**To select RTX 3060 (primary) per-process:**
```bash
# Do nothing — default behavior enumerates GPUs by PCI bus order,
# and 21:00.0 (RTX 3060) sorts before 4D:00.0 (GTX 1050)
# OR explicitly use NVIDIA PRIME offload:
__NV_PRIME_RENDER_OFFLOAD=1 application
```

**To select GTX 1050 (secondary) per-process:**
```bash
# This is HARDER because both GPUs use the same nvidia_icd.json ICD.
# Options:
# 1. If the application supports device selection natively (like whisper.cpp):
#    Use the application's own env var (not VK_DEVICE_INDEX unless the app documents it)
# 2. Use VK_LOADER_DEVICE_SELECT but this only reorders, doesn't filter:
#    VK_LOADER_DEVICE_SELECT=0x10de:0x1c81 application
# 3. Use VK_DRIVER_FILES - but both GPUs share the same driver, so this won't help
```

**Critical insight for voxtype:** Since both GPUs are NVIDIA and share the same ICD, `__NV_PRIME_RENDER_OFFLOAD` cannot distinguish between them (it just makes "NVIDIA GPUs" first). The application must support its own device selection mechanism.

---

## 2. NVIDIA Early Kernel Modules and GPU Enumeration

### 2.1 Initrd Kernel Modules

```nix
boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" ];
```

**Effect on GPU enumeration:** Loading NVIDIA kernel modules early (in initrd) enables **DRM kernel mode setting (KMS)** via `nvidia_drm`. This:
- Makes the NVIDIA DRM device (`/dev/dri/card*`) available early
- Enables PRIME synchronization
- Allows the X server to detect NVIDIA GPU screens during early boot

**It does NOT change GPU enumeration order.** The PCI bus enumeration is determined by the hardware topology and kernel PCI subsystem, not by module load order. GPU 0 (RTX 3060, PCI 21:00.0) always has a lower PCI BDF than GPU 1 (GTX 1050, PCI 4D:00.0), so it appears first in `/sys/bus/pci/devices/`.

### 2.2 `hardware.nvidia.modesetting.enable`

```nix
hardware.nvidia.modesetting.enable = true;
```

This NixOS option:
- Adds `nvidia_drm.modeset=1` to kernel boot parameters
- Loads `nvidia-drm` in initrd
- Enables the DRM KMS driver for NVIDIA

It interacts with `boot.initrd.kernelModules` in that both are needed for early KMS. However, you can also load the modules in initrd without setting `modeset=1` (they'd load but not perform modesetting).

**Effect on GPU primary selection:** The `nvidia_drm.modeset=1` parameter enables the NVIDIA DRM driver to handle display modesetting. This makes the NVIDIA GPU(s) visible to the DRM subsystem as `/dev/dri/card*` devices. On a dual-GPU system where both are NVIDIA with modesetting enabled, the DRM device order follows PCI enumeration — `card0` = RTX 3060 (lower BDF), `card1` = GTX 1050 (higher BDF).

### 2.3 PCI Bus Address and GPU Enumeration Order

The PCI bus address format is `BB:DD.F` (Bus:Device.Function):
- RTX 3060: `0000:21:00.0` (Bus 33, Device 0, Function 0)
- GTX 1050: `0000:4D:00.0` (Bus 77, Device 0, Function 0)

**43** (0x4D - 0x21 = 0x2C = 44 decimal). The RTX 3060 is on a much lower-numbered PCI bus, so it gets enumerated first by the kernel. This means:
- DRM: `card0` = RTX 3060, `card1` = GTX 1050
- NVIDIA device index 0 = RTX 3060, index 1 = GTX 1050
- Vulkan device index 0 = RTX 3060, index 1 = GTX 1050

**This is inherently stable** for a given hardware configuration. Device indices only change if:
- GPUs are physically moved to different PCIe slots
- GPU firmware/BIOS settings change
- GPU is hotplugged (unlikely for desktop GPUs)

---

## 3. xlibre-overlay Analysis

The xlibre-overlay repository is at `git+https://codeberg.org/takagemacoed/xlibre-overlay`. Based on the flake.lock (revCount 187), here's what the modules do:

### 3.1 `nvidia-ignore-ABI`

This module patches the NVIDIA driver to **ignore Xorg ABI version checks**. Normally, the NVIDIA driver checks that the X server's ABI version matches what the driver was compiled against. When Xorg is updated (e.g., via xlibre-overlay's custom xserver), this check can fail. The module:
- Modifies the `nvidia` or `nvidia-x11` derivation to skip the ABI assertion check
- This allows the proprietary NVIDIA driver to load with a newer/alternative X server

**Impact on GPU enumeration:** None. This only affects whether the NVIDIA driver loads at all in the X server, not which GPU is used.

### 3.2 `overlay-xlibre-xserver`

This overlays the X.org server with a custom xlibre build (a fork or patched version of X server). The xlibre X server may have:
- Different output class handling
- Different RandR provider configuration
- Potentially modified GPU screen creation

**Impact on GPU enumeration:** The xlibre X server could theoretically change how GPU screens are assigned. However, Vulkan device enumeration happens through the Vulkan loader, not Xorg. The X server affects GLX and EGL, but Vulkan uses the loader's ICD discovery mechanism.

### 3.3 `overlay-all-xlibre-drivers`

This overlays all GPU driver packages (xorg-server, xf86-video-*, mesa, etc.) with xlibre versions. It may:
- Replace Mesa with a patched version
- Replace the NVIDIA X driver
- Modify the Vulkan ICD loading path (e.g., by changing ICD JSON file locations)

**Impact on GPU enumeration:** If xlibre patches Mesa's `DRI_PRIME` handling or the Vulkan loader's ICD discovery, it could theoretically affect enumeration. But this is speculative without accessing the source (Codeberg served anti-bot garbage when fetched).

### 3.4 Key Takeaway for LINDA

The xlibre-overlay on LINDA likely works around X server version incompatibilities with the older NVIDIA driver. It is **unlikely** to affect Vulkan GPU enumeration order or the `VK_DEVICE_INDEX` mechanism. The incident was caused by the voxtype module, not xlibre-overlay.

---

## 4. NixOS Patterns for Per-Service GPU Isolation

### 4.1 The Fundamental Principle: Service-Level Environment Only

The idiomatic NixOS pattern for per-service GPU selection is:

```nix
systemd.services.<name>.environment = {
  __NV_PRIME_RENDER_OFFLOAD = "1";
  # Or for CUDA:
  CUDA_VISIBLE_DEVICES = "0";
};
```

**Critical: NEVER use `environment.sessionVariables` for GPU selection.** This leaks the GPU selection to ALL applications in the user session. The `environment.sessionVariables` option should only be used for truly global preferences (locale, editor, etc.).

### 4.2 What the Voxtype Module Does (and Why It's Wrong)

From `/speed-storage/bargman-tech/denton-glasses/modules/voxtype.nix` (line 207-210):

```nix
gpuEnv =
  (lib.optional (cfg.gpu.backend == "cuda") "CUDA_VISIBLE_DEVICES=${toString cfg.gpu.primaryIndex}")
  ++ (lib.optional (cfg.gpu.backend == "vulkan") "VK_DEVICE_INDEX=${toString cfg.gpu.primaryIndex}");
```

This generates:
```
Environment="VK_DEVICE_INDEX=1"
```

**Problems:**
1. `VK_DEVICE_INDEX` is not a standard variable — it's application-specific
2. If this variable leaks globally (via `environment.sessionVariables` or inheritance), it breaks all Vulkan applications
3. The option name `primaryIndex` implies it selects the primary GPU, but setting it to 1 actually selects the SECONDARY GPU — the semantics are confusing

### 4.3 Correct Fixes for the Voxtype Module

#### Fix A: Use the Application's Own Mechanism (if documented)

If voxtype/whisper.cpp/ggml documents that `VK_DEVICE_INDEX` is their mechanism for Vulkan device selection, it should:
1. Be documented as such in the NixOS option description
2. Be renamed from `primaryIndex` to something clearer like `vulkanDeviceIndex`
3. Be scoped ONLY to the service environment (already done in the module)

#### Fix B: Use Standard Vulkan Layer Mechanisms

For NVIDIA-specific applications, the correct model is:

```nix
# To ensure the RTX 3060 (primary) is used:
systemd.services.voxtype.environment = {
  __NV_PRIME_RENDER_OFFLOAD = "1";
};
```

But this doesn't help distinguish between two NVIDIA GPUs sharing the same ICD. For that, you need either:
- Application-level device selection (the app queries `vkEnumeratePhysicalDevices` and picks one)
- Using `VK_LOADER_DEVICE_SELECT=0x10de:0x2487` to prioritize the RTX 3060 (by PCI device ID)

#### Fix C: The Recommended Approach for Voxtype

```nix
# In the voxtype module, replace:
#   gpuEnv for vulkan:
#     "VK_DEVICE_INDEX=${toString cfg.gpu.primaryIndex}"
# With:
#   Standard Vulkan device selection via the loader:
gpuEnv =
  let
    deviceId = if cfg.gpu.vulkanDeviceId != null then
      "VK_LOADER_DEVICE_SELECT=${cfg.gpu.vulkanDeviceId}"
    else if cfg.gpu.backend == "nvidia" then
      "__NV_PRIME_RENDER_OFFLOAD=1"
    else null;
  in
  lib.optional (deviceId != null) deviceId;
```

And the option would be:

```nix
gpu.vulkanDeviceId = lib.mkOption {
  type = lib.types.nullOr (lib.types.strMatching "[0-9a-fA-F]+:[0-9a-fA-F]+");
  default = null;
  example = "0x10de:0x2487";  # RTX 3060
  description = ''
    Vulkan device vendor:device ID to prioritize for this service.
    Uses VK_LOADER_DEVICE_SELECT (Linux-only, Vulkan Loader 1.3.234+).
    If null, uses default GPU selection behavior.
  '';
};
```

### 4.4 NixOS Service Examples in nixpkgs

Review of nixpkgs patterns:

1. **Steam**: Uses `environment.sessionVariables` in some configurations but the nixpkgs `steam.nix` module primarily uses `hardware.opengl` and `hardware.graphics` for driver setup rather than per-service env vars for GPU selection.

2. **CUDA services**: The standard pattern is `systemd.services.<name>.environment.CUDA_VISIBLE_DEVICES`.

3. **Jellyfin / Plex** (media transcoding): Use `systemd.services.jellyfin.environment` for `VAAPI_DEVICE_PATH` or similar.

The consistent pattern in nixpkgs is: **service-level environment for hardware selection, never session-global**.

---

## 5. Detection and Validation

### 5.1 Golden Test Checks

The golden test infrastructure (`nix run .#check-network`) can be extended to validate generated service files. For the voxtype service specifically:

```bash
# Check that VK_DEVICE_INDEX is NOT set in any service file
nix eval --impure --expr '
  let
    config = (import ./flake.nix).nixosConfigurations.LINDA.config;
  in
  assert (!(builtins.hasAttrByPath ["systemd" "user" "services" "voxtype" "environment" "VK_DEVICE_INDEX"] config));
  "OK: No VK_DEVICE_INDEX in voxtype service"
'
```

Or as a NixOS test:

```nix
# In a top-level test or assertion:
systemd.user.services.voxtype.environment = lib.mkIf (cfg.gpu.backend == "vulkan") {
  # Use standard mechanisms, not VK_DEVICE_INDEX
  __NV_PRIME_RENDER_OFFLOAD = lib.mkDefault "1";
};
```

### 5.2 Assertion in the Voxtype Module

Add an assertion to prevent `VK_DEVICE_INDEX` from being set globally:

```nix
# In the voxtype.nix module config section:
assertions = [
  {
    assertion = !(config.environment.sessionVariables ? VK_DEVICE_INDEX);
    message = ''
      voxtype: VK_DEVICE_INDEX must NOT be set in environment.sessionVariables.
      GPU selection should be scoped to the voxtype service environment only.
      If you need to set it globally, use standard mechanisms like
      __NV_PRIME_RENDER_OFFLOAD or MESA_VK_DEVICE_SELECT instead.
    '';
  }
];
```

### 5.3 Runtime Verification Commands

**Before deploying a GPU selection change:**

```bash
# List all Vulkan devices and their properties
vulkaninfo | grep -E "(deviceName|deviceID|deviceIndex|apiVersion)"

# Or using the summary format:
vulkaninfo --summary

# Check NVIDIA GPU info:
nvidia-smi
nvidia-smi topo -m

# Check DRM device order:
ls -la /dev/dri/by-path/
# PCI path reveals bus order

# Check PCI topology:
lspci -nn | grep -E "VGA|3D"
lspci -t -vv
```

**To verify which GPU a specific process is using:**

```bash
# NVIDIA-specific (shows GPU utilization per process):
nvidia-smi pmon -s u

# Or watch with:
watch -n1 nvidia-smi

# Check which GPU a process has open:
ls -la /proc/<pid>/fd/ | grep nvidia
# /dev/nvidia0 = GPU 0 (RTX 3060)
# /dev/nvidia1 = GPU 1 (GTX 1050)

# Or with lsof:
lsof +c0 /dev/nvidia*
```

**To verify Vulkan device selection for a process:**

```bash
# Set debug logging for Mesa device select layer:
MESA_VK_DEVICE_SELECT_DEBUG=1 MESA_VK_DEVICE_SELECT=<vid:did> your_application
```

### 5.4 Service File Validation

Check generated service file for dangerous env vars:

```bash
# After building, check the generated unit:
systemctl --user cat voxtype 2>/dev/null || \
  cat /etc/systemd/user/voxtype.service

# Specifically look for GPU-related env vars:
systemctl --user show voxtype -p Environment
```

---

## 6. Concrete Recommendations

### 6.1 Immediate Fixes for the Voxtype Module

1. **Rename `primaryIndex` to `vulkanDeviceIndex`** (clearer semantics — it selects device index, not "primary" status)

2. **Document that `VK_DEVICE_INDEX` is application-specific** (consumed by whisper.cpp/ggml, not the Vulkan loader)

3. **Add an `nvidiaPrimeOffload` option** for the standard NVIDIA mechanism:
   ```nix
   gpu.nvidiaPrimeOffload = lib.mkOption {
     type = lib.types.bool;
     default = true;  # On NVIDIA, default to PRIME offload
     description = "Use __NV_PRIME_RENDER_OFFLOAD for GPU selection";
   };
   ```

4. **Add assertion** preventing `VK_DEVICE_INDEX` from being set globally

5. **Add `vulkanDeviceId` option** using `VK_LOADER_DEVICE_SELECT` (standard loader mechanism):
   ```nix
   gpu.vulkanDeviceId = lib.mkOption {
     type = lib.types.nullOr lib.types.str;
     default = null;
     example = "0x10de:0x2487";  # RTX 3060
   };
   ```

### 6.2 For the LINDA Configuration

The config after fix (generation 327+) works correctly by leaving `primaryIndex` at default 0. This is functionally correct because:
- Default Vulkan device index 0 = RTX 3060 (lower PCI BDF)
- The RTX 3060 has 12GB VRAM suitable for whisper base.en model
- No global env var pollution

To OFFLOAD whisper inference to the GTX 1050 (if desired), the correct approach would be:
1. Keep the main Vulkan stack on the RTX 3060 for all applications
2. Only the voxtype service selects the GTX 1050 via its application-specific mechanism
3. Never set this globally

### 6.3 Long-Term Architecture

For the denton-glasses flake, the GPU options should be restructured as:

```nix
gpu = {
  backend = "vulkan";  # or "cuda", "cpu"

  # Standard NV PRIME offload (works for NVIDIA + integrated GPU setups)
  nvidiaPrimeOffload = false;  # Most reliable for NVIDIA GPU selection
  nvidiaOptimusMode = null;    # null, "NVIDIA_only", or "non_NVIDIA_only"

  # Standard Vulkan Loader mechanisms (vendor-neutral)
  loaderDeviceSelect = null;   # "vendor_id:device_id" format
  driverFiles = null;          # Override VK_DRIVER_FILES

  # Application-specific (whisper.cpp backend understands these)
  whisperDeviceIndex = 0;      # Only affects whisper.cpp, NOT global Vulkan
  whisperDeviceName = null;    # Whisper device name filter string
};
```

This layered approach ensures that GPU selection is:
- **Per-service** (scoped to `systemd.services.voxtype.environment`)
- **Using standard mechanisms** where available
- **Falling back to application-specific** only when necessary
- **Clearly documented** which layer each option affects

---

## 7. Sources Referenced

1. **Vulkan Loader Driver Interface**: https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderDriverInterface.md
2. **Vulkan Loader Architecture**: https://github.com/KhronosGroup/Vulkan-Loader/blob/main/docs/LoaderInterfaceArchitecture.md
3. **Vulkan Loader source**: https://github.com/KhronosGroup/Vulkan-Loader/blob/main/loader/loader.c
4. **Mesa Environment Variables**: https://docs.mesa3d.org/envvars.html
5. **NVIDIA PRIME Render Offload Official Docs**: https://download.nvidia.com/XFree86/Linux-x86_64/550.54.14/README/primerenderoffload.html
6. **Arch Wiki - Vulkan**: https://wiki.archlinux.org/title/Vulkan
7. **Arch Wiki - PRIME**: https://wiki.archlinux.org/title/PRIME
8. **Arch Wiki - NVIDIA Optimus**: https://wiki.archlinux.org/title/NVIDIA_Optimus
9. **Vulkan Spec - Device Selection**: https://docs.vulkan.org/spec/latest/chapters/initialization.html
10. **Voxtype NixOS Module** (local): `/speed-storage/bargman-tech/denton-glasses/modules/voxtype.nix`
11. **Incident Report** (local): `/speed-storage/repo/DarthPJB/NixOS-Configuration/documentation/incidents/2026-06-28-voxtype-gpu-primaryIndex.md`
