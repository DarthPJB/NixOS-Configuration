# GitHub Runner Module Override — Risk Analysis
**Review Date:** 2026-07-09
**Reviewer:** tpol-minimax
**Focus:** ONLY the github-runner module override. Nothing else.

---

## Executive Summary

This document analyzes risks for implementing a module override that fixes the nixpkgs `github-runner` module's destructive registration behavior. The nixpkgs module destroys persistent runner registration on every config change + reboot by running `config.sh destroy` before `run.sh run`. Our override modifies `ExecStartPre` to preserve registration state.

**CRITICAL SECURITY CONSTRAINT:** This implementation uses registration tokens (ephemeral, 1-hour expiry), NOT personal access tokens (PAT). PATs are never acceptable. The security model depends on this distinction.

---

## 1. NIXPKGS MODULE UPDATE RISKS

### 1.1 Interface Drift

**Risk:** When nixpkgs updates the `github-runner` module, the override may break silently or catastrophically.

**Breakage Scenarios:**

| Change Type | Impact | Detection Difficulty |
|-------------|--------|---------------------|
| `ExecStartPre` path/format change | Override targets wrong command; registration loop or silent failure | High (runtime only) |
| New `ExecStartPre` steps added | Pre-existing steps run BEFORE our preservation check; state still destroyed | Medium |
| Module renamed or restructured | Override has no effect; runners re-register every boot | Low (audit catches) |
| `serviceOverrides` attribute renamed | NixOS module error on eval | Low (caught at build) |

**Detection Strategy:**
```nix
# Verify override is actually applied at eval time
assertion = config.services.github-runners.<name>.serviceOverrides.ExecStartPre != null;
```

**Mitigation:** Pin nixpkgs version in flake inputs. Monitor nixpkgs-channels for github-runner module changes.

### 1.2 Store Path Compatibility

**Risk:** The nixpkgs module uses hardcoded nix store paths (e.g., `/nix/store/...-github-runner-2.4.6/run.sh`). Our override script must reference these paths correctly.

**Failure Mode:**
- Original: `${pkgs.github-runner}/bin/github-runner-runner.sh`
- Hardcoded in module: `/nix/store/...-github-runner-2.4.6/bin/Runner_ */run.sh`
- If our script assumes a different store path, runner fails to start

**Mitigation:**
- Always use `config.services.github-runners.<name>.package` to derive correct paths
- Never hardcode store paths in override scripts
- Test with `nix build` before deployment

---

## 2. TOKEN LIFECYCLE RISKS

### 2.1 Token Expiry Before First Boot

**Risk:** Registration token (1-hour expiry) expires before the machine boots and attempts registration.

**Scenario:**
1. Token generated at T+0
2. Machine built, deployed, powered off
3. Machine booted at T+1:05 (token expired)

**Failure Mode:**
- Runner fails to register
- Service enters crash loop
- No recovery without new token

**Mitigation:**
- Token refresh mechanism via secrix (token file updated before boot)
- Or: Use PAT-free registration token rotation via GitHub API
- Or: Accept boot dependency on token freshness (deploy then boot immediately)

### 2.2 Token Expires During Registration

**Risk:** Token expires mid-registration.

**Scenario:**
1. Registration begins (token valid)
2. Network latency delays step 3
3. Token expires before registration completes

**Failure Mode:**
- Partial registration state in `.credentials`
- GitHub shows runner as "never contacted" (ghost runner)
- Re-registration attempts fail (token invalid)

**Mitigation:**
- Implement retry with fresh token detection
- Check token freshness before registration attempt:
  ```bash
  TOKEN_AGE=$(date -d "$(stat -c %y "$TOKEN_FILE")" +%s)
  CURRENT_AGE=$(date +%s)
  if (( CURRENT_AGE - TOKEN_AGE > 3500 )); then  # 58 min buffer
    exit 1  # Token too old, fail fast
  fi
  ```

### 2.3 Missing Token File

**Risk:** `tokenFile` path doesn't exist at service start.

**Failure Modes:**
| Cause | Behavior | Recovery |
|-------|----------|----------|
| secrix decryption failed | Service fails to start; systemd marks dead | Manual intervention |
| Path wrong in config | NixOS eval error (caught early) | Fix config |
| File deleted between eval and run | Runner crashes; restart loop | Check file existence in ExecStartPre |

