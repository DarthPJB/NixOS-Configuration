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

  # PAT for personal repos (shared with hate-filled runners)
  patTokenFile = config.secrix.system.secrets.hate-filled-generator.decrypted.path;
in
{

  services.github-runners = {
    disgust = {
      enable = true;
      name = "disgust";
      package = pkgs_llm.github-runner;
      tokenFile = patTokenFile;
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
      replace = true;
      serviceOverrides = baremetalOverrides;
    };
    rat-infested = {
      enable = true;
      name = "rat-infested";
      package = pkgs_llm.github-runner;
      tokenFile = patTokenFile;
      url = "https://github.com/DarthPJB/ratty";
      replace = true;
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

  # Org runner token (Bargman-Tech — not changed)
  secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.encrypted.file =
    "${self}/secrets/github_org_runner_token";
}
