# F5: Convert `writeShellScript` → `writeShellApplication` — Execution Plan

**Date:** 2026-07-25
**Status:** EXECUTING
**Review Synthesis:** `/speed-storage/opencode/documentation/2026-07-25-F5-REVIEW/SYNTHESIS.md`
**Scope:** 10 instances (excluding `rclone-target.nix:150` — user review pending). Deduplication deferred.

---

## Phase 1: Simple Conversions

**Goal:** Convert 4 low-risk instances. Fix SC2086 bug in gitlab-credentials.

### Step 1.1: flake.nix — QEMU VM launcher (1 instance)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix` line 458

**Current:**
```nix
nixpkgs.writeShellScript "run-bargman-greeter-vm-serial" ''
  export QEMU_OPTS="-display none -serial mon:stdio ''${QEMU_OPTS:-}"
  exec ${self.nixosConfigurations.bargman-greeter-vm.config.system.build.vm}/bin/run-bargman-greeter-vm-vm "$@"
''
```

**Target:**
```nix
nixpkgs.writeShellApplication {
  name = "run-bargman-greeter-vm-serial";
  runtimeInputs = [];
  text = ''
    export QEMU_OPTS="-display none -serial mon:stdio ''${QEMU_OPTS:-}"
    exec ${self.nixosConfigurations.bargman-greeter-vm.config.system.build.vm}/bin/run-bargman-greeter-vm-vm "$@"
  '';
}
```

**Notes:** Use `nixpkgs.writeShellApplication` (not `pkgs.`) to preserve current namespace. No runtimeInputs needed — execs a derivation path.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/flake.nix` around line 458. Convert the `nixpkgs.writeShellScript` call to `nixpkgs.writeShellApplication` with `name = "run-bargman-greeter-vm-serial"`, `runtimeInputs = []`, and the same script body as `text`. Remove the redundant `set -euo pipefail` if present. Commit with message "refactor: convert bargman-greeter-vm-serial to writeShellApplication".

**Success criteria:** Script produces identical derivation path. `nix eval .#apps.x86_64-linux.bargman-greeter-vm-serial` succeeds.

### Step 1.2: gitlab-credentials.nix — askpass + netrc-copy (2 instances)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/services/gitlab-credentials.nix` lines 11, 39

**Instance 11 (line 11):**
```nix
gitlabAskpass = pkgs.writeShellScript "gitlab-askpass" ''
  case "$1" in
    *Username*)
      exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login[[:space:]]*//p' ${userNetrcPath}  # ← SC2086: unquoted
      ;;
    *Password*)
      exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password[[:space:]]*//p' ${userNetrcPath}  # ← SC2086: unquoted
      ;;
  esac
'';
```

**Target:**
```nix
gitlabAskpass = pkgs.writeShellApplication {
  name = "gitlab-askpass";
  runtimeInputs = [ pkgs.gnused ];
  text = ''
    case "$1" in
      *Username*)
        exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login[[:space:]]*//p' "${userNetrcPath}"
        ;;
      *Password*)
        exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password[[:space:]]*//p' "${userNetrcPath}"
        ;;
    esac
  '';
};
```

**SC2086 fix:** Add quotes around `${userNetrcPath}` (lines 14, 17).

**Instance 39 (line 39):**
```nix
ExecStart = pkgs.writeShellScript "gitlab-netrc-copy" ''
  umask 022
  cp /run/system-keys/gitlab_netrc ${userNetrcPath}
  chmod 0644 ${userNetrcPath}
'';
```

**Target:**
```nix
ExecStart = (pkgs.writeShellApplication {
  name = "gitlab-netrc-copy";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    umask 022
    cp /run/system-keys/gitlab_netrc "${userNetrcPath}"
    chmod 0644 "${userNetrcPath}"
  '';
}) + "/bin/gitlab-netrc-copy";
```

**Notes:** `writeShellApplication` returns a derivation, but `ExecStart` needs a path string. Append `/bin/<name>` to get the executable path.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/services/gitlab-credentials.nix`. Convert both `writeShellScript` calls to `writeShellApplication`. CRITICAL: Fix SC2086 by adding quotes around `${userNetrcPath}` in the askpass script. For the netrc-copy ExecStart, append `+ "/bin/gitlab-netrc-copy"` to the derivation. `runtimeInputs` for askpass: `[ pkgs.gnused ]`. For netrc-copy: `[ pkgs.coreutils ]`. Commit with message "refactor: convert gitlab-credentials to writeShellApplication, fix SC2086".

**Success criteria:** Both instances converted. SC2086 fixed (paths quoted). ExecStart produces valid path.

### Step 1.3: mkRunners.nix — askpass (1 instance)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/services/mkRunners.nix` line 31

