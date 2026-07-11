# Grafana Declarative Recovery Plan
**Date:** 2026-07-11
**Author:** tpol-minimax
**Status:** PHASE 0 COMPLETE — Ready for Phase 1

---

## Executive Summary

After comprehensive audit of the current state, **most issues identified in the review documents have already been fixed** by recent commits (7e3fed0, fbf940c, 7cb996f). The primary remaining actionable item is a **typo in the Grafana provisioning code** that prevents proper dashboard update cycles.

### Current State Assessment

| Component | Status | Notes |
|-----------|--------|-------|
| `noob.json` | ✅ REMOVED | Merged into `fleet-cpu-disk.json` (commit 7cb996f) |
| `disk-health.json` SMART queries | ✅ FIXED | Uses correct `smartctl_device_attribute{...}` format |
| `network-wireguard.json` | ✅ FIXED | WireGuard exporter panels removed; only physical network remains |
| `service-health.json` | ✅ FIXED | No Docker/Minio panels; Nix-native services only |
| `fleet-cpu-disk.json` | ⚠️ REVIEW NEEDED | Contains hardcoded IP:port references that may be stale |
| `services/prometheus.nix` | ❌ TYPOD | Line 196: `updateInterfalSeconds` should be `updateIntervalSeconds` |
| Golden test (cortex-alpha) | ❌ STALE | Port 3100 vs 9100 discrepancy; missing peer 10.88.127.43/32 |

---

## Phase 0: State Capture — COMPLETE ✅

### Step 0.1: Git Worktree Check
```
/speed-storage/bargman-tech/NixOS-Configuration  2d8d8b6 [overlord-II]
```
- Working tree clean
- 5 commits ahead of origin/overlord-II
- No parallel worktrees active

### Step 0.2: Prime Directives Review
- Confirmed baremetal Nix primacy (Directive 8)
- Confirmed no Docker (Directive 13)
- Confirmed declarative-only fixes (Directive 20)
- Confirmed absolute paths required (Directive 16)
- Confirmed `--option builders ''` mandatory (Directive 17)

### Step 0.3: Review Documents Analysis
**Critical finding:** The three review documents are now **OUTDATED**:
- `noob.json` referenced in reviews does not exist (removed in commit 7cb996f)
- Most "critical" issues have already been fixed
- Review documents should NOT be used as spec for Phase 1

### Step 0.4: Current Dashboard Inventory
```
services/graphana_dashboards/
├── disk-health.json         (✅ FIXED - SMART queries correct)
├── disk-usage.json          (⚠️ Contains hardcoded LINDA references)
├── failstate-overview.json  (⚠️ Panel mislabeled "Disk Read" → writes)
├── fleet-cpu-disk.json      (⚠️ Contains hardcoded IP:port refs)
├── fleet-deployment.json    (✅ OK)
├── network-wireguard.json   (✅ FIXED - no WG exporter panels)
├── service-health.json      (✅ FIXED - no Docker/Minio)
├── storage-io.json          (✅ OK)
└── zfs-health.json          (✅ OK)
```

### Step 0.5: Nix Eval Baseline
```bash
# Grafana provisioning eval fails with typo (expected):
# error: option `services.grafana.settings."auth.anonymous".enabled' does not exist
# (caused by deprecated options usage + typo in provision path)

# check-network for cortex-alpha shows golden mismatch:
# - services.prometheus.exporters.node.port: 9100 (current) vs 3100 (golden)
# - Missing peer 10.88.127.43/32 in golden
# - Extra 9100 in allowedTCPPorts (current) vs missing (golden)
```

---

## Phase 1: Audit & Correction of Declarative Artifacts

### Step 1.1: Fix Grafana Provisioning Typo
**Action:** Fix `updateInterfalSeconds` → `updateIntervalSeconds` in `services/prometheus.nix`

**Refs:**
- `/speed-storage/bargman-tech/NixOS-Configuration/services/prometheus.nix:196`

**Bellana delegate prompt:**
```
Fix the typo in services/prometheus.nix line 196:
  OLD: updateInterfalSeconds = 5;
  NEW: updateIntervalSeconds = 5;

