{ config
, pkgs
, self
, unstable
, ...
}:
{
  services.github-runners = {
    disgust = {
      enable = true;
      name = "disgust";
      tokenFile = "${config.secrix.services.github-runner-disgust.secrets.github_runner_token.decrypted.path
      }";
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
    };
    rat-infested = {
      enable = true;
      name = "rat-infested";
      tokenFile = "${config.secrix.services.github-runner-rat-infested.secrets.github_runner_token_2.decrypted.path
      }";
      url = "https://github.com/DarthPJB/ratty";
    };
    hate-filled = {
      enable = true;
      name = "hate-filled";
      tokenFile = "${config.secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.decrypted.path
      }";
      url = "https://github.com/DarthPJB/NixOS-Configuration";
    };
    entropy-is-origin = {
      enable = true;
      name = "entropy-is-origin";
      tokenFile = "${config.secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.decrypted.path
      }";
      url = "https://github.com/Bargman-Tech";
    };
  };
  secrix.services.github-runner-disgust.secrets.github_runner_token.encrypted.file =
    "${self}/secrets/github_runner_token";
  secrix.services.github-runner-rat-infested.secrets.github_runner_token_2.encrypted.file =
    "${self}/secrets/github_runner_token_2";
  secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.encrypted.file =
    "${self}/secrets/github_runner_token_3";
  secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.encrypted.file =
    "${self}/secrets/github_org_runner_token";
}
