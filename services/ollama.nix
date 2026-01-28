{ config, lib, pkgs, unstable, self, ... }:
{
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    models = "/speed-storage/ollama";
    package = unstable.ollama;
  };
    environment.systemPackages = [
      self.inputs.nix-mcp-servers.packages.x86_64-linux.github-mcp-server
      self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-git
      self.inputs.nix-mcp-servers.packages.x86_64-linux.mcp-server-filesystem
    ];
}
