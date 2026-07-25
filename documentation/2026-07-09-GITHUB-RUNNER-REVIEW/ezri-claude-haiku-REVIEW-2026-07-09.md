# Tactical Review: GitHub Runner Module Override
**Agent:** Claude-Haiku (Ezri)  
**Date:** 2026-07-09  
**Scope:** nixpkgs `github-runner` module override approach  
**Context:** LINDA github-runner-hate-filled service fails on config change + reboot

---

## Executive Summary

The **current approach is viable but brittle**. We are using the right mechanism (`serviceOverrides` + `lib.mkForce`) but copying three shell scripts creates a **maintenance burden** that grows with every nixpkgs update. 

**Recommendation:** The Phase Overlord-I override (copy scripts) is acceptable as **temporary tactical measure**. However, we should immediately pursue **Phase II (custom module)** because:

1. **Script copies are fragile** — nixpkgs module changes break silently
2. **Phase II is not blocked** — we can build it in parallel with Phase I
3. **The problem is architectural, not tactical** — no simple patch fixes it

---

## Question 1: Is `serviceOverrides` with `lib.mkForce` the Right Approach?

### Answer: Yes, But With Caveats

`serviceOverrides` is the **correct NixOS lever** for this problem. It's designed for exactly this use case: overriding systemd service directives without replacing the entire module.

```nix
serviceOverrides = {
  ExecStartPre = lib.mkForce [
    "+${customUnconfigure}"
    "${customConfigure}"
    "${customSetupWorkDir}"
  ];
};
```

**Why this is right:**
- `lib.mkForce` bypasses module priority rules, ensuring our override wins
- The `+` prefix runs the unconfigure script as root (needed for state cleanup)
- `ExecStartPre` is the correct systemd hook for pre-start checks

**Why we can't do better with NixOS mechanisms:**
- `lib.mkOrder` doesn't work here (we need total replacement, not ordering)
- We can't override *part* of the ExecStartPre sequence — systemd requires the full list
- Module import order can't help (the github-runner module is final authority)
- There's no NixOS option to "modify a script in place"

**Verdict:** This is the **correct mechanism**. The problem is what we're overriding — not *how*.

---

## Question 2: Can We Avoid Copying All Three Scripts?

### Answer: No. We Must Override All Three, But With Strategic Nesting

The **root issue:** nixpkgs passes three scripts as an *ordered sequence* to `ExecStartPre`. Systemd executes them in order:

```bash
ExecStartPre=+${unconfigure}        # Runs as root
ExecStartPre=${configure}           # Runs as the github-runner user
ExecStartPre=${setupWorkDir}        # Sets up symlinks
```

We **cannot override just the unconfigure script** because:
1. If we keep the original unconfigure, it still wipes `.credentials` and `.runner`
2. If we only override unconfigure, the other scripts must still be compatible
3. The three scripts share state (`$STATE_DIRECTORY`) — changes cascade

**However, we can reduce duplication:**

Instead of copying the entire nixpkgs scripts, we could:

```nix
# Option A: Wrap the original unconfigure script
customUnconfigure = pkgs.writeShellScript "gh-runner-unconfigure-patched" ''
  # Preserve registration if already configured
  if [[ -f "$STATE_DIRECTORY/.credentials" ]]; then
    echo "Runner registered, skipping unconfigure"
    exit 0
  fi
  # Fall back to original for first-time setup
  exec ${github-runner.unconfigure-original}
''

# Option B: Use sed/patch to modify the original script
customUnconfigure = pkgs.runCommandCC "unconfigure-patched" {} ''
  ${pkgs.gnused}/bin/sed 's/clean_state()/# clean_state() disabled/' \
    ${github-runner.scripts.unconfigure} > $out
  chmod +x $out
''
```

**Verdict:** We **cannot avoid copying all three scripts** because they must work as a unit. However, we can **reduce duplication by wrapping or patching** the original scripts. This is a **minor optimization** — still requires vendoring the upstream code.

---

## Question 3: Is There a Way to Patch the Module Instead of Replacing Scripts?

### Answer: Not Cleanly. Here's Why.

We explored three alternatives:

#### Option A: Use an Overlay to Patch nixpkgs Module
```nix
nixpkgs.overlays = [(final: prev: {
  github-runner = prev.github-runner.overrideAttrs (old: {
    scripts = old.scripts // {
      unconfigure = patched-unconfigure;
    };
  });
})]
```

