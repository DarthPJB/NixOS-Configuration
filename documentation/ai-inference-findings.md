# AI Inference Findings and Forward Architecture

**Status**: Configuration and build-time validation complete; live validation pending  
**Decision date**: 2026-08-27  
**Scope**: LINDA inference services, the alpha-three LiteLLM gateway, and OpenCode clients

## Executive Decision

Four days of deployment and harness testing established that neither vLLM nor
Ollama should replace the other across every fleet workload.

- **vLLM remains the production-style engine** for small, deliberately sized,
  long-running CPU and GPU services. Its per-model systemd isolation, scheduler,
  OpenAI API, and Prometheus metrics are the correct design for managed services.
- **Ollama returns as the research engine** for models that need to load for a
  request, generate a response, and release resources afterward. It is also the
  proven path for the fleet's Ornith and Laguna GGUF models.
- **LiteLLM remains the gateway**, but model metadata must describe input/context
  and output limits separately. A total context window is not an output budget.

This is a synthesis of measured behavior, not a rollback of the vLLM work.

## Evidence from Usage

### OpenCode harness failures

No OpenCode harness run against `linda-vllm/qwen2.5-vl` completed successfully
while the gateway advertised and defaulted `8192` as `max_tokens` for an
8192-token vLLM sequence limit.

vLLM correctly rejected requests equivalent to:

```text
prompt tokens + 8192 requested output tokens > 8192 total tokens
```

The failure was a contract error between the gateway and client:

- vLLM `--max-model-len` is the total sequence budget: prompt plus completion.
- LiteLLM `model_info.max_input_tokens` advertises the context/input ceiling.
- LiteLLM `model_info.max_output_tokens` advertises the completion ceiling.
- LiteLLM deployment `max_tokens` is only a default; it does not clamp a larger
  client value because the request value takes precedence.
- OpenCode sends its discovered output limit as the completion request.

The initial conservative contract for the 8192-token GPU service is therefore:

| Limit | Tokens |
|---|---:|
| Total context presented to OpenCode | 8192 |
| Maximum completion | 2048 |
| Prompt space when reserving the full completion | 6144 |

The gateway must publish explicit input and output metadata. Backend validation
remains the final guard; a future gateway guardrail may enforce a hard output cap.

### Large vLLM CPU startup cost

The 27B and 30B CPU services demonstrated that vLLM's model preparation,
quantized-kernel preparation, compilation, and large KV-cache allocation can
make startup unsuitable for rapid model iteration. Persistent compilation cache
helps subsequent starts, but it does not turn a large vLLM service into an
on-demand research runner.

The isolation model remains valuable. Each vLLM model has its own unit, port,
memory policy, metrics, and lifecycle. The correction is to begin CPU iteration
with a small model and an explicit memory calculation rather than abandoning the
service architecture.

### Ollama operational behavior

The previous LINDA Ollama configuration worked well for GGUF research models,
especially Laguna S, and cluster-box has demonstrated the same for Ornith.
Ollama's model lifecycle is a better match for:

- loading a model for a short experiment;
- unloading it after generation or stopping the daemon;
- changing models without provisioning a permanent service per experiment;
- GGUF models that already work with their published Modelfiles.

Ollama will therefore be CPU-only, manually started, limited to one loaded model,
and constrained to an 80 GiB systemd memory envelope on LINDA. Model pulls do not
load weights into RAM; inference does.

## Target LINDA Service Layout

| Engine | Service | Device | Lifecycle | Purpose |
|---|---|---|---|---|
| vLLM | `vllm-qwen2.5-vl` | RTX 3060 | Long-running | Small GPU vision/tool development |
| vLLM | `vllm-qwen2.5-vl-cpu` | CPU | Long-running during evaluation | Small CPU/128K context development |
| Ollama | `ollama` | CPU only | Manual start | Ornith 9B and Laguna S research |

The former large vLLM CPU services are retained in git history and model package
outputs but removed from the active LINDA service list. They can return when a
long-running workload justifies their startup and resident-memory cost.

## Small CPU vLLM Memory Budget

The CPU service reuses the pinned
`Qwen/Qwen2.5-VL-3B-Instruct-AWQ` model already used by the GPU service.
This deliberately compares the same model across CPU and GPU execution paths.

Pinned model-store size:

```text
3,417,676,696 bytes = 3.18 GiB
```

From the pinned model configuration:

- 36 transformer layers
- 2 key/value heads
- 128 dimensions per attention head (`hidden_size 2048 / 16 heads`)
- bfloat16 KV entries (2 bytes)
- 128,000 native maximum positions

Full-window KV estimate:

```text
2 (K and V) × 36 × 2 × 128 × 2 bytes × 128000 tokens
  = 4,718,592,000 bytes
  = 4.39 GiB
```

A 6 GiB CPU KV-cache allocation therefore covers the theoretical full window
with allocator headroom. Model store size plus KV cache is about 9.18 GiB;
runtime tensors and process overhead retain substantial margin below the 20 GiB
operational target. This must still be measured under a real 128K request.

## Ollama Policy

The restored LINDA daemon follows these rules:

- CPU package only; it must not claim the RTX 3060.
- No boot target for either the daemon or model-loader unit.
- Declarative availability of `ornith:9b` and `laguna-s-2.1:q4_K_M`.
- `OLLAMA_CONTEXT_LENGTH=262144`, matching the native model family window.
- `OLLAMA_KV_CACHE_TYPE=q4_0` to keep long-context cache affordable.
- At most one loaded model and one parallel request.
- `MemoryMax=80G` as the host-safety boundary.
- WireGuard-only access to TCP 11434.

Operational commands:

```bash
systemctl start ollama
systemctl stop ollama
systemctl start ollama-model-loader  # synchronize declared model blobs
```

Stopping Ollama is the authoritative way to release all of its inference memory
when LINDA is needed for another workload.

## Validation Gates

The transition is complete only when all of the following hold:

1. LiteLLM publishes explicit input and output limits for every LINDA vLLM model.
2. An OpenCode harness receives a non-empty completion through the gateway.
3. The small CPU vLLM service exposes `/v1/models` with a 128,000-token limit.
4. Ollama is inactive after boot and starts only on operator request.
5. Ollama lists Ornith 9B and Laguna S after model synchronization.
6. Nix formatting, dead-code, golden, and full flake checks pass.
7. The LINDA system closure builds successfully.

Live inference and harness validation require deployment and are intentionally
separate from build-time evaluation.

## Build-Time Verification — 2026-08-27

- `nix flake check --option builders ''` passed, including formatting, deadnix,
  topology coverage, and the flake's aggregate golden check.
- The complete LINDA system closure built successfully at
  `/nix/store/nrhd1l3bcks2pbsn6647rgvbz6gj2mfy-nixos-system-LINDA-26.05.20260823.a3b9886`.
- Targeted golden validation passed for LINDA, alpha-three, and cortex-alpha
  after the user-authorized update.
- The LINDA golden records the intentional service/package and firewall deltas.
- The alpha-three golden also records the pre-existing package-version drift
  (`vintagestory`, Ollama, and `llama-cpp`) accepted by that authorization.
