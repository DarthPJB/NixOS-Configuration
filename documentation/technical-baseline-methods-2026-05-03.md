# Technical Report: Correct Methods to Capture and Compare Router Baselines
**Date:** 2026-05-03
**Scope:** `cortex-alpha` topology-driven reconciliation

## Purpose
This report defines a robust, repeatable, low-risk method to gather baseline evidence for a mission-critical NixOS router and compare current state to a historical stable state.

---

## Core Principle
For topology refactors, baseline collection must separate:
1. **Operational behavior parity** (what the router actually does)
2. **Serialization/schema/toolchain drift** (how snapshots are represented)

Do not block deployment on representation drift alone.

---

## Canonical Inputs
Use these sources together:

1. **Historical commit(s)** known stable by date/time.
2. **Golden snapshot JSON** from those commits.
3. **Current generated snapshot JSON** using the same extraction surface.
4. **Subsystem-focused comparisons** (WireGuard/firewall/nftables/dnsmasq/nginx/tailscale).
5. **Build success evidence** from the target branch.

---

## Recommended Procedure (Authoritative)

## Phase A — Pin Baseline Revision(s)
Identify baseline candidates around stable date:
```bash
git log --pretty=format:'%h %ad %s' --date=iso --since='2026-04-20' --until='2026-04-25' --all
```
For each candidate commit, extract golden artifact directly:
```bash
git show <commit>:real-topology/golden/cortex-alpha.json > /tmp/baseline-<commit>.json
```

### Why this is correct
- Avoids accidental evaluation drift from current branch code.
- Preserves exactly what that commit considered expected state.

---

## Phase B — Generate Current Snapshot
From working branch:
```bash
nix --option builders '' --extra-experimental-features 'nix-command flakes' run .#generate-golden -- cortex-alpha > /tmp/current.json
```

### Why this is correct
- Uses repository’s own serializer pipeline.
- Produces normalized, machine-comparable JSON.

---

## Phase C — Validate Build + Router Viability
```bash
nix --option builders '' --extra-experimental-features 'nix-command flakes' build --print-out-paths '.#nixosConfigurations."cortex-alpha".config.system.build.toplevel'
```
And check keys exist:
```bash
ls secrets/public_keys/wireguard
```

### Why this is correct
- Build success confirms evaluation + derivation graph consistency.
- Key presence prevents hidden WireGuard peer breakage.

---

## Phase D — Golden Drift Check
```bash
nix --option builders '' --extra-experimental-features 'nix-command flakes' run .#check-network -- cortex-alpha
```
Classify diffs immediately into categories:
- **Operational change** (routing, ports, peers, NAT behavior)
- **Toolchain/store drift** (Nix store path differences)
- **Normalization drift** (canonical formatting fixes, e.g., MAC)
- **Schema drift** (missing vs explicit empty keys)

### Why this is correct
- Fast high-signal confidence gate.
- Prevents overreacting to harmless serializer/toolchain variance.

---

## Phase E — Subsystem Isomorphism Matrix
Compare these keys explicitly between `/tmp/baseline-*.json` and `/tmp/current.json`:

- `networking.wireguard.interfaces`
- `networking.firewall.interfaces`
- `networking.firewall.allowedTCPPorts`
- `networking.firewall.allowedUDPPorts`
- `networking.nftables.enable`
- `networking.nat.externalInterface`
- `networking.tailscale.advertisedRoutes`
- `services.dnsmasq.settings`
- `services.nginx.virtualHosts`

### Why this is correct
These keys represent core router behavior. If they match (or only differ by known-safe normalization), operational parity is preserved.

---

## Interpreting Missing vs Empty (NAT Example)
Example observed:
- Baseline: `networking.nat.internalInterfaces` **missing**
- Current: `networking.nat.internalInterfaces = []`

Interpretation protocol:
1. Verify whether baseline serializer included this key at that time.
2. If key was not serialized historically, classify as **schema drift**.
3. Confirm runtime NAT mode (`networking.nat.enable`) and effective forwarding path.
4. If behavior unchanged, mark **non-operational**.

In this project, baseline serializer did not include `networking.nat.internalInterfaces`, current serializer does; this is expected representation drift.

---

## Anti-Patterns (Do Not Do)
1. **Do not compare raw `nixos-option` output only** without normalized serializer.
2. **Do not trust a single commit baseline** when there was active same-day churn.
3. **Do not treat store path changes as behavioral regression** by default.
4. **Do not collapse operational and metadata differences into one failure class.**

---

## Standardized Output Template
Every reconciliation run should produce:
1. Baseline commit ID(s)
2. Build result
3. Golden result summary
4. Subsystem pass/fail matrix
5. Drift classification table
6. Final GO/NO-GO recommendation

---

## Hardening Recommendations
1. Add `goldenSchemaVersion` into generated JSON.
2. Freeze serializer option set per schema version.
3. Add a comparison script with typed diff classes.
4. Add an allowlist for accepted drifts (e.g., known sysctl additions).
5. Gate deployment on operational diff only; separately track metadata drift.

---

## Minimal Command Runbook
```bash
# 1) Build confidence
nix --option builders '' --extra-experimental-features 'nix-command flakes' build --print-out-paths '.#nixosConfigurations."cortex-alpha".config.system.build.toplevel'

# 2) Golden check
nix --option builders '' --extra-experimental-features 'nix-command flakes' run .#check-network -- cortex-alpha

# 3) Current snapshot
nix --option builders '' --extra-experimental-features 'nix-command flakes' run .#generate-golden -- cortex-alpha > /tmp/current.json

# 4) Baseline snapshot from pinned commit
git show <baseline_commit>:real-topology/golden/cortex-alpha.json > /tmp/baseline.json

# 5) Compare selected subsystem keys (scripted)
# (Use project comparison helper or JSON key-by-key analysis)
```

---

*This method is suitable for mission-critical router reconciliation where false positives must be separated from true operational risk.*