**Current:**
```nix
gitlabAskpass = pkgs.writeShellScript "gitlab-askpass" ''
  case "$1" in
    *Username*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login...' "${gitlabNetrcPath}" ;;
    *Password*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password...' "${gitlabNetrcPath}" ;;
  esac
'';
```

**Target:**
```nix
gitlabAskpass = pkgs.writeShellApplication {
  name = "gitlab-askpass";
  runtimeInputs = [ pkgs.gnused ];
  text = ''
    case "$1" in
      *Username*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login...' "${gitlabNetrcPath}" ;;
      *Password*) exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password...' "${gitlabNetrcPath}" ;;
    esac
  '';
};
```

**Notes:** Already properly quoted (no SC2086 here).

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/services/mkRunners.nix` line 31. Convert `writeShellScript` to `writeShellApplication` with `name = "gitlab-askpass"`, `runtimeInputs = [ pkgs.gnused ]`. Commit with message "refactor: convert mkRunners askpass to writeShellApplication".

**Success criteria:** Instance converted. Quotes already correct.

### Phase 1 Verification Gate

**Validator:** tpol-minimax
**Criteria:**
- All 4 instances converted
- SC2086 fixed in gitlab-credentials.nix
- `nix eval .#apps.x86_64-linux.bargman-greeter-vm-serial` succeeds
- `nix eval .#nixosConfigurations.remote-builder` succeeds (mkRunners)
- `nix eval .#nixosConfigurations.remote-worker` succeeds (gitlab-credentials)
- No new warnings

---

## Phase 2: GitHub Runner Helper Refactoring

**Goal:** Convert 2 instances in `github-runner-nixos-config.nix`, including the `writeScript` helper.

### Step 2.1: github-runner-nixos-config.nix — askpass (1 instance)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/services/github-runner-nixos-config.nix` line 23

**Current:**
```nix
gitlabAskpass = pkgs.writeShellScript "gitlab-askpass" ''
  case "$1" in
    *Username*)
      exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^login...' "${gitlabNetrcPath}"
      ;;
    *Password*)
      exec ${lib.getExe' pkgs.gnused "sed"} -n 's/^password...' "${gitlabNetrcPath}"
      ;;
  esac
'';
```

**Target:** Same as Step 1.3 pattern.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/services/github-runner-nixos-config.nix` line 23. Convert `writeShellScript` to `writeShellApplication` with `name = "gitlab-askpass"`, `runtimeInputs = [ pkgs.gnused ]`. Commit with message "refactor: convert github-runner askpass to writeShellApplication".

### Step 2.2: github-runner-nixos-config.nix — writeScript helper (1 instance)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/services/github-runner-nixos-config.nix` line 48

**Current:**
```nix
writeScript = scriptName: body:
  pkgs.writeShellScript "${svcName}-${scriptName}.sh" ''
    set -euo pipefail
    STATE_DIRECTORY="$1"
    WORK_DIRECTORY="$2"
    LOGS_DIRECTORY="$3"
    ${body}
  '';
```

**Target:**
```nix
writeScript = scriptName: body:
  let
    drv = pkgs.writeShellApplication {
      name = "${svcName}-${scriptName}";
      runtimeInputs = [ pkgs.coreutils pkgs.findutils ];
      text = ''
        : "''${1?Missing STATE_DIRECTORY}"
        : "''${2?Missing WORK_DIRECTORY}"
        : "''${3?Missing LOGS_DIRECTORY}"
        STATE_DIRECTORY="$1"
        WORK_DIRECTORY="$2"
        LOGS_DIRECTORY="$3"
        ${body}
      '';
    };
  in
  "${drv}/bin/${svcName}-${scriptName}";
```

