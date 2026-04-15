# AGENTS.md - Agent Instructions for NixOS Configuration Repository

## Essential Commands

### Build & Validate
```bash
nix fmt                    # Format all Nix files (REQUIRED before commit)
nix flake check            # Validate flake, run deadnix + nixpkgs-fmt linters
nix flake show             # Verify flake evaluates correctly
```

### Build Specific Machine
```bash
nixos-rebuild build --flake .#<hostname>  # Build without installing
nixos-rebuild build-vm --flake .#<hostname>  # Test in QEMU VM
```

### Deploy (via Nixinate)
```bash
nix run .#<hostname>           # Test deployment (default)
nix run .#<hostname> -- switch # Permanent deployment
nix run .#deploy-all           # Deploy to all hosts (whitelisted)
nix run .#build-all            # Build all configurations
```

### Linting
```bash
nix run .#deadnix  # Check for unused code
```

## Architecture

### Flake Structure
- **`flake.nix`**: Main entry point with `mkX86_64` and `mkAarch64` functions
- **`machines/`**: 19 machine configs, each with `default.nix` + `hardware-configuration.nix`
- **`environments/`**: Software stacks (code.nix, browsers.nix, etc.)
- **`services/`**: Service configs (prometheus.nix, ollama.nix, etc.)
- **`server_services/`**: Server-specific services (ldap.nix, nextcloud.nix, etc.)
- **`modifier_imports/`**: System-wide modifiers (zfs.nix, virtualisation-*.nix)
- **`lib/`**: Shared utilities (wg_peers.nix, mkNftables.nix, etc.)
- **`modules/enable-wg.nix`**: WireGuard VPN module (primary VPN config)

### Machine Configuration Pattern
```nix
# In machines/<hostname>/default.nix
{ config, lib, pkgs, self, hostname, ... }:
{
  imports = [
    ../../environments/code.nix
    ../../services/prometheus.nix
    ./hardware-configuration.nix
  ];
  # Machine-specific config
  networking.hostName = hostname;
  # VPN config via modules/enable-wg.nix
  environment.vpn = {
    enable = true;
    postfix = 20;  # Unique IP: 10.88.127.20
  };
}
```

## Deployment Flow

### Nixinate Configuration
Each machine gets nixinate config in flake.nix:
```nix
nixinate = {
  host = "10.88.127.20";      # WireGuard IP
  sshUser = "deploy";          # Dedicated user (UID 1110)
  buildOn = "local";           # "local" or "remote"
  port = 1108;                 # Custom SSH port
};
```

### Deployment Steps
1. **Test locally**: `nixos-rebuild build --flake .#<hostname>`
2. **Test deploy**: `nix run .#<hostname>` (uses `nixos-rebuild test`)
3. **Permanent deploy**: `nix run .#<hostname> -- switch`
4. **Batch deploy**: `nix run .#deploy-all` (whitelisted hosts only)

### VPN Network
- **Subnet**: `10.88.127.0/24`
- **Gateway**: `cortex-alpha` (10.88.127.1)
- **SSH Port**: 1108 (custom)
- **Deploy User**: `deploy` with NOPASSWD sudo

## Secrets Management (secrix)

### Structure
```
secrets/
├── private_keys/wireguard/wg_<hostname>  # Encrypted private keys
├── public_keys/wireguard/wg_<hostname>_pub  # Public keys
├── public_keys/host_keys/<hostname>.pub  # SSH host keys
└── <service>_secrets  # Service-specific secrets
```

### Adding New Machine Secrets
1. Generate WireGuard keys: `wg genkey | tee priv | wg pubkey > pub`
2. Encrypt private key: `nix run .#secrix create ./secrets/private_keys/wireguard/wg_<hostname> -- -u John88 < priv`
3. Copy public key: `cp pub ./secrets/public_keys/wireguard/wg_<hostname>_pub`
4. Add to `lib/wg_peers.nix`: `"<hostname>" = "<postfix>";`
5. Add SSH host key: `scp user@host:/etc/ssh/ssh_host_ed25519.pub ./secrets/public_keys/host_keys/<hostname>.pub`

### Reference Secrets in Config
```nix
secrix.services.wireguard-wireg0.secrets.<hostname>.encrypted.file = 
  ../../secrets/private_keys/wireguard/wg_<hostname>;
```

## Key Conventions

### File Naming
- **Machines**: `machines/<hostname>/default.nix`
- **Environments**: `environments/<purpose>.nix` (code.nix, browsers.nix)
- **Services**: `services/<service>.nix` (prometheus.nix, ollama.nix)
- **Modifiers**: `modifier_imports/<feature>.nix` (zfs.nix, virtualisation-libvirtd.nix)

### Import Patterns
```nix
# Relative imports from machine configs
imports = [
  ../../environments/code.nix          # Software stack
  ../../services/prometheus.nix        # Service config
  ../../modifier_imports/zfs.nix       # System modifier
  ./hardware-configuration.nix         # Auto-generated hardware
];
```

### Nix Conventions
- Use `lib.mkIf` for conditional config
- Use `lib.mkDefault` for overridable defaults
- Use `with pkgs; [...]` for package lists
- Use `builtins.readFile` for reading external files
- Use `builtins.toString` for number-to-string conversion

## Important Gotchas

### Deployment Requirements
- **VPN Required**: All deployments go through WireGuard (10.88.127.X)
- **SSH User**: Must use `deploy` user (UID 1110) with port 1108
- **Test First**: Always test with `nix run .#<hostname>` before `-- switch`
- **Local Build**: Most machines use `buildOn = "local"` (build locally, copy remotely)

