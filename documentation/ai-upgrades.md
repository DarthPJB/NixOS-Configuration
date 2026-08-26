# AI Infrastructure Upgrades — Planning Document

**Status**: Implementation complete — all priority issues resolved via the vLLM-only migration  
**Started**: 2026-08-24  
**Last updated**: 2026-08-25

---

## Priority Issues

These are the issues that blocked production-grade AI infrastructure, in order of priority.
**All five priority issues (P1–P5) have been resolved as part of the vLLM-only migration.**

### Resolution Summary

| Priority | Issue | Status | Resolution |
|----------|-------|--------|------------|
| P1 | Model Configuration: Ad-Hoc vs Declarative | ✅ **RESOLVED** | Models declared in Nix via `pkgs/models/*.nix` (SRI-pinned, commit-pinned); configured declaratively in `services.vllm.models` |
| P2 | Multi-Model Safety: No Safeguards vs Enforced Isolation | ✅ **RESOLVED** | vLLM native request queuing + per-model systemd services with `MemoryMax` (CPU); LiteLLM router queuing |
| P3 | Technical Debt: CPU-Only Implementation | ✅ **RESOLVED** | CUDA scoped to vLLM via `pkgsCuda` overlay; global `cudaSupport` removed from vLLM module; `pkgsNoCuda` duplicate-import workaround removed |
| P4 | Inference Monitoring: Blind vs Instrumented | ✅ **RESOLVED** | Prometheus scrapes vLLM (:8001/:8002/:8003) and LiteLLM (:8080); AI-inference Grafana dashboard added |
| P5 | Model Templates: Missing vs Proper | ✅ **RESOLVED** | Models ship native chat templates in `tokenizer_config.json`; vLLM applies them by default |

### P1 — Model Configuration: Ad-Hoc vs Declarative

> **Status: ✅ RESOLVED** — vLLM-only migration (Phase 3). Models are now declared
> entirely in Nix. `pkgs/models/qwen3-8b.nix`, `pkgs/models/qwen3-30b-a3b.nix`, and
> `pkgs/models/qwen3-coder-30b-a3b.nix` package model weights into the nix store
> (pinned to commit SHAs with per-file SRI hashes). LINDA configures each model
> declaratively in `services.vllm.models` (device, modelPath, dtype, KV cache
> space, port, served name). vLLM loads weights from the store path — no runtime
> HuggingFace downloads. LiteLLM registers each model with correct `model_info`
> (`max_tokens`, `mode`, `supports_vision`, etc.).

**Current**: Model parameters (temperature, top_p, repeat_penalty, num_ctx) are baked into Ollama Modelfiles, discovered at runtime via `/api/show`, and adjusted ad-hoc. When a model fails, we SSH in and investigate.

**Target**: Every model parameter is declared in Nix, versioned, and validated. The system knows what a model *should* be, not just what it *is*.

**Gap**: `services/ollama.nix` sets `OLLAMA_CONTEXT_LENGTH` and `OLLAMA_KV_CACHE_TYPE` globally, but individual model parameters are invisible to Nix. They live in Ollama's Modelfile, not in our repository.

**Research finding**: Ollama supports per-model parameters through the `options` parameter in API calls. The Modelfile `PARAMETER` instruction sets baked-in defaults. The `options` parameter in `/api/generate` and `/api/chat` overrides these at runtime. However, these are runtime parameters, not declarative configuration. To make them declarative, we need to create custom Ollama models with Modelfiles that have the correct parameters baked in, or configure LiteLLM to pass them per-request.

**Action**: Create a NixOS module option for per-model Ollama parameters. Generate Modelfiles declaratively. Register models with LiteLLM with correct `model_info` (max_tokens, supports_system_message, supports_function_calling).

---

### P2 — Multi-Model Safety: No Safeguards vs Enforced Isolation

> **Status: ✅ RESOLVED** — vLLM-only migration (Phase 2/3). vLLM's built-in
> scheduler provides native request queuing — requests queue when the batch is
> full (`max_num_seqs` controls batch size; set to 16 for the GPU model on
> LINDA). Each model runs as its own isolated systemd service; CPU models set
> `MemoryMax = "80%"` to protect the host from OOM. `gpu_memory_utilization`
> (0.8 on LINDA) caps VRAM for GPU models. LiteLLM's module additionally
> supports router-level `num_retries`, `request_timeout`, and `fallbacks`
> for graceful degradation. The Ollama concurrent-model-loading OOM risk is
> gone because Ollama is no longer in the fleet.

**Current**: Ollama loads 4 models simultaneously. vLLM can load multiple models. No `MemoryMax` on Ollama. No request queuing. If a second model is requested while the first is running, Ollama will try to load it alongside — potentially OOMing.

**Target**: Single model per device, enforced at the orchestrator level. Requests queue when a model is busy. Memory limits are set and enforced. The system degrades gracefully instead of crashing.

