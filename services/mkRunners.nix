# services/mkRunners.nix
# Scalable GitHub Actions runner deployment using mkRunner factory.
#
# Generates N concurrent runners for the NixOS-Configuration CI pipeline.
# All runners share the nix-daemon and store — builds dispatch to hyperhyper/arm-builder.
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

  # GitLab authentication for private flake inputs
  gitlabNetrcPath = config.secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.decrypted.path;
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
    tokenFile = config.secrix.services.github-runner-hate-filled.secrets.hate-filled-generator.decrypted.path;
    count = 5;
    extraLabels = [ "self-hosted" ];
    extraEnvironment = { GIT_ASKPASS = "${gitlabAskpass}"; };
    gitlabNetrcPath = gitlabNetrcPath;
  };

  # PAT for runner registration (shared by all instances)
  secrix.services.github-runner-hate-filled.secrets.hate-filled-generator.encrypted.file =
    "${self}/secrets/hate-filled-generator";

  # GitLab netrc for private flake inputs
  secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.encrypted.file =
    "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
}
