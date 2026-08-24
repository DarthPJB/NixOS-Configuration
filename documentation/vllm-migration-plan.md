# vLLM-Only Migration — Project Plan

**Project**: Migrate AI inference stack from Ollama+vLLM hybrid to vLLM-only  
**Started**: 2026-08-24  
**Status**: Ready for execution  
**Engineer**: bellana-deepseek  
**Verification**: tpol-minimax

---

## Executive Summary

Replace the hybrid Ollama+vLLM inference stack with a unified vLLM-only architecture. All models managed by Nix, served by vLLM, monitored by Prometheus, and routed by LiteLLM.

**Key outcomes**:
- Single inference engine with native request queuing
- Nix-managed model packages in the store
- Per-model hardware assignment (GPU vs CPU)
- Full Prometheus observability
- Elimination of Ollama monitoring gap

---

## Phase 1: Foundation — Model Packages and vLLM CPU Support

**Goal**: Create Nix-managed model packages and validate vLLM CPU inference.

### Step 1.1: Create model package structure

**Prompt for bellana-deepseek**:
Create `pkgs/models/` directory with a template for HuggingFace model packages. The package should:
- Download model from HuggingFace (safetensors format)
- Verify hash
- Install to `$out` with all config files (config.json, tokenizer.json, etc.)
- Support `meta` attributes for description, license, homepage

Reference: `documentation/vllm-architecture.md` section "Model Package Structure"

**Success criteria**: `nix build .#models.qwen3-8b` produces a store path with model files.

---

### Step 1.2: Create Qwen3-8B model package

**Prompt for bellana-deepseek**:
Create `pkgs/models/qwen3-8b.nix` using the template from Step 1.1. The model should be `Qwen/Qwen3-8B` from HuggingFace. Verify the package builds and produces the expected files.

Reference: `pkgs/models/` template from Step 1.1

**Success criteria**: `nix build .#models.qwen3-8b` succeeds and `ls result/` shows model files.

---

### Step 1.3: Validate vLLM CPU inference

**Prompt for bellana-deepseek**:
Test vLLM CPU inference with a small model (Qwen3-0.6B or Qwen3-1.7B). Verify:
- vLLM starts with `--device cpu`
- `VLLM_CPU_KVCACHE_SPACE` is respected
- `VLLM_CPU_OMP_THREADS_BIND` binds threads correctly
- Model loads and responds to a simple request
- Metrics are exposed on `/metrics`

Reference: `documentation/vllm-architecture.md` section "CPU Models"

**Success criteria**: `curl http://localhost:8002/v1/models` returns model info. `curl http://localhost:8002/metrics` returns Prometheus metrics.

---

### Phase 1 Verification Gate (tpol-minimax)

**Verify**:
- [ ] `pkgs/models/` template exists and is valid Nix
- [ ] `pkgs/models/qwen3-8b.nix` builds successfully
- [ ] `nix flake check` passes (no regressions)
- [ ] No changes to existing vLLM GPU service or LINDA config

---

## Phase 2: Module Enhancement — Hardware Assignment and Model Paths

**Goal**: Extend the vLLM NixOS module to support device assignment and nix-store model paths.

### Step 2.1: Add device and modelPath options to vLLM module

**Prompt for bellana-deepseek**:
Extend `modules/vllm.nix` with new options:
- `device`: enum [ "gpu" "cpu" ], default "gpu"
- `modelPath`: nullOr path, default null — path to model in nix store
- `cpuKvCacheSpace`: int, default 4 — CPU KV cache in GiB
- `cpuOmpThreadsBind`: str, default "auto" — CPU core binding

When `device == "cpu"`:
- Set `CUDA_VISIBLE_DEVICES=""`
- Set `VLLM_CPU_KVCACHE_SPACE` and `VLLM_CPU_OMP_THREADS_BIND`
- Add `MemoryMax` to systemd service

When `modelPath != null`:
- Use the nix store path instead of downloading from HuggingFace
- Set `HF_HOME` to a cache directory (models are already in store)

Reference: `modules/vllm.nix` lines 20-100 (existing options), `documentation/vllm-architecture.md` section "Module Changes"

**Success criteria**: `nix flake check` passes. `nix eval .#nixosConfigurations.LINDA.config.services.vllm` shows new options.

