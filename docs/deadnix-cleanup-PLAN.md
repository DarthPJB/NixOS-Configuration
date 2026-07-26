# Deadnix Cleanup Plan

## Objective

Fix all deadnix warnings so that `nix run .#checks.x86_64-linux.deadnix` passes
with `--fail` enabled. The `--fail` flag has been committed (a69845c); this plan
covers the cleanup required to make the check green.

**Status:** COMPLETE — all phases executed, deadnix passes with `--fail` (2026-07-25)

## Reference

- **Deadnix output**: `documentation/deadnix-output.txt` (208 lines, 22 warnings)
- **Check definition**: `flake.nix:734-739`
- **Formatter rules**: DO NOT run `nix fmt` on the entire codebase

## Warning Classification

The 22 warnings fall into three categories:

### Category A: Unused Let Bindings (dead code — remove)

Genuinely unused variables. Safe to delete.

| # | File | Binding(s) |
|---|------|------------|
| A1 | `server_services/samba_server.nix:7` | `readFile` |
| A2 | `server_services/game_servers/dragonwilds.nix:54` | `bash` |
| A3 | `server_services/nextcloud.nix:7` | `readFile` |
| A4 | `modifier_imports/pi-firmware.nix:8-13` | `map`, `getExe`, `cfg`, `kernelSrc` |
| A5 | `lib/network-interfaces.nix:7-10` | `mkMerge`, `splitString`, `last` |
| A6 | `lib/topology/mkHorizons.nix:26-31` | `isAttrs`, `isList`, `isString`, `elemAt`, `foldl'`, `toJSON`, `genList`, `match`, `substring`, `typeOf`, `optionals`, `optional`, `filterAttrs` |
| A7 | `lib/topology/mkDnsSettings.nix:8-9` | `utils`, `safeLookup` |
| A8 | `lib/topology/validate.nix:13,25,73,90,372-374` | `isInt`, `splitString`, `errors`, `hostLabel`, `wgRoutingHosts`, `wgRoutingHostnames` |
| A9 | `lib/topology/genNftablesMatrix.nix:33,113` | `hasAttr`, `toString`, `ifaceSubnetMap` |
| A10 | `modules/topology-derive.nix:23-28,54,87` | `match`, `tail`, `genList`, `length`, `listToAttrs`, `attrValues`, `optionals`, `mapAttrs`, `prefixLengthFromSubnet`, `interfaceConfig` |
| A11 | `flake.nix:193` | `mkLibVirtImage` |
| A12 | `tests/topology/genNginx.nix:52` | `nginxEnabled` |
| A13 | `tests/topology/ponr-subset-equality.nix:25-26,105` | `head`, `elem`, `filter`, `listToAttrs`, `mapAttrs`, `mapAttrs'`, `attrValues`, `flatGet` |
| A14 | `tests/topology/mkRegistry.nix:32` | `countWarningsWithSubstr` |
| A15 | `tests/topology/mkHorizons.nix:15,18,43` | `elem`, `attrValues`, `testHubHorizon`, `testLeafHorizon` |
| A16 | `tests/topology/topology-derive.nix:22,84-85,128` | `head`, `attrNames`, `f1HasLan0`, `f1HasWireg0`, `f2Ifaces` |
| A17 | `tests/topology-validation.nix:9` | `validateTopology` |

### Category B: Unused Lambda Arguments — prefix with `_`

Arguments that are part of a callback signature but not used in the body.
Prefix with `_` to signal intentional non-use.

| # | File | Arg(s) |
|---|------|--------|
| B1 | `lib/network-interfaces.nix:45` | `name` → `_name` |
| B2 | `lib/topology/mkWireguardSettings.nix:26` | `machine` → `_machine` |
| B3 | `lib/topology/genNginx.nix:31` | `vhostName` → `_vhostName` |
| B4 | `lib/topology/genNginx.nix:64` | `domain` → `_domain` |
| B5 | `lib/topology/genNginx.nix:86` | `domain` → `_domain` |
| B6 | `lib/topology/mkDhcpDns.nix:23` | `name` → `_name` |
| B7 | `lib/topology/validate.nix:125` | `name` → `_name` |
| B8 | `lib/topology/validate.nix:373` | `n` → `_n` |
| B9 | `modules/enable-wg-topology.nix:81` | `name` → `_name` |
| B10 | `modules/topology-derive.nix:407` | `iface` → `_iface` |
| B11 | `flake.nix:54` | `name` → `_name` |
| B12 | `flake.nix:110` | `old` → `_old` |
| B13 | `flake.nix:261` | `name` → `_name` |
| B14 | `server_services/game_servers/minecraft-curseforge.nix:513` | `name` → `_name` (×2) |

### Category C: Nixpkgs Overlay Arguments — suppress via `--no-lambda-arg`

The `(final: super: { ... })` overlay pattern is idiomatic Nix. These are not
dead code — they are required by the `overrideAttrs` / overlay API. The cleanest
fix is to add `--no-lambda-arg` to the deadnix invocation, which suppresses all
unused lambda argument warnings globally. This is acceptable because Category B
items are also handled (they become informational-only).

