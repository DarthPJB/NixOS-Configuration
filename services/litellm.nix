{ config, pkgs, lib, unstable, ... }:
let
  stateDir = "/speed-storage/litellm"; 
in
{
  services.litellm =
    {
      enable = true;
      inherit stateDir;
      port = 8080;
      host = "127.0.0.1";
      settings = {
        environment_variables = {
        };
        model_list = [
            {
            model_name = "qwen2.5-coder:7b";
            litellm_params = {
              model = "ollama/qwen2.5-coder:7b";
              api_base = "http://127.0.0.1:${config.services.ollama.port}";
            };
          }
          {
            model_name = "ollama/qwen2.5:7b";
            litellm_params = {
              model = "ollama/qwen2.5:7b";
              api_base = "http://127.0.0.1:${config.services.ollama.port}";
            };
          }
        ];
      };
      environmentFile = config.secrix.services.litellm.secrets.litellm-env.decrypted.path;
    };
  secrix.services.litellm.secrets.litellm-env.encrypted.file = ../secrets/litellm-env-linda;
}