---

### Step 2.2: Add CPU model service generation

**Prompt for bellana-deepseek**:
Extend the systemd service generation in `modules/vllm.nix` to handle CPU models:
- Different environment variables for CPU vs GPU
- `MemoryMax` for CPU models (e.g., 80%)
- `VLLM_CPU_KVCACHE_SPACE` and `VLLM_CPU_OMP_THREADS_BIND` environment variables
- Different `ExecStart` args for CPU (no `--tensor-parallel-size`, no `--gpu-memory-utilization`)

Reference: `modules/vllm.nix` lines 338-378 (existing service generation)

**Success criteria**: `nix eval .#nixosConfigurations.LINDA.config.systemd.services` shows both GPU and CPU vLLM services with correct environment.

---

### Step 2.3: Test CPU model deployment on LINDA

**Prompt for bellana-deepseek**:
Deploy a CPU model on LINDA using the new module options:
- Model: Qwen3-0.6B (small, fast to test)
- Device: cpu
- Port: 8002
- cpuKvCacheSpace: 4
- cpuOmpThreadsBind: "0-29"

Deploy to LINDA and verify:
- Service starts without GPU access
- Model loads and responds
- Metrics are exposed
- Memory usage is within limits

Reference: `machines/LINDA/default.nix` lines 55-78 (existing vLLM config)

**Success criteria**: `curl http://10.88.127.88:8002/v1/models` returns model info. `systemctl status vllm-qwen3-0.6b-cpu` shows active.

---

### Phase 2 Verification Gate (tpol-minimax)

**Verify**:
- [ ] `modules/vllm.nix` has new device and modelPath options
- [ ] CPU model service generates correct systemd config
- [ ] GPU model service unchanged (no regressions)
- [ ] CPU model deploys and responds on LINDA
- [ ] Metrics are exposed for both GPU and CPU services
- [ ] Golden test for LINDA passes

---

## Phase 3: Model Migration — Replace Ollama Models

**Goal**: Migrate all Ollama models to vLLM with Nix-managed packages.

### Step 3.1: Create Qwen3-30B-A3B model package

**Prompt for bellana-deepseek**:
Create `pkgs/models/qwen3-30b-a3b.nix` for the 30B MoE model. This is the CPU-bound model that replaces `qwen3.8:27b-q4_K_M` and `laguna-s-2.1:q4_K_M` in Ollama.

Verify the package builds and produces the expected files. Note: This is a large model (~30B parameters), so the download will be significant.

Reference: `pkgs/models/` template from Phase 1

**Success criteria**: `nix build .#models.qwen3-30b-a3b` succeeds.

---

### Step 3.2: Create Qwen3-Coder model package

**Prompt for bellana-deepseek**:
Create `pkgs/models/qwen3-coder-30b-a3b.nix` for the code-generation model. This replaces `qwen3-coder:30b-a3b-q4_K_M` in Ollama.

Reference: `pkgs/models/` template from Phase 1

**Success criteria**: `nix build .#models.qwen3-coder-30b-a3b` succeeds.

---

### Step 3.3: Migrate LINDA CPU models to vLLM

**Prompt for bellana-deepseek**:
Update `machines/LINDA/default.nix` to replace Ollama CPU models with vLLM CPU models:
- Remove Ollama service import (`services/ollama.nix`)
- Add vLLM CPU models using the new module options
- Configure LiteLLM to route to vLLM CPU ports instead of Ollama

Models to migrate:
- `qwen3.8:27b-q4_K_M` → `Qwen/Qwen3-30B-A3B` (CPU, port 8002)
- `qwen3-coder:30b-a3b-q4_K_M` → `Qwen/Qwen3-Coder-30B-A3B` (CPU, port 8003)

**Note**: Laguna models (laguna-s, laguna-xs) are custom and may not be on HuggingFace. Flag for review.

Reference: `machines/LINDA/default.nix` lines 13-14 (Ollama import), `machines/alpha-three/default.nix` lines 38-48 (LiteLLM backends)

**Success criteria**: `nix flake check` passes. Golden test for LINDA updated. LiteLLM routes to new CPU ports.

---

### Phase 3 Verification Gate (tpol-minimax)