**Notes:**
- `writeShellApplication` returns a derivation, but the callers expect a path string. Append `/bin/<name>`.
- Add `:` guards (tuvok suggestion) for defensive programming against unset positional args.
- Remove redundant `set -euo pipefail` (writeShellApplication adds it).
- `runtimeInputs` includes `coreutils` and `findutils` because the generated scripts use `find`, `mkdir`, `rm`, etc.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/services/github-runner-nixos-config.nix` around line 46-54. Convert the `writeScript` helper from `writeShellScript` to `writeShellApplication`. The helper returns a path string, so wrap the derivation: `let drv = pkgs.writeShellApplication { ... }; in "${drv}/bin/${svcName}-${scriptName}"`. Add `:` guards for `$1`, `$2`, `$3`. Add `runtimeInputs = [ pkgs.coreutils pkgs.findutils ]`. Remove the now-redundant `set -euo pipefail`. Commit with message "refactor: convert github-runner writeScript helper to writeShellApplication".

**Success criteria:** Helper produces identical path strings. All ExecStartPre scripts still resolve.

### Phase 2 Verification Gate

**Validator:** tpol-minimax
**Criteria:**
- Both instances converted
- `writeScript` helper returns path string (not derivation)
- `:` guards added for positional args
- `nix eval .#nixosConfigurations.remote-builder` succeeds
- Check that ExecStartPre scripts still resolve to valid paths

---

## Phase 3: Sysdiag Module (4 instances + PD#19 fixes)

