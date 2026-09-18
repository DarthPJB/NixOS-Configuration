# machines/pillar-of-autum/ollama.nix
#
# Ollama inference service for pillar-of-autum (ASUS NUC14RVH-B, Intel Core Ultra 5 125H).
#
# CPU-only inference with Vulkan iGPU offload capability.
# The Intel Arc iGPU is present and OpenCL-functional via intel-compute-runtime,
# but Ollama's Vulkan backend requires further testing for reliable iGPU offload.
#
# Hardware summary:
#   - CPU: Intel Core Ultra 5 125H, 14 cores / 18 threads, 4500 MHz max
#   - RAM: 14.94 GiB total (~13.8 GiB available idle)
#   - GPU: Intel Arc (Meteor Lake-P), 11.21 GiB shared VRAM, Vulkan 1.4
#   - NPU: Intel NPU (device 0x7d1d), intel_vpu driver, /dev/accel0
#
# Model tiers (tool-calling capable):
#   - Fast (32K):   qwen3:4b      ~25-35 tok/s — quick interactions, coding, tool use
#   - Medium (128K): qwen3.5:9b    ~5-7 tok/s  — long docs, multi-turn agentic, vision
#   - Long (256K):  gemma4:12b    ~4-6 tok/s  — full codebase reasoning, vision
#
# Legacy models (CPU benchmarks, Ollama 0.30.6):
#   - qwen2.5:3b    → 17.1 tok/s
#   - qwen2.5:7b    →  8.0 tok/s
#
# Single-model-per-device discipline enforced (16 GB RAM constraint).
# NOTE: spelling is "pillar-of-autum" — NOT "pillar-of-autumn".
{ lib
, pkgs_llm
, ...
}:
{
  services.ollama = {
    enable = true;
    host = "10.88.127.110"; # WireGuard plane only — not loopback, not all interfaces
    port = 11434;
    package = pkgs_llm.ollama-cpu;
    models = "/var/lib/ollama/models";

    # Models suitable for 16 GB RAM system (single-model-per-device).
    loadModels = [
      "qwen2.5:3b"
      "qwen2.5:7b"
      "qwen3:4b"
      "qwen3.5:9b"
      "gemma4:12b"
    ];

    # Host limits for 16 GB RAM system.
    environmentVariables = {
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_KEEP_ALIVE = "10m"; # 10 minute idle timeout (conservative for RAM)
      OLLAMA_LOAD_TIMEOUT = "10m";
      OLLAMA_VULKAN = "1"; # Enable Vulkan backend for potential iGPU offload
    };
  };

  # Per-model Modelfiles for pillar-of-autum.
  # num_thread tuned for 14-core Meteor Lake (6P + 8E + 2LP).
  # num_ctx 32768 (max for Qwen2.5) — KV cache ~1.1 GB (3B), ~2.0 GB (7B).
  environment.etc."ollama/modelfiles/pillar-qwen3b".text = ''
    FROM qwen2.5:3b
    PARAMETER num_ctx 32768
    PARAMETER num_thread 8
  '';

  environment.etc."ollama/modelfiles/pillar-qwen7b".text = ''
    FROM qwen2.5:7b
    PARAMETER num_ctx 32768
    PARAMETER num_thread 12
  '';

  # Tier 1 — Fast (32K context, ~25-35 tok/s)
  environment.etc."ollama/modelfiles/pillar-qwen3-4b-32k".text = ''
    FROM qwen3:4b
    PARAMETER num_ctx 32768
    PARAMETER num_thread 8
  '';

  # Tier 2 — Medium (128K context, ~5-7 tok/s)
  environment.etc."ollama/modelfiles/pillar-qwen35-9b-128k".text = ''
    FROM qwen3.5:9b
    PARAMETER num_ctx 131072
    PARAMETER num_thread 10
  '';

  # Tier 3 — Long (256K context, ~4-6 tok/s)
  environment.etc."ollama/modelfiles/pillar-gemma4-12b-256k".text = ''
    FROM gemma4:12b
    PARAMETER num_ctx 262144
    PARAMETER num_thread 12
  '';

  # One-shot: materialise created tags after blobs exist.
  systemd.services.ollama-create-profiles = {
    description = "Materialise pillar-of-autum Ollama Modelfiles";
    after = [ "ollama.service" "ollama-model-loader.service" ];
    wants = [ "ollama.service" "ollama-model-loader.service" ];
    wantedBy = [ ];
    serviceConfig.Type = "oneshot";
    environment = { HOME = "/root"; };
    script = ''
      set -euo pipefail
      export OLLAMA_HOST="http://10.88.127.110:11434"
      for f in /etc/ollama/modelfiles/pillar-*; do
        name="$(basename "$f")"
        ${lib.getExe pkgs_llm.ollama-cpu} create "$name" -f "$f"
      done
    '';
  };

  # Manual-start: neither the daemon nor model synchronization starts at boot.
  # Operators explicitly start the daemon and stop it to release RAM.
  systemd.services.ollama.wantedBy = lib.mkForce [ ];
  systemd.services.ollama-model-loader.wantedBy = lib.mkForce [ ];
  systemd.services.ollama.serviceConfig = {
    MemoryMax = "12G"; # 12 GB cap (system has ~15 GB total)
    MemoryHigh = "10G"; # Throttle at 10 GB
  };
}
