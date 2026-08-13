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
    ../../environments/i3wm_darthpjb.nix
    ../../environments/steam.nix
    ../../environments/code.nix
    ../../environments/neovim.nix
    ../../environments/communications.nix
    ../../environments/browsers.nix
    ../../environments/cad_and_graphics.nix
    ../../environments/3dPrinting.nix
    ../../environments/audio_visual_editing.nix
    ../../environments/general_fonts.nix
    ../../environments/video_call_streaming.nix
    ../../environments/rtl-sdr.nix
    ../../modifier_imports/bluetooth.nix
    ../../modifier_imports/hosts.nix
    ../../modifier_imports/cuda.nix
  ];
  enableWgTopology.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.desktopManager.cinnamon.enable = true;
  networking.networkmanager.enable = lib.mkForce false;
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  environment.systemPackages = with pkgs; [
    pkgs.moonlight-qt
  ];
  hardware = {
    sane.enable = true;
    graphics.enable = true;
    graphics.enable32Bit = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
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
  secrix.system.secrets.mimo-token-plan-ai-key = {
    encrypted.file = "${self}/secrets/mimo-token-plan-ai-key";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.general-opencode-key = {
    encrypted.file = "${self}/secrets/general-opencode-key";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };
  secrix.system.secrets.general-xai-key = {
    encrypted.file = "${self}/secrets/general-xai-key";
    decrypted = {
      user = "John88";
      group = "users";
      mode = "0440";
    };
  };

  # OpenCode fleet — Voyager only (client machine) with full provider and MCP config
  services.opencode-fleet = {
    enable = true;
    user = "John88";
    home = "/home/John88";
    shipOverride = [ "voyager" ];
    mcp.git = {
      enable = true;
      extraArgs = [ "--repository" "/home/pokej/NixOS-Configuration" ];
    };
    mcp.filesystem = {
      enable = true;
      paths = [ "/home/pokej" "/speed-storage" "/nix/store" "/home/pokej/NixOS-Configuration" ];
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
      apiKeyFile = config.secrix.system.secrets.general-opencode-key.decrypted.path;
    };
    providers.xiaomi-token-plan-sgp = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.mimo-token-plan-ai-key.decrypted.path;
    };
    providers.xai = {
      enable = true;
      apiKeyFile = config.secrix.system.secrets.general-xai-key.decrypted.path;
    };
  };
}
