# Nixpkgs Unstable Analysis Report

## Flake Input Definition and Propagation
- `flake.nix` defines `nixpkgs_unstable` as an input from `https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0`
  (Determinate Systems-maintained weekly snapshot of NixOS unstable channel).- Unstable
  input
  is
  imported
  and
  passed
  as
  module
  argument
  via `
  _module.args.unstable = import nixpkgs_unstable { system = "<arch>"; config.allowUnfree = true; };`.
- Applied in `mkX86_64` function for x86_64-linux systems.
- Applied in `mkAarch64` function for aarch64-linux systems.
- Aarch64 configurations additionally use `nixpkgs_unstable.lib.nixosSystem` and reference unstable modules for SD image generation (e.g., `"${nixpkgs_unstable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"`).
- Special case: `beta-one` (armv7l-linux) uses `nixpkgs_unstable.lib.nixosSystem` directly without module args propagation.

## Machine Configurations Accessing Unstable Packages
All NixOS configurations (18 total) receive the `unstable` module argument, but only the following explicitly utilize unstable packages:

1. **Via Module Arguments (environments/browsers.nix)**:
- Machines: LINDA, display-1, display-2, terminal-zero, terminal-nx-01, alpha-two.
- Package: `unstable.vivaldi` (Vivaldi web browser).
- Access Pattern: `{ config, pkgs, unstable, ... }:` in environment module.

2. **Direct Input Access (machines/LINDA/default.nix)**:
- Machine: LINDA.
- Packages: `looking-glass-client`, `scream` (KVM display client and audio redirection utility); commented: `nixd` (Nix language server).
- Access Pattern: Direct flake input reference (`self.inputs.nixpkgs_unstable.legacyPackages.x86_64-linux.<package>`).

## References in Environments
- Only `environments/browsers.nix` accesses unstable via module args.
- No other environments/ modules reference unstable or nixpkgs_unstable.

## Recommendations
- Consider migrating LINDA's direct input access to use module args for uniformity.
- Monitor Determinate Systems weekly snapshots for stability vs. bleeding-edge tradeoffs.
- If additional unstable packages needed, leverage existing module args infrastructure in environment modules.

## Conclusion
- Active but targeted usage of nixpkgs_unstable in 7 machines and 1 environment module.
- Fully integrated via module args; minimal direct input access in one machine.
- Primarily for GUI applications and virtualization tools requiring latest features.
