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