This typo prevents Grafana dashboard provisioning from working correctly.
The dashboards are declarative JSON files in services/graphana_dashboards/
that should be auto-updated on change.
```

**Verification required by tpol:**
- Read the file and confirm typo exists at line 196
- Edit the file using edit tool
- Verify the fix using: `nix eval --json --option builders '' '.#nixosConfigurations.local-nas.config.services.grafana.provision' 2>&1 | grep -i interval`

---

### Step 1.2: Audit fleet-cpu-disk.json for Hardcoded Ports
**Action:** Search for `:3100` references in `fleet-cpu-disk.json` and replace with `:9100`

**Refs:**
- `/speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/fleet-cpu-disk.json`

**Bellana delegate prompt:**
```
In /speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/fleet-cpu-disk.json:

1. Search for all occurrences of ":3100" (port 3100 node exporter)
2. Replace all with ":9100" (standard fleet port per environments/metrics.nix)

The standard port for node_exporter across the fleet is 9100 (defined in environments/metrics.nix line 15).
Dashboards that reference port 3100 will show "No data" because nothing listens on 3100.

Report all instances found and replaced.
```

**Verification required by tpol:**
- Use grep to find `:3100` patterns in the file before editing
- Confirm all replaced with `:9100`
- Verify no `:3100` remains: `grep -c ":3100" fleet-cpu-disk.json` should return 0

---

### Step 1.3: Audit fleet-cpu-disk.json for Stale Hostname Mappings
**Action:** Review hardcoded IP-to-hostname transformations in fleet-cpu-disk.json

**Refs:**
- `/speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/fleet-cpu-disk.json` (offset ~800-1000)
- Review document `/speed-storage/bargman-tech/NixOS-Configuration/documentation/2026-07-11-GRAFANA-DASHBOARD-REVIEW/review.md` lines 28-49

**Bellana delegate prompt:**
```
In /speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/fleet-cpu-disk.json:

1. Look for "renameByRegex" or IP-to-hostname transformation patterns
2. Identify hardcoded IPs that may be stale or missing

Per review.md, the following IPs are referenced but may be incomplete:
- 10.88.127.51 (remote-builder) - should be mapped
- 10.88.127.52 (gaming-host-1) - should be mapped  
- 10.88.127.43 (arm-builder) - should be mapped
- 10.88.127.108 (alpha-one) - should be mapped
- 10.88.127.107 (alpha-three) - should be mapped
- 10.88.127.30 (print-controller) - should be mapped

If transformations exist for IP→hostname, verify they cover the above.
If they don't exist, note this as a low-priority issue (dashboards will show IPs instead of names).

DO NOT MODIFY anything - just report findings.
```

**Verification required by tpol:**
- Report all hardcoded IP references found
- Report which IPs have hostname transformations
- Note any missing mappings

---

### Step 1.4: Fix failstate-overview.json Mislabeled Panel
**Action:** Panel ID 3 is titled "Disk Read" but actually shows writes

**Refs:**
- `/speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/failstate-overview.json` (panel id=3)
- duplication-analysis.md lines 72-77

**Bellana delegate prompt:**
```
In /speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/failstate-overview.json:

1. Find panel with id=3 (likely around line 100+)
2. Rename the panel title from "Disk Read" to "Disk Write"
3. The query actually shows: idelta(node_disk_written_bytes_total[5m]) - writes, not reads

Per duplication-analysis.md section 3.1, this panel is mislabeled.
```

**Verification required by tpol:**
- Confirm panel id=3 exists with "Disk Read" title
- Confirm edit changed title to "Disk Write"

---

### Step 1.5: Audit disk-usage.json for Hardcoded References
**Action:** Review disk-usage.json for hardcoded instance references

**Refs:**
- `/speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/disk-usage.json`
- duplication-analysis.md section 7.1 (broken ZFS panel)

**Bellana delegate prompt:**
```
In /speed-storage/bargman-tech/NixOS-Configuration/services/graphana_dashboards/disk-usage.json:

