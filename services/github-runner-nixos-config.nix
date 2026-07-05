# GitHub Actions self-hosted runner for DarthPJB/NixOS-Configuration
# Deployed on LINDA — Threadripper 3960X (48c), 125GiB RAM, 175GiB swap
# Moved from remote-builder (VPS) after repeated OOM kills during nix flake check
{ config
, pkgs
, self
, pkgs_llm
, ...
}:
let
  # Netrc file for GitLab authentication (managed by secrix)
  gitlabNetrcPath = config.secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.decrypted.path;

  # GIT_ASKPASS script that reads credentials from netrc file
  gitlabAskpass = pkgs.writeShellScript "gitlab-askpass" ''
    case "$1" in
      *Username*)
        exec ${pkgs.gnused}/bin/sed -n 's/^login[[:space:]]*//p' "${gitlabNetrcPath}"
        ;;
      *Password*)
        exec ${pkgs.gnused}/bin/sed -n 's/^password[[:space:]]*//p' "${gitlabNetrcPath}"
        ;;
    esac
  '';
in
{
  services.github-runners.hate-filled = {
    enable = true;
    name = "hate-filled";
    package = pkgs_llm.github-runner;
    tokenFile = "${config.secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.decrypted.path}";
    url = "https://github.com/DarthPJB/NixOS-Configuration";

    # GitLab authentication for private flake inputs
    extraEnvironment = {
      GIT_ASKPASS = "${gitlabAskpass}";
    };
    extraLabels = [ "self-hosted" ];
    serviceOverrides = {
      BindReadOnlyPaths = [ gitlabNetrcPath ];
    };
  };

  secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.encrypted.file =
    "${self}/secrets/github_runner_token_3";

  secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.encrypted.file =
    "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
}