| # | File | Arg(s) |
|---|------|--------|
| C1 | `machines/display-2/default.nix:11` | `final` |
| C2 | `machines/display-1/default.nix:89` | `final` |
| C3 | `machines/display-0/default.nix:9` | `final` |
| C4 | `machines/beta-one/1.nix:21` | `final` |
| C5 | `flake.nix:117` | `final`, `prev` |
| C6 | `flake.nix:169` | `final` |
| C7 | `flake.nix:542` | `final` |

**Decision**: If `--no-lambda-arg` is too broad, Category B items must be fixed
first (prefix with `_`), and then `--no-lambda-arg` can be added to suppress only
the overlay pattern warnings. The plan below assumes Category B is fixed.

---

## Phases

### Phase 1: Remove Unused Let Bindings (Category A)

**Goal**: Delete all genuinely unused `let` bindings across 17 files.

**Steps**:

1. **A1-A3**: Remove `inherit (builtins) readFile` from
   `server_services/samba_server.nix:7` and `server_services/nextcloud.nix:7`.
   Remove unused `bash` binding from
   `server_services/game_servers/dragonwilds.nix:54`.

2. **A4**: Remove `map`, `getExe`, `cfg`, `kernelSrc` from
   `modifier_imports/pi-firmware.nix:8-13`. Add a `# WIP` comment preserving
   context for the commented-out implementation block. Verify the file still
   evaluates.

3. **A5**: Remove `mkMerge`, `splitString`, `last` from
   `lib/network-interfaces.nix:7-10`.

4. **A6**: Remove 13 unused bindings from
   `lib/topology/mkHorizons.nix:26-31`. This is the largest single cleanup.

5. **A7**: Remove `utils` and `safeLookup` from
   `lib/topology/mkDnsSettings.nix:8-9`. Also remove the `import ./utils.nix`
   line (the only export consumed was `safeLookup`, which is unused).

6. **A8**: Remove `isInt`, `splitString`, `errors`, `hostLabel`,
   `wgRoutingHosts`, `wgRoutingHostnames` from `lib/topology/validate.nix`.

7. **A9**: Remove `hasAttr`, `toString`, `ifaceSubnetMap` from
   `lib/topology/genNftablesMatrix.nix`.

8. **A10**: Split into two groups in `modules/topology-derive.nix`:
   - **A10a (remove)**: 8 over-broad inherit bindings: `match`, `tail`, `genList`,
     `length`, `listToAttrs`, `attrValues`, `optionals`, `mapAttrs` (lines 23-28)
   - **A10b (preserve with WIP comment)**: `prefixLengthFromSubnet` (line 54) and
     `interfaceConfig` (line 87) — these are WIP scaffold code that builds
     interface address config from JSON topology but is not yet wired into the
     module's config output. Deleting would force reimplementation.

9. **A11**: Remove `mkLibVirtImage` from `flake.nix:193` (and its entire
   function body if it is self-contained and unused).

10. **A12-A17**: Remove unused bindings from test files:
    - `tests/topology/genNginx.nix`
    - `tests/topology/ponr-subset-equality.nix`
    - `tests/topology/mkRegistry.nix`
    - `tests/topology/mkHorizons.nix`
    - `tests/topology/topology-derive.nix`
    - `tests/topology-validation.nix`

**Verification Gate**:
- `nix eval .#checks.x86_64-linux.deadnix --no-build` succeeds (eval phase)
- No new warnings introduced
- `nix run .#checks.x86_64-linux.formatting` still passes

**Executor**: `bellana-deepseek`
**Validator**: `tpol-minimax`

---

### Phase 2: Prefix Unused Lambda Arguments (Category B)

**Goal**: Rename unused lambda arguments with `_` prefix across 14 locations.

**Steps**:

1. **B1-B8**: Prefix unused args in `lib/` files:
   - `lib/network-interfaces.nix` — `name` → `_name`
   - `lib/topology/mkWireguardSettings.nix` — `machine` → `_machine`
   - `lib/topology/genNginx.nix` — `vhostName`, `domain` (×2)
   - `lib/topology/mkDhcpDns.nix` — `name` → `_name`
   - `lib/topology/validate.nix` — `name`, `n`

2. **B9-B10**: Prefix unused args in `modules/`:
   - `modules/enable-wg-topology.nix` — `name` → `_name`
   - `modules/topology-derive.nix` — `iface` → `_iface`

3. **B11-B13**: Prefix unused args in `flake.nix`:
   - Line 54: `name` → `_name`
   - Line 110: `old` → `_old`
   - Line 261: `name` → `_name`

4. **B14**: Prefix `name` → `_name` in
   `server_services/game_servers/minecraft-curseforge.nix` (×2 occurrences).

**Verification Gate**:
- All renamed arguments are confirmed unused in their function bodies
- `nix eval` still succeeds
- Golden tests unaffected (lambda arg names do not appear in evaluated config)
- **Explicit**: Run deadnix without `--no-lambda-arg` and confirm zero
  "Unused lambda argument" warnings remain before proceeding to Phase 3

**Executor**: `bellana-deepseek`
**Validator**: `tpol-minimax`

---

