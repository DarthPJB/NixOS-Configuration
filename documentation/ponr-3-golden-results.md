# PONR-3 Golden Results

**Date:** 2026-07-20
**Commit (post-fix):** pending this commit

## Classification (16 machines)

| Machine | Result |
|---------|--------|
| cortex-alpha | PASS_NIXPKGS_DRIFT |
| LINDA | PASS_NIXPKGS_DRIFT |
| alpha-one | PASS_NIXPKGS_DRIFT |
| alpha-three | PASS_NIXPKGS_DRIFT |
| arm-bootstrap | PASS_IDENTICAL |
| arm-builder | PASS_NIXPKGS_DRIFT |
| beta-one | PASS_IDENTICAL |
| display-1 | PASS_NIXPKGS_DRIFT |
| display-2 | PASS_NIXPKGS_DRIFT |
| gaming-host-1 | PASS_NIXPKGS_DRIFT |
| local-nas | PASS_NIXPKGS_DRIFT |
| print-controller | PASS_NIXPKGS_DRIFT |
| remote-builder | PASS_NIXPKGS_DRIFT |
| remote-worker | PASS_NIXPKGS_DRIFT |
| terminal-nx-01 | PASS_NIXPKGS_DRIFT |
| terminal-zero | PASS_NIXPKGS_DRIFT |

**FAIL_TOPOLOGY:** 0  
**FAIL_EVAL:** 0

## Post-wire fixes

1. Restored carmelsite flake overlays for remote-worker (CSF/carmel vhosts) — not topology-owned.
2. remote-worker JSON: listenAddresses, nextcloud listenAddress, acmeRoot null.
3. Machine overlay: personal-site WG root + nextcloud exporter credentials.
4. topology-derive: optional acmeRoot passthrough.

## Unit tests

mkRegistry, topology-derive, ponr-subset-equality, genNginx: passed.
