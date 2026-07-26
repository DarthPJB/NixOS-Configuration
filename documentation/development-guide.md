# Development Guide

Consolidated reference for codebase structure, coding conventions, and development practices.

---

## Repository Structure

### Root Level
- `flake.nix` - Main flake definition with inputs, outputs, and system configurations
- `AGENTS.md` - Instructions for AI agents working on this repository

### Core Configuration Directories
- `machines/` - Machine-specific NixOS configurations
  - One subdirectory per host (e.g., `cortex-alpha/`, `terminal-zero/`)
  - Each contains `default.nix` for primary config and `hardware-configuration.nix` for auto-generated hardware details
- `topology/` - Planar topology data (JSON, single source of truth)
  - `<machine>.json` - Per-machine topology (coordinate, planes, hub relationships, DNS, nginx, firewall, WireGuard)
  - `shared.json` - Cross-host shared data (WireGuard IPs, LAN IPs, hub relationships)
  - `_template.json` - Template for new machines
  - `external/` - Non-Nix-managed systems (APs, external PCs, WireGuard-only peers)
- `goldens/` - Golden test files (sacrosanct)
  - `<machine>.json` - Golden test references for each machine
- `lib/topology/` - Topology transformation functions
  - `mk*.nix` - Transformers (topology data → flat settings)
  - `gen*.nix` - Generators (settings → NixOS config)
  - `validate.nix` - Topology validation
  - `utils.nix` - Shared utilities
- `lib/serialize-config.nix` - The config serializer (used by `dump-config` and `checks.network-config-*`)
- `lib/golden_coverage.nix` - Coverage audit (checks if every machine has a golden)
- `modules/` - NixOS modules
  - `core-router.nix` - Hub machine module (production)
  - `enable-wg-topology.nix` - WireGuard client module (deployed on 13 machines)
- `environments/` - Environment modules for software collections (e.g., `code.nix`, `browsers.nix`)
- `users/` - User account configurations (one file per user)

### Supporting Directories
- `lib/` - Shared utility functions and libraries
- `services/` - Service-specific configurations (e.g., `nextcloud.nix`, `prometheus.nix`)
- `server_services/` - Server-specific service configurations (game servers, etc.)
- `modifier_imports/` - System-wide modifiers and features (virtualization, builders, energy saving)
- `secrets/` - Encrypted secrets managed by secrix
  - `private_keys/` - WireGuard private keys (encrypted)
  - `public_keys/` - Public cryptographic keys (`wireguard/`, `host_keys/`)
- `scripts/` - Utility scripts
- `tests/` - NixOS tests and validation
- `snippets/` - Reusable configuration snippets

### Web and Assets
- `webroot/` - Static web content
- `pkgs/` - Custom package derivations

---

## Code Conventions

### Architecture Overview

The repository uses a **topology-driven architecture** for network configuration. Planar JSON topology data lives in `topology/<machine>.json`, transformation functions in `lib/topology/` convert topology data to NixOS config, and golden tests in `goldens/` validate output.

### Module Organization
- **Flake-based**: All configurations use Nix flakes for reproducibility
- **Modular imports**: Configurations import from `environments/`, `services/`, and `lib/`
- **Machine-specific**: Each machine in `machines/` has its own config importing shared modules
- **Topology-driven**: Network config derived from `topology/*.json` via `lib/topology/` transformers

### File Patterns
- **Options first**: Each module starts with `options` block defining configurable settings
- **Config second**: Followed by `config` block implementing the logic
- **Relative imports**: Use paths like `../../modules/enable-wg-topology.nix` for local modules

### Key Conventions
- **CamelCase variables**: For attribute names (e.g., `enableService`)
- **Kebab-case files**: Filenames use hyphens (e.g., `nextcloud.nix`)
- **Conditional logic**: Use `lib.mkIf` for optional configurations
- **Default values**: Apply with `lib.mkDefault` for overridable settings
- **Executable paths**: Always use `lib.getExe` for tool invocations (never bare command names)

### Common Patterns
- **Package lists**: Group with `with pkgs; [ package1 package2 ]`
- **Service enabling**: `services.myService.enable = true;`
- **Attribute sets**: Format as multi-line for readability
- **String interpolation**: Use `${variable}` for dynamic strings

### Import Hierarchy
- Machines import environments for software stacks
- Environments may import services for specific features
- Libraries provide utilities used across modules
- Modifiers add global system features

### ⚠️ Prohibited Practices

These practices are strictly prohibited in this repository:

- **Docker** — Antithetical to Nix purity
- **Cloud provider dependencies** — Self-hosted infrastructure only
- **Imperative configurations** — Everything must be declarative
- **Unpinned flake inputs** — All inputs must be pinned
- **Committing unencrypted secrets** — Use secrix for all secrets
- **Direct nixpkgs_unstable input access** — Use the `unstable` arg passed through `_module.args`
- **`pkgs.writeShellScript` / `pkgs.writeShellScriptBin`** — Always use `pkgs.writeShellApplication` with explicit `runtimeInputs`
- **Bare command names** (`tar`, `find`, `sleep`) — Always use `lib.getExe` or `lib.getExe'`