**Mitigation:**
```bash
# In ExecStartPre, before ANY registration attempt
if [ ! -f "$TOKEN_FILE" ]; then
  echo "FATAL: Token file $TOKEN_FILE not found" >&2
  exit 1
fi
```

---

## 3. STATE DIRECTORY PERMISSIONS

### 3.1 Permission Model Summary

| Operation | User | Purpose |
|-----------|------|---------|
| `config.sh unconfigure` | root (`+` prefix) | Clean up service user credentials |
| `run.sh run` | service user | Register and run runner |
| `.credentials` directory | service user | Stores registration |

**Critical Insight:** The `+` prefix on `ExecStartPre` runs that step as root. This is required for `config.sh unconfigure` to work correctly (it needs to operate on files owned by the service user). Our preservation logic runs as root when using `+`.

### 3.2 Permission Failure Modes

**Risk 1:** Service user cannot read `.credentials` after root modifies it
```bash
# If unconfigure runs (as root), it may change ownership
# Then run.sh (as service user) cannot access
```
**Mitigation:** Never let unconfigure run. Our override prevents this.

**Risk 2:** Root-owned token file unreadable by service user
**Actual:** Token file is world-readable (secrix decrypts to mode 0644). This is acceptable since the token is already exposed to the runner process.

**Risk 3:** State directory permissions prevent registration update
**Actual:** State dir is `0750` owned by service user. Root can still access via `+`.

---

## 4. RECOVERY SCENARIOS

### 4.1 Corrupted `.credentials` File

**Risk:** `.credentials` exists but is corrupted (partial write, disk error).

**Detection:**
```bash
# In ExecStartPre, before deciding to preserve
if [ -f "$CREDENTIALS_FILE" ]; then
  # Verify it's valid JSON and has expected fields
  if ! python3 -c "import json; json.load(open('$CREDENTIALS_FILE'))" 2>/dev/null; then
    # Corrupted or invalid
    rm -f "$CREDENTIALS_FILE"
  fi
fi
```

**Recovery:** If corrupted, the runner will re-register (creating new `.credentials`). This is acceptable behavior.

### 4.2 Registration Succeeds But Runner Crashes Before Starting

**Risk:** Runner registers with GitHub, gets `.credentials`, then crashes before the `run.sh` main loop starts.

**Scenario:**
1. `run.sh run` starts
2. Token read, API call succeeds
3. `.credentials` written
4. Runner process crashes (OOM, SIGKILL, etc.)
5. Service restarts
6. GitHub shows runner as "offline" but registered

**Failure Mode:**
- Ghost runners accumulate on GitHub
- Each reboot/crash creates orphaned runner entries
- Runner eventually starts but appears as "first connection" to GitHub

**Mitigation:**
- Implement graceful shutdown handler
- Use systemd `TimeoutStartSec` to allow registration to complete
- Periodically clean ghost runners via GitHub API (CI job)

### 4.3 Runner Registered But Token File Missing at Subsequent Boots

**Risk:** Registration persists across reboots (good!), but token file is missing on reboot.

**Scenario:**
1. First boot: Token file exists, registration succeeds, `.credentials` created
2. Token file deleted/corrupted
3. Reboot
4. Runner cannot re-register (no token), but `.credentials` still valid

**Actual Behavior:** Runner uses `.credentials` to reconnect without token! This is the intended persistence behavior.

**Edge Case:** GitHub may have expired the runner registration (if `disableAuto退役` is not set). In this case, runner falls back to attempting re-registration (which fails without token).

---

## 5. TESTING STRATEGY

### 5.1 Unit Testing (Override Logic)

```nix
# Test: Preserved state is detected correctly
testPreservationLogic = import ./test-github-runner-preservation.nix;
testPreservationLogic = {
  hasCredentials = {
    input = { credentialsExist = true; credentialsValid = true; };
    expected = "preserve";
  };
  noCredentials = {
    input = { credentialsExist = false; };
    expected = "register";
  };
  corruptedCredentials = {
    input = { credentialsExist = true; credentialsValid = false; };
    expected = "register";
  };
}
```

### 5.2 Integration Testing

