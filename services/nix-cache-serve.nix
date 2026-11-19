# services/nix-cache-serve.nix
# Nix binary cache server — serves signed /nix/store paths over plain HTTP.
# TLS termination is split-horizon: cortex-alpha's nginx (internal/WG clients)
# and remote-builder's own nginx/ACME (WAN clients) both proxy to :5001.
#
# Served by harmonia (async Rust, actix/tokio) — replaces nix-serve, whose
# Perl/PSGI Prefork model forked a `nix store dump-path` child per NAR
# request behind 5 synchronous workers (the 504 pathology, diagnosed in
# opencode/plans/deploy-validation-2026-11-12.md). Same binary-cache
# protocol, same port, same signing key — drop-in at every client.

{ config, self, ... }:
{
  services.harmonia.cache = {
    enable = true;
    # narinfo signing via systemd LoadCredential (module-wired); the secrix
    # key below is decrypted before harmonia starts and bound to its lifetime.
    signKeyPaths = [ config.secrix.services.harmonia.secrets.cache-priv-key.decrypted.path ];

    settings = {
      # Exact endpoint already targeted by the firewall (5001), cortex-alpha's
      # topology proxy (10.88.127.51:5001) and this host's nginx front
      # (127.0.0.1:5001). IPv4-only, as before.
      bind = "0.0.0.0:5001";
      # nix-serve advertised Priority: 30 in /nix-cache-info; the module
      # default is 50, so pin 30 for byte-identical client-visible behavior.
      priority = 30;
      # Keep this surface minimal: the legal key set is version-sensitive.
    };
  };

  # Sign locally-built derivations with the cache key so they can be served
  nix.settings.secret-key-files = [
    config.secrix.services.harmonia.secrets.cache-priv-key.decrypted.path
  ];

  # Secrix: decrypt the cache signing key at service start; the key exists
  # only for the lifetime of harmonia (harmonia-keys.service is bound to it,
  # re-decrypting on every restart).
  # forceRuntimeDirs: harmonia's module declares RuntimeDirectory as a
  # string ("harmonia" — its HOME); force-merge keeps both directories,
  # with "harmonia" last so HOME survives any unit-rendering semantics.
  secrix.services.harmonia = {
    forceRuntimeDirs = true;
    additionalRuntimeDirNames = [ "harmonia" ];
    secrets.cache-priv-key.encrypted.file = "${self}/secrets/cache-priv-key";
  };
}