### Network Configuration
- **WireGuard Interface**: Always named `wireg0`
- **Listen Port**: 2108 for WireGuard
- **SSH Port**: 1108 for deployments
- **IP Assignment**: Use unique postfix for each machine (10.88.127.X)

### Secret Handling
- **Never commit decrypted secrets**: Always use secrix
- **Public keys are safe**: Can commit to repository
- **Private keys encrypted**: Must be encrypted before commit

### Flake Inputs
- **Stable nixpkgs**: Primary for all machines
- **Unstable nixpkgs**: Only when required, accessed via `_module.args.unstable`
- **Determinate**: Optional module for some machines (controlled by `dt` parameter)

### Documentation
- **`documentation/`**: Contains `code_structure.md` and `file_structure.md` for reference
- **`flake.lock`**: Pinned dependencies - DO NOT modify without understanding implications
- **Hardware Configs**: Each machine has auto-generated `hardware-configuration.nix` - do not edit manually

### Locale Configuration
- **`locale/`**: Contains network and localization configurations
- **`home_networks.nix`**: WiFi network configurations (contains PSKs - safe to commit per design)
- **`en_gb.nix`**: UK locale settings
- **`tailscale.nix`**: Tailscale VPN configuration

## Common Tasks

### Add New Machine
1. Create `machines/<hostname>/default.nix` and `hardware-configuration.nix`
2. Generate and encrypt WireGuard keys (see Secrets Management)
3. Add to `lib/wg_peers.nix`: `"<hostname>" = "<postfix>";`
4. Add to `flake.nix`: `hostname = mkX86_64 "hostname" { host = "10.88.127.X"; };`
5. Test: `nix fmt; nix flake check; nixos-rebuild build --flake .#<hostname>`

### Add Package to Environment
1. Edit `environments/<environment>.nix`
2. Add to `environment.systemPackages`
3. Test: `nixos-rebuild build --flake .#<hostname>`

### Add Service
1. Create or edit `services/<service>.nix`
2. Import in machine or environment config
3. Configure service options
4. Test: `nixos-rebuild build --flake .#<hostname>`

## Troubleshooting

### Build Failures
```bash
nix flake check          # Check for syntax errors
nix log <derivation>     # View build logs
nix repl                 # Interactive evaluation
```

### Deployment Issues
```bash
ssh -p 1108 deploy@10.88.127.X  # Test SSH connectivity
nix run .#<hostname>            # Test deployment
```

### Secret Issues
```bash
nix run .#secrix -- --help     # Check secrix commands
ls secrets/public_keys/        # Verify public keys exist
```

## Repository Structure
```
├── flake.nix              # Main flake with machine definitions
├── machines/              # 19 machine configurations
├── environments/          # 26 environment modules
├── services/              # 7 service configurations
├── server_services/       # 11 server service configs
├── modifier_imports/      # 19 system modifiers
├── lib/                   # 8 shared utilities
├── modules/enable-wg.nix  # WireGuard VPN module
├── users/                 # 3 user configs
├── secrets/               # Encrypted secrets (secrix)
└── documentation/         # 2 documentation files
```

## Key Files
- **`flake.nix`**: Machine definitions and deployment apps
- **`configuration.nix`**: Base config for all machines (imports locale, users, environments)
- **`modules/enable-wg.nix`**: WireGuard VPN configuration (primary VPN module)
- **`lib/wg_peers.nix`**: VPN peer list generator
- **`lib/mkNftables.nix`**: Network address translation (NAT) rule generator
- **`lib/mkProxyPass.nix`**: Nginx reverse proxy configuration generator
- **`users/deployment.nix`**: Deploy user (UID 1110) with NOPASSWD sudo for port 1108
- **`users/darthpjb.nix`**: Primary user (UID 1108, username John88)
- **`locale/home_networks.nix`**: WiFi network configurations (contains PSKs)
- **`secrets/public_keys/`**: Public keys (safe to commit)
- **`secrets/private_keys/`**: Encrypted private keys

## Critical Patterns

### Machine VPN Setup
All machines use `modules/enable-wg.nix` with this pattern:
```nix
environment.vpn = {
  enable = true;
  postfix = 20;  # Unique IP: 10.88.127.20
};
```

### Network Configuration
- **cortex-alpha**: Router/gateway with NAT and port forwarding
- **mkNftables**: Generates NAT rules for port forwarding
- **mkProxyPass**: Generates nginx reverse proxy configs for internal services

### User Access
- **John88 (UID 1108)**: Primary user, wheel group, authorized SSH keys
- **deploy (UID 1110)**: Deployment user, NOPASSWD sudo, SSH port 1108 only
- **SSH Access**: Port 1108 for deploy user, standard port 22 for John88

### Flake Builder Functions
- **`mkX86_64`**: Creates x86_64-linux configurations with optional determinate module
- **`mkAarch64`**: Creates aarch64-linux configurations for ARM devices
- Both functions accept `dt` parameter to control determinate module inclusion

### Important Constraints
- **No Docker**: Docker is prohibited per prime directives
- **No Cloud**: Cloud providers prohibited except where explicitly authorized
- **Nix-shell Only**: Use `nix-shell` to acquire tools, never install into environment
- **Absolute Paths**: All file operations must use absolute paths
- **Git Commit**: Always commit work with descriptive messages