# Overlord-II Development Report

> **Generated:** 2026-07-11
> **Branch:** `overlord-II-exec` (worktree from `overlord-II`)
> **Base:** `db90b5d` (golden: regenerate 10 active machine configs to match v1.9 fleet state)
> **Head:** `8455cbe` (revert(ssh): remove matchBlocks — option does not exist in nixpkgs 25.11)

## Golden Test Status

**Directive: "Do not update goldens as part of development"**

| Check | Result |
|-------|--------|
| All 18 goldens vs v1.9-Golden tag | ✅ IDENTICAL — zero bytes changed |
| Golden files moved from `real-topology/golden/` to `goldens/` | ✅ Content preserved |
| Golden validation (10 active machines) | ✅ All pass |

**No golden files were modified, regenerated, or created during this development session.**

## Flake Validation

| Check | Result |
|-------|--------|
| `nix flake show` | ✅ Pass |
| `nix flake check` | ✅ Pass (all checks) |
| `checks.x86_64-linux.nixpkgs-fmt` | ✅ Pass |
| `checks.x86_64-linux.network-config-cortex-alpha` | ✅ Pass |
| `checks.x86_64-linux.topology-coverage` | ✅ Pass |
| `checks.x86_64-linux.bargman-greeter-login-test` | ✅ Pass |
| `checks.x86_64-linux.minecraft-server-test` | ✅ Pass |

## Commits in This Session

| # | Hash | Message | Type |
|---|------|---------|------|
| 1 | `4f80255` | fix: check-network uses dump-config (serialize-config.nix) to match golden format | Fix |
| 2 | `4b967b0` | feat(topology): create new directory structure for topology rectification | Feature |
| 3 | `eea67b8` | refactor(topology): update all imports to new topology paths | Refactor |
| 4 | `71c6f42` | cleanup(topology): remove real-topology/ directory | Cleanup |
| 5 | `0d79eea` | feat(ssh): implement fleet-wide SSH multiplexing via topology | Feature |
| 6 | `279ff55` | docs: update documentation for new topology structure | Docs |
| 7 | `8455cbe` | revert(ssh): remove matchBlocks — option does not exist in nixpkgs 25.11 | Revert |

## Directive Violations

### VIOLATION 1: Implementing Without Verifying Prerequisites

**Directive:** "Methodical Development — No Rushing" (Directive 21)

**Violation:** SSH multiplexing was implemented (`0d79eea`) without first verifying that `programs.ssh.matchBlocks` exists in the target nixpkgs version. The plan (`ssh-multiplex-topology-2026-07-03.md`) assumed the option existed based on documentation references, but never verified against the actual nixpkgs 25.11 module.

**Impact:** Wasted commit cycle — implemented in `0d79eea`, immediately reverted in `8455cbe`.

**Root Cause:** The plan was written referencing `programs.ssh.matchBlocks` as if it were a standard NixOS option. It does not exist in nixpkgs 25.11. The `programs.ssh` module only exposes: `agentPKCS11Whitelist`, `agentTimeout`, `askPassword`, `ciphers`, `enableAskPassword`, `extraConfig`, `forwardX11`, `hostKeyAlgorithms`, `kexAlgorithms`, `knownHosts`, `knownHostsFiles`, `macs`, `package`, `pubkeyAcceptedKeyTypes`, `setXAuthLocation`, `startAgent`, `systemd-ssh-proxy`.

**Resolution:** Reverted in `8455cbe`. SSH multiplexing plan needs redesign using `programs.ssh.extraConfig` (raw string approach).

### VIOLATION 2: Golden Files Were Regenerated on Branch Before This Session

**Directive:** "Golden tests are sacrosanct — never regenerate golden as part of refactoring" (AGENTS.md)

**Violation:** Commit `db90b5d` (before this session) regenerated 10 golden files with message "golden: regenerate 10 active machine configs to match v1.9 fleet state". This was done on the `overlord-II` branch before development began.

**Impact:** The golden files were regenerated to match a different generator (`lib/serialize-config.nix`) than what `check-network` was using (`real-topology/default.nix`). This caused all golden tests to fail when I started work.

**Root Cause:** Two generators existed:
- `real-topology/default.nix` → flat structure (591 lines for cortex-alpha)
- `lib/serialize-config.nix` → hierarchical structure (3757 lines for cortex-alpha)

The golden files were generated with `dump-config` (uses `serialize-config.nix`) but `check-network` was calling `generate-golden` (uses `real-topology/default.nix`).

**Resolution:** Fixed in `4f80255` — updated `check-network` to use `dump-config` instead of `generate-golden`. The golden files themselves were NOT modified; only the validation tooling was fixed to match them.

### NO VIOLATION: Golden Integrity Preserved

The golden files from `v1.9-Golden` tag are byte-identical to the current `goldens/` directory. The topology rectification moved files from `real-topology/golden/` to `goldens/` without any content modification. This is the correct behavior.

## Blockers Resolved

### Blocker 1: check-network / generate-golden Mismatch

**Problem:** `check-network` used `generate-golden` which produced flat output. Golden files were generated with `dump-config` which produces hierarchical output. All 10 golden tests failed.

**Fix:** Updated `check-network` and `checks.network-config-cortex-alpha` to use `dump-config` instead of `generate-golden`.

### Blocker 2: programs.ssh.matchBlocks Doesn't Exist

**Problem:** SSH multiplexing plan assumed `programs.ssh.matchBlocks` was a valid NixOS option. It doesn't exist in nixpkgs 25.11.

**Fix:** Reverted all SSH multiplexing changes. Plan needs redesign.

## Outstanding Items

> **Last validated:** 2026-07-17 — code inspection

| Item | Status | Notes |
|------|--------|-------|
| Topology rectification | ✅ Complete | `real-topology/` eliminated |
| SSH multiplexing | ✅ Complete | `ssh-multiplex.nix` module using `extraConfig` approach |
| GitHub runner module | ✅ Complete | Override deployed, hate-filled on remote-builder |
| LLM-CORE re-enable | ✅ Complete | Enabled in flake inputs, `opencode-fleet` active on LINDA |
| Documentation update | ✅ Complete | |
| Phase B: Backup topology | ⬜ Deferred | Deferred to overlord-III (user directive 2026-07-25) |
| remote-builder cache push | ⬜ Pending | Phase 4 of hub plan |

## Recommendations

1. **SSH multiplexing redesign** — Use `programs.ssh.extraConfig` with `Match` blocks instead of `matchBlocks`. This is the raw string approach — less ideal for merging but functional.

2. **Deprecate `generate-golden`** — The `real-topology/default.nix` generator produces a different format than `dump-config`. Since goldens are generated with `dump-config`, the `generate-golden` app should either be removed or updated to use `serialize-config.nix`.

3. **Tag current state** — After merging `overlord-II-exec` into `overlord-II`, tag as `v1.10-topology-rectified` for future reference.
