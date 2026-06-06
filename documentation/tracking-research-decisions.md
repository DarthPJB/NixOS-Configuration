# Tracking Research Decisions - LINDA Machine

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
- **Primary:** Pupil Core (Pupil Labs) — University/research origins, fully open source, Linux support, works with webcams.
- **Secondary:** OpenFace (CMU + Cambridge), OpenCV + dlib models, custom gaze tracking with OpenCV.

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
- **Preferred Framework:** ROS 2 (Humble or Jazzy) — Provides unified graph for all above components.
- **Lightweight Alternative:** Pure Python/C++ with OpenCV + AprilTag + RTAB-Map libraries.
- **Nixpkgs Packages Confirmed Available:**
  - `apriltag`, `rtabmap`, `libsurvive`, `monado`, `pcl`, `freenect`, `opencv4`, `openpose`
  - Various Python bindings and ROS packages.

## Current Reasoning
- The removal of MediaPipe significantly raises the difficulty of high-quality real-time eye tracking and holistic pose estimation. Pupil Core + OpenPose is the best remaining fully open-source path.
- AprilTag + RTAB-Map + libsurvive form a very strong foundation for marker-based and spatial tracking with the available hardware (Kinect depth + SteamVR precision).
- LINDA's CUDA capability means we can run heavier models (OpenPose, RTAB-Map) efficiently.
- We should avoid adding heavy new system services until a prototype validates the stack.
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
1. **Prototype Path:** Create `environments/spatial-computing.nix` with OpenCV, AprilTag, OpenPose, and a devShell. Test Pupil Core separately.
2. **Full Integration Path:** Add ROS 2 environment + `rtabmap-ros`, `apriltag-ros`, and libsurvive integration.
3. **Packaging Work:** Create a proper Nix package for Pupil Core (most complex missing piece).
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

**This document is considered living.** It should be updated as new discoveries are made or constraints change. All future work on the spatial tracking stack for LINDA must reference and respect the blacklist and preferred tools listed above.

**Last Updated:** 2026-06-06 by autonomous research agent.
