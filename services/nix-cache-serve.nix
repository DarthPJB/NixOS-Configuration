# services/nix-cache-serve.nix
# Nix binary cache server — serves signed /nix/store paths over plain HTTP.
# TLS termination is handled by cortex-alpha's nginx reverse proxy.
# Matches the infrastructure-2 pattern (services/nix-cache-serve.nix on hyperhyper).

{ config, lib, pkgs, self, ... }:
{
  # HTTP binary cache server
  services.nix-serve = {
    enable = true;
    secretKeyFile = config.secrix.services.nix-serve.secrets.cache-priv-key.decrypted.path;
    bindAddress = "0.0.0.0";
    port = 5001;

    # The stock psgi calls the deprecated `nix dump-path` spelling, which warns
    # on every request. Use the modern `nix store dump-path`.
    package = pkgs.nix-serve.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace nix-serve.psgi \
          --replace-fail '"dump-path"' '"store", "dump-path"'
      '';
    });
  };

  # nix-serve's CLI is pinned to nixpkgs' `nix`, which cannot parse the
  # Determinate-owned /etc/nix/nix.conf and warns 'unknown setting' on every
  # request. Point it at a config carrying only our own nix.custom.conf
  # (substituters, keys, sandbox policy) — everything the CLI needs, without
  # the Determinate-only keys it cannot read.
  environment.etc."nix-serve/nix.conf".text = ''
    !include /etc/nix/nix.custom.conf
  '';
  systemd.services.nix-serve.environment.NIX_CONF_DIR = "/etc/nix-serve";

  # Sign locally-built derivations with the cache key so they can be served
  nix.settings.secret-key-files = [
    config.secrix.services.nix-serve.secrets.cache-priv-key.decrypted.path
  ];

  # Secrix: decrypt signing key at runtime
  secrix.services.nix-serve.secrets.cache-priv-key.encrypted.file =
    "${self}/secrets/cache-priv-key";
}
