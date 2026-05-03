{ config
, lib
, pkgs
, self
, ...
}:
{
  # Encrypt the ENV file with secrix
  secrix.services.zeroclaw.secrets.zeroclaw-env.encrypted.file =
    ../secrets/zeroclaw.env;

  services.zeroclaw = {
    enable = true;

    # Bind to WireGuard interface
    host = "10.88.127.107";
    port = 42617;

    # Single ENV file with all provider keys
    environmentFile =
      config.secrix.services.zeroclaw.secrets.zeroclaw-env.decrypted.path;

    # Two agents: general on mimo, coder on grok
    agents = {
      general.apiKeyFile = null; # uses ZEROCLAW_API_KEY from env
      coder.apiKeyFile = null; # uses XAI_API_KEY from env
    };

    settings = {
      default_provider = "custom:https://token-plan-sgp.xiaomimimo.com/v1";
      default_model = "mimo-v2.5-pro";

      # Agent definitions
      agents = {
        general = {
          provider = "custom:https://token-plan-sgp.xiaomimimo.com/v1";
          model = "mimo-v2.5-pro";
          system_prompt = "You are a helpful general-purpose assistant.";
          agentic = true;
          allowed_tools = [
            "file_read"
            "file_write"
            "file_list"
            "web_search"
            "http_request"
            "shell"
            "memory_search"
          ];
          max_iterations = 15;
        };

        coder = {
          provider = "xai";
          model = "grok-code";
          system_prompt = "You are an expert coding assistant. Write clean, well-documented code. When modifying files, explain your changes.";
          agentic = true;
          allowed_tools = [
            "file_read"
            "file_write"
            "file_list"
            "shell"
            "web_search"
            "memory_search"
          ];
          max_iterations = 20;
        };
      };

      # Memory
      memory = {
        backend = "sqlite";
        auto_save = true;
      };

      # Autonomy — permissive since alpha-three is expendable
      autonomy = {
        level = "full";
        workspace_only = false;
        allowed_commands = [ "*" ];
        auto_approve = [
          "file_read"
          "file_write"
          "file_list"
          "web_search"
          "http_request"
          "shell"
          "memory_search"
          "memory_save"
        ];
      };

      # Gateway config
      gateway = {
        host = "10.88.127.107";
        port = 42617;
        require_pairing = true;
        allow_public_bind = true;
      };

      # Channels — CLI always on, web gateway enabled
      channels_config = {
        cli = true;
      };

      # Observability
      observability = {
        backend = "log";
      };
    };
  };
}
