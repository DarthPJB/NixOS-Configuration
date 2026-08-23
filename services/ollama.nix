{ config
, lib
, pkgs
, pkgs_llm
, self
, ...
}:
{
  services.ollama = {
    port = 11434;
    host = "0.0.0.0";
    enable = true;
    # CPU only — GPU reserved exclusively for vLLM.
    # pkgs_llm is imported with cudaSupport=true, so pkgs_llm.ollama ≡ ollama-cuda.
    # Pin ollama-cpu so this service cannot claim the 3060.
    package = pkgs_llm.ollama-cpu;
    models = "/speed-storage/ollama";
    loadModels = [
      "qwen3.8:27b-q4_K_M"
      "qwen3-coder:30b-a3b-q4_K_M"
      "laguna-s-2.1:q4_K_M"
      "laguna-xs-2.1:q4_K_M"
    ];
  };
  environment.systemPackages = [
    # MCP servers now provided by opencode-fleet module
    # Configure per-machine: services.opencode-fleet.mcp.<server>.enable = true;
    pkgs.prometheus-mcp-server
  ];
}