**Verify**:
- [ ] Model packages for Qwen3-30B-A3B and Qwen3-Coder build successfully
- [ ] LINDA config replaces Ollama with vLLM CPU models
- [ ] LiteLLM routes to new CPU ports
- [ ] Golden tests updated and passing
- [ ] No references to Ollama remain in LINDA config
- [ ] Laguna models flagged for review (custom, not on HuggingFace)

---

## Phase 4: Monitoring and Observability

**Goal**: Full Prometheus coverage for all inference services.

### Step 4.1: Add vLLM Prometheus scrape targets

**Prompt for bellana-deepseek**:
Add Prometheus scrape targets for vLLM services in `services/prometheus.nix`:
- GPU model: `10.88.127.88:8001` (existing)
- CPU model: `10.88.127.88:8002` (new)
- CPU coder model: `10.88.127.88:8003` (new)

Each with appropriate labels (hostname, device, model).

Reference: `services/prometheus.nix` lines 51-200 (existing scrape configs)

**Success criteria**: `nix eval .#nixosConfigurations.cortex-alpha.config.services.prometheus.scrapeConfigs` shows new vLLM targets.

---

### Step 4.2: Add LiteLLM Prometheus scrape target

**Prompt for bellana-deepseek**:
Add Prometheus scrape target for LiteLLM in `services/prometheus.nix`:
- Target: `10.88.127.107:8080` (alpha-three)
- Requires authentication (Bearer token from secrix)
- Labels: hostname, role=gateway

Also enable LiteLLM Prometheus metrics in `machines/alpha-three/default.nix`:
- Add `callbacks: ["prometheus"]` to LiteLLM settings
- Verify `/metrics` endpoint is exposed

Reference: `services/prometheus.nix`, `machines/alpha-three/default.nix` lines 36-71

**Success criteria**: `curl http://10.88.127.107:8080/metrics -H "Authorization: Bearer <key>"` returns metrics.

---

### Step 4.3: Create AI inference Grafana dashboard

**Prompt for bellana-deepseek**:
Create `services/graphana_dashboards/ai-inference.json` with panels for:
- Request rate (requests/second) by model
- Latency (p50, p95, p99) by model
- Queue depth by model
- KV cache usage by model
- Error rate by model
- Token throughput (input/output) by model
- LiteLLM gateway health (deployment state)

Reference: `services/graphana_dashboards/ai-systems.json` (existing hardware dashboard), vLLM metrics documentation in `documentation/ai-upgrades.md`

**Success criteria**: Dashboard JSON is valid Grafana format. Panels reference correct Prometheus metrics.

---

### Phase 4 Verification Gate (tpol-minimax)

**Verify**:
- [ ] Prometheus scrape targets for all vLLM services
- [ ] LiteLLM Prometheus metrics enabled and scrapeable
- [ ] AI inference dashboard created with correct metrics
- [ ] No regressions in existing monitoring
- [ ] Golden test for cortex-alpha passes

---

## Phase 5: Cleanup and Decommission

**Goal**: Remove Ollama, clean up technical debt, validate golden tests.

### Step 5.1: Remove Ollama service

**Prompt for bellana-deepseek**:
Remove Ollama from LINDA:
- Remove `services/ollama.nix` import
- Remove `services/ollama.nix` file (or archive it)
- Remove Ollama-related firewall rules from topology
- Update LiteLLM to remove Ollama backend references

Reference: `machines/LINDA/default.nix` line 13, `services/ollama.nix`, `topology/LINDA.json`

**Success criteria**: No references to Ollama in LINDA config. `nix flake check` passes.

---

### Step 5.2: Fix technical debt — CUDA scoping

**Prompt for bellana-deepseek**:
Fix the CUDA scoping issue:
- Remove global `nixpkgs.config.cudaSupport = true` from vLLM module
- Create a `pkgsCuda` overlay or use package-level overrides
- Ensure CUDA is only enabled for packages that need it (vLLM, not Ollama or others)

Reference: `modules/vllm.nix` lines 317-321, `documentation/ai-upgrades.md` section P3

**Success criteria**: `nix flake check` passes. No duplicate nixpkgs imports. CUDA only where needed.

---

### Step 5.3: Fix technical debt — Open-WebUI pkgsNoCuda

