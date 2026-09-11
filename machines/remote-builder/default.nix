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
    (import ../../services/acme_server.nix { fqdn = "cache.johnbargman.net"; })
  ];
  # Nix binary cache — open port 5001 on WAN
  # Ports 80/443 for nginx TLS termination (ACME + HTTPS cache)
  networking.firewall.allowedTCPPorts = [ 80 443 5001 ];

  # TLS termination for cache.johnbargman.net → nix-serve on localhost:5001
  services.nginx = {
    enable = true;
    virtualHosts."cache.johnbargman.net" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://127.0.0.1:5001";
    };
  };

  # Virtual disk devices — smartctl/smartd not applicable
  services.smartd.enable = lib.mkForce false;
  services.prometheus.exporters.smartctl.enable = lib.mkForce false;

  enableWgTopology.enable = true;

  # Build-runner hub: never build locally, distribute all builds to
  # hyperhyper (x86_64-linux) and arm-builder (aarch64-linux).
  nix.settings.max-jobs = 0;

  # This machine IS the cache. Never garbage-collect — retain all closures.
  # Both NixOS nix.gc and Determinate Nixd's managed GC must be disabled.
  nix.gc.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce true;

  # Disable Determinate Nixd's managed garbage collection.
  # Without this, determinate-nixd runs its own GC every ~2 hours and deletes
  # store paths whose GC roots are "stale" (e.g. CI runner ./result symlinks
  # in ephemeral /run/github-runner/ directories). This was the root cause of
  # paths being re-copied on every CI run.
  environment.etc."determinate/config.json".text = builtins.toJSON {
    garbageCollector.strategy = "disabled";
  };

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
