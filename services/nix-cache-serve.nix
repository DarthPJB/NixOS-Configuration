# services/nix-cache-serve.nix
# Nix binary cache server — serves signed /nix/store paths over plain HTTP.
# TLS termination is handled by cortex-alpha's nginx reverse proxy.
# Matches the infrastructure-2 pattern (services/nix-cache-serve.nix on hyperhyper).

{ config, lib, self, ... }:
{
  # HTTP binary cache server
  services.nix-serve = {
    enable = true;
    secretKeyFile = config.secrix.services.nix-serve.secrets.cache-priv-key.decrypted.path;
    bindAddress = "10.88.127.51";   # WireGuard IP only — not reachable from public internet
    port = 5001;
  };

  # Sign locally-built derivations with the cache key so they can be served
  nix.settings.secret-key-files = [
    config.secrix.services.nix-serve.secrets.cache-priv-key.decrypted.path
  ];

  # Secrix: decrypt signing key at runtime
  secrix.services.nix-serve.secrets.cache-priv-key.encrypted.file =
    "${self}/secrets/cache-priv-key";
}
