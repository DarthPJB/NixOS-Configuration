{ config, lib, unstable, ... }:
{
  options.services.litellm.backends = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "Ollama API base URL (WireGuard plane)";
            example = "http://10.88.127.88:11434";
          };
          models = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Model tags served by this backend; routed as <name>/<model>";
          };
        };
      }
    );
    default = { };
    description = "Ollama backend endpoints. Gateway mode when non-empty.";
  };

  options.services.litellm.environmentFileSecret = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = "Encrypted secrix env file (LITELLM_MASTER_KEY, DATABASE_URL).";
  };

  config.secrix.services.litellm.secrets.litellm-env.encrypted.file =
    lib.mkIf (config.services.litellm.environmentFileSecret != null)
      config.services.litellm.environmentFileSecret;

  config.services.litellm =
    let
      # Per-backend model lists — each backend advertises ONLY its own models
      modelList = lib.concatLists (lib.mapAttrsToList
        (name: cfg:
          map
            (m: {
              model_name = "${name}/${m}";
              litellm_params = {
                model = "ollama/${m}";
                api_base = cfg.url;
              };
            })
            cfg.models)
        config.services.litellm.backends);
    in
    {
      enable = true;
      stateDir = "/var/lib/litellm"; # upstream default; alpha-three has no /speed-storage
      port = 8080;
      host = "127.0.0.1"; # nginx fronts TLS; HTTP never leaves localhost
      package = unstable.litellm;
      settings = {
        environment_variables = { };
        environmentFile = config.secrix.services.litellm.secrets.litellm-env.decrypted.path;
        model_list = modelList;
      };
    };
}