**Gap**: The testbed can OOM. In production, that's a service outage.

**Research findings**:

**vLLM**: Has built-in request queuing through its scheduler. The `max_num_seqs` parameter controls how many sequences can be batched simultaneously. The `gpu_memory_utilization` parameter controls how much VRAM is allocated. Requests queue when the batch is full. The scheduler handles preemption — if a higher-priority request arrives, it can preempt lower-priority requests. Metrics are exposed via `/metrics` endpoint (Prometheus-compatible).

**Ollama**: Does NOT have built-in request queuing. When multiple requests arrive for different models, Ollama loads them all into memory. The `keep_alive` parameter controls how long a model stays loaded (default 5m). There is no queue — requests are processed concurrently, which can OOM.

**LiteLLM**: Has request queuing through its router. The `router_settings` control routing strategy (`least-busy`, `simple-shuffle`, `usage-based-routing`, `latency-based-routing`). The `num_retries` and `timeout` settings control retry behavior. The `allowed_fails` setting controls circuit breaking. Requests can be queued and routed to the least-busy backend.

**Action**: 
- vLLM: Set `max_num_seqs` to control batch size. Use `gpu_memory_utilization` to limit VRAM. Metrics are already exposed.
- Ollama: Use `MemoryMax` on the systemd service to limit RAM. Use `keep_alive` to control model residency. Consider using LiteLLM to serialize requests across models.
- LiteLLM: Configure `router_settings` for queuing and failover. Use `allowed_fails` for circuit breaking.

---

### P3 — Technical Debt: CPU-Only Implementation

> **Status: ✅ RESOLVED** — vLLM-only migration (Phase 5.2/5.3). CUDA is now
> scoped to the vLLM package via a `pkgsCuda` overlay in `flake.nix` (CUDA
> torch + CUDA build inputs, scoped via `python313Packages.overrideScope` so
> all torch-dependent packages in the set — torchaudio, torchvision, xformers,
> triton — consistently use the CUDA torch; `triton` is overridden to
> `triton-cuda` from the outer scope to avoid duplicate-triton closure
> conflicts). The global `nixpkgs.config.cudaSupport = true` was removed from
> the vLLM module. The `pkgsNoCuda` duplicate-nixpkgs-import workaround in
> `ollama-ui.nix` was replaced with a scoped `overrideScope` on the same
> nixpkgs instance — no duplicate imports, no CUDA cascade into open-webui's
> pytorch.

**Current**: 
- `pkgsNoCuda` import in `ollama-ui.nix` avoids pytorch CUDA build — workaround, not solution
- `pkgs_llm` passed globally via `_module.args` — every machine gets CUDA-capable nixpkgs even if unused
- `nixpkgs.config.cudaSupport = true` set globally by vLLM module — cascades CUDA to all packages

**Target**: Clean separation. GPU packages only where needed. No duplicate nixpkgs imports.

**Gap**: Every eval carries the cost of a duplicate nixpkgs import. Slow and fragile.

**Research finding**: Nixpkgs supports per-package CUDA overrides. The `pkgs_llm` import has `config.cudaSupport = true` which affects all packages in that nixpkgs instance. The solution is to create a separate nixpkgs instance for CUDA packages, or use package-level overrides.

**Action**: 
- Create a `pkgsCuda` overlay that only affects specific packages
- Remove global `cudaSupport = true` from vLLM module
- Use package-level overrides for vLLM and Ollama instead

---

### P4 — Inference Monitoring: Blind vs Instrumented

> **Status: ✅ RESOLVED** — vLLM-only migration (Phase 4). Prometheus now scrapes
> every inference backend: vLLM GPU (`vllm-gpu` :8001), vLLM CPU
> (`vllm-cpu` :8002), vLLM CPU coder (`vllm-cpu-coder` :8003), and LiteLLM
> (`litellm` :8080, with `callbacks: ["prometheus"]` enabled). Each vLLM target
> is labelled with hostname, device, and model. An `ai-inference` Grafana
> dashboard was added under `services/graphana_dashboards/` for request rate,
> latency, queue depth, KV cache usage, error rate, and token throughput.
> (Ollama had no `/metrics` endpoint; with Ollama retired, this monitoring gap is
> closed.)

**Current**: No Prometheus exporters for Ollama, vLLM, or LiteLLM. The AI Systems dashboard shows hardware (CPU, GPU temp, VRAM) but not inference. We don't know request rate, latency, error rate, or tokens/second.

**Target**: Every inference backend exposes metrics. Prometheus scrapes them. Grafana dashboards show request rate, p50/p95/p99 latency, error rate, and per-model token throughput. Alerting fires on GPU temp > 80°C, VRAM > 90%, or error rate > 5%.

