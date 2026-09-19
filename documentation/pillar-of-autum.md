# pillar-of-autum — Assimilation & Deployment Workflow

> **Last updated:** 2026-09-17
> **Status:** Deployed and running on NVMe. Ollama inference validated (CPU-only).
> **Machine:** `pillar-of-autum` (ASUS NUC14RVH-B, Intel Core Ultra 5 125H)
> **Spelling:** `pillar-of-autum` — **NOT** `pillar-of-autumn`. The extra `n` is a known
> misspelling and must not appear in code, topology, goldens, or commits.

This document is the **record of actions and method of completion** for the first
"proven" assimilator-probe assimilation. It doubles as the runbook for the follow-up
nixinate deployment. Companion planning document: `planning-pillar-of-autum.md`.

---

## 1. Purpose

`pillar-of-autum` is the first machine assimilated end-to-end via the
**assimilator-probe x86-bootstrap** workflow. Its initial configuration is a
**minimal librex11 (XLibre X11) headed system**, similar in shape to `alpha-one`
(i3 + lightdm), built on the existing `@flake.nix` infrastructure.

**Intended future purpose** (per `documentation/ai-stack.md`, "Future Expansion →
Additional backends"): an **AI inference backend** for the fleet LiteLLM gateway,
alongside LINDA and cluster-box.

---

## 2. Hardware Identification (Probe Discovery)

The assimilator-probe was deployed via the generic `x86-bootstrap` raw-disk image
(USB boot, GRUB EFI removable). Discovery followed the standard protocol
(`documentation/x86-bootstrap-deployment-workflow.md`, Stage 2):

| Step | Command | Result |
|------|---------|--------|
| mDNS discovery | `avahi-resolve -n x86-bootstrap.local` | `10.88.128.150` (IPv4), `fe80::8aae:ddff:fe66:70ff` (IPv6) |
| Service enumeration | `avahi-browse -a -t` | `x86-bootstrap [88:ae:dd:66:70:ff] _workstation._tcp` |
| Host key pre-check | `grep 10.88.128.150 ~/.ssh/known_hosts` | `[10.88.128.150]:1108 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE5fWYYizH6kYupOXVB0Eq7qCl68dUkySNdvFEBeW9zo` |
| SSH (inspect, read-only) | `ssh -p 1108 inspect@10.88.128.150` | Banner: "ASSIMILATOR PROBE … Awaiting assimilation." |

**Hardware captured** (read-only `inspect` access, port 1108):

| Attribute | Value |
|-----------|-------|
| Chassis | ASUS NUC14RVH-B (mini-PC) |
| CPU | Intel Core Ultra 5 125H, 18 cores (Meteor Lake, integrated Arc graphics) |
| RAM | 16 GiB |
| Boot medium | `sda` — 118.1 GiB USB flash drive |
| └ `/boot` (ESP) | `sda1`, 1 GiB vfat, UUID `12CE-A600` |
| └ swap | `sda2`, 8 GiB, UUID `851d149e-df1d-4dea-9253-fb64340d714d` |
| └ `/` (root) | `sda3`, 11 GiB ext4, UUID `793f5bea-fb84-4c96-a832-3a8b287a760a` |
| Target storage | `nvme0n1` — 238.5 GiB addlink M.2 PCIe NVMe (pre-existing partitions, unmounted) |
| Wired NIC | `enp86s0`, MAC `88:ae:dd:66:70:ff` |
| WiFi NIC | `wlo1`, MAC `00:d7:6d:e0:5f:83` |
| OS (probe) | NixOS 26.05.20260724.597283a, kernel 6.18.39 |
| machine-id | `7bdcbf4385dd4d489e4bf86fc5dafd0b` |

The partition UUIDs above were read from `/dev/disk/by-uuid` on the running probe and
are the source of truth for `machines/pillar-of-autum/hardware-configuration.nix`.

---

## 3. Configuration Implementation (Completed)

The following files were created/modified to implement the system configuration on the
existing `@flake.nix` infrastructure:

| File | Action | Purpose |
|------|--------|---------|
| `machines/pillar-of-autum/hardware-configuration.nix` | **created** | Probe hardware scan: USB boot layout (by UUID), initrd modules, Intel microcode |
| `machines/pillar-of-autum/default.nix` | **created** | Minimal librex11 headed system: i3 + lightdm (via `i3wm_darthpjb.nix`), WG topology, GRUB EFI removable (mirrors bootstrap), Intel graphics |
| `topology/pillar-of-autum.json` | **created** | Planar topology: `wg` plane peer_id **110** (10.88.127.110), `cortex-alpha.lan` plane peer_id **150** (10.88.128.150, interface `enp86s0`) |
| `secrets/public_keys/host_keys/pillar-of-autum.pub` | **created** | Device SSH host public key (archived from probe, Stage 3) |
| `secrets/public_keys/wireguard/wg_pillar-of-autum_pub` | **created** | WireGuard public key |
| `secrets/private_keys/wireguard/wg_pillar-of-autum` | **created** | WireGuard private key, age-encrypted to John88 + host (secrix) |
| `flake.nix` | **modified** | Registered `pillar-of-autum = mkX86_64 "pillar-of-autum" { … }` with `xlibre-overlay` extraModules |
| `goldens/pillar-of-autum.json` | **created** | Golden test reference (ground truth) |

### 3.1 librex11 (XLibre X11) wiring

"librex11" is the **XLibre X11** server (community fork of X.org X11). It is provided
by the existing `xlibre-overlay` flake input (already used by LINDA) and passed through
`extraModules` in `flake.nix` (flake inputs cannot be referenced from a machine
config's `imports`):

```nix
pillar-of-autum = mkX86_64 "pillar-of-autum" {
  host = topoIp "pillar-of-autum";
  extraModules = [
    xlibre-overlay.nixosModules.overlay-xlibre-xserver      # xorg-server → xlibre-xserver
    xlibre-overlay.nixosModules.overlay-all-xlibre-drivers  # X11 drivers
  ];
};
```

Verified applied: `services.xserver.terminateOnReset = false` (set by the overlay) and
28 nixpkgs overlays present.

### 3.2 Headed environment (similar to alpha-one)

`machines/pillar-of-autum/default.nix` imports `environments/i3wm_darthpjb.nix`
(i3 + lightdm + bargman greeter + picom), the same headed stack as `alpha-one`, but
**without** alpha-one's NVIDIA driver, opencode-fleet, or the heavy environment
modules (steam, code, neovim, etc.) — hence "minimal". Intel integrated graphics use
the default modesetting driver (`hardware.graphics.enable = true`).

### 3.3 Bootloader

The config mirrors the bootstrap image's **GRUB EFI removable** bootloader
(`efiInstallAsRemovable = true`, `canTouchEfiVariables = false`) so the first
nixinate `switch` activates cleanly on the existing ESP. A permanent-install
bootloader migration (systemd-boot on the NVMe) is a documented follow-up
(see `planning-pillar-of-autum.md`, Phase 3).

---

## 4. Validation Performed (Completed)

| Check | Command | Result |
|-------|---------|--------|
| Config evaluates | `nix eval … .config.networking.hostName` | `"pillar-of-autum"` |
| WireGuard enabled | `… .config.networking.wireguard.enable` | `true` (10.88.127.110/32, hub peer cortex-alpha) |
| X server + i3 + lightdm | `… .config.services.xserver.{enable,windowManager.i3.enable,displayManager.lightdm.enable}` | all `true` |
| XLibre overlay applied | `… .config.services.xserver.terminateOnReset` | `false` |
| Golden generated | `nix run .#dump-config -- pillar-of-autum \| jq -S . > goldens/pillar-of-autum.json` | 85 KB |
| Golden matches | `nix run .#validate-goldens -- pillar-of-autum` | ✓ matches |
| Topology coverage | `lib/golden_coverage.nix` | 100% (12/12), no missing |
| Topology registry | `lib/topology/mkRegistry.nix` | 0 errors, 0 warnings |

**Note on git tracking:** Nix flakes only see git-tracked paths. New files required
`git add -N <path>` (intent-to-add) before `nix eval`/`nix run` could resolve them.

---

## 5. Live System Diagnostics (2026-09-17)

The system is now deployed and running from the NVMe drive (Phase 3 complete).

### 5.1 Current Storage Layout

| Device | Size | Type | Mount |
|--------|------|------|-------|
| `nvme0n1` | 238.5 GiB | M.2 PCIe NVMe | — |
| └ `nvme0n1p1` | 976 MiB | ESP | `/boot` |
| └ `nvme0n1p2` | 13.9 GiB | swap | `[SWAP]` |
| └ `nvme0n1p3` | 223.6 GiB | ext4 | `/nix/store`, `/` |

### 5.2 CPU Details

| Attribute | Value |
|-----------|-------|
| Model | Intel Core Ultra 5 125H |
| Architecture | Meteor Lake (family 6, model 170, stepping 4) |
| Cores | 14 cores / 18 threads (6P + 8E + 2LP) |
| Max frequency | 4500 MHz |
| Min frequency | 400 MHz |
| L1d cache | 448 KiB (12 instances) |
| L1i cache | 768 KiB (12 instances) |
| L2 cache | 14 MiB (7 instances) |
| L3 cache | 18 MiB |
| Key flags | avx2, avx_vnni, fma, f16c, aes, sha_ni, amx_tile, amx_int8, amx_bf16 |

### 5.3 Memory

| Attribute | Value |
|-----------|-------|
| Total RAM | 14.94 GiB (15,666,696 kB) |
| Available (idle) | ~13.8 GiB |
| Swap | 13.9 GiB |

### 5.4 GPU — Intel Arc (Meteor Lake-P)

| Attribute | Value |
|-----------|-------|
| Device | Intel Corporation Meteor Lake-P [Intel Arc Graphics] (rev 08) |
| Kernel driver | `i915` (also available: `xe`) |
| Render node | `/dev/dri/renderD128` |
| Vulkan | Supported (Vulkan 1.4.341, Mesa 26.1.5) |
| Vulkan VRAM (shared) | 11.21 GiB device-local heap |
| OpenCL | Available via `intel-compute-runtime` (NEO) — configured in `default.nix` |
| GPU frequency | 800 MHz (idle), 2200 MHz (max observed) |

**iGPU inference status:** The Intel Arc iGPU is present and Vulkan-functional. Intel
compute runtime (`intel-compute-runtime` / NEO) is now configured in
`machines/pillar-of-autum/default.nix` via `hardware.graphics.extraPackages`. Ollama's
`OLLAMA_VULKAN=1` is set — live validation of iGPU offload is pending a deploy + reboot.

### 5.5 Ollama Inference Benchmarks (CPU-only)

Tested with Ollama 0.30.6, CPU-only inference (no GPU offload):

| Model | Size | Load Time | Prompt Eval | Output Tokens | Output Speed | Total Time |
|-------|------|-----------|-------------|---------------|--------------|------------|
| `qwen2.5:0.5b` | 397 MB | 0.16s | 36 tok / 0.017s | 97 | **65.5 tok/s** | 1.66s |
| `qwen2.5:3b` | 1.9 GiB | 1.71s | 40 tok / 0.64s | 218 | **17.1 tok/s** | 15.12s |
| `qwen2.5:7b` | 4.7 GiB | 3.48s | 40 tok / 1.56s | 417 | **8.0 tok/s** | 57.34s |

**Assessment:**
- **0.5B models:** Excellent for interactive use (>60 tok/s).
- **3B models:** Good for interactive use (~17 tok/s). Suitable for LiteLLM backend.
- **7B models:** Usable but slower (~8 tok/s). Acceptable for batch/async workloads.
- **13B+ models:** Would require >10 GiB RAM for weights alone; with KV cache, likely
  to swap on the 14.9 GiB system. Not recommended without iGPU offload.
- **Single-model-per-device discipline** is enforced (per `ai-stack.md`).

**Recommended models for LiteLLM backend:**
- `qwen2.5:3b` (Q4_K_M) — best balance of speed and quality for CPU-only
- `qwen2.5:7b` (Q4_K_M) — viable for non-interactive workloads

### 5.6 NPU — Intel Neural Processing Unit

| Attribute | Value |
|-----------|-------|
| Device | Intel NPU (Meteor Lake), PCI `0x7d1d` |
| Kernel driver | `intel_vpu` (loaded, bound) |
| Device node | `/dev/accel0` |
| NPU driver pkg | `intel-npu-driver` 1.35.0 (via `hardware.cpu.intel.npu.enable`) |
| Level Zero | `level-zero` available in `nixpkgs_llm` |

The Intel NPU is a dedicated inference accelerator separate from the CPU and iGPU.
It is **not** usable by Ollama or llama.cpp — those engines use CPU (llama.cpp) or
GPU (Vulkan/CUDA). The NPU requires the OpenVINO runtime and its `intel_vpu` plugin.

**OpenVINO capability in `nixpkgs_llm` (2026-09-17 research):**

| Package | Version | Purpose |
|---------|---------|---------|
| `openvino` | 2026.3.0 | Core toolkit — inference engine, model optimizer, CPU/GPU/NPU plugins |
| `openvino-genai` | 2026.3.0.0 | Generative AI pipeline library (LLMs, text/image/speech generation) |
| `openvino-tokenizers` | 2026.3.0.0 | Text tokenisation extensions |
| `python3Packages.openvino` | 2026.3.0 | Python bindings |
| `python3Packages.openvino-genai` | 2026.3.0.0 | Python GenAI API |
| `intel-npu-driver` | 1.35.0 | Standalone NPU driver (already deployed) |
| `level-zero` | — | Low-level Intel compute API (GPU/NPU abstraction) |
| `onednn` / `onednn_2` | — | oneAPI Deep Neural Network Library (MKL-DNN) |

**Not present in `nixpkgs_llm`:**
- `optimum-intel` — HuggingFace → OpenVINO model conversion. Would need packaging
  or pip venv for model conversion workflows.

**NPU inference path:**
```
HuggingFace model → optimum-intel / Model Optimizer → OpenVINO IR (XML+BIN)
  → openvino-genai → intel_vpu plugin → /dev/accel0 (NPU)
```

OpenVINO uses its own IR format — it does not consume GGUF. It is a **separate
inference engine** from Ollama/vLLM, suited for INT8/INT4 quantized models that
OpenVINO optimises specifically for Intel hardware.

### 5.7 NPU Use Case — Homelab AI Vision (`environments/denton-glasses`)

The NPU's real value is **not** LLM inference — it's **always-on, low-power
vision and sensory inference** for edge-AI workloads. The `environments/denton-glasses.nix`
component defines the fleet's machine-perception augmentation stack:

- **Eye tracking** (OpenFace) — webcam → V4L2 → face/eye detection → gaze CSV
- **Speech-to-text** (Voxtype/Whisper) — USB mic → PipeWire → Whisper → keyboard input

Both workloads are **inference-bound, latency-sensitive, and power-sensitive** —
exactly what the NPU was designed for.

**NPU-fit workloads for denton-glasses:**

| Workload | NPU feasibility | Performance | Power advantage |
|----------|----------------|-------------|-----------------|
| Face detection (OpenFace) | ✅ Excellent | 30+ fps real-time | ~1-3W vs ~15-30W iGPU |
| Eye tracking (gaze estimation) | ✅ Excellent | Sub-frame latency | Always-on without battery drain |
| Whisper tiny/base (STT) | ✅ Yes | ~1-2x realtime | ~2W vs ~15W GPU |
| Whisper small/medium | ⚠️ Marginal | ~0.5x realtime | Model too large for SRAM |
| Object detection (YOLO) | ✅ Excellent | 30+ fps video | Ideal for camera feeds |
| Background blur / presence | ✅ Excellent | Real-time | Intel's primary NPU demo |

**Architecture — NPU as denton-glasses backend:**

```
Webcam (V4L2) ──→ OpenFace (NPU via OpenVINO) ──→ gaze CSV
                                                      │
Microphone ──→ Whisper (NPU via OpenVINO) ──→ voxtype ──→ keyboard input
                  ↑
            /dev/accel0 (intel_vpu)
            11 TOPS INT8, ~1-3W
```

**Why NPU over iGPU for vision tasks:**
- **Power:** NPU draws ~1-3W vs ~15-30W for iGPU — critical for always-on workloads
- **Thermals:** No fan spin-up during continuous camera inference
- **Dedicated:** NPU is not shared with display/compute — no frame drops during eye tracking
- **Privacy:** All inference on-silith, no cloud dependency

**Why NPU is wrong for LLMs:**
- 4 MB SRAM cannot hold LLM activations (even 1.5B INT4 is marginal)
- CPU/iGPU have 11+ GB of working memory for KV cache
- 11 TOPS is 10× less than a mid-range discrete GPU

**Integration path (future):**
1. Package `openvino` + `intel-npu-driver` from `pkgs_llm` into pillar-of-autum system
2. Convert OpenFace models to OpenVINO IR (or use Intel's pre-optimised models)
3. Convert Whisper tiny/base to OpenVINO IR via `optimum-intel`
4. Create `services.denton-glasses.npu-backend` option to route inference to NPU
5. Benchmark NPU vs iGPU vs CPU for each workload
6. If validated, deploy as always-on vision node for the fleet

**Candidate machines for NPU-backed denton-glasses:**
- `pillar-of-autum` — Intel NPU (Meteor Lake), confirmed working
- Future Intel Core Ultra machines with NPU silicon

The NPU is **not a replacement** for the iGPU — it's a **complementary engine**
for workloads where power efficiency and always-on capability matter more than
raw throughput. The iGPU handles large models; the NPU handles continuous
low-power inference.

### 5.8 Deployment Strategy

The intended deployment cycle for pillar-of-autum:

1. **Ollama payload (complete)** — `services/ollama.nix` deployed, CPU inference
   benchmarked, registered as LiteLLM backend, end-to-end validated.
2. **Benchmarking & profiling** — establish tok/s baselines across model sizes,
   measure iGPU offload gains once Vulkan offload validated on live system,
   compare CPU vs iGPU vs mixed execution.
3. **OpenVINO / NPU (future)** — package `openvino-genai` + `optimum-intel`, convert
   candidate models to OpenVINO IR, benchmark NPU inference via `/dev/accel0`,
   compare against Ollama CPU/iGPU baselines.

**onednn relevance:** The `onednn` package (oneAPI Deep Neural Network Library) is
available and may serve as a lower-level backend for experimentation — particularly
for the "bottom-up approach" project where direct control over kernel selection and
memory layout matters. Ollama's llama.cpp already links against oneDNN internally
for CPU inference; exposing it at the Nix level allows direct benchmarking and
potential integration with custom inference pipelines outside the Ollama/vLLM
envelope.

---

## 6. Deployment Workflow (Completed — nixinate)

This is the runbook for the first "proven" deployment. It mirrors
`documentation/x86-bootstrap-deployment-workflow.md` Stages 5–7.

### Pre-deployment checklist

- [ ] Probe still reachable: `avahi-resolve -n x86-bootstrap.local` → `10.88.128.150`
- [ ] SSH works: `ssh -p 1108 inspect@10.88.128.150 "hostname"` → `x86-bootstrap`
- [ ] Golden passes: `nix run .#validate-goldens -- pillar-of-autum`
- [ ] WG keys present: `ls secrets/public_keys/wireguard/wg_pillar-of-autum_pub`
- [ ] Host key archived: `ls secrets/public_keys/host_keys/pillar-of-autum.pub`

### Stage A — Deploy over LAN (temporary)

1. **Point flake.nix at the device's LAN IP** (temporary):
   ```nix
   pillar-of-autum = mkX86_64 "pillar-of-autum" {
     host = "10.88.128.150";   # TEMPORARY: LAN IP (was: topoIp "pillar-of-autum")
     …
   };
   ```
2. **Deploy with nixinate** (switches the running USB system):
   ```bash
   nix run .#pillar-of-autum --option builders '' -- switch
   ```
3. **Reset flake.nix** to the WireGuard IP:
   ```nix
   host = topoIp "pillar-of-autum";   # back to 10.88.127.110
   ```
4. **Commit and push** the reset.

### Stage B — Verify

1. **WireGuard connectivity:** `ping 10.88.127.110`
2. **SSH on WG:** `ssh -p 1108 deploy@10.88.127.110`
3. **Hostname changed:** `ssh -p 1108 inspect@10.88.127.110 "hostname"` → `pillar-of-autum`
4. **Headed session:** confirm lightdm greeter + i3 session on the attached display
   (XLibre X11 server running).
5. **Golden re-check:** `nix run .#validate-goldens -- pillar-of-autum`

### Stage C — Post-deployment

- [ ] Add `pillar-of-autum` to `~/.ssh/config` (inspect + deploy entries, port 1108)
- [ ] Record the deployment in `shared_updates.md`
- [ ] Proceed to `planning-pillar-of-autum.md` Phase 2 (AI backend) / Phase 3 (NVMe)

---

## 6. Key Differences from Prior Deployments

| Aspect | arm-bootstrap (ARM) | x86-bootstrap → pillar-of-autum |
|--------|---------------------|----------------------------------|
| Image format | SD card (`.img`) | Raw disk (`.raw`, GPT, USB) |
| SSH port | 22 | 1108 |
| Module source | Raw NixOS modules | assimilator-probe nixosModule |
| Cross-compilation | Yes (x86_64 → aarch64) | No (native x86_64) |
| Bootloader | extlinux (Raspberry Pi) | GRUB EFI removable (`EFI/BOOT/BOOTX64.EFI`) |
| Diagnostics | None | Boot-time `/run/diagnostics/hardware.json` |
| X server | — | **XLibre (librex11)** via xlibre-overlay |
| Determinate Nix | Not in bootstrap | Not in bootstrap (native build on first deploy) |

---

## 7. Lessons / Notes

1. **Spelling discipline:** `pillar-of-autum` (no extra `n`). Enforced in code comments,
   topology `hostname`, and golden.
2. **Git intent-to-add:** New files must be `git add -N` before Nix can see them in a
   flake.
3. **secrix system resolution:** `nix run .#secrix encrypt … -s <host>` resolves the
   host from `nixosConfigurations` — the machine must be registered in `flake.nix`
   **before** its WG private key can be encrypted with `-s <host>`.
4. **Bootloader continuity:** Keep GRUB EFI removable for the first `switch` so the
   existing ESP boots the new kernel without EFI-variable changes.
5. **Read-only inspection:** All probe hardware discovery used the `inspect` user
   (no sudo, port 1108) per the SSH Access Standard.
