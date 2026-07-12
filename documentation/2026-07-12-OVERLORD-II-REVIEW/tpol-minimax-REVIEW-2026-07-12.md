# OVERLORD-II Goal Validation Review
**Review Date:** 2026-07-12
**Reviewer:** tpol-minimax
**Branch:** `overlord-II`
**Base Commit:** `db90b5d`

---

## Executive Summary

The overlord-II development phase has made **partial progress** on three fronts but is **materially behind plan** on most goals. The branch has accumulated 19 commits since `db90b5d`, but most of that work was unplanned topology-rectification cleanup and documentation. The core Phase B (transformer architecture completion) and Phase C (library split preparation) goals remain **largely incomplete**. SSH multiplexing was attempted but reverted. LLM-CORE re-enable, GitHub runner custom module, and backup topology are untouched.

**Overall Status:** ⚠️ **DEVIATION FROM PLAN — Significant gaps in Phase B/C core objectives**

---

## Phase B Assessment: Complete Transformer Architecture

### B.1: WIP Transformers — mkDnsSettings, mkFirewallSettings, mkNginxSettings

#### mkDnsSettings.nix — ❌ NOT PRODUCTION-READY

```nix
dhcpRange = "10.89.128.100,10.89.128.200,24h";  # WRONG SUBNET — topology uses 10.88.128.0/24
upstreamServers = [ "8.8.8.8" "1.1.1.1" ];       # HARDCODED EXAMPLE DATA
dnsEntries = [ ];                                 # EMPTY — no real DNS data
dhcpHosts = [ ];                                  # EMPTY — no real DHCP hosts
```

**Problems:**
- The DHCP range uses `10.89.128.0/24` but the actual LAN subnet is `10.88.128.0/24` (per `topology/shared.nix` and `topology/cortex-alpha.nix`)
- No static DNS entries (`dnsEntries = [ ]`)
- No DHCP host reservations (`dhcpHosts = [ ]`)
- Returns only hardcoded placeholder data — this is a skeleton, not a working transformer
- Warnings and errors are empty arrays

**Verdict:** This transformer cannot generate correct DNS/DHCP configuration. It must read real data from topology before it can be considered production-ready.

---

#### mkFirewallSettings.nix — ❌ NOT PRODUCTION-READY

```nix
tcpPorts = lib.unique ([ 22 1108 ] ++
  (if machine ? nginx-proxy then [ 443 ] ++ extractServicePorts machine.nginx-proxy else [ ]) ++
  (if machine ? firewall then machine.firewall.allowedTCPPorts or [ ] else [ ]));
```

**Problems:**
- Base ports `[ 22 1108 ]` are hardcoded — no data source
- `extractServicePorts` function attempts to parse `nginx-proxy` backends, but:
  - It splits on `:` and assumes port is at index 1, which is fragile
  - If `nginx-proxy` structure differs from expectations, returns null
- No integration with `topology/<machine>.nix` firewall data (the real firewall rules live in `topology/cortex-alpha.nix.firewall`)
- `firewall.allowedUDPPorts` only includes hub ports and explicit machine firewall rules — no WAN port forwarding data from `topology.<machine>.forwarding`
- `interfaces` field generates empty `{ }` for machines with `lan` — this is incomplete

**Verdict:** This transformer attempts to derive firewall settings from topology, but the actual firewall data in `topology/cortex-alpha.nix.firewall` is not being consumed. The logic is a first-pass sketch, not working code.

---

#### mkNginxSettings.nix — ⚠️ PARTIALLY WORKING — HAS LOGIC FLAWS

```nix
acmeHost =
  if proxies != { } then
    let
      firstDomain = builtins.head (builtins.attrNames proxies);
      parts = lib.splitString "." firstDomain;
    in
    builtins.concatStringsSep "." (lib.drop 1 parts)  # Drops first label — WRONG
  else null;
```