### Phase 3: Suppress Overlay Warnings (Category C)

**Goal**: Handle the `(final: super: { ... })` overlay pattern warnings.

**Steps**:

1. Add `--no-lambda-arg` to the deadnix invocation in `flake.nix:738` with an
   audit comment:
   ```nix
   # NOTE: --no-lambda-arg suppresses ALL unused lambda-arg warnings.
   # Intentional: handles idiomatic (final: super: {...}) overlay patterns.
   # Any new dead lambda args will be silently suppressed — audit annually.
   text = ''exec deadnix --fail --no-lambda-arg --no-lambda-pattern-names "${self}"'';
   ```
   This suppresses all unused lambda argument warnings. After Phase 2, the only
   remaining lambda arg warnings are the idiomatic overlay patterns.

2. Verify the check passes: `nix run .#checks.x86_64-linux.deadnix`

**Verification Gate**:
- `nix run .#checks.x86_64-linux.deadnix` exits 0 with `--fail` enabled
- No warnings printed to stderr
- `nix flake check --option builders ''` passes all checks

**Executor**: `bellana-deepseek`
**Validator**: `tpol-minimax`

---

### Phase 4: Validation & Golden Verification

**Goal**: Confirm no regressions across the fleet.

**Steps**:

1. Run `nix run .#checks.x86_64-linux.deadnix` — must exit 0.
2. Run `nix run .#checks.x86_64-linux.formatting` — must exit 0.
3. Run golden tests for all machines:
   ```bash
   for m in $(ls machines/); do
     nix run .#check-network -- "$m" 2>&1 | tail -1
   done
   ```
4. Run `nix flake check --option builders ''` — all checks pass.

**Executor**: `tpol-minimax`
**Validator**: User sign-off

---

## Commit Strategy

Phase 1 sub-commits by directory for bisection safety:

```
1a: lib/ + lib/topology/     (A5, A6, A7, A8, A9)
1b: modules/ + modifier_imports/  (A4, A10)
1c: server_services/         (A1, A2, A3)
1d: flake.nix                (A11)
1e: tests/                   (A12-A17)
 2: deadnix: prefix unused lambda args (all B items)
 3: deadnix: add --no-lambda-arg + audit comment
 4: deadnix: preserve WIP interfaceConfig scaffold
```

## Execution Order

```
Phase 1 (remove dead bindings — 5 sub-commits)
    ↓ tpol-minimax verification gate
Phase 2 (prefix unused lambda args)
    ↓ tpol-minimax verification gate
    ↓ EXPLICIT: confirm zero lambda-arg warnings BEFORE adding flag
Phase 3 (add --no-lambda-arg + audit comment)
    ↓ tpol-minimax verification gate
Phase 4 (full validation)
    ↓ user sign-off
```

## Risk Assessment

- **Low risk**: Removing unused let bindings cannot change evaluated output.
- **Low risk**: Prefixing lambda args with `_` cannot change evaluated output.
- **Low risk**: `--no-lambda-arg` only suppresses warnings; does not change behavior.
- **Zero risk to goldens**: None of these changes affect the NixOS configuration
  output. Golden tests are a safety net, not expected to fail.

---

## Review Synthesis (2026-07-25)

Two adversarial reviews were conducted: `tpol-minimax` and `bellana-deepseek`.
Key findings verified and incorporated:

### Corrections to Original Plan

1. **A10 split**: `interfaceConfig` and `prefixLengthFromSubnet` in
   `topology-derive.nix` are WIP scaffold code (builds interface address
   config from JSON topology but not wired into module output). Deleting them
   would force reimplementation. **Action**: Remove only the 8 over-broad
   inherit bindings. Preserve the two WIP functions with comments.

2. **A7 verification**: `safeLookup` in `mkDnsSettings.nix` was flagged by
   both reviewers as potentially used. **Verified**: `safeLookup` appears ONLY
   at line 9 (the inherit). It is genuinely unused in the file body. Deadnix
   is correct. The plan is correct.

3. **A8 verification**: Reviewer concern about dual-location removal of `errors`
   (binding + `inherit`) was unfounded. The `inherit warnings errors` is in
   `mkDnsSettings.nix`, not `validate.nix`. No dual-location issue exists.

4. **A10 binding name**: Reviewer claimed plan had wrong binding name (`match`
   vs `elemAt`). **Verified**: Fresh deadnix run confirms `match` is the unused
   binding at line 23, not `elemAt`. The plan is correct.

### Improvements Incorporated

5. **Phase 2→3 gate**: Added explicit step to confirm zero lambda-arg warnings
   before adding `--no-lambda-arg`, preventing the flag from masking missed
   Phase 2 renames.

6. **Audit comment**: Added explanatory comment at `--no-lambda-arg` flag in
   `flake.nix` documenting why the flag exists and the trade-off (permanently
   suppresses all lambda-arg warnings, including future dead code).

7. **WIP preservation**: A4 (`pi-firmware.nix`) and A10 (`topology-derive.nix`)
   now preserve WIP scaffold code with comments instead of blind deletion.

8. **Commit strategy**: Per-directory sub-commits for Phase 1 enable precise
   bisection if a golden test fails.
