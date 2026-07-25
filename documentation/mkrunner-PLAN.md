# mkRunner — Scalable GitHub Runner Factory

> **Created:** 2026-07-19
> **Worktree:** `/tmp/nixos-mkrunner` (branch `feat/mkrunner`)
> **Status:** PLANNING

## Objective

Replace the custom `github-runner-nixos-config.nix` with a reusable `mkRunner` function that generates N concurrent self-hosted runners using the vanilla nixpkgs module. Eliminates the serial build bottleneck.

## Key Design Decisions

1. **Vanilla module** — no custom `ExecStartPre` override. PAT handles re-registration.
2. **`replace = true`** — re-registration replaces existing runner by name (not duplicate).
3. **Count-based** — `mkRunner { ... count = 5; }` generates 5 runner instances.
4. **Shared infrastructure** — all runners share nix-daemon, store, and GitLab netrc.
5. **Secrets via secrix** — PAT stored as `hate-filled-generator`, shared by all instances.

## Phase 1: Create `lib/mkRunner.nix`

**Goal:** Pure function that generates runner attrset from properties + count.

**Files:** `lib/mkRunner.nix` (new)

**Function signature:**
```nix
mkRunner = { config, lib, pkgs, self, pkgs_llm }:
  { namePrefix     # "hate-filled"
  , url            # "https://github.com/DarthPJB/NixOS-Configuration"
  , tokenFile      # config.secrix.services.github-runner-*.secrets.*.decrypted.path
  , count          # 5
  , extraLabels ? [ "self-hosted" ]
  , extraEnvironment ? { }
  , extraServiceOverrides ? { }
  , gitlabNetrcPath ? null  # optional — only for runners that need GitLab auth
  , package ? pkgs_llm.github-runner
  }: ...
```

**Returns:** attrset of runner definitions suitable for `services.github-runners = mkRunner { ... };`

**Logic:**
```nix
let
  mkInstance = i: {
    "${namePrefix}-${toString i}" = {
      enable = true;
      name = "${namePrefix}-${toString i}";
      inherit package url tokenFile;
      replace = true;  # KEY: replaces existing runner by name on re-registration
      extraLabels = extraLabels ++ [ "runner-${toString i}" ];
      extraEnvironment = extraEnvironment;
      serviceOverrides = {
        BindReadOnlyPaths = lib.optional (gitlabNetrcPath != null) gitlabNetrcPath;
      } // extraServiceOverrides;
    };
  };
in
  builtins.foldl' (a: b: a // b) {} (map mkInstance (lib.range 1 count))
```

**References:**
- `/speed-storage/bargman-tech/nixpkgs_llm/nixos/modules/services/continuous-integration/github-runner/options.nix` — `replace` option (line 200-207)
- `/speed-storage/bargman-tech/nixpkgs_llm/nixos/modules/services/continuous-integration/github-runner/service.nix` — PAT detection (line 151-157)

**Exit criteria:** `mkRunner.nix` exists, exports a pure function, no dependencies on specific runner names.

---

## Phase 2: Create `services/mkRunners.nix`

**Goal:** Wire `mkRunner` into the machine configuration with the `hate-filled` PAT.

**Files:** `services/mkRunners.nix` (new), `services/github-runner-nixos-config.nix` (to be replaced)

**Module structure:**
```nix
{ config, lib, pkgs, self, pkgs_llm, ... }:
let
  mkRunner = import ../lib/mkRunner.nix { inherit config lib pkgs self pkgs_llm; };

  # GitLab auth — only needed for runners that access private flake inputs
  gitlabNetrcPath = config.secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.decrypted.path;
  gitlabAskpass = pkgs.writeShellScript "gitlab-askpass" ''
    case "$1" in
      *Username*) exec ${pkgs.gnused}/bin/sed -n 's/^login[[:space:]]*//p' "${gitlabNetrcPath}" ;;
      *Password*) exec ${pkgs.gnused}/bin/sed -n 's/^password[[:space:]]*//p' "${gitlabNetrcPath}" ;;
    esac
  '';
in
{
  services.github-runners = mkRunner {
    namePrefix = "hate-filled";
    url = "https://github.com/DarthPJB/NixOS-Configuration";
    tokenFile = config.secrix.services.github-runner-hate-filled.secrets.hate-filled-generator.decrypted.path;
    count = 5;
    extraLabels = [ "self-hosted" ];
    extraEnvironment = { GIT_ASKPASS = "${gitlabAskpass}"; };
    gitlabNetrcPath = gitlabNetrcPath;  # optional — omit for runners without GitLab deps
  };

  secrix.services.github-runner-hate-filled.secrets.hate-filled-generator.encrypted.file =
    "${self}/secrets/hate-filled-generator";
  secrix.services.github-runner-hate-filled.secrets.gitlab_netrc.encrypted.file =
    "${self}/secrets/ssh_deploy_keys/gitlab_netrc";
}
```

**Exit criteria:** `mkRunners.nix` generates 5 runner instances, all using the PAT, all with `replace = true`.

---

## Phase 3: Wire into `machines/remote-builder/default.nix`

**Goal:** Replace `github-runner-nixos-config.nix` import with `mkRunners.nix`.

**Files:** `machines/remote-builder/default.nix`

**Changes:**
- Remove: `../../services/github-runner-nixos-config.nix`
- Add: `../../services/mkRunners.nix`
- Keep: `../../services/github_runners.nix` (disgust, rat-infested, entropy-is-origin — different repos)

**Exit criteria:** `machines/remote-builder/default.nix` imports `mkRunners.nix` instead of `github-runner-nixos-config.nix`.

---

## Phase 4: Build Validation

**Goal:** Verify the configuration builds and produces 5 runner services.

**Steps:**
1. `nix build --option builders '' --no-link --print-out-paths .#nixosConfigurations.remote-builder.config.system.build.toplevel`
2. Verify 5 systemd units: `github-runner-hate-filled-1.service` through `github-runner-hate-filled-5.service`
3. Verify all use the PAT (not registration tokens)
4. Verify all have `replace = true`

**Exit criteria:** Build succeeds, 5 runner services present, no custom ExecStartPre.

---

## Phase 5: LINDA Integration

**Goal:** Apply the same `mkRunners` pattern to LINDA (if desired).

**Files:** `machines/LINDA/default.nix`

**Steps:**
1. Import `services/mkRunners.nix` in LINDA
2. Verify the `hate-filled-generator` secret is encrypted for LINDA (already done)
3. Build LINDA to verify

**Exit criteria:** LINDA builds with 5 runners using the same PAT.

---

## Summary

| Phase | File | Change |
|---|---|---|
| 1 | `lib/mkRunner.nix` | New — reusable runner factory function |
| 2 | `services/mkRunners.nix` | New — wires mkRunner with hate-filled config |
| 3 | `machines/remote-builder/default.nix` | Replace github-runner-nixos-config.nix with mkRunners.nix |
| 4 | — | Build validation |
| 5 | `machines/LINDA/default.nix` | Optional: apply mkRunners to LINDA |