**Problems:**
- The ACME host extraction drops the first label of the domain, which would turn `git.johnbargman.net` into `johnbargman.net` — this happens to work for the current domain structure, but:
  - It assumes the first label is always the subdomain — not necessarily true
  - For `johnbargman.net` itself (no subdomain), it would return empty string
  - The logic is fragile and coincidentally correct, not architecturally sound
- `resolveBackend` function is reasonable but doesn't validate that resolved IPs exist in topology
- `listenAddresses` uses `builtins.attrNames machine.lan` which returns only IPs (since lan is `{ "10.88.128.1" = "enp3s0" }`), which is correct but the variable name is misleading
- Has actual warning generation logic (checks for invalid backend format), but the warnings would need to be plumbed into the module's assertion system

**Verdict:** Has more logic than the others but contains at least one semantic bug (ACME extraction). Not yet validated against golden tests.

---

### B.2: Wired core-router-topology.nix into cortex-alpha? — ❌ NO

**Finding:** `modules/core-router-topology.nix` exists (104 lines, WIP architecture) but is **NOT imported by `machines/cortex-alpha/default.nix`**.

```nix
# machines/cortex-alpha/default.nix (line 23)
imports = [
  ...
  ../../modules/core-router.nix   # ← PRODUCTION MODULE
  # NOTE: enable-wg.nix is for WireGuard CLIENTS, not the hub
  # The hub's WireGuard config comes from core-router.nix via topology
  ...
];
```

**`core-router-topology.nix`** imports:
- `topology/shared.nix` — not `topology/<machine>.nix`
- `mkWireguardSettings.nix`, `mkNginxSettings.nix`, `mkFirewallSettings.nix`, `mkDnsSettings.nix` — the WIP transformers
- `genWireguard.nix`, `genNginx.nix`, `genFirewall.nix`, `genDns.nix` — the WIP generators

**`core-router.nix`** (production) imports the proven transformers:
- `mkWireguardPeers.nix`, `mkTailscaleConfig.nix`, `mkDhcpDns.nix`, `mkNginxProxies.nix`, `mkForwarding.nix`, `mkMonitoringSettings.nix`

**Verdict:** The WIP topology architecture exists but is **dead code** — not wired into any machine. It cannot be validated until it replaces `core-router.nix` on a target machine.

---

### B.3: Backup Topology — ❌ NOT STARTED

**Finding:** No `backup` key exists in any topology file.

```
$ grep -r "backup" topology/*.nix
# No matches
```

The `topology-rectification-2026-06-23.md` plan specifies a backup data model:

```nix
# topology/LINDA.nix
{
  backup = {
    configFile = "rclone-config-file";
    targets = {
      obsidian-v3 = {
        source = "/bulk-storage/88-DB-v3/";
        bucket = "obsidian-v3";
        mode = "bisync";
        interval = 60;
      };
    };
  };
}
```

**Status:**
- `lib/topology/mkBackupSettings.nix` — does not exist
- `lib/topology/genBackup.nix` — does not exist
- No `backup` keys in any topology file
- The plan called this "first-draft WIP in topology.nix" — it was never started

**Verdict:** Backup topology is a planned-but-never-started item.

---

## Phase C Assessment: Library Split Preparation

### Finding: ❌ NO PREPARATION DETECTED

The `topology-rectification-2026-06-23.md` specifies:

```
lib/
├── topology_library.nix     # Library functions that consume topology data
│                            # (consolidated from lib/topology/*.nix, ready for Phase C extraction)
└── topology/                # Current transformer/generator files (to be consolidated)
```

**Status:**
- `lib/topology_library.nix` — **does not exist**
- No Ketchup/Secret-Sauce/Mayo abstractions
- No entry point consolidating transformers/generators for external consumption
- The Phase C three-way split (Ketchup: open-source, Secret-Sauce: proprietary, Mayo: shared) is not reflected in any code or documentation beyond the original architecture description

**Verdict:** Phase C has not been initiated. No library split preparation work has been done.

---

## Additional Goals Assessment

### Topology Rectification — ✅ DONE

