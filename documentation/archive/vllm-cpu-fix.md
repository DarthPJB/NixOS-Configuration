# vLLM CPU Inference — Remaining Changes

**Status**: Implemented  
**Branch**: `ai/hardening-ii/vllm-authority`  
**Last updated**: 2026-08-26

---

## Problem

GPU model (`qwen2.5-vl`) works on port 8001. CPU models (`qwen3-30b-a3b`, `qwen3-coder-30b-a3b`) failed on ports 8002/8003 with `RuntimeError: Failed to infer device type`.

## Root Cause

vLLM 0.24.0's `cpu_platform_plugin()` selects CPU only if `importlib.metadata.version("vllm")` contains `"cpu"` (or Darwin). nixpkgs builds with `VLLM_TARGET_DEVICE=cpu` but leaves the version at `0.24.0`. Official CPU wheels are `0.24.0+cpu`.

`VLLM_TARGET_DEVICE=cpu` as a runtime env var is ignored by 0.24.0.

## Implementation (no source patch, no overlay, no vLLM rebuild)

`overrideAttrs postInstall` would rebuild vLLM. The wrapper does not.

### 1. `pkgs/zentorch/default.nix`

cp313 manylinux wheel from PyPI (2.13.0.0). Wheel is built against torch 2.13; nixpkgs_llm has torch 2.12. If `import zentorch` fails, vLLM stays on `CpuPlatform` (oneDNN). The `+cpu` metadata still selects CPU.

### 2. `pkgs/vllm-cpu/default.nix`

Wraps `pkgs_llm.vllm`:

- Prepends a site-packages overlay whose `vllm-*.dist-info/METADATA` Version is `${version}+cpu` — this is what `importlib.metadata.version("vllm")` reads (not `_version.py`).
- Symlinks zentorch onto the same prefix.
- `makeWrapper` `--prefix PYTHONPATH`.

### 3. `modules/vllm.nix`

- Explicit `gpuPackage` / `cpuPackage` (defaults: `pkgsCuda.vllm` / `pkgsCpuVllm`)
- No `FLASH_ATTN` → `TORCH_SDPA` rewrite — `CpuPlatform` ignores user backends
- No `VLLM_TARGET_DEVICE` env var
- `VLLM_USE_FLASHINFER_SAMPLER=0` only on GPU
- Each model unit: `wantedBy = [ "multi-user.target" ]`, no inter-model `requires`

### 4. GPU weights in the store

`pkgs/models/qwen25-vl-7b-instruct-awq.nix` — LINDA GPU model uses `modelPath`.

### 5. Docs

`pkgsCuda` is a separate nixpkgs import, not an overlay.

---

## Verification

```bash
nix build .#vllm-cpu --option builders ''
# metadata must contain +cpu:
PYTHONPATH=$(nix eval --raw .#packages.x86_64-linux.vllm-cpu)/lib/python3.13/site-packages \
  python -c 'from importlib.metadata import version; print(version("vllm"))'
```

On LINDA, as user `vllm`:

```
Confirmed CPU platform is available because vLLM is built with CPU.
```

(`ZenCpuPlatform` only if `import zentorch` succeeds against torch 2.12.)

Then `GET /v1/models` on :8002 / :8003.
