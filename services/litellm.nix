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
        environment_variables = { };
        model_list = map (m: {
          model_name = m;
          litellm_params.model = "ollama/${m}";
          litellm_params.api_base = "http://127.0.0.1:${toString config.services.ollama.port}";
        }) [
          "qwen2.5:1.5b"
          "qwen2.5:32b-instruct-q5_K_M"
          "qwen2.5:7b"
          "qwen2.5-coder:32b-instruct-q5_K_M"
          "qwen2.5-coder:7b"
          "qwen3-coder:30b"
          "qwen2.5-coder:7b-16k"
          "qwen2.5:7b-16k"
        ];
      };
      environmentFile = config.secrix.services.litellm.secrets.litellm-env.decrypted.path;
    };
  secrix.services.litellm.secrets.litellm-env.encrypted.file = ../secrets/litellm-env-linda;
}
