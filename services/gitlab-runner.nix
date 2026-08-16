# services/gitlab-runner.nix
# GitHub Actions self-hosted runners for remote-builder.
#
# Runner groups:
#   disgust           — DarthPJB/parsec-gaming-nix (PAT)
#   rat-infested      — DarthPJB/ratty (PAT)
#   entropy-is-origin — Bargman-Tech org (org runner token, gitlab-aware)
#   hate-filled       — DarthPJB/NixOS-Configuration (PAT, gitlab-aware, eval cache)
#
# GitLab auth: netrc from gitlab-credentials.nix, passed via GIT_ASKPASS.
# All runners share the nix-daemon and store — builds dispatch to hyperhyper/arm-builder.
{ config, lib, pkgs, self, pkgs_llm, ... }:
let
  # GitLab netrc — user-readable copy from gitlab-credentials.nix
  gitlabNetrcPath = "/run/gitlab-netrc";

  # GIT_ASKPASS script — runner uses DynamicUser, doesn't inherit session variables
  gitlabAskpass = pkgs.writeShellApplication {
    name = "gitlab-askpass";
    runtimeInputs = [ pkgs.gnused ];
    text = ''
      case "$1" in
        *Username*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login[[:space:]]*//p' "${gitlabNetrcPath}" ;;
        *Password*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password[[:space:]]*//p' "${gitlabNetrcPath}" ;;
      esac
    '';
  };

  # PAT for personal repos (shared across disgust, rat-infested, hate-filled)
  patTokenFile = config.secrix.system.secrets.hate-filled-generator.decrypted.path;

  # Inline runner factory — generates N concurrent runner instances.
  # Uses the vanilla nixpkgs github-runner module, PAT-based auth (replace = true).
  mkRunners =
    { namePrefix
    , url
    , tokenFile
    , count
    , extraLabels ? [ ]
    , extraEnvironment ? { }
    , extraServiceOverrides ? { }
    , gitlabNetrcPath' ? null
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
            BindReadOnlyPaths = [ "/nix" ] ++ lib.optional (gitlabNetrcPath' != null) gitlabNetrcPath';
            # Writable bind mount for eval cache and flake input cache
            BindPaths = [ "/nix/cache" ];
          } // extraServiceOverrides;
        };
      };
    in
    builtins.foldl' (a: b: a // b) { } (map mkInstance (lib.range 1 count));
in
{
  services.github-runners =
    # disgust — DarthPJB/parsec-gaming-nix
    (mkRunners {
      namePrefix = "disgust";
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
      tokenFile = patTokenFile;
      count = 1;
      extraLabels = [ "self-hosted" ];
    }) //
    # rat-infested — DarthPJB/ratty
    (mkRunners {
      namePrefix = "rat-infested";
      url = "https://github.com/DarthPJB/ratty";
      tokenFile = patTokenFile;
      count = 1;
      extraLabels = [ "self-hosted" ];
    }) //
    # entropy-is-origin — Bargman-Tech org (org runner token, gitlab-aware)
    (mkRunners {
      namePrefix = "entropy-is-origin";
      url = "https://github.com/Bargman-Tech";
      tokenFile = config.secrix.system.secrets.github_org_runner_token.decrypted.path;
      count = 1;
      extraLabels = [ "self-hosted" ];
      extraEnvironment = { GIT_ASKPASS = lib.getExe gitlabAskpass; };
      gitlabNetrcPath' = gitlabNetrcPath;
    }) //
    # hate-filled — DarthPJB/NixOS-Configuration (gitlab-aware + eval cache)
    (mkRunners {
      namePrefix = "hate-filled";
      url = "https://github.com/DarthPJB/NixOS-Configuration";
      tokenFile = patTokenFile;
      count = 2;
      extraLabels = [ "self-hosted" ];
      extraEnvironment = {
        GIT_ASKPASS = lib.getExe gitlabAskpass;
        # Persist eval cache and flake input cache across jobs.
        # Runner HOME is tmpfs (/run/github-runner/...) — ephemeral.
        # /nix/cache survives reboots and is on the 295GB store disk.
        NIX_CACHE_HOME = "/nix/cache";
      };
      gitlabNetrcPath' = gitlabNetrcPath;
    });

  # PAT for runner registration — system secret (decrypted at boot to /run/system-keys/)
  secrix.system.secrets.hate-filled-generator.encrypted.file =
    "${self}/secrets/hate-filled-generator";

  # Org runner token for Bargman-Tech (entropy-is-origin)
  secrix.system.secrets.github_org_runner_token.encrypted.file =
    "${self}/secrets/github_org_runner_token";

  # Ensure /nix/cache exists and is writable by the build user.
  systemd.tmpfiles.rules = [
    "d /nix/cache 0755 build users - -"
  ];

  # Ensure gitlab-netrc is available before netrc-dependent runners start.
  # gitlab-netrc-copy runs before nix-daemon, but runners don't explicitly
  # depend on it — only on nix-daemon (via store). This closes the race.
  systemd.services = builtins.listToAttrs (map
    (name: {
      name = "github-runner-${name}";
      value = { after = lib.mkAfter [ "gitlab-netrc-copy.service" ]; };
    })
    [ "hate-filled-1" "hate-filled-2" "entropy-is-origin-1" ]
  );
}
