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
  # Git invokes this with the prompt as $1 (e.g., "Username for 'https://gitlab.com': ")
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
  services.github-runners = {
    disgust = {
      enable = true;
      name = "disgust";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-disgust.secrets.github_runner_token.decrypted.path
      }";
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
    };
    rat-infested = {
      enable = true;
      name = "rat-infested";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-rat-infested.secrets.github_runner_token_2.decrypted.path
      }";
      url = "https://github.com/DarthPJB/ratty";
    };
    hate-filled = {
      enable = true;
      name = "hate-filled";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.decrypted.path
      }";
      url = "https://github.com/DarthPJB/NixOS-Configuration";

      # GitLab authentication for private flake inputs
      # The GIT_ASKPASS script reads from /run/github-runner-hate-filled-keys/gitlab_netrc
      # which is placed there by the keys service.
      # BindReadOnlyPaths (capital B) mounts it into the service's PrivateMounts namespace.
      # The NixOS systemd module passes attribute names verbatim (systemd-lib.nix:339).
      # NOTE: serviceOverrides is NOT part of the config JSON hash (runnerRegistrationConfig),
      # so changing this will NOT trigger runner re-registration.
      extraEnvironment = {
        GIT_ASKPASS = "${gitlabAskpass}";
      };
      extraLabels = [ "self-hosted" ];
      serviceOverrides = {
        BindReadOnlyPaths = [ gitlabNetrcPath ];
      };
    };
    entropy-is-origin = {
      enable = true;
      name = "entropy-is-origin";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.decrypted.path
      }";
      url = "https://github.com/Bargman-Tech";
    };
  };

  # Existing runner token secrets
  secrix.services.github-runner-disgust.secrets.github_runner_token.encrypted.file =
    "${self}/secrets/github_runner_token";
  secrix.services.github-runner-rat-infested.secrets.github_runner_token_2.encrypted.file =
    "${self}/secrets/github_runner_token_2";
  secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.encrypted.file =
    "${self}/secrets/github_runner_token_3";
  secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.encrypted.file =
    "${self}/secrets/github_org_runner_token";

  # GitLab deploy token for private flake inputs
  secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.encrypted.file =
    "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
}
