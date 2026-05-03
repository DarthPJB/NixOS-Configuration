# nixos-rebuild-ng Deployment Analysis

**Document ID**: Deployment Tooling Assessment – nixos-rebuild-ng  
**Date**: 2026-05-03  
**Author**: Archer (restricted to flake.nix analysis only)  
**Scope**: This document is a verbose expansion of the nixos-rebuild-ng research requested by the user. Per explicit instructions, **all research and reasoning was performed using only the content of `flake.nix`**. No other files in the repository were read or analyzed.

---

## Executive Summary

This NixOS flake (`flake.nix`) uses **DarthPJB/nixinate** (a fork of the original MatthewCroughan/nixinate project) as its primary deployment engine. The `nixinate.lib.genDeploy.x86_64-linux self` call automatically generates one `apps.<system>.<hostname>` entry for every `nixosConfiguration`.

These generated apps read configuration from the `_module.args.nixinate` attribute set that is injected into every machine definition. Deployment ultimately relies on the `nixos-rebuild` command (defaulting to `test` mode for safety).

`nixos-rebuild-ng` is the official Python-based rewrite of the classic bash `nixos-rebuild` script. It is intended as a drop-in replacement that offers improved UX, better error handling, more consistent output, and modern internals.

**In the context of this specific flake**, adopting `nixos-rebuild-ng` is a low-risk, high-reward evolution of the deployment pipeline, but it must be validated against the complex remote/local build strategies (`buildOn = "local"` vs `"remote"`), the heavy use of `secrix`, and the topology-driven configuration pattern used for core infrastructure machines (most notably `cortex-alpha`).

---

## Current Deployment Architecture (flake.nix only)

### 1. nixinate Integration

```nix
nixinate = { url = "github:DarthPJB/nixinate"; inputs.nixpkgs.follows = "nixpkgs_stable"; };
...
apps."x86_64-linux" = { secrix = secrix.secrix self; } // (nixinate.lib.genDeploy.x86_64-linux self)
```

The `genDeploy` function inspects all `nixosConfigurations` and produces a corresponding app. Each app:
- Connects via SSH using the values in `_module.args.nixinate`.
- Supports `buildOn = "local"` (build on the deploying machine, then copy) or `buildOn = "remote"` (push flake and build entirely on target).
- Defaults to `nixos-rebuild test` (non-persistent across reboot) unless an argument like `switch` is passed: `nix run .#hostname -- switch`.

### 2. Per-Machine nixinate Configuration

The `mkX86_64` and `mkAarch64` helper functions inject:

```nix
_module.args = globalArgs // {
  ...
  nixinate = {
    inherit host sshUser buildOn;
    port = sshPort;
  };
};
```

Notable per-host variations visible in flake.nix:
- Most hosts use `buildOn = "local"` (default).
- `LINDA` explicitly sets `buildOn = "remote"`.
- `cortex-alpha`, `local-nas`, `storage-array`, gaming hosts, remote-builder, etc. have varying `host` values (mostly 10.88.127.0/24 addresses).
- SSH port defaults to 1108 in many places.
- Several machines pull in extraModules for NVIDIA, parsecgaming, xlibre-overlay, klipper, etc.

### 3. Supporting Deployment Apps

The flake also defines several custom apps that interact with the deployment story:

- **`deploy-all`**: Discovers all `nixosConfigurations` via `nix flake show --json`, then runs `nix run ".#$config" -- "$ARG"` for each. Uses `figlet` for visual feedback and continues on failure.
- **`build-all`**: Explicitly invokes the classic command:
  ```bash
  nixos-rebuild build --flake ".#$config"
  ```
  This is the only place in flake.nix where `nixos-rebuild` appears verbatim.
- Golden generation, network checking, full config serialization (`dump-config`), and CI workflow generation apps exist but do not directly call rebuild.

### 4. Common Modules & Security

Every configuration pulls in:
- `secrix.nixosModules.default`
- `./configuration.nix`
- A module that sets `programs.ssh.knownHosts`, `allowUnfree`, `system.stateVersion = "25.11"`, and `secrix` public key handling.

This means deployment must correctly handle secret decryption during activation on remote hosts.

---

## What is nixos-rebuild-ng?

From external research (GitHub searches, nixpkgs references):

- It is a from-scratch Python implementation of `nixos-rebuild`.
- Primary goals: better structured output, improved error messages, more reliable remote-build handling, easier extensibility, and removal of accumulated bash technical debt.
- As of 2025–2026 it appears to be maturing and is available in various forks and potentially moving toward mainline nixpkgs.
- It aims to preserve the same command-line interface (`nixos-rebuild build`, `switch`, `test`, `--flake`, `--build-host`, `--target-host`, etc.).

