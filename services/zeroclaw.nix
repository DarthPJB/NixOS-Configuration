{ config
, lib
, pkgs
, self
, ...
}:
{
  # Make the zeroclaw CLI available in PATH
  environment.systemPackages = [ config.services.zeroclaw.package ];

  # Allow ZeroClaw gateway over WireGuard
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [
    config.services.zeroclaw.port
  ];

  # Encrypt the ENV file with secrix
  secrix.services.zeroclaw.secrets.zeroclaw-env.encrypted.file =
    ../secrets/zeroclaw-env-file;

  # Mattermost bot token secret
  secrix.services.zeroclaw.secrets.openclaw-alpha-mattermost.encrypted.file =
    ../secrets/openclaw-alpha-mattermost;

  services.zeroclaw = {
    enable = true;
    mutableConfig = false;  # Critical: always regenerate from Nix

    channels.mattermost.secretFiles.bot_token =
      config.secrix.services.zeroclaw.secrets.openclaw-alpha-mattermost.decrypted.path;

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
          system_prompt = ''
            You are a helpful general-purpose assistant in a Mattermost chat.
            NEVER output tool call JSON, delegation patterns, or raw commands.
            Execute tasks silently and present only clean, human-readable results.
            If you run a command, summarize the outcome in plain English.
          '';
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
          max_iterations = 10;
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

      # Agent-level settings
      agent = {
        max_tool_iterations = 20;
        non_cli_excluded_tools = [ "delegate" ];
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

      # Channels — CLI always on via module, web gateway enabled
      channels_config = {
        mattermost = {
          url = "https://chat.platonic.systems";
          channel_id = "tawaaxipuj877nz4nbetkb53ge";
          allowed_users = [ "*" ];
          thread_replies = true;
          mention_only = true;
        };
      };

      # Observability
      observability = {
        backend = "log";
      };
    };
  };
}
