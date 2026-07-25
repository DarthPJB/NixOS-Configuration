# bellana-deepseek Review: github-runner ExecStartPre Override

**Date:** 2026-07-09
**Reviewer:** bellana-deepseek (opencode-go/deepseek-v4-flash)
**Scope:** Complete Nix implementation for `serviceOverrides.ExecStartPre` override

---

## Problem Analysis

**Root cause:** The nixpkgs `github-runner` module's `ExecStartPre` destroys the runner's `.credentials` and `.runner` files on every config change via its `diff_config` mechanism. When using **registration tokens** (the correct approach — PATs are wrong), this is catastrophic because:

1. Registration tokens are **single-use** — once consumed by `Runner.Listener configure`, they cannot be reused
2. On config change, `diff_config` detects the token file changed (because the secrix decrypted path or token value differs), calls `clean_state()` which wipes `.credentials` and `.runner`
3. The next `configure` attempt fails because the registration token is already spent
4. The runner must be manually removed from GitHub UI and re-registered with a fresh token

**Why PATs aren't the answer:**
- PATs have broad scope (admin:org, repo, workflow)
- Registration tokens are scoped to runner registration only
- Using PATs is a **security regression**
- The nixpkgs module's token-type detection (`ghp_*` / `github_pat_*` prefixes) is a workaround for a design flaw

**The fix:** Override `ExecStartPre` to check for existing `.credentials` and `.runner` files. If they exist, **do nothing** — the runner is already registered. Only copy the token and run `configure` on first install.

---

## Implementation: Complete Nix Override

The following code replaces the `serviceOverrides` block in `services/github-runner-nixos-config.nix`. It adds the `ExecStartPre` override while preserving the existing `BindReadOnlyPaths`.

### Complete `github-runner-nixos-config.nix`

```nix
# GitHub Actions self-hosted runner for DarthPJB/NixOS-Configuration
# Deployed on LINDA — Threadripper 3960X (48c), 125GiB RAM, 175GiB swap
# Moved from remote-builder (VPS) after repeated OOM kills during nix flake check
#
# OVERRIDE: ExecStartPre preserves .credentials and .runner across reboots and
# config changes. Registration tokens are single-use — we never re-run configure
# if the runner is already registered.
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
        exec ${pkgs.gnused}/bin/sed -n 's/^login[[:space:]]*//p' "${gitlabNetrcPath}"
        ;;
      *Password*)
        exec ${pkgs.gnused}/bin/sed -n 's/^password[[:space:]]*//p' "${gitlabNetrcPath}"
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
  stateDir = "%S/${systemdDir}";   # /var/lib/github-runner/hate-filled
  logsDir  = "%L/${systemdDir}";   # /var/log/github-runner/hate-filled
  workDir  = "%t/${systemdDir}";   # /run/github-runner/hate-filled

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
          "+${unconfigureRunner}"   # runs as root (preserves credentials)
          configureRunner            # runs as dynamic user
          setupWorkDir               # runs as dynamic user
        ]
      );
    };
  };

  secrix.services.github-runner-hate-filled.secrets.github_runner_token_3.encrypted.file =
    "${self}/secrets/github_runner_token_3";

  secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.encrypted.file =
    "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
}
```

---

## What Changed vs. nixpkgs Original

### `unconfigureRunner` — The Critical Change

**nixpkgs original** (broken for registration tokens):
```bash
# Destroys everything on config/token change
diff_config() {
  changed=0
  diff -q config.json current-config.json || changed=1
  diff -q token current-token || changed=1
  if [[ changed -eq 1 ]]; then
    clean_state  # ← DELETES .credentials AND .runner
  fi
}
```

**Override** (preserves registration):
```bash
if [[ -f .credentials && -f .runner ]]; then
  # Already registered — skip everything
else
  # First install — copy token for configure
  install --mode=666 token .new-token
fi
```

### `configureRunner` — Unchanged
Copied verbatim from nixpkgs. Runs `Runner.Listener configure` with the same arguments, same PAT/registration-token detection, same `_diag` handling.

### `setupWorkDir` — Unchanged
Copied verbatim from nixpkgs. Creates `_diag` and credentials symlinks in work directory.

---

## Behavior Matrix

| Scenario | `.credentials` / `.runner` exist? | What happens |
|---|---|---|
| **First install** | No | Token copied → configure runs → registration succeeds |
| **Reboot** | Yes (state dir persists) | Skipped — credentials preserved |
| **Config change (ports, labels, etc.)** | Yes | Skipped — credentials preserved |
| **nixpkgs upgrade** | Yes | Skipped — credentials preserved |
| **Token rotation (new .token file)** | Yes | Skipped — existing registration is valid |
| **Manual credential removal** | No | Token copied → re-registration |
| **Ephemeral mode** | N/A (handled by nixpkgs `Restart=on-success`) | Works same as original |

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| **Config changes don't take effect** (e.g., new labels, changed URL) | Runner must be manually re-registered: `rm .credentials .runner` on the host, then restart the service |
| **Expired registration** (credentials become invalid) | Runner will fail at job time — same as before. Must re-register with fresh token |
| **nixpkgs module updates change configure/setupWorkDir semantics** | Periodically diff our copies against upstream. The `inherit` bindings auto-track the config options but the script bodies are static copies |
| **Multiple github-runner instances** | The code is specific to `hate-filled`. For additional runners, extract the pattern into a shared helper |

---

## Verification Steps

After deploying, verify the override is active:

```bash
# Check the ExecStartPre commands
systemctl cat github-runner-hate-filled | grep ExecStartPre

# Expected: 3 lines — unconfigure (with + prefix), configure, setup-work-dirs
# NOT the nixpkgs originals

# Confirm credentials are preserved after reboot/restart
ls -la /var/lib/github-runner/hate-filled/.credentials
ls -la /var/lib/github-runner/hate-filled/.runner

# Check service status
systemctl status github-runner-hate-filled
journalctl -u github-runner-hate-filled --no-pager | grep -i "already registered"
```

---

## Maintenance Note

If nixpkgs changes the configure or setupWorkDir scripts (e.g., new CLI flags for `Runner.Listener configure`), this override will be out of date. Monitor for changes in:

```
nixpkgs/nixos/modules/services/continuous-integration/github-runner/service.nix
```

And diff against our copies when upgrading nixpkgs.