**Goal:** Convert 4 instances in `sysdiag.nix`. Fix bare `find`/`sort`/`rm` (PD#19 violations).

### Step 3.1: sysdiag.nix — sysdiagImpl (1 instance)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 43

**Current:**
```nix
sysdiagImpl = pkgs.writeShellScript "sysdiag.sh" (builtins.readFile ../system-diagnostics/sysdiag.sh);
```

**Target:**
```nix
sysdiagImpl = pkgs.writeShellApplication {
  name = "sysdiag";
  runtimeInputs = with pkgs; [
    coreutils findutils util-linux procps gnugrep gnused iproute2
  ];
  text = builtins.readFile ../system-diagnostics/sysdiag.sh;
};
```

**Notes:**
- `builtins.readFile` is a Nix string — compatible with `writeShellApplication`.
- The external script already has `set -euo pipefail` — redundant but harmless.
- `runtimeInputs` based on commands used in sysdiag.sh: `find`, `sort`, `rm`, `cp`, `mkdir`, `hostname`, `date`, `df`, `free`, `ps`, `ip`, `dmesg`, etc.
- Name changes from `"sysdiag.sh"` to `"sysdiag"` (writeShellApplication convention). Verify the exec at line 63 still resolves.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 43. Convert `writeShellScript` to `writeShellApplication` with `name = "sysdiag"`, `text = builtins.readFile ../system-diagnostics/sysdiag.sh`, and appropriate `runtimeInputs`. Read the external script to determine which commands it uses. The exec at line 63 references `${sysdiagImpl}` — verify the binary name matches. Commit with message "refactor: convert sysdiagImpl to writeShellApplication".

**Success criteria:** `sysdiagImpl` produces a derivation with the correct binary name. Exec at line 63 resolves.

### Step 3.2: sysdiag.nix — sysdiagWrapper (1 instance)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 45

**Current:**
```nix
sysdiagWrapper = pkgs.writeShellScriptBin "sysdiag" ''
  #!/usr/bin/env bash
  set -euo pipefail
  export SYSDIAG_OUTPUT_BASE="${cfg.outputBase}"
  ...
  exec ${sysdiagImpl} "$@"
'';
```

**Target:**
```nix
sysdiagWrapper = pkgs.writeShellApplication {
  name = "sysdiag";
  runtimeInputs = [];
  text = ''
    export SYSDIAG_OUTPUT_BASE="${cfg.outputBase}"
    ...
    exec ${sysdiagImpl} "$@"
  '';
};
```

**Notes:** Remove redundant `#!/usr/bin/env bash` and `set -euo pipefail`. No runtimeInputs needed — only exports env vars and execs a derivation.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 45. Convert `writeShellScriptBin` to `writeShellApplication` with `name = "sysdiag"`, `runtimeInputs = []`. Remove redundant shebang and `set -euo pipefail`. Commit with message "refactor: convert sysdiagWrapper to writeShellApplication".

### Step 3.3: sysdiag.nix — cleanupImpl (1 instance + PD#19 fixes)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 69

**Current:** Uses bare `find`, `sort`, `rm`.

**Target:**
```nix
cleanupImpl = pkgs.writeShellApplication {
  name = "sysdiag-cleanup";
  runtimeInputs = [ pkgs.findutils pkgs.coreutils ];
  text = ''
    set -euo pipefail

    DIAG_BASE="''${SYSDIAG_OUTPUT_BASE:-/tmp}"
    PATTERN="sysdiag-*"
    RETENTION_DAYS="''${SYSDIAG_RETENTION_DAYS:-${toString cleanupCfg.retentionDays}}"
    RETENTION_COUNT="''${SYSDIAG_RETENTION_COUNT:-${toString cleanupCfg.retentionCount}}"

    log_info() { echo "[INFO] $*"; }

    find_diagnostic_dirs() {
      ${lib.getExe pkgs.findutils} "$DIAG_BASE" -maxdepth 1 -type d -name "$PATTERN" 2>/dev/null | ${lib.getExe' pkgs.coreutils "sort"} -r
    }

    # ... rest of script with ${lib.getExe' pkgs.coreutils "rm"} replacing bare rm
  '';
};
```

**PD#19 fixes needed:**
- `find` → `${lib.getExe pkgs.findutils}`
- `sort` → `${lib.getExe' pkgs.coreutils "sort"}`
- `rm` → `${lib.getExe' pkgs.coreutils "rm"}`

**Note:** Keep `set -euo pipefail` in the body (even though writeShellApplication adds it) — the script uses `''${VAR:-default}` which is compatible with `set -u`. The `((count++))` arithmetic and array operations are compatible with `set -e` because they're in conditionals.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 69. Convert `writeShellScript` to `writeShellApplication` with `name = "sysdiag-cleanup"`, `runtimeInputs = [ pkgs.findutils pkgs.coreutils ]`. CRITICAL: Fix PD#19 violations — replace bare `find` with `${lib.getExe pkgs.findutils}`, bare `sort` with `${lib.getExe' pkgs.coreutils "sort"}`, bare `rm` with `${lib.getExe' pkgs.coreutils "rm"}`. Keep the script body logic unchanged. Commit with message "refactor: convert cleanupImpl to writeShellApplication, fix PD#19".

**Success criteria:** All bare commands replaced with `lib.getExe`. Script logic unchanged. `runtimeInputs` correct.

### Step 3.4: sysdiag.nix — cleanupWrapper (1 instance)

**File:** `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 116

**Current:**
```nix
cleanupWrapper = pkgs.writeShellScriptBin "sysdiag-cleanup" ''
  #!/usr/bin/env bash
  set -euo pipefail
  export SYSDIAG_OUTPUT_BASE="${cfg.outputBase}"
  export SYSDIAG_RETENTION_DAYS="${toString cleanupCfg.retentionDays}"
  export SYSDIAG_RETENTION_COUNT="${toString cleanupCfg.retentionCount}"
  exec ${cleanupImpl} "$@"
'';
```

**Target:** Same pattern as Step 3.2.

**Prompt for bellana-deepseek:**
> Edit `/speed-storage/bargman-tech/NixOS-Configuration/modules/sysdiag.nix` line 116. Convert `writeShellScriptBin` to `writeShellApplication` with `name = "sysdiag-cleanup"`, `runtimeInputs = []`. Remove redundant shebang and `set -euo pipefail`. Commit with message "refactor: convert cleanupWrapper to writeShellApplication".

### Phase 3 Verification Gate

**Validator:** tpol-minimax
**Criteria:**
- All 4 instances converted
- PD#19 violations fixed in cleanupImpl (no bare `find`/`sort`/`rm`)
- `sysdiagImpl` exec path resolves correctly
- `cleanupImpl` exec path resolves correctly
- `nix eval .#nixosConfigurations.cortex-alpha` succeeds (sysdiag is on cortex-alpha)
- ShellCheck would pass (runtimeInputs cover all commands)

---

## Phase 4: Final Verification

**Goal:** Confirm all conversions, run full checks.

### Step 4.1: Verify no remaining writeShellScript

```bash
grep -rn 'writeShellScript\|writeShellScriptBin' --include="*.nix" | grep -v "rclone-target.nix" | grep -v "^#"
```

Should return ZERO matches (excluding rclone-target.nix which is intentionally preserved).

### Step 4.2: Run flake checks

```bash
nix flake check --option builders ''
```

All checks must pass: deadnix, formatting, network-config.

### Phase 4 Verification Gate

**Validator:** tpol-minimax
**Criteria:**
- Zero `writeShellScript` instances except `rclone-target.nix:150`
- All flake checks pass
- No new warnings
- Spot-check 3 ExecStart paths resolve correctly

---

## Execution Summary

| Phase | Instances | Files | Risk |
|-------|-----------|-------|------|
| 1: Simple | 4 | 3 | Low |
| 2: Runner helper | 2 | 1 | Medium |
| 3: Sysdiag | 4 | 1 | Medium (PD#19) |
| 4: Verify | — | — | — |
| **Total** | **10** | **5** | |

**Excluded:** `rclone-target.nix:150` (user review pending)
**Deferred:** Deduplication of gitlabAskpass (3 files)
