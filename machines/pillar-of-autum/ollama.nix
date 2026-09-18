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
# Inference benchmarks (CPU-only, Ollama 0.30.6):
#   - qwen2.5:0.5b  → 65.5 tok/s (excellent for interactive)
#   - qwen2.5:3b    → 17.1 tok/s (good for LiteLLM backend)
#   - qwen2.5:7b    →  8.0 tok/s (viable for batch/async)
#
# Recommended models: qwen2.5:3b (interactive), qwen2.5:7b (batch)
# Single-model-per-device discipline enforced (16 GB RAM constraint).
#
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
    # qwen2.5:3b is the primary workhorse (~2 GiB model, ~6 GiB with context).
    # qwen2.5:7b is viable for batch workloads (~4.7 GiB model, ~10 GiB with context).
    loadModels = [
      "qwen2.5:3b"
      "qwen2.5:7b"
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
  # Using 8 threads for 3B (E-core friendly), 12 for 7B (P-core stretch).
  environment.etc."ollama/modelfiles/pillar-qwen3b".text = ''
    FROM qwen2.5:3b
    PARAMETER num_ctx 8192
    PARAMETER num_thread 8
  '';

  environment.etc."ollama/modelfiles/pillar-qwen7b".text = ''
    FROM qwen2.5:7b
    PARAMETER num_ctx 4096
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
