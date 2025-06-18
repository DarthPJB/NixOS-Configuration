{ config, pkgs, self, ... }:
{

  services.github-runners = {
    disgust = {
      enable = true;
      name = "disgust";
      tokenFile = "${config.secrix.services.github-runner-disgust.secrets.github_runner_token.decrypted.path}";
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
    };
  };
  secrix.services.github-runner-disgust.secrets.github_runner_token.encrypted.file = "${self}/secrets/github_runner_token";
}
