{ lib
, pkgs_llm
, ...
}:
{
  services.ollama = {
    enable = true;
    host = "10.88.127.88"; # WireGuard plane only — not loopback, not all interfaces
    port = 11434;
    package = pkgs_llm.ollama-cpu;
    models = "/speed-storage/ollama";

    # Disk catalog only. model-loader stays off at boot.
    loadModels = [
      "ornith:9b"
      "ornith:35b"
      "laguna-xs-2.1:q4_K_M"
      "laguna-xs-2.1:bf16"
      "laguna-s-2.1:q4_K_M"
      "qwen3.8:27b"
      "qwen3:4b"
      "qwen3.5:9b"
      "gemma4:12b"
    ];

    # Host limits only — not model policy. CPU cores are assigned per model
    # via num_thread in the Modelfiles below, not here.
    environmentVariables = {
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_KEEP_ALIVE = "-1"; # Keep loaded permanently — no idle unload
      OLLAMA_LOAD_TIMEOUT = "20m"; # Allow large models (Laguna S 96GB) to load without connection drop
    };
  };

  # Per-model Modelfiles. num_thread is llama.cpp -t: the CPU core count handed
  # to each model at load. Ornith gets 38 cores, Laguna gets 48 — tuned per
  # family, not per daemon.
  environment.etc."ollama/modelfiles/linda-ornith9-q4-256k".text = ''
    FROM ornith:9b
    PARAMETER num_ctx 262144
    PARAMETER num_thread 38
  '';

  environment.etc."ollama/modelfiles/linda-ornith35-q4-256k".text = ''
    FROM ornith:35b
    PARAMETER num_ctx 262144
    PARAMETER num_thread 38
  '';

  environment.etc."ollama/modelfiles/linda-laguna-xs-q4-256k".text = ''
    FROM laguna-xs-2.1:q4_K_M
    PARAMETER num_ctx 262144
    PARAMETER num_thread 48
  '';

  environment.etc."ollama/modelfiles/linda-laguna-xs-bf16-256k".text = ''
    FROM laguna-xs-2.1:bf16
    PARAMETER num_ctx 262144
    PARAMETER num_thread 48
  '';

  environment.etc."ollama/modelfiles/linda-laguna-s-q4-256k".text = ''
    FROM laguna-s-2.1:q4_K_M
    PARAMETER num_ctx 262144
    PARAMETER num_thread 48
  '';

  environment.etc."ollama/modelfiles/linda-qwen38-27b-q4-256k".text = ''
    FROM qwen3.8:27b
    PARAMETER num_ctx 262144
    PARAMETER num_thread 48
  '';

  # Pillar comparison models — same num_ctx as pillar-of-autum for A/B testing.
  # num_thread scaled up for LINDA's 48-core EPYC.
  environment.etc."ollama/modelfiles/linda-qwen3-4b-32k".text = ''
    FROM qwen3:4b
    PARAMETER num_ctx 32768
    PARAMETER num_thread 24
  '';

  environment.etc."ollama/modelfiles/linda-qwen35-9b-128k".text = ''
    FROM qwen3.5:9b
    PARAMETER num_ctx 131072
    PARAMETER num_thread 32
  '';

  environment.etc."ollama/modelfiles/linda-gemma4-12b-256k".text = ''
    FROM gemma4:12b
    PARAMETER num_ctx 262144
    PARAMETER num_thread 38
  '';

  # One-shot: materialise created tags after blobs exist.
  systemd.services.ollama-create-profiles = {
    description = "Materialise LINDA Ollama Modelfiles";
    after = [ "ollama.service" "ollama-model-loader.service" ];
    wants = [ "ollama.service" "ollama-model-loader.service" ];
    wantedBy = [ ];
    serviceConfig.Type = "oneshot";
    environment = { HOME = "/root"; };
    script = ''
      set -euo pipefail
      export OLLAMA_HOST="http://10.88.127.88:11434"
      for f in /etc/ollama/modelfiles/*; do
        name="$(basename "$f")"
        ${lib.getExe pkgs_llm.ollama-cpu} create "$name" -f "$f"
      done
    '';
  };

  # Research service: neither the daemon nor model synchronization starts at
  # boot. Operators explicitly start the daemon and stop it to release RAM.
  systemd.services.ollama.wantedBy = lib.mkForce [ ];
  systemd.services.ollama-model-loader.wantedBy = lib.mkForce [ ];
  systemd.services.ollama.serviceConfig = {
    MemoryMax = "105G";
    MemoryHigh = "85G";
  };
}
