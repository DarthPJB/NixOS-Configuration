# Phase I: CI Private Input Authentication

**Date**: 2026-06-26
**Branch**: Current working branch
**Goal**: Enable self-hosted GitHub Actions runners to fetch private GitLab flake inputs
**Status**: In Progress — reviewed by bellana-minimax and bellana-deepseek

## Problem

The NixOS flake has 4 inputs using `git+ssh://` to private GitLab repos. Self-hosted runners on `remote-builder` cannot authenticate because:

1. GitHub Actions runner service has systemd sandboxing (`DynamicUser`, `ProtectHome`, `ProtectSystem`)
2. No SSH keys or credentials are available inside the sandbox
3. `git+ssh://` requires SSH authentication

## Solution: HTTPS + Deploy Token via `GIT_ASKPASS`

Switch all 4 private inputs from `git+ssh://` to `git+https://` and inject a GitLab deploy token via `GIT_ASKPASS` script.

### Why HTTPS over SSH?

- GitLab deploy keys (SSH) require Premium tier for group-level
- Deploy tokens (HTTPS) work on free tier
- Single token covers all repos in `mecha-team-zero` group
- Simpler credential management

### Why `GIT_ASKPASS` over `NETRC`?

Git/libcurl does NOT read the `NETRC` environment variable — that's curl CLI only. Git reads `$HOME/.netrc` by default, but the runner's `HOME` is set to the runtime directory. `GIT_ASKPASS` is natively supported by git, inherited by Nix subprocesses, and widely used in CI environments.

## Phase I.A: Credential Setup (DONE)

- [x] Create GitLab deploy token (`pub-deploy`) with read access to `mecha-team-zero` group
- [x] Encrypt token via secrix: `secrets/ssh_deploy_keys/gitlab_netrc`

**Netrc format** (decrypted content):
```
machine gitlab.com
login pub-deploy
password <deploy-token>
```

## Phase I.B: Update Flake Inputs

Change all 4 private inputs from SSH to HTTPS:

```nix
# BEFORE (SSH)
carmelsite = { url = "git+ssh://git@gitlab.com/mecha-team-zero/carmelsite.git"; };
hype-train-outlaw.url = "git+ssh://git@gitlab.com/mecha-team-zero/macha-orchestration";
bargman-assets = {
  url = "git+ssh://git@gitlab.com/mecha-team-zero/bargman-assets.git?ref=main";
  inputs.nixpkgs.follows = "nixpkgs_stable";
};
denton-glasses.url = "git+ssh://git@gitlab.com/mecha-team-zero/denton-glasses.git";

# AFTER (HTTPS)
carmelsite = { url = "git+https://gitlab.com/mecha-team-zero/carmelsite.git"; };
hype-train-outlaw.url = "git+https://gitlab.com/mecha-team-zero/macha-orchestration";
bargman-assets = {
  url = "git+https://gitlab.com/mecha-team-zero/bargman-assets.git?ref=main";
  inputs.nixpkgs.follows = "nixpkgs_stable";
};
denton-glasses.url = "git+https://gitlab.com/mecha-team-zero/denton-glasses.git";
```

## Phase I.C: Runner Configuration

Update `services/github_runners.nix` to inject credentials via `GIT_ASKPASS`:

```nix
{ config, pkgs, self, pkgs_llm, ... }:
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
      tokenFile = "${config.secrix.services.github-runner-disgust.secrets.github_runner_token.decrypted.path}";
      url = "https://github.com/DarthPJB/parsec-gaming-nix";
    };
    rat-infested = {
      enable = true;
      name = "rat-infested";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-rat-infested.secrets.github_runner_token_2.decrypted.path}";
      url = "https://github.com/DarthPJB/ratty";
    };
    hate-filled = {
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
      serviceOverrides = {
        bindReadOnlyPaths = [ gitlabNetrcPath ];
      };
    };
    entropy-is-origin = {
      enable = true;
      name = "entropy-is-origin";
      package = pkgs_llm.github-runner;
      tokenFile = "${config.secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.decrypted.path}";
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

  # NEW: GitLab deploy token for private flake inputs
  secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.encrypted.file =
    "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
}
```

### How It Works

1. Secrix decrypts `gitlab_netrc` at service start to `/run/...` path
2. `GIT_ASKPASS` env var points git to a credential script
3. `bindReadOnlyPaths` mounts the decrypted netrc file into the systemd sandbox
4. When Nix fetches `git+https://gitlab.com/...`, git invokes `GIT_ASKPASS`
5. The script reads username/password from the mounted netrc file
6. Git authenticates with GitLab using the deploy token

## Phase I.D: CI Workflow Updates

Update `ci.nix` to use self-hosted runners for build jobs:

```nix
# In ciJobs.build-x86 and ciJobs.build-arm:
runs-on = "self-hosted";  # was "ubuntu-latest"

# Validation job: also needs self-hosted (nix flake check fetches ALL inputs)
runs-on = "self-hosted";  # was "ubuntu-latest"

# Security job: can stay on ubuntu-latest (no nix build required)
runs-on = "ubuntu-latest";  # unchanged
```

**Note**: The `validation` job runs `nix flake check` which fetches ALL inputs. It must also use self-hosted runners with deploy token access, or be modified to skip input fetching.

## Phase I.E: Validation

1. Deploy updated `remote-builder` config
2. Push to branch, trigger CI
3. Verify all machines build (especially `LINDA`, `remote-worker`, `bargman-greeter-vm`)
4. Merge to main

## Security Considerations

- Deploy token is read-only
- Secrix encrypts token at rest (age-encryption with host SSH key)
- Token only decrypted at runtime in tmpfs
- `GIT_ASKPASS` script contains only path reference, not the token itself
- Token never appears in process args or environment variables
- Risk: CI job could exfiltrate token by reading the mounted file path
- Mitigation: Accepted risk for proprietary codebase; encrypted secrets remain protected

## Token Rotation

1. Generate new deploy token in GitLab UI
2. Re-encrypt: `echo -n 'new-token' | nix run .#secrix encrypt secrets/ssh_deploy_keys/gitlab_netrc -- --all-users -s remote-builder`
3. Restart runner: `systemctl restart github-runner-hate-filled`
4. Bind mount re-reads the file on restart

## Files Modified

- `flake.nix` — Input URLs changed to HTTPS
- `services/github_runners.nix` — Added GIT_ASKPASS injection
- `secrets/ssh_deploy_keys/gitlab_netrc` — Encrypted deploy token (NEW)
- `.github/workflows/ci.yml` — Regenerated (via `nix run .#generate-ci-workflow`)

## Rollback

If HTTPS approach fails:
1. Revert `flake.nix` input URLs to `git+ssh://`
2. Generate SSH key pair, add to GitLab as project-level deploy keys
3. Encrypt private key via secrix
4. Inject via `GIT_SSH_COMMAND` environment variable

## Review Notes

**Reviewed by**: bellana-minimax, bellana-deepseek
**Review date**: 2026-06-26

### Issues Found & Fixed

1. ~~`NETRC` env var~~ → `GIT_ASKPASS` (git doesn't read `NETRC`)
2. ~~`BindReadOnlyPaths`~~ → `bindReadOnlyPaths` (NixOS underscore notation)
3. Added `extraLabels = [ "self-hosted" ]` for CI runner matching
4. Updated validation job to use self-hosted runners
5. Documented netrc format and token rotation
