# services/gitlab-runner.nix
# GitHub Actions self-hosted runners for remote-builder.
#
# Runner groups:
#   disgust — DarthPJB/parsec-gaming-nix (PAT)
#
# Removed 2026-11-19 (user ruling): rat-infested, entropy-is-origin,
# hate-filled — registrations were purged server-side after 14 days offline
# and could not be revived by restart; the dead stand down.
#
# GitLab auth: netrc from gitlab-credentials.nix (nix-daemon side).
# All runners share the nix-daemon and store — builds dispatch to hyperhyper/arm-builder.
{ config, lib, self, pkgs_llm, ... }:
let
  # PAT for runner registration (disgust)
  patTokenFile = config.secrix.system.secrets.hate-filled-generator.decrypted.path;

  # Inline runner factory — generates N concurrent runner instances.
  # Uses the vanilla nixpkgs github-runner module, PAT-based auth (replace = true).
  mkRunners =
    { namePrefix
    , url
    , tokenFile
    , count
    , extraLabels ? [ ]
    , extraEnvironment ? { }
    , extraServiceOverrides ? { }
    , gitlabNetrcPath' ? null
    , package ? pkgs_llm.github-runner
    }:
    let
      mkInstance = i: {
        "${namePrefix}-${toString i}" = {
          enable = true;
          name = "${namePrefix}-${toString i}";
          inherit package url tokenFile;
          replace = true;
          extraLabels = extraLabels ++ [ "runner-${toString i}" ];
          extraEnvironment = extraEnvironment;
          serviceOverrides = {
            # Baremetal runner on trusted VPN — share host's nix store
            PrivateMounts = false;
            DynamicUser = false;
            User = "build";
            ProtectSystem = false;
            BindReadOnlyPaths = [ "/nix" ] ++ lib.optional (gitlabNetrcPath' != null) gitlabNetrcPath';
            # Writable bind mount for eval cache and flake input cache
            BindPaths = [ "/nix/cache" ];
          } // extraServiceOverrides;
        };
      };
    in
    builtins.foldl' (a: b: a // b) { } (map mkInstance (lib.range 1 count));
in
{
  services.github-runners =
    # disgust — DarthPJB/parsec-gaming-nix
    (mkRunners {
      namePrefix = "disgust";
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
      tokenFile = patTokenFile;
      count = 1;
      extraLabels = [ "self-hosted" ];
    });

  # PAT for runner registration — system secret (decrypted at boot to /run/system-keys/)
  secrix.system.secrets.hate-filled-generator.encrypted.file =
    "${self}/secrets/hate-filled-generator";

  # Ensure /nix/cache exists and is writable by the build user.
  systemd.tmpfiles.rules = [
    "d /nix/cache 0755 build users - -"
  ];
}
