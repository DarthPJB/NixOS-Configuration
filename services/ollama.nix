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
    # Runtime envelope — all four models are 256K-native (verified via /api/show).
    # Upstream default num_ctx=4096 silently truncates real client prompts
    # (log-proven: 31,608-token prompt cut to 2,051; system prompts destroyed).
    # q4_0 KV cache makes the full window affordable on CPU:
    # ~15-16 GiB KV/model instead of ~40 GiB at f16.
    # Sampling is intentionally NOT set here — each model carries its own
    # baked PARAMETERs which take precedence over env defaults anyway.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "262144";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
    };
  };
  environment.systemPackages = [
    # MCP servers now provided by opencode-fleet module
    # Configure per-machine: services.opencode-fleet.mcp.<server>.enable = true;
    pkgs.prometheus-mcp-server
  ];
}
