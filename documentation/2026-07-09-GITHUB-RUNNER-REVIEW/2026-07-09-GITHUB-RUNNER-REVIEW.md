# GitHub Runner Module Override Review

**Date:** 2026-07-09
**Scope:** Review the "copy-paste from nixpkgs" override approach for the github-runner module
**Status:** Active — agents delegated

---

## Review Objectives

1. **Correctness:** Does the override approach correctly preserve runner registration across reboots?
2. **Security:** Does it maintain the registration token security model (NOT PATs)?
3. **Completeness:** Are all three ExecStartPre scripts accounted for?
4. **Edge Cases:** What happens on first start, recovery, config changes?
5. **Risks:** What breaks if nixpkgs changes the module?

## Critical Constraints

**PAT tokens are WRONG. We are RIGHT. No exceptions.**

- Registration tokens are scoped to runner registration only
- PATs have broader scope (admin:org, repo) — this is a security regression
- Named runners are tied to specific registration tokens
- The nixpkgs module's suggestion to "use a PAT" is wrong for our use case
- We preserve the security model; the nixpkgs module is broken, not us

## Files to Review

- `nixpkgs/nixos/modules/services/continuous-integration/github-runner/service.nix` — original module
- `nixpkgs/nixos/modules/services/continuous-integration/github-runner/options.nix` — module options
- `services/github-runner-nixos-config.nix` — our runner config
- `machines/LINDA/default.nix` — machine config
- `documentation/plans/github-runner-custom-module-2026-07-09.md` — implementation plan

## Agent Prompts

### Agent 1: tpol-xai — Structured Analysis

**Prompt:**

You are reviewing a NixOS module override approach for the github-runner service. The nixpkgs module has a critical design flaw: it destroys persistent runner registration on every config change + reboot.

**Your task:** Analyze the "copy-paste from nixpkgs" override approach. We will use `serviceOverrides` with `lib.mkForce` to replace `ExecStartPre` with custom scripts that preserve `.credentials` and `.runner` files.

**Critical constraint:** PAT tokens are WRONG. We use registration tokens. The nixpkgs module's suggestion to "use a PAT" is a security regression. Registration tokens are scoped to runner registration only; PATs have broader scope. We are right. No exceptions.

**Review focus:**
1. Read the original module code at `/nix/store/9gg23zh4ajxmwvg2kb0pgcmp848000jd-jf7h05118kz9qrf7ny5mhln8myf2plz1-source/nixos/modules/services/continuous-integration/github-runner/service.nix`
2. Analyze the `unconfigureRunner`, `configureRunner`, and `setupWorkDir` scripts
3. Identify the exact points where state is destroyed
4. Verify that our conditional approach (skip wipe if `.credentials` exists) is correct
5. Identify edge cases: first start, recovery after failed registration, token expiry

**Output:** Write a structured analysis to `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-09-GITHUB-RUNNER-REVIEW/tpol-xai-REVIEW-2026-07-09.md`

---

### Agent 2: bellana-deepseek — Engineering Deep Dive

**Prompt:**

You are reviewing a NixOS module override implementation. The nixpkgs `github-runner` module destroys persistent runner registration on reboot. We are implementing a `serviceOverrides` approach to fix this.

**Your task:** Write the actual Nix code for the override. Copy the scripts from the nixpkgs module and modify them to preserve registration.

**Critical constraint:** PAT tokens are WRONG. We use registration tokens. No exceptions. The nixpkgs module is broken, not us.

**Implementation requirements:**

1. **Custom unconfigure script:** If `.credentials` and `.runner` exist in STATE_DIRECTORY, skip everything (runner already registered). Otherwise, copy token to `.new-token` for configure.

2. **Custom configure script:** Copy from nixpkgs — check for `.new-token`, register runner, clean up.

3. **Custom setupWorkDir script:** Copy from nixpkgs — symlink credentials and diag to work directory.

4. **Nix wrapper:** Use `serviceOverrides.ExecStartPre = lib.mkForce [...]` to replace the original scripts.

**Review the original scripts at:**
- `/nix/store/9gg23zh4ajxmwvg2kb0pgcmp848000jd-jf7h05118kz9qrf7ny5mhln8myf2plz1-source/nixos/modules/services/continuous-integration/github-runner/service.nix`

**Write the implementation to:**
- `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-09-GITHUB-RUNNER-REVIEW/bellana-deepseek-REVIEW-2026-07-09.md`

Include the complete Nix code for the override, ready to be added to `services/github-runner-nixos-config.nix`.

---

### Agent 3: tpol-minimax — Risk Analysis

**Prompt:**

You are analyzing risks for a NixOS module override approach. We are overriding the nixpkgs `github-runner` module's `ExecStartPre` to preserve runner registration across reboots.

**Your task:** Identify all risks, failure modes, and edge cases for this approach.

**Critical constraint:** PAT tokens are WRONG. We use registration tokens. The security model must be preserved. No exceptions.

**Risk areas to analyze:**

1. **Nixpkgs module updates:** What happens if nixpkgs changes the module interface? How do we detect this?

2. **Script compatibility:** The original scripts use hardcoded nix store paths. Our scripts need to handle this correctly.

3. **Token lifecycle:** Registration tokens expire in 1 hour. What happens if:
   - Token expires before first boot?
   - Token expires during registration?
   - Token file is missing or corrupted?

4. **State directory permissions:** The unconfigure runs as root (`+` prefix). The configure runs as the service user. Are permissions handled correctly?

5. **Recovery scenarios:** What happens if:
   - `.credentials` exists but is corrupted?
   - `.runner` exists but points to wrong GitHub repo?
   - Registration succeeds but runner crashes before starting?

6. **Testing strategy:** How do we verify the override works correctly?

**Output:** Write a risk analysis to `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-09-GITHUB-RUNNER-REVIEW/tpol-minimax-REVIEW-2026-07-09.md`

---

### Agent 4: ezri-claude-haiku — Adaptive Tactical Review

**Prompt:**

You are reviewing a tactical decision: overriding the nixpkgs `github-runner` module's `ExecStartPre` to preserve runner registration.

**Your task:** Evaluate the tactical approach and identify if there's a simpler or better way.

**Critical constraint:** PAT tokens are WRONG. We use registration tokens. The nixpkgs module's suggestion to "use a PAT" is wrong. We are right. No exceptions.

**Tactical questions:**

1. **Is `serviceOverrides` with `lib.mkForce` the right approach?** Are there other NixOS module mechanisms that would work better?

2. **Can we avoid copying all three scripts?** Is there a way to override just the unconfigure script without touching configure and setupWorkDir?

3. **Is there a way to patch the module instead of replacing scripts?** Could we use overlays or module imports to fix the behavior?

4. **What's the minimal change that fixes the problem?** Can we get away with less code?

5. **Is there upstream movement on this issue?** Has anyone else reported this? Is there a PR?

**Output:** Write a tactical review to `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-09-GITHUB-RUNNER-REVIEW/ezri-claude-haiku-REVIEW-2026-07-09.md`
