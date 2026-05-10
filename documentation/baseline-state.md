# Baseline State (pre topology refactor)

## Machines defined by the flake
The following `nixosConfigurations` exist in `flake.nix` today:

- `beta-one`
- `display-0`
- `display-1`
- `display-2`
- `gaming-host-1`
- `local-nas`
- `print-controller`
- `remote-builder`
- `remote-worker`
- `storage-array`
- `terminal-nx-01`
- `terminal-zero`
- `alpha-one`
- `alpha-two`
- `alpha-three`
- `LINDA`
- `cortex-alpha`

## Topology files currently present
- `topology.nix` (single attrset declaration that mirrors the planned target topology)
- `real-topology/cortex-alpha.nix` (per-machine topology reality and service config)
- `real-topology/default.nix` (helper entrypoint used by golden generation)
- `real-topology/golden/cortex-alpha.json` (reference output for the cortex-alpha golden test)

## Golden tests available today
- `real-topology/golden/cortex-alpha.json` — golden output for `cortex-alpha` (the only golden file currently stored)

## `nix flake check` status (2026-05-10)
Command run: `nix --option builders '' flake check`

Result: ✅ all checks and apps completed; warnings about `stdenv.hostPlatform.system` renaming and the incompatible systems (`aarch64-linux`, `armv7l-linux`) being omitted. The `network-config-cortex-alpha` check produced a diff-free comparison.

## Known issues observed before implementing the new transformer/generator flow
1. `modules/core-router.nix` still imports per-machine topology files (`real-topology/${hostname}.nix`) and never consults `topology.nix`, so the new central data file is unused.
2. The `lib/topology/mkWireguardSettings.nix` transformer and `lib/topology/genWireguard.nix` generator exist but are not wired into any module, leaving their outputs unconsumed.
3. There is only a single golden test (`cortex-alpha`), so the coverage requirement described in the architecture document is not met yet.
4. The propensity to mix `real-topology/cortex-alpha.nix` with the new `topology.nix` makes it unclear whether data duplication will persist during the refactor.
5. No automated validation script currently verifies the presence and parseability of the new topology artifacts, so regression could go unnoticed.
