# lib/mkRunner.nix
# Factory function for generating N concurrent GitHub Actions self-hosted runners.
#
# Uses the vanilla nixpkgs github-runner module — no custom ExecStartPre override.
# PAT-based authentication handles re-registration (replace = true).
#
# Usage:
#   mkRunner {
#     namePrefix = "hate-filled";
#     url = "https://github.com/DarthPJB/NixOS-Configuration";
#     tokenFile = config.secrix.services.github-runner-hate-filled.secrets.pat.decrypted.path;
#     count = 5;
#     extraLabels = [ "self-hosted" ];
#     extraEnvironment = { GIT_ASKPASS = "..."; };
#     gitlabNetrcPath = "/run/secrets/gitlab-netrc";  # optional
#   }
#
# Returns: attrset of runner definitions for services.github-runners
{ config, lib, pkgs, self, pkgs_llm }:

{ namePrefix
, url
, tokenFile
, count
, extraLabels ? [ ]
, extraEnvironment ? { }
, extraServiceOverrides ? { }
, gitlabNetrcPath ? null
, package ? pkgs_llm.github-runner
}:

let
  mkInstance = i: {
    "${namePrefix}-${toString i}" = {
      enable = true;
      name = "${namePrefix}-${toString i}";
      inherit package url tokenFile;
      replace = true;
      extraLabels = extraLabels ++ [ "runner-${toString i}" ];
      extraEnvironment = extraEnvironment;
      serviceOverrides = {
        # Baremetal runner on trusted VPN — share host's nix store
        PrivateMounts = false;
        DynamicUser = false;
        User = "build";
        ProtectSystem = false;
        BindReadOnlyPaths = [ "/nix" ] ++ lib.optional (gitlabNetrcPath != null) gitlabNetrcPath;
      } // extraServiceOverrides;
    };
  };
in
builtins.foldl' (a: b: a // b) { } (map mkInstance (lib.range 1 count))
