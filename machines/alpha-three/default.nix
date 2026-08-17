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
    (import ../../services/acme_server.nix { fqdn = "johnbargman.net"; })
  ];
  enableWgTopology.enable = true;
  security.acme.defaults.email = "commander@johnbargman.net";
  # Wildcard cert serves agentic-gateway.johnbargman.net via useACMEHost (topology vhost)
  security.acme.certs."johnbargman.net".extraDomainNames = [ "*.johnbargman.net" ];

  # ── Fleet LLM Gateway ──────────────────────────────────────────
  # Backends on the WireGuard plane (10.88.127.0/24):
  #   linda       = 10.88.127.88  (qwen fleet)
  #   cluster-box = 10.88.127.211 (Malayalam: laguna/ornith; dlyon-operated)
  services.litellm = {
    environmentFileSecret = ../../secrets/litellm-env;
    backends = {
      linda = {
        url = "http://10.88.127.88:11434";
        models = [
          "qwen2.5:1.5b"
          "qwen2.5:7b"
          "qwen2.5:7b-16k"
          "qwen2.5-coder:7b"
          "qwen2.5-coder:7b-16k"
          "qwen2.5:32b-instruct-q5_K_M"
          "qwen2.5-coder:32b-instruct-q5_K_M"
          "qwen3-coder:30b"
          "qwen3-coder:30b-instruct-q5_K_M"
        ];
      };
      cluster-box = {
        url = "http://10.88.127.211:11434";
        models = [
          "laguna-xs-2.1:q4_K_M"
          "ornith:9b"
          "ornith:35b"
        ];
      };
    };
  };
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

  # OpenCode fleet configuration — full fleet with MCP servers
  services.opencode-fleet = {
    enable = true;
    user = "John88";
    home = "/home/John88";
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
  };
}
