# topology/default.nix
# Entry point for topology data. Imports shared topology and per-machine files.
# Exposes a unified attrset that the library transforms consume.
{ lib, self ? null, ... }:
let
  # Import shared topology (WireGuard IPs, LAN IPs, hub relationships)
  shared = import ./shared.nix { inherit lib; };

  # Import per-machine topology files (detailed config for specific machines)
  # Only cortex-alpha has a detailed topology file currently.
  # Other machines are defined in shared.nix.
  machineFiles = {
    cortex-alpha = import ./cortex-alpha.nix { inherit lib self; };
  };

  # Merge shared topology with per-machine overrides
  # Per-machine files take precedence over shared data
  topology = shared // lib.mapAttrs
    (name: machineCfg:
      let
        sharedCfg = shared.${name} or { };
      in
      sharedCfg // machineCfg
    )
    machineFiles;
in
{
  inherit topology;
}
