# Gate M-0 — Planar Topology Phase M-0 Verification

**Date:** 2026-07-22
**Vetter:** tpol-minimax (via bellana-deepseek execution context)
**Branch:** `overlord-ii-planar-topology`
**Commit:** `9e00fe6` (refactor(planar-topology): M-0 — derive topoIp from JSON registry)

---

## Results

| # | Check | Status | Details |
|---|---|---|---|
| 1 | `topoIp` derives correct WG IPs from JSON | ✅ PASS | Both `shared.nix` compat shim and direct JSON registry produce identical IPs for all 14 WireGuard machines. cortex-alpha→`10.88.127.1`, LINDA→`10.88.127.88`, etc. |
| 2 | `shared.nix` exists as registry compat shim | ✅ PASS | `topology/shared.nix` reads from `mkRegistry.nix` (line 6). Not deleted — still consumed by `enable-wg-topology.nix`. |
| 3 | All 17 nixosConfigurations evaluate | ✅ PASS | All 17 produce valid derivation paths: LINDA, alpha-one, alpha-three, arm-bootstrap, arm-builder, bargman-greeter-vm, beta-one, cortex-alpha, display-1, display-2, gaming-host-1, local-nas, print-controller, remote-builder, remote-worker, terminal-nx-01, terminal-zero |
| 4 | Golden spot-check | ✅ PASS | cortex-alpha: **PASS_IDENTICAL**. LINDA: **PASS_NIXPKGS_DRIFT** (only `crush-0.70.0` removed from nixpkgs). terminal-zero: **PASS_NIXPKGS_DRIFT** (same). |
| 5 | mkRegistry: 0 errors | ✅ PASS | `errors = [ ]` — all 10 validators pass. `warnings = [ ]` — no warnings. |

## Gate Verdict

**APPROVED** ✅ — All conditions satisfied. Proceeding to M-1 execution.

---

### Evidence

#### topoIp values (derived from JSON registry)
```
cortex-alpha  = 10.88.127.1
LINDA         = 10.88.127.88
alpha-one     = 10.88.127.108
alpha-three   = 10.88.127.107
arm-builder   = 10.88.127.43
display-1     = 10.88.127.41
display-2     = 10.88.127.42
gaming-host-1 = 10.88.127.52
local-nas     = 10.88.127.3
print-controller = 10.88.127.30
remote-builder   = 10.88.127.51
remote-worker    = 10.88.127.50
terminal-nx-01   = 10.88.127.21
terminal-zero    = 10.88.127.20
```

#### All 17 evaluations
```
LINDA: OK
alpha-one: OK
alpha-three: OK
arm-bootstrap: OK
arm-builder: OK
bargman-greeter-vm: OK
beta-one: OK
cortex-alpha: OK
display-1: OK
display-2: OK
gaming-host-1: OK
local-nas: OK
print-controller: OK
remote-builder: OK
remote-worker: OK
terminal-nx-01: OK
terminal-zero: OK
```

#### mkRegistry errors
```
{ errors = [ ]; warnings = [ ]; }
```
