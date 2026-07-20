{ config
, pkgs
, self
, pkgs_llm
, lib
, ...
}:
let
  # Baremetal runner service overrides — share host nix store
  baremetalOverrides = {
    PrivateMounts = false;
    DynamicUser = false;
    User = "build";
    ProtectSystem = false;
    BindReadOnlyPaths = [ "/nix" ];
  };
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
      serviceOverrides = baremetalOverrides;
    };
    rat-infested = {
      enable = true;
      name = "rat-infested";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-rat-infested.secrets.github_runner_token_2.decrypted.path
      }";
      url = "https://github.com/DarthPJB/ratty";
      serviceOverrides = baremetalOverrides;
    };
    entropy-is-origin = {
      enable = true;
      name = "entropy-is-origin";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.decrypted.path
      }";
      url = "https://github.com/Bargman-Tech";
      serviceOverrides = baremetalOverrides;
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