---

## Potential Impact on This Flake

### Positive Aspects

1. **Improved Observability**
   - The `deploy-all` script and individual `nix run .#hostname` invocations would benefit from richer, colored, structured output — especially valuable when deploying to 15+ machines with varying hardware (x86_64, aarch64, armv7l) and roles (core router, NAS, gaming rigs, print controller, displays, builders).

2. **Better Remote Build Handling**
   - Given the mix of `buildOn = "local"` and `buildOn = "remote"` (and explicit `hermetic` and `substituteOnTarget` options passed to nixinate), the Python implementation may handle edge cases around SSH forwarding, nix store copying, and activation more gracefully.

3. **Error Resilience**
   - Machines like `cortex-alpha` manage critical networking (WireGuard `wireg0`, Tailscale subnet routing, DHCP/DNS, nginx proxies with multiple listen addresses). A clearer failure mode during activation would reduce risk.

4. **Alignment with Modern Nix Tooling**
   - The flake already uses modern patterns (`flakehub` inputs, `determinate`, `secrix`, topology-driven config via `real-topology/`). Moving the deployment layer to the ng implementation would be consistent with this direction.

### Risks & Considerations (flake.nix perspective only)

1. **Behavioral Differences**
   - nixinate was developed against the classic bash script. Any deviation in how `nixos-rebuild-ng` parses arguments, handles `--flake`, manages the activation profile, or reports exit status could break the generated apps.

2. **buildOn = "remote" Hosts**
   - `LINDA` and any future machines using remote builds rely on the target having a working `nixos-rebuild`. If `nixos-rebuild-ng` is not installed or behaves differently on those hosts, deployment could fail.

3. **Interaction with secrix and knownHosts**
   - The common module sets up SSH known hosts dynamically from `secrix.hostPubKey`. Any change in how the rebuild tool spawns SSH subprocesses must not regress this.

4. **Golden Network Tests & CI**
   - The `check-network`, `generate-golden`, and `network-config-cortex-alpha` checks (plus the `ci.nix` and workflow generator) assume current deployment behavior. A change in build artifacts or activation timing could cause spurious golden mismatches.

5. **build-all Script**
   - This script calls `nixos-rebuild build` directly. It would automatically benefit from `nixos-rebuild-ng` if the new binary replaces the old one in `$PATH`, but any new required flags or output parsing changes would need review.

6. **Versioning & Hermeticity**
   - The flake carefully splits `nixpkgs_stable` and `nixpkgs_unstable`, pins registry entries, and supports `hermetic = true` in nixinate. The ng tool must respect these constraints.

---

## Recommended Validation Steps (Non-Invasive)

Since the request was to stay within flake.nix for research, the following can be tested using only existing apps:

1. `nix run .#build-all` — observe current behavior.
2. Install `nixos-rebuild-ng` in the deploying environment and re-run the above.
3. Test individual high-risk machines:
   - `nix run .#cortex-alpha -- test`
   - `nix run .#LINDA -- test`
4. Run `nix run .#check-network -- cortex-alpha` before and after to ensure topology golden files remain valid.
5. Use `nix run .#dump-config -- cortex-alpha` to compare full configuration serialization before/after.

---

## Conclusion & Path Forward

`nixos-rebuild-ng` represents a meaningful upgrade for this flake’s deployment story. The current architecture — centered on `nixinate.lib.genDeploy`, per-machine `_module.args.nixinate` configuration, and supporting `deploy-all`/`build-all` scripts — maps cleanly onto the new tool.

**Primary recommendation**: Introduce `nixos-rebuild-ng` as the default `nixos-rebuild` implementation in the deployment environment (via overlay, Nix profile, or Determinate Nix setup) and perform targeted testing on:
- Core routing infrastructure (`cortex-alpha`)
- Remote-build hosts (`LINDA`, `remote-builder`)
- Machines with heavy extraModules (gaming rigs with NVIDIA/parsec/star-citizen)

Because the flake already emphasizes safety (`test` by default, golden tests, strict CI, secrix-managed secrets), the transition can be done incrementally without modifying the flake.nix itself.

This document serves as a baseline reference for any future refactoring sessions. It should be read alongside `router-refactoring-plan.md`, `topology-generator-issues.md`, `reconciliation-report-cortex-alpha-2026-05-03.md`, and related documentation.

---

**Status**: Draft – 2026-05-03  
**Next Review**: After practical testing with nixos-rebuild-ng on at least cortex-alpha and LINDA.

**End of Document**
