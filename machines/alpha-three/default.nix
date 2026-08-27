# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config
, lib
, pkgs
, self
, hostname
, ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/enable-wg-topology.nix
    ../../modifier_imports/cuda.nix
    ../../environments/i3wm_darthpjb.nix
    ../../environments/steam.nix
    ../../environments/code.nix
    ../../environments/neovim.nix
    ../../services/gitlab-credentials.nix
    ../../services/litellm.nix
    ../../services/ollama-ui.nix
    (import ../../services/acme_server.nix { fqdn = "johnbargman.net"; })
  ];
  enableWgTopology.enable = true;
  security.acme.defaults.email = "commander@johnbargman.net";
  # Wildcard cert serves agentic-gateway + ollama UI via useACMEHost (topology vhosts)
  security.acme.certs."johnbargman.net".extraDomainNames = [ "*.johnbargman.net" ];

  # ── Fleet LLM Gateway ──────────────────────────────────────────
  # Backends on the WireGuard plane (10.88.127.0/24):
  #   linda       = 10.88.127.88  (vLLM: GPU :8001, CPU :8002/:8003)
  #   cluster-box = 10.88.127.211 (Malayalam: laguna/ornith; dlyon-operated)
  services.litellm = {
    environmentFileSecret = ../../secrets/litellm-env;
    # Expose /metrics for Prometheus scraping (vLLM-only migration, Phase 4.2)
    callbacks = [ "prometheus" ];
    backends = {
      # LINDA vLLM GPU (RTX 3060) — qwen2.5-vl on :8001
      linda-vllm = {
        url = "http://10.88.127.88:8001/v1";
        modelType = "hosted_vllm";
        apiKey = "none";
        models = [
          "qwen2.5-vl"
        ];
        maxTokens = 8192;
        maxTokensParam = 8192; # Clamp client max_tokens to model max_model_len
        mode = "chat";
        supportsVision = true;
        supportsVideoInput = true;
        supportsFunctionCalling = true;
      };
      # LINDA vLLM CPU — Qwen3.8-27B on :8002
      linda-vllm-cpu = {
        url = "http://10.88.127.88:8002/v1";
        modelType = "hosted_vllm";
        apiKey = "none";
        models = [
          "qwen38-27b"
        ];
        # Qwen3.8-27B dense model (262K native context; maxModelLen unset on LINDA)
        maxTokens = 32768;
        mode = "chat";
        supportsVision = true;
        supportsVideoInput = true;
        # Qwen3 emits reasoning params — drop them from requests to this backend
        additional_drop_params = [ "reasoningSummary" "reasoning_effort" ];
      };
      # LINDA vLLM CPU — Qwen3-Coder-30B-A3B on :8003
      linda-vllm-coder = {
        url = "http://10.88.127.88:8003/v1";
        modelType = "hosted_vllm";
        apiKey = "none";
        models = [
          "qwen3-coder-30b-a3b"
        ];
        maxTokens = 32768;
        mode = "chat";
        additional_drop_params = [ "reasoningSummary" "reasoning_effort" ];
      };
      cluster-box = {
        url = "http://10.88.127.211:11434/v1";
        models = [
          "laguna-xs-2.1:q4_K_M"
          "ornith:9b"
          "ornith:35b"
        ];
      };
    };
  };

  # Override nginx vhost to add extended timeouts for local LLMs
  # Local models (27B+) can take 1-3 minutes per request
  services.nginx.virtualHosts."agentic-gateway.johnbargman.net".locations."/".extraConfig = ''
    proxy_read_timeout 1200s;
    proxy_connect_timeout 10s;
    proxy_send_timeout 1200s;
    proxy_socket_keepalive on;
  '';
  services.nginx.virtualHosts."ollama.johnbargman.net".locations."/".extraConfig = ''
    proxy_read_timeout 1200s;
    proxy_connect_timeout 10s;
    proxy_send_timeout 1200s;
    proxy_socket_keepalive on;
  '';

  # nginx-config-reload times out during switch-to-configuration because
  # old nginx workers are stuck waiting for upstream (litellm on 127.0.0.1:8080)
  # which is stopped during the switch. Increase systemd timeout to 120s.
  systemd.services.nginx-config-reload.serviceConfig.TimeoutStartSec = 120;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
  ];
  hardware = {
    sane.enable = true;
    graphics.enable = true;
    cpu.amd.updateMicrocode = config.hardware.enableRedistributableFirmware;
    graphics.enable32Bit = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
      nvidiaSettings = true;
      open = false;
      modesetting.enable = false;
      powerManagement.enable = true;
    };
  };

  # secrix secret declarations for MCP tokens
  secrix.system.secretsDir = {
    permissions = "0555";
    user = "root";
    group = "users";
  };
  secrix.system.secrets.github-PAT-token = {
    encrypted.file = "${self}/secrets/github-PAT-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.gitlab-PAT-token = {
    encrypted.file = "${self}/secrets/gitlab-PAT-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.openrouter-master-token = {
    encrypted.file = "${self}/secrets/openrouter-master-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.alpha-three-openCODE-token = {
    encrypted.file = "${self}/secrets/alpha-three-openCODE-token";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.mimo-token-plan-ai-key = {
    encrypted.file = "${self}/secrets/mimo-token-plan-ai-key";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.litellm-master = {
    encrypted.file = "${self}/secrets/litellm-master";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.open-webui-env = {
    encrypted.file = "${self}/secrets/litellm-openai-env";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };

  # OpenCode fleet configuration — full fleet with MCP servers
  services.opencode-fleet = {
    enable = true;
    user = "John88";
    home = "/home/pokej";
    mcp.git = {
      enable = true;
      extraArgs = [ "--repository" "/home/pokej/NixOS-Configuration" ];
    };
    mcp.filesystem = {
      enable = true;
      paths = [ "/home/pokej" "/nix/store" "/home/pokej/NixOS-Configuration" ];
    };
    mcp.time.enable = true;
    mcp.sqlite.enable = true;
    mcp.playwright.enable = true;
    mcp.github = {
      enable = true;
      tokenFile = config.secrix.system.secrets.github-PAT-token.decrypted.path;
    };
    mcp.gitlab = {
      enable = true;
      tokenFile = config.secrix.system.secrets.gitlab-PAT-token.decrypted.path;
    };
    mcp.prometheus = {
      enable = true;
      prometheusUrl = "http://10.88.127.3:8080";
    };
    mcp.nix-mcp.enable = true;
    providers.openrouter = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.openrouter-master-token.decrypted.path;
    };
    providers.opencode-go = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.alpha-three-openCODE-token.decrypted.path;
    };
    providers.xiaomi-token-plan-sgp = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.mimo-token-plan-ai-key.decrypted.path;
    };
    providers.litellm = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.litellm-master.decrypted.path;
    };
  };
}
