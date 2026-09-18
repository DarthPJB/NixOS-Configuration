# pillar-of-autum — Planning: Velocity & Track

> **Last updated:** 2026-09-17
> **Status:** Phase 1–3 complete. Phase 2 (AI backend) complete — Ollama + LiteLLM live.
> **Companion runbook:** `pillar-of-autum.md` (workflow record + deployment runbook)

This document holds the **expected velocity and track** for `pillar-of-autum` from
first assimilation through its intended role as a fleet **AI inference backend**.

---

## 1. Mission & Intended Future Purpose

`pillar-of-autum` (ASUS NUC14RVH-B, Intel Core Ultra 5 125H, 16 GiB RAM, integrated
Arc graphics) is being assimilated as the **first proven assimilator-probe deployment**.

Its intended future purpose, per `documentation/ai-stack.md`
("Future Expansion → Additional backends: **pillar-of-autum**, dlyon-PC (provisioning)"),
is to become an **AI inference backend** for the fleet LiteLLM gateway
(`agentic-gateway.johnbargman.net`), alongside LINDA (CPU+GPU) and cluster-box (GPU).

The NUC's Intel Core Ultra 5 125H has an integrated **Arc (Meteor Lake) GPU** with
oneAPI/Vulkan support — a candidate for CPU+iGPU inference (Ollama) without a discrete
GPU.

---

## 2. Track (Phases)

### Phase 1 — Assimilation & Proven Bootstrap (COMPLETE)

**Goal:** Prove the assimilator-probe x86-bootstrap workflow end-to-end; deploy a
minimal librex11 headed system.

| # | Task | Status |
|---|------|--------|
| 1.1 | Probe discovery (mDNS + inspect SSH) | ✅ done |
| 1.2 | Hardware capture → `hardware-configuration.nix` | ✅ done |
| 1.3 | Minimal librex11 headed config (i3 + lightdm + XLibre) | ✅ done |
| 1.4 | Topology (WG peer 110, LAN peer 150) + WG keys (secrix) | ✅ done |
| 1.5 | flake.nix registration + golden + validation | ✅ done |
| 1.6 | nixinate `switch` over LAN (10.88.128.150) | ✅ done |
| 1.7 | Verify WG (10.88.127.110) + headed session | ✅ done |
| 1.8 | Reset flake.nix to WG IP + commit | ✅ done |

**Exit criteria met:** System deployed, running on NVMe, hostname `pillar-of-autum`.

### Phase 2 — AI Inference Backend (COMPLETE)

**Goal:** Stand up Ollama (CPU + iGPU) and register as a LiteLLM backend.

| # | Task | Status | Notes |
|---|------|--------|-------|
| 2.1 | Evaluate iGPU inference (oneAPI/Vulkan, Arc on Meteor Lake) | ✅ done | Intel compute runtime configured; Vulkan iGPU offload pending further profiling. |
| 2.2 | Add `services/ollama.nix` to machine config | ✅ done | `machines/pillar-of-autum/ollama.nix`; iGPU drivers in `default.nix` |
| 2.3 | Pre-load 1–2 models | ✅ done | `qwen2.5:3b` + `qwen2.5:7b` pulled; Modelfile profiles `pillar-qwen3b` / `pillar-qwen7b` created |
| 2.4 | Register backend in `machines/alpha-three/default.nix` LiteLLM | ✅ done | `pillar-qwen3b` + `pillar-qwen7b` backends on `http://10.88.127.110:11434/v1` |
| 2.5 | Prometheus scrape target + Grafana dashboard entry | ⏳ pending | Close the "missing monitoring" gap |
| 2.6 | Regenerate golden + deploy | ✅ done | Topology firewall (port 11434 on wireg0) + golden + deployed |

**Live validation (2026-09-18):**

| Test | Result |
|------|--------|
| Ollama running on pillar-of-autum | ✅ `systemctl start ollama` → active |
| Models pulled | ✅ `qwen2.5:3b` (1.9 GiB), `qwen2.5:7b` (4.7 GiB) |
| Modelfile profiles created | ✅ `pillar-qwen3b` (8K ctx, 8 threads), `pillar-qwen7b` (4K ctx, 12 threads) |
| Direct inference on pillar-of-autum | ✅ `curl http://10.88.127.110:11434/api/generate` → response |
| LiteLLM gateway → pillar-of-autum | ✅ `curl http://127.0.0.1:8080/v1/chat/completions` with model `pillar-qwen3b/pillar-qwen3b` → response |
| Firewall port 11434 on wireg0 | ✅ Topology updated, golden regenerated |

**Fix applied:** Topology `pillar-of-autum.json` was missing a `firewall` section.
Port 11434 (Ollama) was not open on `wireg0`. Added `firewall.interfaces.wireg0.tcp = [11434]`
to match the LINDA pattern. This blocked the LiteLLM → pillar-of-autum connection until
the topology change was deployed.

**CPU inference benchmarks (Ollama 0.30.6):**