**Test Harness Requirements:**
1. VM with github-runner module override applied
2. Mock GitHub API (or use test organization)
3. Simulate:
   - Fresh registration
   - Config reload (should NOT re-register)
   - Reboot (should NOT re-register)
   - Corrupted credentials (should re-register)
   - Missing token file (should fail gracefully)

**Test Cases:**
| Test | Expected Outcome |
|------|------------------|
| Fresh boot, token valid | Registration succeeds |
| Config reload | No re-registration; runner continues |
| Reboot | No re-registration; runner reconnects |
| Corrupted `.credentials` | Re-registration, new `.credentials` |
| Token expired | Fail at ExecStartPre (detected early) |
| Missing token file | Fail at ExecStartPre (detected early) |

### 5.3 Smoke Test (Manual)

```bash
# On deployed machine:
systemctl status github-runner-<name>
journalctl -u github-runner-<name> -n 50 | grep -E "(credentials|register|token)"
# Verify: No "config.sh destroy" in logs after initial registration
```

---

## 6. SECURITY CONSIDERATIONS

### 6.1 Registration Token vs PAT

**Registration Token Properties:**
- Ephemeral: 1-hour expiry
- Scoped to: Organization + repository
- Cannot: Access source code, manage other runners, view secrets
- Can: Register a runner, receive work, report status

**PAT Properties (NEVER USE):**
- Long-lived: No automatic expiry
- Scoped to: Whatever scopes were granted
- Can: Full API access, source code access, secret management
- Risk: Token exfiltration = full account compromise

**Enforcement:**
- Code review: PAT usage is a blocking review comment
- Linting: Reject any `tokenFile` content that resembles a PAT pattern
- Monitoring: Log token source on service start

### 6.2 Token File Permissions

**Current Model:** secrix decrypts to world-readable file (`0644`)

**Acceptability:** YES, because:
- Runner process already has access to the token (needed for registration)
- Token is useless after expiry (1 hour)
- Alternative (0600) prevents even reading for debugging

**Risk:** Malicious local user reads token, registers their own runner within the hour

**Mitigation:** Local user mitigation is out of scope (local users already have runner code execution). Token expiry limits exposure window.

---

## 7. DEPLOYMENT CHECKLIST

Before deploying the override:

- [ ] Override evaluated against current nixpkgs version
- [ ] `ExecStartPre` path tested in VM
- [ ] Token refresh mechanism confirmed working with secrix
- [ ] Permission model verified (root vs service user)
- [ ] Corrupted credentials detection implemented
- [ ] Missing token file detection implemented
- [ ] Integration test suite passes
- [ ] Golden test generated (if applicable)
- [ ] Rollback plan documented

---

## 8. FAILURE MATRIX

| Failure Mode | Detection | Impact | Recovery |
|--------------|-----------|--------|----------|
| Module interface changed | Nix eval warning | Registration broken | Re-pin nixpkgs, audit override |
| Token expires before boot | Service fails to start | Runner never registers | Refresh token via secrix |
| Token expires during registration | Crash loop | Ghost runner on GitHub | Manual cleanup, new token |
| Missing token file | ExecStartPre fails | Runner doesn't start | Fix secrix decryption |
| Corrupted `.credentials` | Runner re-registers | Ephemeral runner (not persistent) | Accept or restore backup |
| Runner crashes post-registration | Ghost runner | Orphaned runner on GitHub | Periodic cleanup job |
| nixpkgs update changes ExecStartPre format | Silent breakage | State destroyed on config change | Pin nixpkgs, monitor updates |

---

## 9. RECOMMENDATIONS

### High Priority
1. **Pin nixpkgs version** for github-runner deployments until override is proven stable
2. **Implement token age check** in ExecStartPre (fail fast if token > 50 minutes old)
3. **Verify `.credentials` validity** before deciding to preserve state

### Medium Priority
4. **Add integration tests** that simulate all failure modes
5. **Document token refresh procedure** for operators
6. **Create ghost runner cleanup** CI job

### Low Priority (Nice to Have)
7. Expose token age as metric (Prometheus)
8. Alert if runner registration age exceeds expected lifecycle

---

## 10. REFERENCES

- nixpkgs `services/github-runners.nix` module
- GitHub Runner Registration API (ephemeral tokens)
- secrix secret management system (token decryption)
- Existing overrides in codebase: `minecraft-curseforge.nix`, `terratech.nix`

---

**END OF REVIEW**
