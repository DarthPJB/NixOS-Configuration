# pillar-of-autum — Planning: Velocity & Track

> **Last updated:** 2026-08-27
> **Status:** Phase 1 (assimilation) configuration complete. Planning Phases 2–4.
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

### Phase 1 — Assimilation & Proven Bootstrap (CURRENT)

**Goal:** Prove the assimilator-probe x86-bootstrap workflow end-to-end; deploy a
minimal librex11 headed system.

| # | Task | Status |
|---|------|--------|
| 1.1 | Probe discovery (mDNS + inspect SSH) | ✅ done |
| 1.2 | Hardware capture → `hardware-configuration.nix` | ✅ done |
| 1.3 | Minimal librex11 headed config (i3 + lightdm + XLibre) | ✅ done |
| 1.4 | Topology (WG peer 110, LAN peer 150) + WG keys (secrix) | ✅ done |
| 1.5 | flake.nix registration + golden + validation | ✅ done |
| 1.6 | **nixinate `switch` over LAN (10.88.128.150)** | ⏳ pending |
| 1.7 | Verify WG (10.88.127.110) + headed session | ⏳ pending |
| 1.8 | Reset flake.nix to WG IP + commit | ⏳ pending |

**Exit criteria:** `pillar-of-autum` reachable on WireGuard at 10.88.127.110, hostname
changed, lightdm+i3 (XLibre) session visible on display, golden passes.

### Phase 2 — AI Inference Backend

**Goal:** Stand up Ollama (CPU + iGPU) and register as a LiteLLM backend.

| # | Task | Notes |
|---|------|-------|
| 2.1 | Evaluate iGPU inference (oneAPI/Vulkan, Arc on Meteor Lake) | Determine viable model sizes |
| 2.2 | Add `services/ollama.nix` (or vLLM) to machine config | CPU-only first, iGPU if viable |
| 2.3 | Pre-load 1–2 models (e.g. a 7–14B Q4) | Single-model-per-device discipline |
| 2.4 | Register backend in `machines/alpha-three/default.nix` LiteLLM | `pillar-of-autum/*` prefix |
| 2.5 | Prometheus scrape target + Grafana dashboard entry | Close the "missing monitoring" gap |
| 2.6 | Regenerate golden + deploy | `nix run .#pillar-of-autum -- switch` |

**Exit criteria:** `curl https://agentic-gateway.johnbargman.net/v1/models` lists
`pillar-of-autum/*`; a chat completion routes to the NUC and returns.

### Phase 3 — Permanent Install (NVMe)

**Goal:** Migrate from the USB boot medium to the 238.5 GiB NVMe for a durable install.

| # | Task | Notes |
|---|------|-------|
| 3.1 | Partition/format `nvme0n1` (ESP + root + swap) | disko or manual; back up first |
| 3.2 | Update `hardware-configuration.nix` fileSystems to NVMe UUIDs | Regenerate golden |
| 3.3 | Migrate bootloader to systemd-boot (non-removable) | Set EFI boot variable |
| 3.4 | Copy `/nix/store` closure to NVMe (see operational_patterns.md) | Re-copy after deploy |
| 3.5 | Rebuild + switch from NVMe; verify boot | Remove USB |

**Exit criteria:** System boots from NVMe, USB removed, all services + WG intact.

### Phase 4 — Fleet Integration & Hardening

**Goal:** Full fleet membership.

| # | Task | Notes |
|---|------|-------|
| 4.1 | Add to `~/.ssh/config` (inspect + deploy) | Port 1108 |
| 4.2 | CI build job (x86_64 machine list) | `ci.nix` auto-derives from nixosConfigurations |
| 4.3 | Backup topology key (if applicable) | `topology.backup` |
| 4.4 | genWireguard migration (overlord-iii) | When the pipeline lands |

---

## 3. Expected Velocity

Estimates assume a single operator + agent, builds from source (no third-party cache),
and the in-house binary cache **not** yet operational (per AGENTS.md Build Philosophy).

| Phase | Scope | Expected velocity | Dominant cost |
|-------|-------|-------------------|---------------|
| **Phase 1** | Assimilation + first deploy | **~0.5–1 day** (config done; deploy + verify is the remainder) | nixinate `switch` closure copy over LAN; first native build of Determinate Nix + XLibre on-target |
| **Phase 2** | AI backend | **~2–4 days** | iGPU inference evaluation (oneAPI/Vulkan on Meteor Lake is the unknown); model download + VRAM/RAM sizing; gateway wiring |
| **Phase 3** | NVMe permanent install | **~1–2 days** | `/nix/store` migration + bootloader cutover; low technical risk, high care |
| **Phase 4** | Fleet integration | **~0.5–1 day** | CI + backup + hardening; mostly mechanical |

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