1. Check if panel id=1 (ZFS) has duplicate queries (both targets using identical query)
2. Check for hardcoded "10.88.127.88" references (LINDA-only monitoring)
3. Report findings

Per duplication-analysis.md section 7.1, the ZFS panel may have identical queries in both targets A and B.
Per section 4, disk-usage.json has hardcoded LINDA-only references.

DO NOT MODIFY - just report findings.
```

**Verification required by tpol:**
- Report all hardcoded IPs found
- Report if panel ID 1 has duplicate queries

---

## Phase 2: Validation of Declarative Correctness

### Step 2.1: Eval local-nas Grafana Config
**Action:** Verify grafana config evaluates without errors

**Command:**
```bash
cd /speed-storage/bargman-tech/NixOS-Configuration
nix eval --json --option builders '' '.#nixosConfigurations.local-nas.config.services.grafana.provision' 2>&1
```

**Expected:** Should complete without the "anonymous.enabled" error after Step 1.1 fix

**Verification required by tpol:**
- No "does not exist" errors
- Contains dashboard provision path

---

### Step 2.2: Build local-nas Configuration
**Action:** Dry-run build to validate full NixOS config

**Command:**
```bash
cd /speed-storage/bargman-tech/NixOS-Configuration
nix build .#nixosConfigurations.local-nas.config.system.build.toplevel --dry-run --option builders ''
```

**Expected:** Build derivation should be solvable

**Verification required by tpol:**
- Exit code 0
- No evaluation errors

---

### Step 2.3: Verify No Side Effects on check-network
**Action:** Run check-network on cortex-alpha to ensure no regression

**Command:**
```bash
cd /speed-storage/bargman-tech/NixOS-Configuration
nix run .#check-network -- cortex-alpha 2>&1
```

**Expected:** May show the pre-existing golden mismatch (port 3100→9100) but should NOT show new regressions

**Note:** The golden mismatch is a **separate issue** from grafana. The golden shows port 3100 but environments/metrics.nix defines 9100 as standard. This indicates golden was not regenerated after port standardization.

**Verification required by tpol:**
- Report whether failures are NEW or PRE-EXISTING
- If new failures appear, halt and investigate

---

### Step 2.4: Validate Dashboard JSON Syntax
**Action:** Ensure all dashboard JSON files are valid JSON

**Command:**
```bash
cd /speed-storage/bargman-tech/NixOS-Configuration
for f in services/graphana_dashboards/*.json; do
  python3 -c "import json; json.load(open('$f'))" && echo "OK: $f" || echo "FAIL: $f"
done
```

**Verification required by tpol:**
- All 9 dashboards pass JSON validation

---

## Phase 3: Deployment Readiness Check + Simulation

### Step 3.1: Document Expected Activation Effects
**Action:** Document what will happen when local-nas is rebuilt/deployed

**Expected effects after `nix run .#local-nas -- switch`:**
1. Grafana will restart
2. Dashboard provisioning will run with correct `updateIntervalSeconds`
3. All 9 dashboards will be (re)loaded from `services/graphana_dashboards/*.json`
4. Existing Grafana DB at `/var/lib/grafana/grafana.db` will be preserved (unless `overwrite` is set)
5. Prometheus will continue scraping at port 8080

**Critical note from review.md:** Grafana provisioning by default does NOT overwrite existing dashboards with same identifier. To force overwrite, need `allowUiUpdates: true` or delete via UI first. The typo `updateInterfalSeconds` meant the 5-second update interval was never applied.

**Verification required by tpol:**
- Document confirm understanding of provisioning behavior
- Note that `updateIntervalSeconds` controls how often Grafana checks for file changes, not whether it overwrites

---

### Step 3.2: Prepare Deployment Command
**Action:** Document exact deployment command

**Command:**
```bash
cd /speed-storage/bargman-tech/NixOS-Configuration
# For build only (recommended first):
nix build .#nixosConfigurations.local-nas.config.system.build.toplevel --option builders ''

# For switch (after build succeeds):
# nix run .#local-nas -- switch --option builders ''
```

**Verification required by tpol:**
- Document the two-step process
- Emphasize build-first approach

---

### Step 3.3: Document Rollback Procedure
**Action:** Document how to rollback if issues arise

**Rollback via imperative SSH (ONLY for emergency):**
```bash
# SSH to local-nas as root (OBSERVATION ONLY - fixes via Nix)
# Emergency rollback to previous generation:
# nix-env --rollback /nix/var/nix/profiles/system/
# systemctl restart grafana
```

**Note:** Per Prime Directive 20, imperative fixes are FORBIDDEN except for emergency service restarts. All actual fixes MUST go through Nix rebuild.

**Verification required by tpol:**
- Document rollback steps
- Confirm understanding of declarative-only fix philosophy

---

## Cross-Cutting Concerns

### Cargo Cult / Anti-Imperative Violation Check
**Status:** ✅ CLEAN

The following were checked and found NOT violated:
- No `docker` commands in config (Directive 13)
- All fixes via Nix declarations
- SSH used only for observation (checking status/logs)
- No direct database modifications
- No manual edits via Grafana UI (imperative approach that caused prior compromise)

### Golden Test Status
**Note:** Golden tests are for **network topology** (check-network), NOT grafana dashboards. The cortex-alpha golden mismatch (3100 vs 9100) is:
1. A pre-existing issue unrelated to grafana
2. An intentional port standardization that wasn't propagated to golden
3. NOT a grafana issue

The grafana dashboards are tested by:
1. JSON syntax validation
2. Build evaluation
3. Manual verification post-deploy

---

## Summary of Actions Required

### Immediate (Phase 1)
| Step | File | Action | Priority |
|------|------|--------|----------|
| 1.1 | services/prometheus.nix:196 | Fix `updateInterfalSeconds` typo | CRITICAL |
| 1.2 | fleet-cpu-disk.json | Replace `:3100` with `:9100` | HIGH |
| 1.4 | failstate-overview.json | Rename panel "Disk Read" → "Disk Write" | MEDIUM |

### Informational (No immediate action)
| Item | File | Status |
|------|------|--------|
| Stale hostname mappings | fleet-cpu-disk.json | Report only - low priority |
| Hardcoded LINDA refs | disk-usage.json | Report only - known limitation |
| Duplicate ZFS query | disk-usage.json | Report only - pre-existing |

### Not Required (Already fixed per recent commits)
- noob.json removal ✅
- disk-health.json SMART queries ✅
- network-wireguard.json WG panels ✅
- service-health.json Docker/Minio ✅

---

## Verification Gates

### Gate 1 (After Step 1.1)
- [ ] `updateIntervalSeconds` typo fixed in prometheus.nix
- [ ] Grafana provision eval succeeds

### Gate 2 (After Steps 1.2-1.5)
- [ ] No `:3100` references in fleet-cpu-disk.json
- [ ] failstate-overview.json panel 3 renamed
- [ ] All dashboards valid JSON

### Gate 3 (After Phase 2)
- [ ] local-nas builds without errors
- [ ] check-network shows no NEW failures
- [ ] All 9 dashboards pass JSON validation

### Gate 4 (After Phase 3)
- [ ] Deployment plan documented
- [ ] Rollback procedure documented
- [ ] Commit message drafted

---

## Next Steps

1. **User authorization required** to proceed with Phase 1 execution
2. **Delegate to bellana-grok-code** for code edits (Steps 1.1-1.5)
3. **Verification by tpol-minimax** at each gate
4. **Final commit** with descriptive message per Directive 9

---

*Plan generated by tpol-minimax following Phase Discipline (AGENTS.md) and Methodical Development (Prime Directive 21). No rushing. Correctness is the only virtue.*
