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
  ];
  enableWgTopology.enable = true;
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
  secrix.system.secrets.github-PAT-token.encrypted.file =
    "${self}/secrets/github-PAT-token";
  secrix.system.secrets.gitlab-PAT-token.encrypted.file =
    "${self}/secrets/gitlab-PAT-token";

  # OpenCode fleet configuration — full fleet with MCP servers
  services.opencode-fleet = {
    enable = true;
    voyagerOnly = false; # Full fleet
    mcp.git.enable = true;
    mcp.filesystem.enable = true;
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
  };
}