---

## Development Workflow

### Pre-Commit Checklist

- [ ] Run `nix fmt` to format code (do NOT run on entire codebase without explicit permission)
- [ ] Run `nix flake check` to validate
- [ ] Run `nix flake show` to verify evaluation
- [ ] Run `nix run .#check-network -- <machine>` to verify topology config
- [ ] Test build with `nixos-rebuild build --flake .#hostname`
- [ ] Write descriptive commit message
- [ ] Verify no secrets are committed

### Adding a New Machine

1. Create topology file: `topology/<machine>.json` (use `_template.json` as reference)
2. Register in `flake.nix` with `mkX86_64` or `mkAarch64`
3. Generate WireGuard keys and encrypt with secrix:
   ```bash
   wg genkey | tee /tmp/priv | wg pubkey > /tmp/pub
   cat /tmp/priv | nix run .#secrix encrypt secrets/private_keys/wireguard/wg_<machine> -- -u John88 -s <machine>
   cp /tmp/pub secrets/public_keys/wireguard/wg_<machine>_pub
   rm /tmp/priv /tmp/pub
   ```
4. Generate golden: `nix run .#dump-config -- <machine> | jq -S . > goldens/<machine>.json`
5. Validate: `nix run .#check-network -- <machine>`
6. First deploy via LAN IP, then switch to WireGuard

### Deployment

```bash
# Deploy a machine (nixinate)
nix run .#hostname -- switch

# Check network config against golden
nix run .#check-network -- hostname

# Dump machine config
nix run .#dump-config -- hostname | jq -S .

# Dry-run activation
nix run .#hostname -- --dry-activate
```

---

## ARM Deployment

ARM deployments use a two-stage process: a generic bootstrap image, then the device-specific configuration deployed over SSH.

### Bootstrap Image

The bootstrap image (`.#packages.aarch64-linux.arm-bootstrap`) is a generic, reusable image for ALL ARM devices.

**What it provides:**
- Open SSH on port 22 (all interfaces)
- Users: John88, deploy, inspect
- Avahi/mDNS discovery (`nixos-bootstrap.local`)
- No WireGuard — that's part of the actual config
- Cross-compiled from x86_64, minimal closure
- `nix.settings.trusted-users = [ "deploy" ]` — required for nixos-rebuild

**Build and flash:**
```bash
nix build .#packages.aarch64-linux.arm-bootstrap --no-link --print-out-paths
dd if=<path>/sd-image/nixos-*-aarch64-linux.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### Device Discovery
```bash
avahi-resolve -n nixos-bootstrap.local
# Or check DHCP leases on your router
ssh -p 22 deploy@<device-ip>
```

### Host Key Extraction
```bash
# Extract public key
ssh -p 22 deploy@<device-ip> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub"
# Store in secrets/public_keys/host_keys/<hostname>.pub

# Extract private key for secrix backup (NOT runtime decryption)
ssh -p 22 deploy@<device-ip> "sudo cat /etc/ssh/ssh_host_ed25519_key" > /tmp/arm-host-key
cat /tmp/arm-host-key | nix run .#secrix encrypt secrets/host_keys/<hostname>_ssh_host_ed25519 -- -u John88
# The SSH host private key is the root of trust for secrix — encrypted copy is for operator backup only
```

### Deploy Over SSH

```bash
# Temporarily point flake.nix at LAN IP, then deploy:
NIX_SSHOPTS="-p 22" nixos-rebuild switch --flake .#<hostname> --target-host deploy@<device-ip> --sudo

# Reset flake.nix to WireGuard IP when done
```

### Determinate Nix and Cross-Compilation

- **Bootstrap image must NOT include Determinate Nix** — `determinate-nixd` cannot be cross-compiled
- ARM machines use `dt = true` (Determinate Nix) — built natively on first deployment
- Local x86_64 host and all remote builders MUST run Determinate Nix to avoid protocol mismatch

---

## Troubleshooting

### Build Failures
- Check syntax with `nix flake check`
- Verify file paths are correct
- Check for missing imports
- Review build logs: `nix log <derivation>`
- Use `nix repl` for debugging

### Deployment Issues
- Test SSH: `ssh -p 1108 deploy@10.88.127.X`
- Verify VPN connectivity
- Check deploy user permissions
- Verify secrix paths

### Secret Issues
- Check secrix configuration
- Verify public keys exist
- Test secret decryption
- Check file permissions
- Verify secret paths

### Network Issues
- Check WireGuard status
- Verify IP assignments
- Test connectivity between hosts
- Check firewall rules
- Verify DNS resolution

---

## Reference

- **Formatter**: `nixpkgs.nixpkgs-fmt` (enforced via `nix flake check`)
- **Dead code**: `deadnix` (enforced via `nix flake check`)
- **Golden tests**: `goldens/<machine>.json` — ground truth, only regenerated for intentional changes
- **Topology**: `topology/<machine>.json` — single source of truth for network configuration
- **Formatter constraints**: Do NOT run `nix fmt` on entire codebase without explicit permission