**Gap**: We're flying blind on inference health. A model could be silently failing for hours and we wouldn't know until someone reports it.

**Research findings**:

**vLLM**: Exposes rich Prometheus metrics via `/metrics` endpoint. Metrics include:
- `vllm:num_requests_running` (Gauge) — requests currently running
- `vllm:kv_cache_usage_perc` (Gauge) — KV cache usage
- `vllm:prompt_tokens_total` (Counter) — total prompt tokens
- `vllm:generation_tokens_total` (Counter) — total generation tokens
- `vllm:request_success_total` (Counter) — finished requests by reason
- `vllm:time_to_first_token_seconds` (Histogram) — TTFT
- `vllm:e2e_request_latency_seconds` (Histogram) — end-to-end latency
- `vllm:request_queue_time_seconds` (Histogram) — queue time

**Ollama**: Does NOT expose a Prometheus `/metrics` endpoint. However, API responses include usage metrics (total_duration, load_duration, prompt_eval_count, eval_count, etc.). These can be scraped by a custom exporter. There is no official Ollama Prometheus exporter in nixpkgs.

**LiteLLM**: Exposes Prometheus metrics via `/metrics` endpoint when `callbacks: ["prometheus"]` is configured. Metrics include:
- `litellm_proxy_total_requests_metric` — total requests by model, key, team
- `litellm_proxy_failed_requests_metric` — failed requests by model, key, team
- `litellm_request_total_latency_metric` — end-to-end latency
- `litellm_llm_api_latency_metric` — LLM API latency
- `litellm_spend_metric` — spend tracking
- `litellm_deployment_state` — deployment health (0=healthy, 1=partial, 2=outage)

**Action**: 
- vLLM: Already exposes metrics. Add Prometheus scrape target for port 8001.
- Ollama: Write a custom exporter or use a third-party exporter. No official nixpkgs package.
- LiteLLM: Enable `callbacks: ["prometheus"]` in config. Add Prometheus scrape target for port 8080.

---

### P5 — Model Templates: Missing vs Proper

> **Status: ✅ RESOLVED** — vLLM-only migration. All Qwen3 models ship with a
> proper chat template in their `tokenizer_config.json`, and vLLM applies it
> automatically by default (no `--chat-template` override needed). This eliminates
> the "no user query found in messages" errors caused by Ollama's raw
> `{{ .Prompt }}` template on `qwen3.8:27b-q4_K_M`. Messages are now formatted
> correctly for each model's tokenizer.

**Current**: Qwen3 model `qwen3.8:27b-q4_K_M` has template `{{ .Prompt }}` — raw prompt template, not a chat template. When Ollama's OpenAI-compatible endpoint receives messages, it tries to apply a chat template. There is none. Messages are passed raw, and Qwen3's tokenizer can't find the user turn.

**Target**: Every model has a proper chat template. Messages are formatted correctly for the model's tokenizer.

**Gap**: "no user query found in messages" errors. Models fail silently.

**Research finding**: Ollama supports custom templates via the Modelfile `TEMPLATE` instruction. The template uses Go template syntax with variables like `.System`, `.Prompt`, `.Response`, `.Messages`, `.Tools`. For Qwen3, the template should use `<|im_start|>` and `` tokens. The vLLM documentation notes that some models don't provide chat templates — for those, you can specify `--chat-template` with a file path or inline template.

**Action**: 
- Create Modelfiles with proper Qwen3 chat templates
- Test templates with a simple request before deploying
- Register models with LiteLLM with correct `model_info`

---

## Research Summary

### vLLM

| Feature | Status | Notes |
|---------|--------|-------|
| Prometheus metrics | ✅ Built-in | `/metrics` endpoint, rich set of gauges/counters/histograms |
| Request queuing | ✅ Built-in | Scheduler handles queuing, preemption, batching |
| Per-model config | ✅ Engine args | `max_num_seqs`, `gpu_memory_utilization`, `max_model_len` |
| Chat templates | ✅ Configurable | `--chat-template` flag or model's tokenizer_config.json |
| Multi-model | ✅ Per-model services | Each model gets its own systemd service |
| CPU inference | ✅ Supported | `--device cpu` (deployed on LINDA: qwen3-30b-a3b :8002, qwen3-coder :8003) |

### Ollama

> **Retired from the fleet** as part of the vLLM-only migration — the table below
> documents its capabilities for reference only. `services/ollama.nix` is archived
> at `services/archive/ollama.nix`. Laguna models (laguna-s/laguna-xs) still run on
> Ollama on cluster-box pending review (custom GGUF, not on HuggingFace).

