# GitHub Runner Custom Module Plan

> **Created:** 2026-07-09
> **Status:** Planned — Phase Overlord-II
> **Priority:** High (blocks CI reliability)
> **Parent directive:** Correctness over speed; real infrastructure survives reboots

## Context

The nixpkgs `github-runner` module (`nixpkgs/nixos/modules/services/continuous-integration/github-runner/service.nix`) has a critical design flaw: it destroys persistent runner registration on every config change. The `unconfigureRunner` script runs `diff_config()` on every boot, which compares the nix store path of `config.json`. Since the store path changes on every rebuild (it includes the hash of the entire closure), **any nix rebuild + reboot = runner death**.

The module's "solution" is to use a PAT (Personal Access Token) instead of a registration token. This is a security regression — PATs have broader scope (`admin:org` or `repo`) while registration tokens are scoped to runner registration only. Using a PAT invalidates the entire security model of named runners.

## The Problem (Detailed)

1. `unconfigureRunner` runs as `ExecStartPre` before every start
2. `diff_config()` compares nix store path of `config.json` against stored symlink
3. If path changed → `clean_state()` deletes `.credentials` and `.runner`
4. `configureRunner` tries to re-register with stored token
5. Token expired (1-hour validity) → GitHub returns 404
6. Runner is dead

The module treats nix config changes as requiring complete re-registration. But runner registration is independent of nix config — `.credentials` and `.runner` should survive config changes.

## Goals

1. **Immediate fix (Phase Overlord-I):** Override `ExecStartPre` via `serviceOverrides` to preserve registration
2. **Proper fix (Phase Overlord-II):** Build a custom module that separates identity from config

## Phase 1: Immediate Override (Current)

Copy-paste the nixpkgs module's scripts with the destructive behavior removed:

```nix
services.github-runners.hate-filled = {
  serviceOverrides = {
    ExecStartPre = lib.mkForce [
      "+${customUnconfigure}"
      "${customConfigure}"
      "${customSetupWorkDir}"
    ];
  };
};
```

### Custom Scripts

**unconfigure** (preserves registration):
```bash
# If runner is already registered, skip everything
if [[ -f "$STATE_DIRECTORY/.credentials" ]] && \
   [[ -f "$STATE_DIRECTORY/.runner" ]]; then
  echo "Runner already registered, preserving state."
  find -H "$WORK_DIRECTORY" -mindepth 1 -delete
  exit 0
fi
# First start or recovery: copy token for configure
install --mode=666 <tokenFile> "$STATE_DIRECTORY/.new-token"
```

**configure** (unchanged logic from nixpkgs):
```bash
if [[ -e "$STATE_DIRECTORY/.new-token" ]]; then
  # ... registration logic ...
fi
```

**setupWorkDir** (unchanged logic from nixpkgs):
```bash
ln -s "$LOGS_DIRECTORY" "$WORK_DIRECTORY/_diag"
ln -s "$STATE_DIRECTORY"/{.credentials,.credentials_rsaparams,.runner} "$WORK_DIRECTORY/"
```

### Risks

- **Fragile:** If nixpkgs changes the module interface, our override breaks
- **Maintenance:** We own the scripts now — any upstream fixes need manual porting
- **Mitigation:** This is temporary — Phase 2 replaces the entire module

## Phase 2: Custom Module (Overlord-II)

Build a proper `github-runner` module that:

1. **Separates identity from config:**
   - `.credentials`, `.runner`, `.credentials_rsaparams` in a separate directory
   - Config symlink in a different directory
   - Config changes don't touch identity files

2. **Only wipes on actual identity changes:**
   - Diff the runner name, URL, and token content
   - If only the nix store path changed → preserve registration
   - If the runner name/URL changed → re-register

3. **Supports both token types:**
   - Registration tokens (scoped, 1-hour expiry)
   - PATs (broader scope, no expiry)
   - Auto-detect based on prefix

4. **Provides escape hatches:**
   - `preserveRegistration` option
   - `forceReRegister` option
   - Custom unconfigure script option

### Module Structure

```
modules/github-runner/
  default.nix        # Module entry point
  options.nix        # Option declarations
  service.nix        # Service configuration
  scripts/
    unconfigure.sh   # Non-destructive unconfigure
    configure.sh     # Registration logic
    setup-workdir.sh # Work directory setup
```

### Testing

- Golden test for service configuration
- VM test for runner registration flow
- Test reboot survival (config change + reboot = runner still registered)

## Security Model

**We use registration tokens, not PATs. No exceptions.**

- Registration tokens are scoped to runner registration only
- PATs have broader scope (admin:org, repo) — security regression
- Named runners are tied to specific registration tokens
- The security model is correct; the nixpkgs module is wrong

## Related

- Blog draft: `personal-website-blog/draft-blogs/2026-07-09-nixpkgs-github-runner-registration-destroyed.md`
- Incident: LINDA github-runner-hate-filled failure (2026-07-09)
- Nixpkgs module: `nixpkgs/nixos/modules/services/continuous-integration/github-runner/service.nix`
