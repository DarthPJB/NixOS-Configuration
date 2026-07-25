# Overlord-II Review Synthesis

> **Date:** 2026-07-12
> **Branch:** `overlord-II` (12 commits ahead of origin)
> **Reviewers:** tpol-xai, tpol-minimax, bellana-deepseek, ezri-claude-haiku

## Executive Summary

Overlord-II successfully completed **topology rectification** and **fleet deployment** (12 machines). However, the **core Phase B/C objectives remain largely incomplete**. The work that was done is structurally sound — golden tests pass, imports are valid, no dead code — but the scope of what was delivered does not match the original plan.

**Overall Assessment: TOPOLOGY RECTIFICATION SUCCESSFUL / PHASE B/C NOT STARTED**

## Findings Summary

### ✅ What Went Well

| Item | Status |
|------|--------|
| Topology rectification | ✅ Complete — `real-topology/` eliminated |
| Golden integrity | ✅ All 18 goldens identical to v1.9-Golden tag |
| Golden validation | ✅ `check-network` fixed to use `dump-config` |
| Import graph | ✅ All 25 imports resolve to valid paths |
| Dead code | ✅ Zero functional references to `real-topology/` |
| Circular dependencies | ✅ None detected |
| Fleet deployment | ✅ 12 machines deployed and verified via derivation outpath |
| Core router protocol | ✅ Correct three-phase deployment (dry-activate → test → switch) |

### ❌ What Needs Attention

| Item | Severity | Issue |
|------|----------|-------|
| Phase B transformers | **HIGH** | `mkDnsSettings`, `mkFirewallSettings`, `mkNginxSettings` are skeletons, not production-ready |
| Phase C library split | **HIGH** | Not initiated — no Ketchup/Secret-Sauce/Mayo abstractions |
| `generate-golden` app | **MEDIUM** | Produces different format than `dump-config` — would corrupt goldens if used |
| Broken scripts | **MEDIUM** | `scripts/topology-report.sh` and `scripts/validate-new-architecture.sh` reference removed paths |
| SSH multiplexing | **MEDIUM** | `programs.ssh.matchBlocks` not in nixpkgs 25.11 — needs custom module or `extraConfig` approach |
| GitHub runner module | **MEDIUM** | Not started — Phase 2 custom module not built |
| LLM-CORE re-enable | **LOW** | Not started — fully commented out |
| Backup topology | **LOW** | Not started — no backup keys in topology |
| Exporter state bug | **LOW** | Stale `system_path` in state.json after activation |
| Prometheus retention | **INFO** | Unlimited (`0d`) — user decision, disk growth ~500MB/week |

### ⚠️ Directive Violations (from development report)

1. **Implementing without verifying prerequisites** — SSH multiplexing committed without verifying `matchBlocks` exists
2. **Golden regeneration on branch** — Pre-session commit `db90b5d` regenerated goldens with different generator

## Original Goals vs Actual

### Phase B: Complete Transformer Architecture

| Goal | Status | Notes |
|------|--------|-------|
| Finish WIP transformers with real data | ❌ | `mkDnsSettings` has wrong subnet (`10.89` vs `10.88`), empty data |
| Wire `core-router-topology.nix` into cortex-alpha | ❌ | Not wired — cortex-alpha uses production `core-router.nix` |
| Include backup topology | ❌ | No backup keys in topology, no `mkBackupSettings.nix` |

### Phase C: Library Split

| Goal | Status | Notes |
|------|--------|-------|
| Create Ketchup/Secret-Sauce/Mayo abstractions | ❌ | Not initiated |
| Create `lib/topology_library.nix` | ❌ | Does not exist |

### Additional Goals

| Goal | Status | Notes |
|------|--------|-------|
| Topology rectification | ✅ | `real-topology/` eliminated |
| SSH multiplexing | ⚠️ | Needs custom module — `matchBlocks` not in nixpkgs |
| GitHub runner module | ❌ | Not started |
| LLM-CORE re-enable | ❌ | Not started |