**Phases 1-3 from `overlord-II-PLAN.md` were completed** (but outside the planned phase structure):

| Phase | Status | Evidence |
|-------|--------|----------|
| Directory Structure | ✅ Complete | `topology/`, `topology/external/`, `goldens/` created |
| Update Imports | ✅ Complete | All consumers updated to new paths |
| Cleanup | ✅ Complete | `real-topology/` removed (commit `71c6f42`) |

**Evidence:**
```
$ ls topology/
cortex-alpha.nix  default.nix  shared.nix

$ ls goldens/ | wc -l
18

$ ls real-topology/ 2>/dev/null
real-topology/ does not exist
```

The `topology/default.nix` properly imports `shared.nix` and per-machine files, and delegates golden generation to `lib/golden_generator.nix`. The `lib/golden_generator.nix` and `lib/golden_coverage.nix` files were copied from `real-topology/` as planned.

**Deviation from plan:** The work was done in fewer phases than specified in `overlord-II-PLAN.md` (which had 8 phases for topology rectification). The actual execution compressed phases 1-3 into bulk commits rather than incremental per-phase validation.

---

### SSH Multiplexing — ❌ REVERTED

**Timeline:**
- `0d79eea` (2026-07-11): Implemented `mkMultiplexConfig` in `flake.nix`, added `tmpfiles` rules, increased `MaxSessions` to 20
- `8455cbe` (2026-07-12): **Reverted** — `programs.ssh.matchBlocks` does not exist in NixOS 25.11

```
$ git show 8455cbe --stat
 environments/sshd.nix |  2 +-
 flake.nix             | 30 ------------------------------
 2 files changed, 1 insertion(+), 31 deletions(-)
```

**Current state:** SSH multiplexing is not functional. The plan document (`ssh-multiplex-topology-2026-07-03.md`) still exists but is marked "needs redesign using `programs.ssh.extraConfig` instead."

**Verdict:** SSH multiplexing was attempted, failed, and was reverted. The plan needs a new approach before it can be re-attempted.

---

### GitHub Runner Custom Module — ❌ NOT STARTED

**Finding:** `modules/github-runner/` directory does not exist.

```
$ ls modules/github-runner/
modules/github-runner/ does not exist
```

The plan document (`github-runner-custom-module-2026-07-09.md`) specifies:

```
modules/github-runner/
  default.nix        # Module entry point
  options.nix        # Option declarations
  service.nix        # Service configuration
  scripts/
    unconfigure.sh   # Non-destructive unconfigure
    configure.sh     # Registration logic
    setup-workdir.sh # Work directory setup
```

**Current state:**
- The `services/github-runner-nixos-config.nix` file (Phase 1 override) exists and uses `serviceOverrides` to prevent runner destruction
- Phase 2 (custom module with proper identity/config separation) has not been implemented
- The planning document exists but no code has been written

**Verdict:** GitHub runner custom module is planned but not started.

---

### LLM-CORE Re-enable — ❌ DISABLED AND NOT RE-ENABLED

**Finding:** LLM-CORE input is entirely absent from `flake.nix`.

```nix
# flake.nix lines 26-30 (commented out)
    # LLM-CORE: Disabled for overlord-I deployment — re-enable and test as part of overlord-II
    # LLM-CORE = { url = "git+https://gitlab.com/mecha-team-zero/llm-core.git"; };

  # LLM-CORE: Disabled for overlord-I deployment — re-enable and test as part of overlord-II
  outputs = { self, deadnix, determinate, hyprland, lint-utils, nixinate, nixos-hardware, nixpkgs_stable, nixpkgs_unstable, nixpkgs_llm, hype-train-outlaw, star-citizen, parsecgaming, secrix, hype-train-claw, carmelsite, xlibre-overlay, ratty, ikbaeb-th, bargman-assets, denton-glasses, personal-site/*, LLM-CORE*/ }:
```

