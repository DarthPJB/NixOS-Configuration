# services/mkRunners.nix
# Scalable GitHub Actions runner deployment using mkRunner factory.
#
# Generates N concurrent runners for the NixOS-Configuration CI pipeline.
# All runners share the nix-daemon and store — builds dispatch to hyperhyper/arm-builder.
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
      *Username*) exec ${pkgs.gnused}/bin/sed -n 's/^login[[:space:]]*//p' "${gitlabNetrcPath}" ;;
      *Password*) exec ${pkgs.gnused}/bin/sed -n 's/^password[[:space:]]*//p' "${gitlabNetrcPath}" ;;
    esac
  '';
in
{
  services.github-runners = mkRunner {
    namePrefix = "hate-filled";
    url = "https://github.com/DarthPJB/NixOS-Configuration";
    tokenFile = config.secrix.system.secrets.hate-filled-generator.decrypted.path;
    count = 1;
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
  };

  # PAT for runner registration — system secret (decrypted at boot to /run/system-keys/)
  secrix.system.secrets.hate-filled-generator.encrypted.file =
    "${self}/secrets/hate-filled-generator";

  # Ensure /nix/cache exists and is writable by the build user.
  # This persists eval-cache and flake input cache across CI jobs.
  systemd.tmpfiles.rules = [
    "d /nix/cache 0755 build users - -"
  ];
}