**Prompt for bellana-deepseek**:
Fix the `pkgsNoCuda` workaround in `services/ollama-ui.nix`:
- Investigate if open-webui can be built without CUDA using package overrides
- If not, document the workaround and create an upstream issue
- If yes, remove the `pkgsNoCuda` import and use the standard package

Reference: `services/ollama-ui.nix` lines 10-14

**Success criteria**: `pkgsNoCuda` removed or documented as permanent workaround.

---

### Step 5.4: Validate all golden tests

**Prompt for bellana-deepseek**:
Run golden tests for all affected machines:
- LINDA
- alpha-three
- cortex-alpha
- cluster-box (if affected)

Regenerate goldens if intentional changes were made. Verify all pass.

Reference: `documentation/development-guide.md` section "Validate Against Golden Test"

**Success criteria**: All golden tests pass. `for m in $(ls machines/); do nix run .#validate-goldens -- "$m" 2>&1 | tail -1; done` shows all pass.

---

### Phase 5 Verification Gate (tpol-minimax)

**Verify**:
- [ ] Ollama fully removed from LINDA
- [ ] CUDA scoping fixed (no global cudaSupport)
- [ ] Open-WebUI workaround resolved or documented
- [ ] All golden tests pass
- [ ] No regressions in any machine config
- [ ] Documentation updated to reflect vLLM-only architecture

---

## Phase 6: Documentation and Handoff

**Goal**: Update all documentation to reflect the vLLM-only architecture.

### Step 6.1: Update ai-stack.md

**Prompt for bellana-deepseek**:
Update `documentation/ai-stack.md` to reflect vLLM-only architecture:
- Remove Ollama references
- Update architecture diagram
- Update model inventory
- Update monitoring section
- Update operational procedures

Reference: `documentation/ai-stack.md`

**Success criteria**: Document reflects vLLM-only architecture. No Ollama references.

---

### Step 6.2: Update vllm-architecture.md

**Prompt for bellana-deepseek**:
Update `documentation/vllm-architecture.md` with implementation details:
- Mark completed phases
- Add any deviations from plan
- Add lessons learned
- Update open questions with resolutions

Reference: `documentation/vllm-architecture.md`

**Success criteria**: Document reflects actual implementation state.

---

### Step 6.3: Update ai-upgrades.md

**Prompt for bellana-deepseek**:
Update `documentation/ai-upgrades.md` to mark completed priority issues:
- P1 (Model Configuration): Mark as resolved if model packages are working
- P2 (Multi-Model Safety): Mark as resolved if queuing is working
- P3 (Technical Debt): Mark as resolved if CUDA scoping is fixed
- P4 (Monitoring): Mark as resolved if Prometheus is scraping all services
- P5 (Model Templates): Mark as resolved if chat templates are working

Reference: `documentation/ai-upgrades.md`

**Success criteria**: Document reflects resolved status of priority issues.

---

### Phase 6 Verification Gate (tpol-minimax)

**Verify**:
- [ ] ai-stack.md reflects vLLM-only architecture
- [ ] vllm-architecture.md updated with implementation details
- [ ] ai-upgrades.md shows resolved priority issues
- [ ] README.md references correct documents
- [ ] All documentation is consistent

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Laguna models not on HuggingFace | Medium | High | Keep Ollama for Laguna models, or convert GGUF to HF |
| vLLM CPU performance insufficient | Medium | Medium | Benchmark before full migration, keep Ollama as fallback |
| Model store space insufficient | Low | Medium | Monitor disk usage, use sparse checkout if needed |
| Golden test failures | Low | Low | Regenerate goldens for intentional changes |
| LiteLLM breaking change | Low | High | Pin to specific commit, test before deploying |

---

## Success Criteria

The migration is complete when:

1. All models served by vLLM (no Ollama)
2. All models managed by Nix (store paths, not runtime downloads)
3. All models monitored by Prometheus (metrics on every port)
4. All models have proper chat templates (no "no user query found" errors)
5. Request queuing works (no OOM from concurrent requests)
6. Golden tests pass for all machines
7. Documentation is up to date

---

*Plan created: 2026-08-24*  
*Engineer: bellana-deepseek*  
*Verification: tpol-minimax*
