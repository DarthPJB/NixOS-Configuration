# NixOS-Configuration

My personal NixOS-Configuration, including public keys.


My intent here is to build a reliable way to deploy my workstation, and surrounding homelab (and further surrounding infrastructure) using NixOS, with the hope this may later be expandable to other technological integrations.
This repository now allows me to deploy to any hardware, with my expected environment.

So; here's a little summary for the TL;DR types.

 - Every machine is deployed via VPN, with the command "nix run .#machine-name -- switch"
 - Every machine is fully RAGE-secret encrypted (sops is basically a kids toy full of vulnerabilitites at this point in comparison to secrix @pinktrink keeps the world turning)
 - My greatest weakness is watching ubuntu users, WSL users, and Mac users prove, endlessly, that Nix is superior.

 P.s.

 ## IF THIS CONFIG SAVES YOUR ASS FROM A FIRE; JUST LET ME KNOW I'M NOT ALONE OUT HERE. ONE LITTLE MESSAGE TO LET ME KNOW IT WAS WORTH IT :) 

## Adding a New Machine

For the current add-machine procedure, see `documentation/development-guide.md#adding-a-new-machine`.
The topology-driven workflow requires creating a `topology/<machine>.json` file,
generating a golden test, and running `check-network` before deployment.

## VPN
WireGuard VPN is managed via `modules/enable-wg-topology.nix` on client machines; see `documentation/operations-runbooks.md`.

## AI Infrastructure
Self-hosted LLM inference stack (vLLM, LiteLLM, Open-WebUI) across LINDA and cluster-box. See `documentation/ai-stack.md` for current architecture and `documentation/vllm-architecture.md` for the vLLM-only migration plan.

## CI/CD Pipeline
Automated CI/CD pipeline with configuration generated from Nix evaluation:

### Quick Commands
```bash
# Generate CI workflow (outputs YAML to stdout)
nix run .#generate-ci-workflow > .github/workflows/ci.yml

# Validate generated workflow
nix run .#validate-ci-workflow
```

### CI Features
- **17 Machine Coverage**: All machines tested (12 x86_64, 5 ARM)
- **Job Dependencies**: Validation → Security → Builds → Deploy
- **Artifact Preservation**: 7-day build retention, 30-day logs
- **Enhanced Security**: Gitleaks + pattern matching + IP validation
- **Manual Deployment**: Single-machine builds via workflow_dispatch

### CI Jobs
1. **Validation** - Formatting, flake check, dead code detection
2. **Security** - Gitleaks scanning, secret detection, IP validation
3. **Build x86** - Parallel builds for 12 x86_64 machines
4. **Build ARM** - Parallel builds for 5 ARM machines
5. **Deploy** - Manual trigger for single machine deployment

## Hardware Assimilation (assimilator-probe)

New x86_64 hardware is onboarded via a two-stage bootstrap process using
[assimilator-probe](https://gitlab.com/mecha-team-zero/assimilator-probe)
and [nixinate](https://github.com/Bargman-Tech/nixinate).

### How It Works

1. **Build a generic bootstrap image** — a raw disk image with SSH, DHCP,
   mDNS, and diagnostics. No device-specific config, no secrets, no WireGuard.
2. **Write to USB, boot on target hardware** — the probe gets a DHCP lease
   and publishes via Avahi (`x86-bootstrap.local`).
3. **Discover and extract identity** — SSH in, capture the host key, note
   the hardware from `/run/diagnostics/hardware.json`.
4. **Create the machine config** — write `machines/<hostname>/default.nix`
   with device-specific settings (WireGuard, static IP, services).
5. **Deploy via nixinate** — `nix run .#<hostname> -- switch` pushes the
   actual configuration over SSH.

### Flake Input

```nix
inputs = {
  assimilator-probe.url = "git+https://gitlab.com/mecha-team-zero/assimilator-probe.git";
};
```

### nixosConfiguration Wiring

The `x86-bootstrap` configuration in `flake.nix` consumes assimilator-probe
as a module. Module imports go in the `nixosSystem` module list (NOT in the
machine config's `imports` — flake inputs cannot be referenced there due to
`_module.args` resolution order):

```nix
x86-bootstrap = nixpkgs_stable.lib.nixosSystem {
  modules = [
    nixinate.nixosModules.image-gen           # disko + image generation
    assimilator-probe.nixosModules.default    # SSH, network, diagnostics, banner
    "${assimilator-probe}/users/deployment.nix"
    "${assimilator-probe}/users/inspect.nix"
    ./machines/x86-bootstrap
    {
      nixpkgs.hostPlatform = "x86_64-linux";
      networking.hostName = "x86-bootstrap";
      _module.args.nixinate = {
        host = null;       # no deploy target — this IS the bootstrap
        sshUser = "deploy";
        buildOn = "local";
        port = 1108;
      };
    }
  ];
};
```

### Machine Config

`machines/x86-bootstrap/default.nix` sets assimilator options and the GRUB
EFI removable-media bootloader (required for USB boot):

```nix
{ pkgs, config, lib, ... }:
{
  assimilator = {
    hostname = "x86-bootstrap";
    sshAllowUsers = [ "John88" "deploy" "inspect" ];
    sshAuthorizedKeys = [ (lib.readFile ../../secrets/public_keys/JOHN_BARGMAN_ED_25519.pub) ];
    fleetKeys = [ (lib.readFile ../../secrets/public_keys/JOHN_BARGMAN_ED_25519.pub) ];
    inspectAuthorizedKeys = [ (lib.readFile ../../secrets/public_keys/INSPECT_ED_25519.pub) ];
  };

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;
  # ... kernel params, initrd modules, firmware
}
```

### Build and Burn

```bash
# Build
nix build .#nixosConfigurations.x86-bootstrap.config.system.build.diskoImages \
  --option builders '' --no-link --print-out-paths

# Write to USB
dd if=/nix/store/...-x86-bootstrap-disko-images/main.raw of=/dev/sdX \
  bs=4M status=progress conv=fsync
```

### What the Probe Provides

| Capability | Details |
|-----------|---------|
| SSH | Port 1108, key-only, ed25519-enforced |
| Users | `deploy` (sudo), `John88` (console), `inspect` (read-only) |
| Networking | DHCP on all interfaces |
| Discovery | Avahi/mDNS (`x86-bootstrap.local`) |
| Diagnostics | `/run/diagnostics/hardware.json` (CPU, memory, disks, network) |
| Console | kmscon with hardware acceleration, John88 autologin |
| Banner | SSH login banner with probe identity |

### After Assimilation

Once the probe is on the network and you've created the machine-specific
configuration, deploy it:

```bash
# Temporarily point flake.nix at the device's LAN IP
# Then:
nix run .#<hostname> -- switch --option builders ''
```

The probe's hardware identity (NVMe, MAC addresses, network position) is now
known. The assimilator's job is done — ninate takes over for ongoing
deployment.

### Documentation

- `documentation/x86-bootstrap-deployment-workflow.md` — full step-by-step workflow
- [assimilator-probe readme](https://gitlab.com/mecha-team-zero/assimilator-probe) — module structure, bootloader contract, options reference


