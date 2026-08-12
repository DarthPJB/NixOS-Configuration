{ config
, pkgs
, lib
, self
, hostname
, ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../users/darthpjb.nix
    ../../modifier_imports/flakes.nix
    ../../environments/sshd.nix
    ../../environments/tools.nix
    ../../services/dynamic_domain_gandi.nix
    ../../services/gitlab-runner.nix
    ../../services/gitlab-credentials.nix
    ../../modifier_imports/remote-builder.nix
    ../../users/build.nix
    ../../modules/enable-wg-topology.nix
    ../../services/nix-cache-serve.nix
  ];
  # Nix binary cache — open port 5001 on WAN
  networking.firewall.allowedTCPPorts = [ 5001 ];

  # Virtual disk devices — smartctl/smartd not applicable
  services.smartd.enable = lib.mkForce false;
  services.prometheus.exporters.smartctl.enable = lib.mkForce false;

  enableWgTopology.enable = true;

  # Build-runner hub: never build locally, distribute all builds to
  # hyperhyper (x86_64-linux) and arm-builder (aarch64-linux).
  nix.settings.max-jobs = 0;

  # This machine IS the cache. Never garbage-collect — retain all closures.
  # Also skip store optimisation — only grows, never rebuilds locally.
  nix.gc.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  # Build-time GC: last-resort protection against disk-full.
  # Triggers during builds when free space drops below 10GB.
  # Collects unreachable garbage until 30GB free (max 20GB freed).
  # This only deletes paths with no GC roots — system profiles and active
  # builds are never touched.
  nix.settings.min-free = 10 * 1024 * 1024 * 1024; # 10GB
  nix.settings.max-free = 30 * 1024 * 1024 * 1024; # 30GB
  nix.settings.min-free-check-interval = 30;

  # Tailscale: direct connection to hyperhyper (replaces WireGuard proxy route)
  secrix.services.tailscaled.secrets.auth-key.encrypted.file =
    ../../secrets/tailscale_auth_key;
  services.tailscale = {
    enable = true;
    authKeyFile = config.secrix.services.tailscaled.secrets.auth-key.decrypted.path;
    # NOTE: Do NOT set authKeyParameters.preauthorized. Pre-auth keys
    # (tskey-auth-*) have properties baked in at creation. Appending
    # ?preauthorized=true to the key string breaks validation.
  };
}
