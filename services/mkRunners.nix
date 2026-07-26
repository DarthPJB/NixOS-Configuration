# services/mkRunners.nix
# Unified GitHub Actions runner deployment using mkRunner factory.
#
# All runners share the nix-daemon and store — builds dispatch to hyperhyper/arm-builder.
# Each runner group targets a specific repository with its own token and environment.
#
# Runner groups:
#   disgust          — DarthPJB/parsec-gaming-nix (PAT, no gitlab)
#   rat-infested     — DarthPJB/ratty (PAT, no gitlab)
#   entropy-is-origin — Bargman-Tech org (org runner token, gitlab-aware)
#   hate-filled      — DarthPJB/NixOS-Configuration (PAT, gitlab-aware, eval cache)
#
# GitLab auth: system secret from gitlab-credentials.nix, passed to mkRunner as runtime path.
#
# See: lib/mkRunner.nix for the factory function
# See: documentation/mkrunner-PLAN.md for design rationale
{ config
, lib
, pkgs
, self
, pkgs_llm
, ...
}:
let
  mkRunner = import ../lib/mkRunner.nix { inherit config lib pkgs self pkgs_llm; };

  # GitLab netrc — user-readable copy from gitlab-credentials.nix
  gitlabNetrcPath = "/run/gitlab-netrc";

  # GIT_ASKPASS script — runner uses DynamicUser, doesn't inherit session variables
  gitlabAskpass = pkgs.writeShellScript "gitlab-askpass" ''
    case "$1" in
      *Username*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login[[:space:]]*//p' "${gitlabNetrcPath}" ;;
      *Password*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password[[:space:]]*//p' "${gitlabNetrcPath}" ;;
    esac
  '';

  # PAT for personal repos (shared across disgust, rat-infested, hate-filled)
  patTokenFile = config.secrix.system.secrets.hate-filled-generator.decrypted.path;
in
{
  services.github-runners =
    # disgust — DarthPJB/parsec-gaming-nix
    (mkRunner {
      namePrefix = "disgust";
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
      tokenFile = patTokenFile;
      count = 1;
      extraLabels = [ "self-hosted" ];
    }) //
    # rat-infested — DarthPJB/ratty
    (mkRunner {
      namePrefix = "rat-infested";
      url = "https://github.com/DarthPJB/ratty";
      tokenFile = patTokenFile;
      count = 1;
      extraLabels = [ "self-hosted" ];
    }) //
    # entropy-is-origin — Bargman-Tech org (gitlab-aware for private flake inputs)
    (mkRunner {
      namePrefix = "entropy-is-origin";
      url = "https://github.com/Bargman-Tech";
      tokenFile = config.secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.decrypted.path;
      count = 1;
      extraLabels = [ "self-hosted" ];
      extraEnvironment = { GIT_ASKPASS = "${gitlabAskpass}"; };
      gitlabNetrcPath = gitlabNetrcPath;
    }) //
    # hate-filled — DarthPJB/NixOS-Configuration (gitlab-aware + eval cache)
    (mkRunner {
      namePrefix = "hate-filled";
      url = "https://github.com/DarthPJB/NixOS-Configuration";
      tokenFile = patTokenFile;
      count = 2;
      extraLabels = [ "self-hosted" ];
      extraEnvironment = {
        GIT_ASKPASS = "${gitlabAskpass}";
        # Persist eval cache and flake input cache across jobs.
        # Runner HOME is tmpfs (/run/github-runner/...) — ephemeral.
        # /nix/cache survives reboots and is on the 295GB store disk.
        # NIX_CACHE_HOME is the nix-native env var (checked before XDG_CACHE_HOME).
        # Eval cache: /nix/cache/eval-cache-v6/
        NIX_CACHE_HOME = "/nix/cache";
      };
      gitlabNetrcPath = gitlabNetrcPath;
    });

  # PAT for runner registration — system secret (decrypted at boot to /run/system-keys/)
  secrix.system.secrets.hate-filled-generator.encrypted.file =
    "${self}/secrets/hate-filled-generator";

  # Org runner token for Bargman-Tech (entropy-is-origin)
  secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.encrypted.file =
    "${self}/secrets/github_org_runner_token";

  # Ensure /nix/cache exists and is writable by the build user.
  # This persists eval-cache and flake input cache across CI jobs.
  systemd.tmpfiles.rules = [
    "d /nix/cache 0755 build users - -"
  ];
}
