{ config
, lib
, pkgs
, pkgs_llm
, self
, ...
}:
{
  services.nextjs-ollama-llm-ui = {
    port = 8081;
    ollamaUrl = "http://127.0.0.1:${builtins.toString config.services.ollama.port}";
    enable = true;
  };
  services.ollama = {
    port = 11434;
    host = "0.0.0.0";
    enable = true;
    # acceleration = "cuda"; # CPU-only — GPU reserved for vLLM
    models = "/speed-storage/ollama";
    package = pkgs_llm.ollama-cuda; # keep CUDA package for potential future use
    loadModels = [
      "qwen3.8:27b-q4_K_M"
      "qwen3-coder:30b-a3b-q4_K_M"
      "laguna-s-2.1:q4_K_M"
      "laguna-xs-2.1:q4_K_M"
    ];
    environmentVariables = {
      OLLAMA_NUM_GPU = "0"; # CPU-only — no GPU offload
    };

  };
  environment.systemPackages = [
    # MCP servers now provided by opencode-fleet module
    # Configure per-machine: services.opencode-fleet.mcp.<server>.enable = true;
    pkgs.prometheus-mcp-server
  ];
}
