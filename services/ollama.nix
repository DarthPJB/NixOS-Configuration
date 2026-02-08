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


  };
  environment.systemPackages = [
    self.inputs.nix-mcp-servers.packages.x86_64-linux.github-mcp-server
    self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-git
    self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-filesystem
  ];
}