| Model | Size | Output Speed | Assessment |
|-------|------|--------------|------------|
| `qwen2.5:0.5b` | 397 MB | 65.5 tok/s | Excellent for interactive |
| `qwen2.5:3b` | 1.9 GiB | 17.1 tok/s | Good for LiteLLM backend |
| `qwen2.5:7b` | 4.7 GiB | 8.0 tok/s | Viable for batch/async |

**Exit criteria met:** LiteLLM gateway routes to pillar-of-autum; chat completion
returns through the full chain.

### Phase 3 — Permanent Install (NVMe) (COMPLETE)

**Goal:** Migrate from the USB boot medium to the 238.5 GiB NVMe for a durable install.

| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.1 | Partition/format `nvme0n1` (ESP + root + swap) | ✅ done | 976M ESP + 13.9G swap + 223.6G root |
| 3.2 | Update `hardware-configuration.nix` fileSystems to NVMe UUIDs | ✅ done | Golden regenerated |
| 3.3 | Migrate bootloader to systemd-boot (non-removable) | ⏳ pending | Still using GRUB EFI removable |
| 3.4 | Copy `/nix/store` closure to NVMe | ✅ done | |
| 3.5 | Rebuild + switch from NVMe; verify boot | ✅ done | USB no longer required |

**Exit criteria met:** System boots from NVMe, all services + WG intact. Bootloader
migration to systemd-boot deferred (low priority, GRUB works).

### Phase 4 — Fleet Integration & Hardening

**Goal:** Full fleet membership.

| # | Task | Notes |
|---|------|-------|
| 4.1 | Add to `~/.ssh/config` (inspect + deploy) | Port 1108 |
| 4.2 | CI build job (x86_64 machine list) | `ci.nix` auto-derives from nixosConfigurations |
| 4.3 | Backup topology key (if applicable) | `topology.backup` |
| 4.4 | genWireguard migration (overlord-iii) | When the pipeline lands |

### Phase 5 — OpenVINO / NPU Exploration (FUTURE)

**Goal:** Benchmark Intel NPU inference via OpenVINO; evaluate for fleet expansion.

This phase begins after Ollama is operational and benchmarking knowledge is
established. OpenVINO is a **separate inference engine** — it does not consume
GGUF models and does not replace Ollama/vLLM. It targets INT8/INT4 quantized
models optimised for Intel hardware, running on the dedicated NPU
(`/dev/accel0`, `intel_vpu` driver, device `0x7d1d`).

**Primary use case:** The NPU is **not viable for LLM inference** (4 MB SRAM,
11 TOPS). Its strength is **always-on, low-power vision/sensory inference** for
the `environments/denton-glasses` component — eye tracking (OpenFace), speech-
to-text (Whisper tiny/base), object detection (YOLO), and background presence
detection. See `documentation/pillar-of-autum.md` §5.7 for the full analysis.

| # | Task | Notes |
|---|------|-------|
| 5.1 | Package `optimum-intel` (or pip venv) | HuggingFace → OpenVINO IR model conversion |
| 5.2 | Test `openvino-genai` pipeline on CPU | Validate OpenVINO IR inference path without NPU |
| 5.3 | Benchmark NPU inference via `intel_vpu` plugin | Compare tok/s against Ollama CPU/iGPU baselines |
| 5.4 | Convert Whisper tiny/base to OpenVINO IR | Target: denton-glasses speech-to-text on NPU |
| 5.5 | Convert OpenFace models to OpenVINO IR | Target: denton-glasses eye tracking on NPU |
| 5.6 | Benchmark NPU vs iGPU vs CPU for vision tasks | Per-workload power/perf comparison |
| 5.7 | Evaluate `onednn` for bottom-up approach | Direct kernel/memory control for custom pipelines |

**Available packages in `nixpkgs_llm` (2026-09-17):**

| Package | Version | Purpose |
|---------|---------|---------|
| `openvino` | 2026.3.0 | Core toolkit — inference engine, model optimizer, CPU/GPU/NPU plugins |
| `openvino-genai` | 2026.3.0.0 | Generative AI pipeline library (LLMs, text/image/speech) |
| `openvino-tokenizers` | 2026.3.0.0 | Tokenisation extensions |
| `python3Packages.openvino` | 2026.3.0 | Python bindings |
| `python3Packages.openvino-genai` | 2026.3.0.0 | Python GenAI API |
| `intel-npu-driver` | 1.35.0 | Already deployed via `hardware.cpu.intel.npu.enable` |
| `level-zero` | — | Low-level Intel compute API |
| `onednn` / `onednn_2` | — | oneAPI Deep Neural Network Library |

**Not packaged:** `optimum-intel` (HuggingFace integration). Would need to be
packaged or used via pip in a venv for model conversion.

**Exit criteria:** NPU inference benchmarked, tok/s comparison table published,
recommendation on NPU viability for fleet inference.

---

## 3. Expected Velocity

