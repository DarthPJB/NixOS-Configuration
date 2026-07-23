# Gate M-2 — Planar Topology Phase M-2 Verification

**Date:** 2026-07-22
**Vetter:** tpol-minimax (via bellana-deepseek execution context)
**Branch:** `overlord-ii-planar-topology`
**Commit:** `bb83aba` (refactor(planar-topology): M-2 — firewall/DNS/forwarding/tailscale/WireGuard from JSON)

---

## Results

| # | Check | Status | Details |
|---|---|---|---|
| 1 | `topology-derive.nix` produces firewall config from JSON | ✅ PASS | Lines 373-384: `networking.firewall` with `allowedTCPPorts`, `allowedUDPPorts`, per-interface rules |
| 2 | `topology-derive.nix` produces DNS/DHCP config from JSON | ✅ PASS | Lines 387-415: `services.dnsmasq` with dhcp-range, static hosts, upstream servers |
| 3 | `topology-derive.nix` produces forwarding/nftables from JSON | ✅ PASS | Lines 418-449: `networking.nftables.ruleset` with DNAT + masquerade |
| 4 | `topology-derive.nix` produces Tailscale config from JSON | ✅ PASS | Lines 453-461: `services.tailscale` with `--advertise-routes` |
| 5 | `topology-derive.nix` produces WireGuard hub config from JSON | ✅ PASS | Lines 466-513: `networking.wireguard.interfaces` with dynamic peer derivation from mkRegistry |
| 6 | `core-router-topology.nix` deleted | ✅ PASS | File does not exist (`ls: cannot access`, confirmed) |
| 7 | cortex-alpha evaluates without `core-router-topology.nix` | ✅ PASS | `config.networking.hostName` returns `cortex-alpha`; imports list has no reference to `core-router-topology` |
| 8 | All 16 golden checks pass | ✅ PASS | 7 `PASS_IDENTICAL`, 9 `PASS_NIXPKGS_DRIFT` (nixpkgs churn only). **No topology regression.** |
| 9 | All 6 unit test suites pass | ✅ PASS | mkRegistry, mkHorizons, genNginx, genDnsmasqHorizons, genNftablesMatrix, topology-derive — all pass |
| 10 | mkRegistry: 0 errors | ✅ PASS | 31 hosts, 0 errors, 0 warnings |

## Gate Verdict

**APPROVED** ✅ — All conditions satisfied. Proceeding to M-3 execution.

---

### Evidence

#### Golden checks
```
cortex-alpha     PASS_IDENTICAL
LINDA            PASS_NIXPKGS_DRIFT
alpha-one        PASS_NIXPKGS_DRIFT
alpha-three      PASS_NIXPKGS_DRIFT
arm-bootstrap    PASS_IDENTICAL
arm-builder      PASS_NIXPKGS_DRIFT
beta-one         PASS_IDENTICAL
display-1        PASS_NIXPKGS_DRIFT
display-2        PASS_NIXPKGS_DRIFT
gaming-host-1    PASS_IDENTICAL
local-nas        PASS_NIXPKGS_DRIFT
print-controller PASS_NIXPKGS_DRIFT
remote-builder   PASS_IDENTICAL
remote-worker    PASS_IDENTICAL
terminal-nx-01   PASS_NIXPKGS_DRIFT
terminal-zero    PASS_NIXPKGS_DRIFT
FAIL=0
```

#### Unit tests
```
mkRegistry:           {"passed":true,"failed":0}
mkHorizons:           {"passed":true,"failed":0}
genNginx:             {"passed":true,"failed":0}
genDnsmasqHorizons:   {"passed":true,"failed":0}
genNftablesMatrix:    {"passed":true,"failed":0}
topology-derive:      {"passed":true,"failed":0}
```

#### mkRegistry state
```
{"errors":0,"hosts":31,"warnings":0}
```

#### topology-derive.nix capabilities confirmed
- **Firewall** (M-2.1): lines 373-384 — ports, per-interface rules
- **DNS/DHCP** (M-2.2): lines 387-415 — dnsmasq with static hosts, upstream, dhcp-range
- **Forwarding** (M-2.3): lines 418-449 — nftables DNAT + masquerade
- **Tailscale** (M-2.4): lines 453-461 — advertised routes
- **WireGuard hub** (M-2 sup): lines 466-513 — peers from mkRegistry
