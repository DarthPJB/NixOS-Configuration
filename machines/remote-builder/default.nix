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
    # ../../configuration.nix — already in commonModules (flake.nix), do not duplicate
    ../../users/darthpjb.nix
    ../../modifier_imports/flakes.nix
    ../../environments/sshd.nix
    ../../environments/tools.nix
    ../../services/dynamic_domain_gandi.nix
    ../../services/github_runners.nix
    ../../services/mkRunners.nix
    ../../services/gitlab-credentials.nix
    ../../modifier_imports/remote-builder.nix
    ../../users/build.nix
    ../../modules/enable-wg-topology.nix
    ../../locale/tailscale.nix
  ];
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

  # Tailscale: direct connection to hyperhyper (replaces WireGuard proxy route)
  secrix.services.tailscaled.secrets.auth-key.encrypted.file =
    ../../secrets/tailscale_auth_key;
  services.tailscale = {
    authKeyFile = config.secrix.services.tailscaled.secrets.auth-key.decrypted.path;
    authKeyParameters.preauthorized = true;
  };
}
