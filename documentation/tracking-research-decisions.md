# Tracking Research Decisions - LINDA Machine

> **Canonical Implementation:** The vision/perception stack described in this document is implemented in the [`denton-glasses`](https://github.com/DarthPJB/denton-glasses) flake. All eye tracking, speech-to-text, and augmentation tooling lives there. This document is the **research record** — `denton-glasses` is the **source of truth** for implementation.
>
> Flake input in this repo: `inputs.denton-glasses.url = "path:/speed-storage/LLM-END/denton-glasses";`

**Document Created:** 2026-06-06  
**Purpose:** Capture current reasoning, constraints, tool choices, blacklisted items, and viable options for open-source computer vision / spatial tracking stack on the LINDA (LINDACORE) machine.

## Machine Context
- **Hostname:** LINDA / LINDACORE
- **Hardware:** High-end AMD CPU, NVIDIA GPU with CUDA, 3x 4K webcams, Xbox Kinect (depth), SteamVR tracking gear (lighthouses/trackers).
- **Existing Software:** CUDA enabled, Ollama, Steam, i3wm, virtualisation, video editing, CAD, 3D printing environments.
- **Goal:** Automatic eye tracking, motion/body tracking, tag/marker/QR tracking, and spatial mapping / RGB-D SLAM using only open-source software with clean provenance.

## Hard Constraints
- **No Google, Microsoft, or Amazon products** — treated as automatic security threats.
- Only software with clear open-source, academic, or independent community origins is acceptable.
- Must work on x86_64 Linux (NixOS).
- Preference for packages already available in `nixpkgs` where possible.
- Golden test / topology architecture in this repo must not be broken by any changes.

## Blacklisted Tools & Software
Due to corporate origin or heavy dependency on barred entities:

### Corporate Barred List
- **MediaPipe** (Google) — Previously top choice for eye + pose tracking. Completely excluded.
- TensorFlow (Google)
- Anything from Azure Cognitive Services, AWS Rekognition, MS Kinect SDK (proprietary versions)
- Google ARCore, Microsoft Mixed Reality, Amazon Sumerian, etc.
- Any binary blobs or cloud-dependent "open core" tools with corporate backing from the above.

### Other Cautions
- Avoid projects with heavy reliance on barred upstream models or datasets if possible.
- dlib is acceptable (independent academic origin) but monitored.
- ROS 2 is acceptable (Linux Foundation / academic roots via Willow Garage/Open Robotics).

## Accepted Open-Source Tools (Current Viable Stack)

### Eye Tracking
- **Primary:** OpenFace (CMU + Cambridge) — **packaged in `denton-glasses` flake** (`github:DarthPJB/OpenFace` input). Provides `FaceLandmarkVid`, `FaceLandmarkImg`, `FeatureExtraction` apps and a NixOS module (`denton-glasses.nixosModules.eye-tracking`).
- **Fallback:** Pupil Core (Pupil Labs) — University/research origins, fully open source, Linux support, works with webcams. Not yet packaged.
- **Also available:** OpenCV + dlib models, custom gaze tracking with OpenCV (included in `denton-glasses` devShell).

### Motion / Body / Pose Tracking
- **Primary:** OpenPose (Carnegie Mellon University) — Strong academic open-source project.
- **Alternatives:** MMPose, HRNet, AlphaPose (OpenMMLab — independent open computer vision community).

### Tag / Marker / QR Tracking
- **Primary:** AprilTag (`apriltag` in nixpkgs) — University of Michigan / April Robotics. Excellent robustness and speed.
- **Supporting:** ArUco (via OpenCV), ZBar, Quirc, pyzbar.

### Spatial Mapping / SLAM / Depth Processing
- **Primary:** RTAB-Map (`rtabmap` in nixpkgs) — Université de Sherbrooke. Excellent RGB-D SLAM.
- **Core Libraries:** PCL (`pcl`), OpenCV (`opencv4`).
- **SteamVR Tracking:** libsurvive (`libsurvive` in nixpkgs) — Independent open-source Lighthouse tracker.
- **XR Runtime:** Monado (`monado` in nixpkgs) — Open-source OpenXR implementation.
- **Kinect Support:** freenect / libfreenect2.

### Integration & Tooling
- **Canonical Source:** [`denton-glasses` flake](https://github.com/DarthPJB/denton-glasses) — provides NixOS modules (`eye-tracking`, `voxtype`), devShells (`default`, `minimal`, `augment`), and re-exported OpenFace apps.
- **Speech-to-Text:** Voxtype (whisper-based, push-to-talk) — **packaged in `denton-glasses` flake** as `nixosModules.voxtype`. Standalone NixOS module, no home-manager dependency.
- **Preferred Framework:** ROS 2 (Humble or Jazzy) — Provides unified graph for all above components.
- **Lightweight Alternative:** Pure Python/C++ with OpenCV + AprilTag + RTAB-Map libraries.
- **Nixpkgs Packages Confirmed Available:**
  - `apriltag`, `rtabmap`, `libsurvive`, `monado`, `pcl`, `freenect`, `opencv4`, `openpose`
  - Various Python bindings and ROS packages.

## Current Reasoning
- The removal of MediaPipe significantly raises the difficulty of high-quality real-time eye tracking and holistic pose estimation. OpenFace (via `denton-glasses`) is now the primary eye tracking solution — fully packaged and operational.
- Pupil Core remains a viable fallback but is not yet packaged for Nix.
- AprilTag + RTAB-Map + libsurvive form a very strong foundation for marker-based and spatial tracking with the available hardware (Kinect depth + SteamVR precision).
- LINDA's CUDA capability means we can run heavier models (OpenPose, RTAB-Map) efficiently.
- The `denton-glasses` flake cleanly separates perception tooling from main infrastructure, respecting the directive to **embrace simplicity**. No heavy services are added to LINDA until explicitly enabled.
- Integration via ROS 2 offers the cleanest "automatic" pipeline but increases complexity. A Python prototype may be a better first step.
- All changes must respect the repo's worktree workflow, golden tests (`real-topology/`), and formatter rules.

## Tool Choices Used in This Research
- **`read`** tool: Inspected `machines/LINDA/default.nix` and `hardware-configuration.nix` to understand current machine config (CUDA, environments, hardware).
- **`bash`** tool: Ran `nix search` commands to discover available nixpkgs packages (`apriltag`, `rtabmap`, `libsurvive`, `monado`, `pcl`, `openpose`, etc.).
- **`grep`**: Searched the repository for existing references to tracking-related packages (none found).
- **`task`** tool (general agent): Used for initial broad research synthesis before applying corporate blacklist.
- **Avoided:** `webfetch` for general web searches (to prevent pulling in potentially tainted information). Stuck to nixpkgs searches and local repo analysis where possible.
- Deliberately avoided any Microsoft/GitHub Copilot-style tools or Google-linked services.

## Open Options Being Considered
1. **~~Prototype Path~~:** ~~Create `environments/spatial-computing.nix`~~ → **Done.** `denton-glasses` flake provides devShells and NixOS modules. See implementation proposal below.
2. **Full Integration Path:** Add ROS 2 environment + `rtabmap-ros`, `apriltag-ros`, and libsurvive integration.
3. **~~Packaging Work~~:** ~~Create a proper Nix package for Pupil Core~~ → OpenFace is packaged in `denton-glasses` via `github:DarthPJB/OpenFace`. Pupil Core still unpackaged.
4. **Hardware Prioritization:** 
   - Phase 1: AprilTag + Kinect + RTAB-Map (spatial mapping)
   - Phase 2: Add OpenPose + libsurvive
   - Phase 3: Add robust eye tracking via Pupil
5. **Testing Approach:** Use QEMU or direct hardware testing. Add golden tests if new services are added to topology.

## Open Questions
- How much effort should be put into packaging Pupil Core for Nix?
- Should we default to ROS 2 or keep the system lighter?
- Are there any other independent open-source eye tracking projects worth deeper investigation (e.g. OpenEyeTrack, ViSP extensions)?

---

## Implementation Proposal: denton-glasses on LINDA

### Context
- **LINDA** uses i3wm (X11), NVIDIA GPU with CUDA, 3x 4K webcams, Xbox Kinect, SteamVR tracking gear.
- **User:** `John88`
- **Display:** X11 (`:0`), not Wayland.
- **denton-glasses** provides two NixOS modules: `eye-tracking` (OpenFace) and `voxtype` (whisper speech-to-text).

### Recommended Implementation

```nix
# In machines/LINDA/default.nix — add to imports:
# (via flake.nix globalArgs, pass denton-glasses to _module.args)

# Then in LINDA config or a dedicated environment file:
{ config, pkgs, denton-glasses, ... }:
{
  imports = [
    denton-glasses.nixosModules.eye-tracking
    denton-glasses.nixosModules.voxtype
  ];

  # Eye tracking via OpenFace
  denton-glasses.eye-tracking = {
    enable = true;
    user = "John88";
    camera = "0";  # First 4K webcam; use v4l2-ctl --list-devices to verify
    autoStart = false;  # Manual start until validated
    outputDir = "/var/lib/denton-glasses/eye-tracking";
    outputFormat = "csv";
  };

  # Speech-to-text via Voxtype (whisper)
  services.voxtype = {
    enable = true;
    user = "John88";
    package = pkgs.voxtype-vulkan;  # GPU-accelerated via CUDA
    x11.display = ":0";  # LINDA uses X11 i3wm
    loadModels = [ "base.en" ];
    settings = {
      whisper = {
        model = "base.en";
        language = "en";
      };
      output = {
        mode = "type";
        fallback_to_clipboard = true;
      };
    };
  };
}
```

### Wiring Steps

1. **Pass `denton-glasses` to LINDA's module args** in `flake.nix`:
   ```nix
   # In globalArgs or LINDA's mkX86_64 call:
   _module.args = globalArgs // {
     inherit denton-glasses;
     # ... existing args
   };
   ```
   Or add it to `globalArgs` if other machines will use it.

2. **Create `environments/denton-glasses.nix`** (optional, for clean separation):
   ```nix
   # environments/denton-glasses.nix
   { config, pkgs, denton-glasses, ... }:
   {
     imports = [
       denton-glasses.nixosModules.eye-tracking
       denton-glasses.nixosModules.voxtype
     ];
     # ... config as above
   }
   ```
   Then import from LINDA: `../../environments/denton-glasses.nix`

3. **Validate camera devices** on LINDA:
   ```bash
   v4l2-ctl --list-devices
   ```
   Update `camera` to the correct device index or `/dev/videoN` path.

4. **Test manually before autoStart**:
   ```bash
   nix run denton-glasses#FaceLandmarkVid -- -device 0 -pose -aus -gaze
   ```

### Phased Rollout

| Phase | What | Risk |
|-------|------|------|
| 1 | Enable `eye-tracking` module, `autoStart = false` | None — installs package, no service |
| 2 | Manual test with webcam, validate output | Low — user-initiated |
| 3 | Enable `voxtype` with X11 display | Low — user service, no system impact |
| 4 | Set `autoStart = true` for eye tracking | Medium — persistent service |
| 5 | Add devShell for spatial computing prototyping | None — dev only |

### What This Does NOT Do
- Does not add OpenPose, RTAB-Map, or libsurvive as system services (those are devShell-only)
- Does not affect golden tests or topology (no network services)
- Does not add ROS 2 (future work)
- Does not package Pupil Core (still a gap)

---

**This document is considered living.** It should be updated as new discoveries are made or constraints change. All future work on the spatial tracking stack for LINDA must reference and respect the blacklist and preferred tools listed above.

**Last Updated:** 2026-06-15 — Updated to reference `denton-glasses` flake as canonical implementation source. Added LINDA implementation proposal.