| Feature | Status | Notes |
|---------|--------|-------|
| Prometheus metrics | ❌ No endpoint | Usage metrics in API responses, no /metrics |
| Request queuing | ❌ No queue | Concurrent requests, can OOM |
| Per-model config | ✅ Modelfile | `PARAMETER` instruction for baked-in defaults |
| Chat templates | ✅ Modelfile | `TEMPLATE` instruction with Go template syntax |
| Multi-model | ✅ Concurrent | Loads multiple models, no isolation |
| CPU/GPU split | ✅ Automatic | GPU/CPU hybrid based on model size |

### LiteLLM

| Feature | Status | Notes |
|---------|--------|-------|
| Prometheus metrics | ✅ Built-in | `/metrics` endpoint with `callbacks: ["prometheus"]` |
| Request queuing | ✅ Router | `router_settings` with `least-busy` strategy |
| Per-model config | ✅ model_list | `litellm_params` and `model_info` per model |
| Chat templates | ⚠️ Passthrough | Relies on backend to handle templates |
| Multi-backend | ✅ Router | Routes to multiple backends by model prefix |
| Extensibility | ✅ Python | Custom callbacks, plugins, middleware |

---

## Implementation Plan

**All phases completed as part of the vLLM-only migration.**
The original plan below (Phase 1–5 by cost/value) was executed via the
`vllm-migration-plan.md` phase structure (Phases 1–5, each with a verification
gate). Completed items are marked ✅; items made obsolete by the vLLM-only
decision are marked ~~struck~~.

### Phase 1: Monitoring (Low Cost, High Value)

1. ✅ Enable LiteLLM Prometheus metrics (`callbacks: ["prometheus"]`) — set on alpha-three
2. ✅ Add Prometheus scrape target for LiteLLM (port 8080) — `litellm` job in `services/prometheus.nix`
3. ✅ Add Prometheus scrape target for vLLM (port 8001) — plus 8002/8003 (`vllm-gpu`, `vllm-cpu`, `vllm-cpu-coder`)
4. ~~Write custom Ollama exporter~~ — **OBSOLETE**: Ollama retired; vLLM exposes `/metrics` natively
5. ✅ Create Grafana dashboard for inference metrics — `services/graphana_dashboards/ai-inference.json`

### Phase 2: Multi-Model Safety (Medium Cost, High Value)

1. ~~Set `MemoryMax` on Ollama systemd service~~ — **OBSOLETE**: Ollama retired
2. ✅ Configure vLLM `max_num_seqs` and `gpu_memory_utilization` — per-model args on LINDA
3. ✅ Configure LiteLLM `router_settings` for queuing — `num_retries`, `request_timeout`, `fallbacks`
4. ✅ Test OOM behavior with concurrent requests — vLLM native scheduler queues requests

### Phase 3: Model Templates (Medium Cost, High Value)

1. ~~Create Modelfiles with proper Qwen3 chat templates~~ — **OBSOLETE**: replaced by native HF chat templates
2. ✅ Test templates with simple requests — vLLM applies model `tokenizer_config.json` templates by default
3. ✅ Update LiteLLM model registration with correct `model_info` — `max_tokens`, `mode`, `supports_*` per backend

### Phase 4: Technical Debt (Medium Cost, Medium Value)

1. ✅ Create `pkgsCuda` overlay for scoped CUDA support — in `flake.nix`; only `vllm` rebuilt with CUDA
2. ✅ Remove global `cudaSupport = true` from vLLM module — done; CUDA scoped to vLLM package
3. ✅ Fix `pkgsNoCuda` workaround in ollama-ui.nix — replaced with `overrideScope` on the same nixpkgs instance

### Phase 5: Declarative Model Configuration (High Cost, High Value)

1. ✅ Create NixOS module for per-model parameters — `services.vllm.models` (device, modelPath, dtype, KV cache, ports)
2. ✅ Generate Modelfiles declaratively — replaced by Nix-managed model packages (`pkgs/models/*.nix`)
3. ✅ Register models with LiteLLM with full `model_info` — `max_tokens`, `mode`, `supports_vision`, `supports_video_input`, `supports_function_calling`

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-08-24 | Migrate from Ollama+vLLM hybrid to **vLLM-only** | vLLM has native request queuing, per-model services, and `/metrics`; Ollama has no queue and no Prometheus endpoint |
| 2026-08-24 | Scope CUDA to vLLM via `pkgsCuda` overlay instead of global `cudaSupport` | Prevents CUDA cascade into unrelated packages; no duplicate nixpkgs imports |
| 2026-08-25 | Replace `pkgsNoCuda` duplicate-import with `overrideScope` on the same nixpkgs instance | Eliminates duplicate nixpkgs eval cost; keeps open-webui pytorch CPU-only |
| 2026-08-25 | Model weights packaged in the nix store via `pkgs/models/*.nix` (SRI + commit pinned) | Immutable, versioned, no runtime HuggingFace downloads |
| 2026-08-25 | Laguna models (laguna-s/laguna-xs) left on Ollama, not migrated | Custom GGUF, not on HuggingFace — flagged for review |
