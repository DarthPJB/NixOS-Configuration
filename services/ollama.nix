{ lib
, pkgs_llm
, ...
}:
{
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;

    # CPU only. The RTX 3060 remains dedicated to the vLLM GPU service.
    package = pkgs_llm.ollama-cpu;
    models = "/speed-storage/ollama";
    loadModels = [
      "ornith:9b"
      "laguna-s-2.1:q4_K_M"
    ];

    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "262144";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
    };
  };

  # Research service: neither the daemon nor model synchronization starts at
  # boot. Operators explicitly start the daemon and stop it to release RAM.
  systemd.services.ollama.wantedBy = lib.mkForce [ ];
  systemd.services.ollama-model-loader.wantedBy = lib.mkForce [ ];
  systemd.services.ollama.serviceConfig.MemoryMax = "80G";
}