And in the module imports (lines 549, 573):
```nix
# self.inputs.LLM-CORE.nixosModules.opencode-fleet  # Disabled for overlord-I
```

**Verdict:** LLM-CORE is completely commented out. No re-enable work has been done.

---

## Plan Completeness Assessment

### overlord-II-PLAN.md — Status Table

| Phase | Status in Plan | Actual Status |
|-------|---------------|---------------|
| 0: Pre-flight | ⬜ Pending | ⚠️ Implicit (not explicitly validated) |
| 1: Directory Structure | ⬜ Pending | ✅ Done (but outside plan structure) |
| 2: Update Imports | ⬜ Pending | ✅ Done (but outside plan structure) |
| 3: Cleanup | ⬜ Pending | ✅ Done (but outside plan structure) |
| 4: GitHub Runner | ⬜ Pending | ❌ Not started |
| 5: SSH Multiplexing | ⬜ Pending | ❌ Reverted |
| 6: LLM-CORE | ⬜ Pending | ❌ Not started |
| 7: Documentation | ⬜ Pending | ⚠️ Partial (279ff55) |

**Critical observation:** The topology rectification work (Phases 1-3) was completed **outside the planned phase structure** — it was done as bulk commits (`4b967b0`, `eea67b8`, `71c6f42`) rather than the prescribed incremental worktree-per-phase pattern. This means the validation gate between phases was not enforced as specified.

### topology-rectification-2026-06-23.md — WIP Generator Status

| Transformer | Plan Status | Actual Status |
|-------------|-------------|---------------|
| mkWireguardSettings.nix | ✅ Written | ✅ Written (99 lines, has real data from secrets) |
| mkNginxSettings.nix | ✅ Written | ✅ Written (81 lines, has logic but broken ACME extraction) |
| mkFirewallSettings.nix | ✅ Written | ✅ Written (46 lines, skeleton — no real data) |
| mkDnsSettings.nix | ✅ Written | ✅ Written (29 lines, all hardcoded placeholder data) |
| genWireguard.nix | ✅ Written | ✅ Written (26 lines) |
| genNginx.nix | Written | ❓ Need to verify |
| genFirewall.nix | Written | ❓ Need to verify |
| genDns.nix | Written | ❓ Need to verify |
| mkBackupSettings.nix | Planned | ❌ Not created |
| genBackup.nix | Planned | ❌ Not created |

**Generator verification needed:** `genNginx.nix`, `genFirewall.nix`, and `genDns.nix` exist in `lib/topology/` but their production readiness was not assessed in this review scope.

---

## Detailed Findings

### Finding 1: WIP Transformers Use Placeholder Data

All four WIP transformers (`mkDnsSettings`, `mkFirewallSettings`, `mkNginxSettings`, `mkWireguardSettings`) follow the transformer contract signature:

```nix
# mkXxxSettings: topology -> { machines, warnings, errors }
```

However:
- `mkDnsSettings` returns hardcoded example values that don't match actual topology data
- `mkFirewallSettings` generates rules from hardcoded port lists rather than `topology.<machine>.firewall` data
- `mkNginxSettings` has semantic bugs in ACME host extraction

The `core-router-topology.nix` module wires all four WIP transformers, but they produce incorrect output because the input data they claim to consume doesn't exist in `topology/shared.nix`.

### Finding 2: topology/shared.nix is Insufficient for WIP Transformers

The WIP transformers expect topology data that lives in `topology/<machine>.nix` files (e.g., `topology/cortex-alpha.nix` has `firewall`, `nginx`, `dns`, `forwarding` keys). But `topology/default.nix` only imports `cortex-alpha.nix` as a per-machine override — **no other machine has a detailed topology file**.

This means:
1. `mkNginxSettings` expects `machine.nginx-proxy` — only cortex-alpha has this
2. `mkFirewallSettings` expects `machine.firewall` — only cortex-alpha has this
3. `mkDnsSettings` expects `machine.lan` with DHCP data — only cortex-alpha has this

For all other machines, these transformers would return null or empty data.

