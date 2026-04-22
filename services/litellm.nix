{
  config,
  pkgs,
  lib,
  self,
  unstable,
  ...
}:
let
  stateDir = "/speed-storage/litellm";
in
{
  options.services.litellm.backends = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "Ollama API base URL";
            example = "http://10.75.69.88:11434";
          };
        };
      }
    );
    default = { };
    description = "Ollama backend endpoints. If set, these backends are used instead of local Ollama.";
  };

  # Only set environmentFile if NOT using backends
  config.secrix.services.litellm.secrets.litellm-env.encrypted.file = ../secrets/litellm-env-linda;

  config.services.litellm =
    let
      backends = config.services.litellm.backends or { };
      modelNames = [
        "qwen2.5:1.5b"
        "qwen2.5:32b-instruct-q5_K_M"
        "qwen2.5:7b"
        "qwen2.5-coder:32b-instruct-q5_K_M"
        "qwen2.5-coder:7b"
        "qwen3-coder:30b"
        "qwen2.5-coder:7b-16k"
        "qwen2.5:7b-16k"
      ];
      # Generate model entries: backends mode OR local mode
      modelList =
        if backends != { } then
          lib.concatLists (
            lib.mapAttrsToList (
              name: cfg:
              map (m: {
                model_name = "${name}/${m}";
                litellm_params = {
                  model = "ollama/${m}";
                  api_base = cfg.url;
                };
              }) modelNames
            ) backends
          )
        else
          map (m: {
            model_name = m;
            litellm_params = {
              model = "ollama/${m}";
              api_base = "http://127.0.0.1:${toString config.services.ollama.port}";
            };
          }) modelNames;
    in
    {
      enable = true;
      inherit stateDir;
      port = 8080;
      host = "127.0.0.1";
      package = unstable.litellm;
      settings = {
        environment_variables = { };
        environmentFile =
          if backends != { } then null else config.secrix.services.litellm.secrets.litellm-env.decrypted.path;
        model_list = modelList;
      };
    };
}
