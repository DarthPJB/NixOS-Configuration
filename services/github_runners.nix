{ config
, pkgs
, self
, pkgs_llm
, ...
}:
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
  secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.encrypted.file =
    "${self}/secrets/github_org_runner_token";
}
