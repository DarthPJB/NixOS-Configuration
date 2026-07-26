# GitHub Actions self-hosted runner for DarthPJB/NixOS-Configuration
# Deployed on LINDA — Threadripper 3960X (48c), 125GiB RAM, 175GiB swap
# Moved from remote-builder (VPS) after repeated OOM kills during nix flake check
#
# OVERRIDE: ExecStartPre preserves .credentials and .runner across reboots and
# config changes. Registration tokens are single-use — we never re-run configure
# if the runner is already registered.
#
# See: documentation/2026-07-09-GITHUB-RUNNER-REVIEW/bellana-deepseek-REVIEW-2026-07-09.md
# See: documentation/plans/github-runner-custom-module-2026-07-09.md
{ config
, lib
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
        exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login[[:space:]]*//p' "${gitlabNetrcPath}"
        ;;
      *Password*)
        exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password[[:space:]]*//p' "${gitlabNetrcPath}"
        ;;
    esac
  '';

  # ────────────────────────────────────────────────────────────────────
  # Service identity (must match the attribute name below)
  # ────────────────────────────────────────────────────────────────────
  name = "hate-filled";
  svcName = "github-runner-${name}";
  systemdDir = "github-runner/${name}";

  # Derived directories (systemd specifiers — expanded at runtime)
  stateDir = "%S/${systemdDir}"; # /var/lib/github-runner/hate-filled
  logsDir = "%L/${systemdDir}"; # /var/log/github-runner/hate-filled
  workDir = "%t/${systemdDir}"; # /run/github-runner/hate-filled

  # Helper to create the three ExecStartPre scripts
  writeScript = scriptName: body:
    pkgs.writeShellScript "${svcName}-${scriptName}.sh" ''
      set -euo pipefail
      STATE_DIRECTORY="$1"
      WORK_DIRECTORY="$2"
      LOGS_DIRECTORY="$3"
      ${body}
    '';

  # ────────────────────────────────────────────────────────────────────
  # Script 1: unconfigure (PRESERVE registration)
  # ────────────────────────────────────────────────────────────────────
  # If .credentials AND .runner exist → skip all reconfiguration.
  # Only clean the work directory (ephemeral job data).
  #
  # Otherwise (first install) → copy registration token for configure step.
  unconfigureRunner = writeScript "unconfigure" ''
    if [[ -f "$STATE_DIRECTORY/.credentials" && -f "$STATE_DIRECTORY/.runner" ]]; then
      echo "${svcName}: Runner already registered — preserving credentials and skipping reconfiguration."
    else
      echo "${svcName}: No existing registration found — preparing first-time configuration."
      install --mode=666 ${lib.escapeShellArg (
        config.secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.decrypted.path
      )} "$STATE_DIRECTORY/.new-token"
      install --mode=600 ${lib.escapeShellArg (
        config.secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.decrypted.path
      )} "$STATE_DIRECTORY/.current-token"
    fi
    # Always clean work directory (transient job data, never credentials)
    find -H "$WORK_DIRECTORY" -mindepth 1 -delete 2>/dev/null || true
  '';

  # ────────────────────────────────────────────────────────────────────
  # Script 2: configure (IDENTICAL to nixpkgs)
  # ────────────────────────────────────────────────────────────────────
  # Only runs if .new-token was created by unconfigure.
  # Registers the runner, moves _diag to logs dir, cleans up token.
  inherit (config.services.github-runners.hate-filled)
    url extraLabels runnerGroup replace noDefaultLabels ephemeral package;
  configureRunner = writeScript "configure" ''
    if [[ -e "$STATE_DIRECTORY/.new-token" ]]; then
      echo "Configuring GitHub Actions Runner"
      # shellcheck disable=SC2054  # don't complain about commas in --labels
      args=(
        --unattended
        --disableupdate
        --work "$WORK_DIRECTORY"
        --url ${lib.escapeShellArg url}
        --labels ${lib.escapeShellArg (lib.concatStringsSep "," extraLabels)}
        ${lib.optionalString (name != null) "--name ${lib.escapeShellArg name}"}
        ${lib.optionalString replace "--replace"}
        ${lib.optionalString (runnerGroup != null) "--runnergroup ${lib.escapeShellArg runnerGroup}"}
        ${lib.optionalString ephemeral "--ephemeral"}
        ${lib.optionalString noDefaultLabels "--no-default-labels"}
      )
      # Detect token type: PAT (ghp_* / github_pat_*) vs registration token
      token=$(<"$STATE_DIRECTORY/.new-token")
      if [[ "$token" =~ ^ghp_* ]] || [[ "$token" =~ ^github_pat_* ]]; then
        args+=(--pat "$token")
      else
        args+=(--token "$token")
      fi
      ${package}/bin/Runner.Listener configure "''${args[@]}"
      # Move the automatically created _diag dir to the logs dir
      mkdir -p  "$STATE_DIRECTORY/_diag"
      cp    -r  "$STATE_DIRECTORY/_diag/." "$LOGS_DIRECTORY/"
      rm    -rf "$STATE_DIRECTORY/_diag/"
      # Cleanup token file
      rm "$STATE_DIRECTORY/.new-token"
    fi
  '';

  # ────────────────────────────────────────────────────────────────────
  # Script 3: setupWorkDir (IDENTICAL to nixpkgs)
  # ────────────────────────────────────────────────────────────────────
  # Links _diag and credentials into the work directory.
  runnerCredFiles = [ ".credentials" ".credentials_rsaparams" ".runner" ];
  setupWorkDir = writeScript "setup-work-dirs" ''
    # Link _diag dir
    ln -s "$LOGS_DIRECTORY" "$WORK_DIRECTORY/_diag"
    # Link the runner credentials to the work dir
    ln -s "$STATE_DIRECTORY"/{${lib.concatStringsSep "," runnerCredFiles}} "$WORK_DIRECTORY/"
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

    # ─── SERVICE OVERRIDES ──────────────────────────────────────────
    serviceOverrides = {
      # Existing: expose GitLab netrc for git authentication
      BindReadOnlyPaths = [ gitlabNetrcPath ];

      # OVERRIDE: Preserve runner registration across reboots
      # The nixpkgs default ExecStartPre wipes .credentials/.runner on
      # every config change. With registration tokens (single-use), this
      # breaks the runner irrecoverably.
      ExecStartPre = lib.mkForce (
        map (x: "${x} ${lib.escapeShellArgs [ stateDir workDir logsDir ]}") [
          "+${unconfigureRunner}" # runs as root (preserves credentials)
          configureRunner # runs as dynamic user
          setupWorkDir # runs as dynamic user
        ]
      );
    };
  };

  secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.encrypted.file =
    "${self}/secrets/github_runner_token_3";

  secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.encrypted.file =
    "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
}
