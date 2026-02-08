{ config, lib, pkgs, unstable, self, ... }:
{
  services.nextjs-ollama-llm-ui = {
    port = 8081;
    ollamaUrl = "http://127.0.0.1:${config.services.ollama.port}";
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

  };
  environment.systemPackages = [
    self.inputs.nix-mcp-servers.packages.x86_64-linux.github-mcp-server
    self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-git
    self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-filesystem
  ];
}
