{ config, lib, unstable, ... }:
{
  options.services.litellm.backends = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "API base URL (WireGuard plane)";
            example = "http://10.88.127.88:11434/v1";
          };
          models = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Model tags served by this backend; routed as <name>/<model>";
          };
          modelType = lib.mkOption {
            type = lib.types.enum [ "openai" "hosted_vllm" "ollama_chat" ];
            default = "openai";
            description = ''
              LiteLLM provider prefix for litellm_params.model.
              openai — default. OpenAI SDK path for Ollama /v1 and other
              OpenAI-compatible endpoints. Requires a non-empty api_key
              (use "none" when the backend ignores it).
              hosted_vllm — vLLM OpenAI-compatible server.
              ollama_chat — legacy native POST /api/chat. Reserved for
              native-API clients; the fleet UI uses LiteLLM /ollama passthrough.
            '';
          };
          apiKey = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "none";
            description = ''
              Backend api_key passed as litellm_params.api_key.
              Default "none" satisfies the OpenAI SDK for unauthenticated
              local backends (Ollama /v1, vLLM without --api-key).
              Override with a real key when the backend enforces auth.
              Not a gateway master key — that lives in environmentFileSecret.
            '';
            example = "none";
          };
          additional_drop_params = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Parameters to drop from requests to this backend (e.g., reasoningSummary)";
          };
          rpm = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Requests per minute for this deployment (litellm_params.rpm). Unset = no limit.";
          };
          tpm = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Tokens per minute for this deployment (litellm_params.tpm). Unset = no limit.";
          };
          timeout = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Per-deployment request timeout in seconds (litellm_params.timeout). Unset = LiteLLM default.";
          };
          supportsSystemMessage = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "If false, LiteLLM remaps system messages to user (litellm_params.supports_system_message). Unset = provider default.";
          };
          maxTokens = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.positive;
            default = null;
            description = "Advertised context window (model_info.max_tokens). Clients use this to avoid overshooting.";
          };
          mode = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum [
              "chat"
              "embedding"
              "completion"
              "image_generation"
              "audio_transcription"
            ]);
            default = null;
            description = "LiteLLM model_info.mode. Set 'chat' for chat/completions backends.";
          };
          supportsVision = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Advertise vision (image_url) on /model/info (model_info.supports_vision).";
          };
          supportsVideoInput = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Advertise video_url / file video input (model_info.supports_video_input).";
          };
          supportsFunctionCalling = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Advertise tools/function calling (model_info.supports_function_calling).";
          };
        };
      }
    );
    default = { };
    description = "LLM backend endpoints. Gateway mode when non-empty.";
  };

  options.services.litellm.environmentFileSecret = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
    description = "Encrypted secrix env file (LITELLM_MASTER_KEY, DATABASE_URL).";
  };

  options.services.litellm.dropParams = lib.mkOption {
    type = lib.types.nullOr lib.types.bool;
    default = null;
    description = "Global litellm_settings.drop_params. Drops unsupported OpenAI params instead of erroring. Unset = LiteLLM default.";
  };

  options.services.litellm.numRetries = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.unsigned;
    default = null;
    description = "Global litellm_settings.num_retries. Unset = LiteLLM default.";
  };

  options.services.litellm.fallbacks = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    description = ''
      Global litellm_settings.fallbacks. Each entry is { "model-group" = [ "fallback-group" ]; }.
      Empty = no fallbacks.
    '';
    example = [{ "linda-vllm/qwen2.5-vl" = [ "linda/qwen3.8:27b-q4_K_M" ]; }];
  };

  options.services.litellm.requestTimeout = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = null;
    description = "Global litellm_settings.request_timeout in seconds. Unset = LiteLLM default (6000s).";
  };

  config.secrix.services.litellm.secrets.litellm-env.encrypted.file =
    lib.mkIf (config.services.litellm.environmentFileSecret != null)
      config.services.litellm.environmentFileSecret;

  config.services.litellm =
    let
      # Count how many backends advertise each Ollama tag.
      # When a tag is unique, the public id is <backend>/<tag>.
      # When the same tag appears on multiple backends, repeat the backend
      # name in the remainder so opencode-plugin-litellm's formatModelName()
      # (which strips only the first `provider/` segment) produces distinct
      # picker labels instead of collapsing both to "Laguna Xs …".
      tagCounts = lib.foldl'
        (acc: cfg: lib.foldl' (a: m: a // { ${m} = (a.${m} or 0) + 1; }) acc cfg.models)
        { }
        (lib.attrValues config.services.litellm.backends);

      modelInfoOf = cfg: lib.filterAttrs (_: v: v != null) {
        max_tokens = cfg.maxTokens;
        mode = cfg.mode;
        supports_vision = cfg.supportsVision;
        supports_video_input = cfg.supportsVideoInput;
        supports_function_calling = cfg.supportsFunctionCalling;
      };

      # Per-backend model lists — each backend advertises ONLY its own models
      modelList = lib.concatLists (lib.mapAttrsToList
        (name: cfg:
          map
            (m: {
              model_name =
                if (tagCounts.${m} or 1) > 1
                then "${name}/${name}-${m}"
                else "${name}/${m}";
              litellm_params = {
                model = "${cfg.modelType}/${m}";
                api_base = cfg.url;
              } // lib.optionalAttrs (cfg.apiKey != null) {
                api_key = cfg.apiKey;
              } // lib.optionalAttrs (cfg.additional_drop_params != [ ]) {
                additional_drop_params = cfg.additional_drop_params;
              } // lib.optionalAttrs (cfg.rpm != null) {
                rpm = cfg.rpm;
              } // lib.optionalAttrs (cfg.tpm != null) {
                tpm = cfg.tpm;
              } // lib.optionalAttrs (cfg.timeout != null) {
                timeout = cfg.timeout;
              } // lib.optionalAttrs (cfg.supportsSystemMessage != null) {
                supports_system_message = cfg.supportsSystemMessage;
              };
            } // lib.optionalAttrs (modelInfoOf cfg != { }) {
              model_info = modelInfoOf cfg;
            })
            cfg.models)
        config.services.litellm.backends);

      litellmSettings = lib.filterAttrs (_: v: v != null)
        {
          drop_params = config.services.litellm.dropParams;
          num_retries = config.services.litellm.numRetries;
          request_timeout = config.services.litellm.requestTimeout;
        } // lib.optionalAttrs (config.services.litellm.fallbacks != [ ]) {
        fallbacks = config.services.litellm.fallbacks;
      };
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
      } // lib.optionalAttrs (litellmSettings != { }) {
        litellm_settings = litellmSettings;
      };
    };
}