## Verified Corrections

### `generate-golden` Format Mismatch — CONFIRMED

The golden files were originally in `generate-golden` format (34 keys, flat: `networking.firewall.allowedTCPPorts`). Commit `db90b5d` regenerated them with `dump-config` format (25 keys, hierarchical: `networking.firewall`). The `check-network` app was then broken until fixed to use `dump-config`.

**Timeline:**
1. `ea80e81` — Golden files: 34 keys (generate-golden format)
2. `db90b5d` — Golden files regenerated: 25 keys (dump-config format)
3. `check-network` still used `generate-golden` — golden tests would FAIL
4. `4f80255` — Fixed `check-network` to use `dump-config` — golden tests pass

### `programs.ssh.matchBlocks` — Does Not Exist in Nixpkgs 25.11

Verified against `/speed-storage/bargman-tech/nixpkgs_stable/nixos/modules/programs/ssh.nix`. The module defines: `extraConfig`, `knownHosts`, `knownHostsFiles`, `forwardX11`, `startAgent`, `agentTimeout`, `ciphers`, `macs`, `kexAlgorithms`, `hostKeyAlgorithms`, `pubkeyAcceptedKeyTypes`, `setXAuthLocation`, `systemd-ssh-proxy`, `askPassword`, `agentPKCS11Whitelist`, `package`.

**No `matchBlocks` option exists.** However, this is Nix — we have full control. Options:
1. Use `programs.ssh.extraConfig` with raw `Match` blocks
2. Create a custom NixOS module that extends `programs.ssh` with `matchBlocks`
3. Add `matchBlocks` directly to the nixpkgs fork

## Structural Health

| Check | Result |
|-------|--------|
| Dead code | ✅ Clean |
| Orphaned files | ✅ None |
| Import graph | ✅ Valid |
| Circular dependencies | ✅ None |
| Golden integrity | ✅ Preserved |
| Documentation | ✅ Updated |

## Actionable Items

### Immediate (before next development session)

1. **Fix or remove `generate-golden` app** — It produces a different format than `dump-config` and would corrupt goldens if used. Either update it to use `serialize-config.nix` or remove it entirely.

2. **Fix broken scripts** — `scripts/topology-report.sh` and `scripts/validate-new-architecture.sh` reference removed `real-topology/` paths.

3. **Document Prometheus unlimited retention** — User decision to keep `retentionTime = "0d"`. Add monitoring for disk usage on local-nas.

### Short-term (next development session)

4. **Phase B: Fix WIP transformers** — `mkDnsSettings` needs correct subnet (`10.88.128.0/24`), real DNS entries, real DHCP hosts. `mkFirewallSettings` needs to consume topology firewall data. `mkNginxSettings` needs ACME logic fix.

5. **Phase B: Wire core-router-topology.nix** — Test with cortex-alpha, validate golden output matches.

6. **SSH multiplexing redesign** — Create custom module extending `programs.ssh` with `matchBlocks`, or use `extraConfig` approach.

### Medium-term

7. **Phase C: Library split preparation** — Create `lib/topology_library.nix` entry point.

8. **GitHub runner custom module** — Build Phase 2 module that separates identity from config.

9. **LLM-CORE re-enable** — Uncomment and test on LINDA and remote-worker.

## Conclusion

The topology rectification work is **structurally sound and well-executed**. The directory restructuring, import updates, and fleet deployment were done correctly with no regressions. Golden files were preserved byte-for-byte.

However, the **core Phase B/C objectives were not addressed**. The WIP transformers remain skeletons with hardcoded/incorrect data. The library split has no preparation work. SSH multiplexing, GitHub runner, and LLM-CORE were not started.

The branch is safe to merge and deploy — the work that was done is correct. But overlord-II is not complete in the sense originally planned.