Estimates assume a single operator + agent, builds from source (no third-party cache),
and the in-house binary cache **not** yet operational (per AGENTS.md Build Philosophy).

| Phase | Scope | Expected velocity | Actual | Dominant cost |
|-------|-------|-------------------|--------|---------------|
| **Phase 1** | Assimilation + first deploy | **~0.5–1 day** | ✅ Complete | nixinate `switch` closure copy over LAN; first native build of Determinate Nix + XLibre on-target |
| **Phase 2** | AI backend | **~2–4 days** | ✅ Complete | Ollama deployed, models loaded, LiteLLM registered, end-to-end validated |
| **Phase 3** | NVMe permanent install | **~1–2 days** | ✅ Complete | `/nix/store` migration + bootloader cutover; low technical risk, high care |
| **Phase 4** | Fleet integration | **~0.5–1 day** | ⏳ Pending | CI + backup + hardening; mostly mechanical |
| **Phase 5** | OpenVINO / NPU | **~2–3 days** | ⏳ Future | Model conversion pipeline; NPU benchmarking; `optimum-intel` packaging |

**Total to full AI-backend fleet member: ~4–8 working days**, dominated by Phase 2's
iGPU inference evaluation.

### Velocity assumptions & risks

- **Correctness over speed** (AGENTS.md): a four-hour build is acceptable if it
  guarantees correctness. Estimates are floors, not deadlines.
- **No third-party cache:** builds complete from source within the closed environment
  until the in-house binary cache is operational. First on-target builds (Determinate
  Nix, XLibre, Ollama) are the slowest step.
- **iGPU inference is the key unknown:** Meteor Lake Arc + oneAPI/Vulkan + Ollama is
  not yet proven in this fleet. If iGPU inference is not viable, Phase 2 falls back to
  **CPU-only Ollama** (still a valid backend, smaller models), which is faster to land.
- **Single-model-per-device:** enforce one model per device to prevent RAM/VRAM
  exhaustion (ai-stack.md "Current Limitations").

---

## 4. Dependencies

| Dependency | Status | Blocks |
|------------|--------|--------|
| assimilator-probe flake input | ✅ pinned in flake.lock | Phase 1 |
| xlibre-overlay flake input | ✅ pinned (main, for 26.05) | Phase 1 (XLibre) |
| nixinate | ✅ flake input | Phase 1 (deploy) |
| secrix | ✅ flake input | Phase 1 (WG keys) |
| LiteLLM gateway (alpha-three) | ✅ active (staging) | Phase 2 |
| Ollama / vLLM modules | ✅ `services/ollama.nix`, `modules/vllm.nix` | Phase 2 |
| In-house binary cache | ⏳ planned | All phases (speed) |
| genWireguard pipeline (overlord-iii) | ⏳ deferred | Phase 4 |

---

## 5. Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-08-27 | Name is `pillar-of-autum` (no extra `n`) | User directive; misspelling `pillar-of-autumn` prohibited in code |
| 2026-08-27 | Initial config = minimal librex11 headed (i3 + lightdm + XLibre) | User directive; similar to alpha-one but minimal |
| 2026-08-27 | WG peer_id 110, LAN peer_id 150 | 110 is next free after alpha series (107–109); 150 matches current DHCP address |
| 2026-08-27 | Keep GRUB EFI removable for first `switch` | Bootloader continuity on existing ESP; systemd-boot is a Phase 3 follow-up |
| 2026-08-27 | hardware-configuration.nix references USB (sda) partitions | First deploy switches the running USB system; NVMe is Phase 3 |
| 2026-09-17 | CPU-only Ollama for Phase 2 | Intel compute runtime not installed; iGPU inference blocked. CPU viable for 3B–7B models. |
| 2026-09-17 | Recommended models: `qwen2.5:3b` (interactive), `qwen2.5:7b` (batch) | Benchmarked on live hardware: 17.1 tok/s and 8.0 tok/s respectively |
| 2026-09-17 | `intel-compute-runtime` added to `default.nix` | Enables OpenCL/iGPU for Ollama Vulkan offload; per-system graphics in per-system config |
| 2026-09-17 | OpenVINO/NPU deferred to Phase 5 | Ollama first → benchmarking → OpenVINO later. Separate engine, separate model format (IR, not GGUF). |
| 2026-09-17 | `onednn` noted for bottom-up approach | Available in `nixpkgs_llm`; may serve as low-level backend for custom inference pipelines |
| 2026-09-18 | Topology firewall: port 11434 on wireg0 | Missing firewall rule blocked LiteLLM → pillar-of-autum. Added `firewall.interfaces.wireg0.tcp = [11434]` matching LINDA pattern. |
| 2026-09-18 | LiteLLM backends: `pillar-qwen3b`, `pillar-qwen7b` | Registered in `machines/alpha-three/default.nix`; context 8K/4K, output 2K, timeout 300s/600s |
| 2026-09-18 | Phase 2 exit criteria met | End-to-end validated: LiteLLM → WireGuard → pillar-of-autum Ollama → response |
