{ lib
, pkgs_llm
, ...
}:
{
  services.ollama = {
    enable = true;
    host = "127.0.0.1"; # LiteLLM/WG is the public plane
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
    ];

    # Host limits only — not model policy.
    environmentVariables = {
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
    };
  };

  # Per-model Modelfiles. Context lives on the model name, not the daemon.
  environment.etc."ollama/modelfiles/linda-ornith9-q4-256k".text = ''
    FROM ornith:9b
    PARAMETER num_ctx 262144
  '';

  environment.etc."ollama/modelfiles/linda-ornith35-q4-256k".text = ''
    FROM ornith:35b
    PARAMETER num_ctx 262144
  '';

  environment.etc."ollama/modelfiles/linda-laguna-xs-q4-256k".text = ''
    FROM laguna-xs-2.1:q4_K_M
    PARAMETER num_ctx 262144
  '';

  environment.etc."ollama/modelfiles/linda-laguna-xs-bf16-256k".text = ''
    FROM laguna-xs-2.1:bf16
    PARAMETER num_ctx 262144
  '';

  environment.etc."ollama/modelfiles/linda-laguna-s-q4-256k".text = ''
    FROM laguna-s-2.1:q4_K_M
    PARAMETER num_ctx 262144
  '';

  environment.etc."ollama/modelfiles/linda-qwen38-27b-q4-256k".text = ''
    FROM qwen3.8:27b
    PARAMETER num_ctx 262144
  '';

  # One-shot: materialise created tags after blobs exist.
  systemd.services.ollama-create-profiles = {
    description = "Materialise LINDA Ollama Modelfiles";
    after = [ "ollama.service" ];
    wants = [ "ollama.service" ];
    wantedBy = [ ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
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
    MemoryMax = "96G";
    MemoryHigh = "88G";
  };
}