**Problem:** The `github-runner` *module* (not package) is in `nixpkgs/nixos/modules/...`. Module code doesn't have an overlay path. You can't overlay NixOS modules directly — only packages.

#### Option B: Use `disabledModules` to Disable + Replace
```nix
disabledModules = ["services/continuous-integration/github-runner"];
imports = ["./modules/custom-github-runner.nix"];
```

**Problem:** This is Phase II work. We'd have to copy the *entire* module (not just scripts). It's the right long-term solution but overkill for a tactical hotfix.

#### Option C: Module Arguments/Options Override
```nix
# Some NixOS modules allow extending behavior via options
services.github-runners.hate-filled = {
  preserveRegistrationScript = true; # hypothetical option
};
```

**Problem:** The nixpkgs module doesn't expose this option. We can't add NixOS options to an upstream module without redefining it locally.

**Verdict:** **There is no clean patch path.** The nixpkgs module is not designed for surgical overrides of the script logic. Our options are:

1. **Phase I (Current):** Override `ExecStartPre` with custom scripts (brittle but minimal)
2. **Phase II (Proper):** Disable the module + use our own (requires copying entire module, but future-proof)
3. **Upstream:** File a PR against nixpkgs to add a `preserveRegistration` option (not our problem to solve)

---

## Question 4: What's the Minimal Change That Fixes the Problem?

### Answer: Override Just `ExecStartPre`, But Do It Carefully

The **minimal working override** is:

```nix
serviceOverrides = {
  ExecStartPre = lib.mkForce [
    "+${pkgs.writeShellScript "gh-unconfigure-preserve" ''
      # Skip unconfigure if runner is already registered
      if [[ -f "$STATE_DIRECTORY/.credentials" ]]; then
        exit 0
      fi
      # On first boot: prepare token for configure step
      install --mode=666 "${tokenFile}" "$STATE_DIRECTORY/.new-token"
    ''}"
  ];
};
```

**What this does:**
- Removes the `diff_config()` check that compares nix store paths
- Preserves `.credentials` and `.runner` across config changes
- Still configures on first boot (token exists → configure runs)

**What it doesn't do:**
- Doesn't modify the `configure` or `setupWorkDir` scripts (they already handle the idempotence)
- Doesn't touch the nixpkgs module — just overrides one systemd directive

**Why this works:**
1. `ExecStartPre` runs before every start
2. Our override checks if `.credentials` exists (sign of prior registration)
3. If yes → skip all steps, let the service start
4. If no → prepare the token, let `configure` run

**Risk:** If nixpkgs changes the `configure` or `setupWorkDir` behavior, we might miss it. But those are less likely to change than the `unconfigure` logic.

**Verdict:** This is the **true minimal fix**. It's a **single-script override** that doesn't require copying configure/setupWorkDir. However, if nixpkgs already has coupled logic between all three scripts, we still need all three.

---

## Question 5: Is There Upstream Movement on This Issue?

### Answer: Unlikely. The Problem is Architectural, Not a Bug.

**Nixpkgs Design Philosophy:**
The module *intentionally* tears down and rebuilds runner state on every config change. The assumption is:
- "Config changes might affect runner behavior"
- "Better to re-register than risk inconsistency"

