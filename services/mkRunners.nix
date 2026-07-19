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

  # GitLab netrc path (system secret, decrypted at boot)
  gitlabNetrcPath = config.secrix.system.secrets.gitlab_netrc.decrypted.path;

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
    count = 5;
    extraLabels = [ "self-hosted" ];
    extraEnvironment = { GIT_ASKPASS = "${gitlabAskpass}"; };
    gitlabNetrcPath = gitlabNetrcPath;
  };

  # PAT for runner registration — system secret (decrypted at boot to /run/system-keys/)
  secrix.system.secrets.hate-filled-generator.encrypted.file =
    "${self}/secrets/hate-filled-generator";
}
