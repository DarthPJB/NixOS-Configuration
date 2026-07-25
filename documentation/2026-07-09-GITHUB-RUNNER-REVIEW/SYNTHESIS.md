# GitHub Runner Module Override — Synthesis

**Date:** 2026-07-09
**Status:** Complete — all agents agree on approach
**Constraint:** Registration tokens only. PATs are wrong. No exceptions.

---

## Consensus

All four agents agree:

1. **`serviceOverrides` + `lib.mkForce` is the correct mechanism**
2. **The conditional `.credentials` check is the correct logic**
3. **All three scripts must be overridden** (they form a unit)
4. **PATs are wrong** — all agents upheld this constraint without exception

## The Implementation

From `bellana-deepseek` — complete code ready to deploy:

**Core logic (unconfigure script):**
```bash
if [[ -f "$STATE_DIRECTORY/.credentials" && -f "$STATE_DIRECTORY/.runner" ]]; then
  echo "Runner already registered — preserving credentials."
else
  echo "No existing registration — preparing first-time configuration."
  install --mode=666 <tokenFile> "$STATE_DIRECTORY/.new-token"
  install --mode=600 <tokenFile> "$STATE_DIRECTORY/.current-token"
fi
find -H "$WORK_DIRECTORY" -mindepth 1 -delete 2>/dev/null || true
```

**configure and setupWorkDir:** Verbatim copies from nixpkgs. Unchanged.

## Behavior Matrix

| Scenario | `.credentials` exist? | What happens |
|----------|----------------------|--------------|
| First install | No | Token copied → configure runs → registration succeeds |
| Reboot | Yes | Skipped — credentials preserved |
| Config change | Yes | Skipped — credentials preserved |
| nixpkgs upgrade | Yes | Skipped — credentials preserved |
| Token rotation | Yes | Skipped — existing registration is valid |
| Manual credential removal | No | Token copied → re-registration |

## Risks Identified

| Risk | Severity | Mitigation |
|------|----------|------------|
| nixpkgs module interface changes | Medium | Pin nixpkgs, diff on upgrades |
| Token expires before first boot | Low | Deploy then boot immediately |
| Config changes don't take effect | Low | Manual re-registration required |
| Corrupted `.credentials` | Low | Delete files, restart → re-registration |

## Verification

After deployment:
```bash
# Check ExecStartPre is our version
systemctl cat github-runner-hate-filled | grep ExecStartPre

# Confirm credentials preserved after restart
ls -la /var/lib/github-runner/hate-filled/.credentials
ls -la /var/lib/github-runner/hate-filled/.runner

# Check service logs
journalctl -u github-runner-hate-filled | grep "already registered"
```

## Phase Plan

- **Phase I (Now):** Override `ExecStartPre` via `serviceOverrides` — this review
- **Phase II (Overlord-II):** Custom module that separates identity from config — `plans/github-runner-custom-module-2026-07-09.md`

---

## Agent Reports

- `tpol-xai-REVIEW-2026-07-09.md` — Structured analysis of root cause and correctness
- `bellana-deepseek-REVIEW-2026-07-09.md` — Complete Nix implementation
- `tpol-minimax-REVIEW-2026-07-09.md` — Risk analysis (359 lines)
- `ezri-claude-haiku-REVIEW-2026-07-09.md` — Tactical review and alternatives

## Conclusion

The override approach is **correct and necessary**. The nixpkgs module is broken by design for registration tokens. Our fix preserves the security model (registration tokens, not PATs) and survives reboots.

**PATs are wrong. We are right. No exceptions.**