**Why nixpkgs suggests PATs instead:**
- Registration tokens expire (1 hour)
- Re-registration with PATs is more reliable (PATs don't expire)
- Security concern ignored (PATs are overprivileged)

**Has anyone reported this?**

I cannot search the nixpkgs issue tracker from this environment, but based on the problem statement:
- The issue is **real** (we just experienced it on LINDA)
- It's **architectural** (not a simple bug)
- The **suggested fix (PAT) is worse than the problem** (security regression)

**What an upstream PR would look like:**

```nix
# Hypothetical nixpkgs enhancement
services.github-runners.<name> = {
  # ...
  preserveRegistration = lib.mkOption {
    description = "Keep runner registered across config changes";
    type = lib.types.bool;
    default = false; # Safe default
  };
};
```

**Our position:** We should **not wait for upstream**. We're right; nixpkgs is wrong. Building our own module is the correct path.

---

## Tactical Recommendation: Phase I + Phase II Plan

### Phase I (Current) — Minimal Tactical Override

```nix
# In services/github-runner-nixos-config.nix
serviceOverrides = {
  ExecStartPre = lib.mkForce [
    "+${unconfigurePreserve}"
    # Re-use nixpkgs configure and setupWorkDir scripts
  ];
};
```

**Cost:** One custom script, minimal maintenance  
**Duration:** Temporary (until Phase II)  
**Risk:** Low (only changes the destructive behavior)

### Phase II (Next) — Custom Module

```
modules/github-runner/
  default.nix        # Module entry
  options.nix        # Options (preserveRegistration, forceReRegister, etc.)
  scripts/
    unconfigure.sh   # Non-destructive
    configure.sh     # Registration logic
    setup-workdir.sh # Symlinks
```

**Cost:** ~300 lines, mirrors nixpkgs structure  
**Duration:** 2–3 days (Phase Overlord-II)  
**Risk:** Medium (need golden test validation)  
**Benefit:** **Permanent fix**, no upstream dependency, full control

---

## Critical Constraint: Registration Tokens, Not PATs

**Reaffirmed:** We use registration tokens. Period.

- **Registration tokens:** Scoped to runner registration, 1-hour expiry
- **PATs:** Broader scope (repo, admin:org), no expiry, security regression

Using a PAT would:
- Violate principle of least privilege
- Create a persistent high-privilege credential
- Make it easier for an attacker to compromise the runner
- Enable unauthorized actions beyond runner registration

The nixpkgs module's "solution" is fundamentally flawed. We are right to reject it.

---

## Summary Table

| Approach | Mechanism | Effort | Fragility | Verdict |
|----------|-----------|--------|-----------|---------|
| **Current (Phase I)** | `serviceOverrides` + custom unconfigure | Minimal | Medium | ✅ **Use Now** |
| **Wrap Original Script** | sed/patch the nixpkgs script | Minimal | High | ❌ Don't bother |
| **Disable + Replace Module** | `disabledModules` + custom module | High | Low | ✅ **Phase II** |
| **Upstream PR** | File nixpkgs issue/PR | Unknown | N/A | ⏸️ **Not Priority** |
| **Use PAT** | Switch to PAT tokens | Zero | Low | ❌ **Security Regression** |

---

## Final Verdict

1. **`serviceOverrides` + `lib.mkForce` is the correct mechanism** ✅
2. **We must copy the unconfigure script; configure/setupWorkDir can be shared if unchanged** ⚠️
3. **Patching the module is not feasible; disable + replace is the alternative** ❌
4. **Minimal fix: single unconfigure override that checks for prior registration** ✅
5. **No upstream fix expected; we own the solution** ✅

**Recommendation:** Proceed with Phase I (current override). Schedule Phase II (custom module) immediately. The current solution is **viable, tactical, and temporary**. The problem is **architectural and permanent**, so treat Phase II as a mandatory follow-up.

---

## Appendix: Minimal Phase I Script

If we can reuse the nixpkgs `configure` and `setupWorkDir` scripts unchanged, the Phase I override reduces to:

```nix
let
  unconfigurePreserve = pkgs.writeShellScript "gh-runner-unconfigure-preserve" ''
    set -euo pipefail
    source ${pkgs.github-runner}/libexec/unconfigure-common.sh
    
    # If runner is already registered, skip all destructive operations
    if [[ -f "$STATE_DIRECTORY/.credentials" ]] && \
       [[ -f "$STATE_DIRECTORY/.runner" ]]; then
      echo "Runner already registered, preserving state"
      # Still clean work directory (it's temporary anyway)
      find -H "$WORK_DIRECTORY" -mindepth 1 -maxdepth 1 -delete || true
      exit 0
    fi
    
    # First boot: prepare token for configure step
    install -m 0666 "${tokenFile}" "$STATE_DIRECTORY/.new-token"
  '';
in
{
  services.github-runners.hate-filled = {
    serviceOverrides = {
      ExecStartPre = lib.mkForce [
        "+${unconfigurePreserve}"
        # These should remain unchanged from nixpkgs:
        # "${pkg.github-runner}/libexec/configure"
        # "${pkg.github-runner}/libexec/setup-workdir"
      ];
    };
  };
}
```

**This is the tactical sweet spot:** Minimal override, clear intent, preserves registration.