### Finding 3: Git History Shows Unplanned Work Dominated

The 19 commits on `overlord-II` since `db90b5d` show a pattern of unplanned work consuming bandwidth:

```
0902092 docs: add overlord-II consolidated execution plan
511141b fix(prometheus): unlimited retention
4e7f989 docs: final deployment status and tool patterns
8691cc6 docs: overlord-II deployment status
ad9770c docs: overlord-II development report
8455cbe revert(ssh): remove matchBlocks
279ff55 docs: update documentation for new topology structure
0d79eea feat(ssh): implement fleet-wide SSH multiplexing
71c6f42 cleanup(topology): remove real-topology/ directory
eea67b8 refactor(topology): update all imports to new topology/ paths
4b967b0 feat(topology): create new directory structure
```

Only 3-4 commits (SSH multiplexing, topology rectification) are related to the planned goals. The rest are documentation, revert, or unrelated fixes.

### Finding 4: The `core-router-topology.nix` is WIP Architecture in Limbo

The AGENTS.md describes `core-router-topology.nix` as:
> "Hub machine module (WIP)"
> "Status: WIP — `enable-wg-topology.nix` is deployed on 13 client machines (replaces legacy `enable-wg.nix`). `core-router-topology.nix` is not yet wired into cortex-alpha."

This confirms the assessment: the WIP architecture exists but is stranded — not deployed to any machine, cannot be validated, and is effectively dead code pending integration.

---

## Risks and Blockers

| Risk | Severity | Status |
|------|----------|--------|
| WIP transformers produce wrong output (wrong subnet, empty data) | HIGH | Unchanged — transformers not fixed |
| WIP architecture (core-router-topology) never gets validated | HIGH | Unchanged — not wired to any machine |
| Backup topology never started | MEDIUM | Unchanged |
| SSH multiplexing redesign not started | MEDIUM | Plan exists but approach needs revision |
| Library split (Phase C) not initiated | MEDIUM | No work detected |
| LLM-CORE remains disabled | MEDIUM | No re-enable work |
| GitHub runner Phase 2 not started | MEDIUM | Phase 1 override is fragile |
| Planned phases not tracked — work done ad-hoc | LOW | Deviation from prescribed methodology |

---

## Recommendations

1. **Phase B priority:** Wire `core-router-topology.nix` into cortex-alpha **one transformer at a time**, validating each against golden tests before proceeding. Start with `mkWireguardSettings` + `genWireguard` since they have the most complete logic.

2. **Fix mkDnsSettings:** The DHCP range must use `10.88.128.0/24` not `10.89.128.0/24`. Replace all hardcoded values with real data from `topology/cortex-alpha.nix.dns`.

3. **Fix mkNginxSettings ACME extraction:** The `lib.drop 1 parts` logic is fragile. Use `lib.removeSuffix` or pattern matching on the domain structure properly.

4. **SSH multiplexing redesign:** Evaluate `programs.ssh.extraConfig` approach specified in the revert commit. Update the plan document with the new approach.

5. **LLM-CORE:** If re-enable is still desired, uncomment the input and module imports in `flake.nix` and run the Phase 6 validation steps from the plan.

6. **Library split:** Before attempting Phase C, the WIP architecture must be validated in production. The three-way split (Ketchup/Secret-Sauce/Mayo) requires a stable interface (the transformer output format) to base the extraction on.

---

## Conclusion

Overlord-II has made partial progress on infrastructure cleanup (topology rectification) but has **not completed the core Phase B or Phase C objectives**. The WIP transformer architecture exists but is not wired into any production machine, cannot be validated against golden tests, and produces incorrect output due to placeholder data. SSH multiplexing was attempted and reverted. The remaining goals (GitHub runner Phase 2, LLM-CORE, backup topology, library split) are planned but not started.

The branch is in a **stabilization state** — infrastructure cleanup is complete, but the forward development goals remain in a early WIP stage.

---

*Review conducted by tpol-minimax — 2026-07-12*
