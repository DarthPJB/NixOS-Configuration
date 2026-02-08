{ config, lib, pkgs, unstable, self, ... }:
{
  services.litellm =
    {
      enable = true;
      stateDir = "/speed-storage/litellm";
      port = 8080;
      host = "127.0.0.1";
      settings = {
        "environment_variables" = { };
        "model_list" = [
          {
            "model_name" = "ollama/qwen3:30b";
            "litellm_params" = {
              model = "ollama/qwen3:30b";
              api_base = "http://127.0.0.1:11434";
            };
          }
        ];
      };
      environmentFile = config.secrix.services.litellm.secrets.litellm-env.decrypted.path; 
    };
  secrix.services.litellm.secrets.litellm-env.
    encrypted.file = ../secrets/litellm-env-linda;
  services.nextjs-ollama-llm-ui = {
    port = 8081;
    ollamaUrl = "http://127.0.0.1:11434";
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
