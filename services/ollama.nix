{ config, lib, pkgs, unstable, self, ... }:
{
  services.nextjs-ollama-llm-ui = {
    port = 8081;
    ollamaUrl = "http://127.0.0.1:${builtins.toString config.services.ollama.port}";
    enable = true;
  };
  services.ollama = {
    port = 11434;
    enable = true;
    acceleration = "cuda";
    models = "/speed-storage/ollama";
    package = unstable.ollama-cuda;
    loadModels = [
      "qwen3-coder:30b-instruct-q5_K_M"
      "qwen2.5-coder:32b-instruct-q5_K_M"
      "qwen2.5:32b-instruct-q5_K_M"
      "qwen3-coder:30b"
      "qwen2.5-coder:7b"
      "qwen2.5:7b"
      "qwen2.5:1.5b"
    ];
    environmentVariables = {  /* The fragging LLM told me to set these and I did it; I question not the machine spirits */ 
      CUDA_VISIBLE_DEVICES = "0,1";          # tells Ollama both GPUs exist (0 = RTX 3060, 1 = GTX 1050)
      OLLAMA_NUM_CTX = "16384"; # 16k context — small models lose coherence fast; 8k default is usually too tight for tool use / multi-turn
      OLLAMA_NUM_PREDICT = "4096"; # reasonable max output length — prevents endless generation while still allowing long code / explanations
      OLLAMA_REPEAT_PENALTY = "1.12"; # mild repetition suppression — small models repeat phrases a lot; 1.1–1.15 usually optimal range
      OLLAMA_TEMPERATURE = "0.75"; # slightly creative but controlled — 0.7–0.8 gives best balance between deterministic code and natural language
      OLLAMA_TOP_P = "0.9"; # nucleus sampling — 0.9–0.95 reduces nonsense while keeping some variety (better than greedy for small models)
      OLLAMA_TOP_K = "40"; # limits token choices — 30–50 works well on 7B models to avoid very low-probability garbage tokens
      OLLAMA_NUM_GPU = "-1"; # offload as many layers as possible — maximizes speed on RTX 3060 (usually all layers fit at Q5/Q4)
      OLLAMA_FLASH_ATTENTION = "true"; # enables flash attention if compiled in — ~20–40% faster inference on CUDA, almost free speedup
    };

  };
  environment.systemPackages = [
    self.inputs.nix-mcp-servers.packages.x86_64-linux.github-mcp-server
    self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-git
    self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-filesystem
  ];
}
