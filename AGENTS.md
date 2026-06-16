## Development Velocity

Current development is phased. Each phase builds on the previous.

### Phase A: Backup Capabilities
1. ~~Create backup capabilities proposal and report~~ ✅ (`documentation/backup-capacity-report.md`)
2. ~~Implement minimal phase-1 backup~~ ✅ (`lib/rclone-target.nix` extended with `mode`, `calendar`, `bwlimit`, `preExec`; example in `snippets/gaming-host-1-daily-backup.nix`)

### Phase B: Complete Transformer Architecture
1. Finish WIP transformers (`mkDnsSettings`, `mkFirewallSettings`, `mkNginxSettings`) with real data
2. Wire `core-router-topology.nix` into cortex-alpha, validate golden tests match
3. Include backup topology as first-draft WIP in `topology.nix`

### Phase C: Library Split
Split infrastructure into separate modular library components:
- **Ketchup** — The open-source, freely distributable library (generic NixOS modules, topology engine, transformers, generators)
- **Secret-Sauce** — The closed-source Bargman proprietary library (machine configs, secrets, service definitions, game servers)
- **Mayo** — Helpers and utilities shared between both (shared functions, validation, common patterns)

## Architecture

### CRITICAL: Formatter Configuration
**DO NOT CHANGE THE FORMATTER CONFIGURATION** without explicit user approval.
- Current formatter: `nixpkgs.nixpkgs-fmt`
- Check: `lint-utils.linters.x86_64-linux.nixpkgs-fmt`
- These MUST match. Changing one without the other breaks the build.
- Do NOT run `nix fmt` on the entire codebase without explicit permission.

### CRITICAL: Git Worktree Workflow

**Always use worktrees for parallel development.** Multiple agents or users working on the same repo simultaneously will cause file contention and merge conflicts without worktrees.

#### Before Starting Work — Check Your Location
```bash
# ALWAYS check which worktree you're in before making changes:
git worktree list
# Output shows all active worktrees and their branches:
#   /speed-storage/repo/DarthPJB/NixOS-Configuration  4a0ad55 [main]
#   /tmp/nixos-agent-a                                abc1234 [feat/validation]
#   /tmp/nixos-agent-b                                def5678 [feat/topology]

# If you're in the main repo and another agent is active, CREATE A WORKTREE
```

#### Creating a Worktree for Feature Work
```bash
# Create a new worktree with a descriptive branch name:
git worktree add /tmp/nixos-<descriptive-name> -b <branch-name>

# Example:
git worktree add /tmp/nixos-validation-fix -b fix/silent-dhcp-drops
```

#### Working in a Worktree
```bash
# Navigate to your worktree:
cd /tmp/nixos-validation-fix

# Make changes, commit as normal:
git add <files>
git commit -m "fix: description"

# The worktree is a FULL repo — all git commands work
```

#### Merging Worktree Changes Back
```bash
# From the MAIN repo:
cd /speed-storage/repo/DarthPJB/NixOS-Configuration
git merge <branch-name>        # e.g., git merge fix/silent-dhcp-drops

# Clean up the worktree:
git worktree remove /tmp/nixos-validation-fix
```

#### Rules
1. **NEVER work on the same branch in two worktrees** — git will refuse
2. **Always check `git worktree list`** before starting work
3. **Use descriptive paths**: `/tmp/nixos-<purpose>` (e.g., `/tmp/nixos-validation-fix`)
4. **Use descriptive branch names**: `fix/...`, `feat/...`, `refactor/...`
5. **Clean up worktrees when done** — stale worktrees waste disk space
6. **Agents should suggest worktree creation** when parallel work is detected

### CRITICAL: Golden Test (Simulation-Driven Development)
The golden test is our primary integrity mechanism — it captures the deterministic output of nix evaluation, simulating the actual deployment state.

**Philosophy:**
- **Golden tests represent the best possible working state** — the canonical record of correct configuration output
- **All failures are errors** — no silent failure; deployment is blocked on any mismatch
- **No unintended side effects** — structural code changes must not alter golden output; if they do, the system is working correctly by catching the drift
- **Intended changes require manual golden update** — the user must explicitly regenerate and validate the new state before committing
- **Errors may be lowered to warnings by user request** — but warnings cannot be silenced
- **Coverage grows over time** — every new machine eventually gets a golden test

```bash
nix run .#check-network -- cortex-alpha
```
**DO NOT DEPLOY** if golden test fails. The golden file captures the exact deterministic evaluation output and must match exactly.

### CRITICAL: WireGuard Public Keys
Public keys are read from `secrets/public_keys/wireguard/wg_${name}_pub` files using `builtins.readFile`. The transformation function requires `self` (the flake) to construct paths. **DO NOT use placeholder keys** - the system was broken by this previously.

### CRITICAL: Secrex Private Key
WireGuard private key is managed by secrix:
```nix
secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file =
  ../../secrets/private_keys/wireguard/wg_cortex-alpha;

networking.wireguard.interfaces.wireg0.privateKeyFile =
  config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
```

### CRITICAL: Golden Tests Must NEVER Be Changed by Restructuring

Golden tests are the **ground truth**. They capture the exact deterministic evaluation output for each machine. They are NOT "legacy" or "new" — they represent correct working state. Any refactoring of transformers, generators, or modules MUST produce byte-identical golden output. If output diverges, the new code is wrong — never the golden.

**Rules:**
- Golden regeneration is ONLY for intentional configuration changes (new ports, added hosts, changed IPs)
- Code restructuring must NEVER require golden regeneration
- If `check-network` fails after refactoring, the refactoring introduced a side effect — fix it
- The user explicitly authorizes all golden updates

### Active Architecture (Production)

The production architecture uses per-machine topology files with direct transformation:

**Data Flow:**
```
real-topology/<machine>.nix (per-machine topology data)
         ↓
lib/topology/*.nix (transformation functions: mkWireguardPeers, mkNginxProxies, mkDhcpDns, etc.)
         ↓
modules/core-router.nix (NixOS config generation)
```

**Active Files:**
- `real-topology/<machine>.nix` - Per-machine topology data (DNS, nginx, firewall, WG, etc.)
- `real-topology/default.nix` - Golden test generator
- `real-topology/golden/<machine>.json` - Golden test references (sacrosanct)
- `lib/topology/mkWireguardPeers.nix` - WireGuard peer transformation (requires `self`)
- `lib/topology/mkTailscaleConfig.nix` - Tailscale configuration
- `lib/topology/mkDhcpDns.nix` - DHCP/DNS configuration
- `lib/topology/mkNginxProxies.nix` - Nginx proxy configuration
- `lib/topology/mkForwarding.nix` - nftables forwarding rules
- `lib/topology/mkMonitoringSettings.nix` - Prometheus exporter config
- `lib/topology/validate.nix` - Topology validation
- `lib/topology/utils.nix` - Shared utilities
- `modules/core-router.nix` - Core router module (imported by cortex-alpha)
- `modules/enable-wg-topology.nix` - WireGuard client module (deployed on 13 machines)

**Currently Using Production Architecture:** cortex-alpha (via `machines/cortex-alpha/default.nix`)

**Known Issues (Active):**
- Inconsistent function signatures across transformers (TG-003)
- `mkForwarding.nix` missing section-level `or` default for `topology.forwarding` (TG-004)

### WIP: Two-Layer Topology Architecture (Incremental Development)

The WIP architecture introduces a **single topology source of truth** with a clear two-layer pattern: **Transformers** → **Generators**. The WireGuard client module (`enable-wg-topology.nix`) is deployed on 13 machines. The hub module (`core-router-topology.nix`) is not yet wired into cortex-alpha.

**Architecture Pattern (WIP):**
```
topology.nix (incremental — only models what it currently generates, NOT a complete network description)
     ↓
lib/topology/mk*Settings.nix (transformers: topology + files → flat pure data)
     ↓
lib/topology/gen*.nix (generators: settings + hostname → NixOS config)
     ↓
modules/core-router-topology.nix or modules/enable-wg-topology.nix
```

**Key Principles:**
- `topology.nix` is **incremental** — it only models what it generates. Per-machine files (`real-topology/*.nix`) remain the complete data source.
- Transformers + generators must produce **identical output** to the production path when integrated. Golden tests enforce this.
- Integration is done **one machine at a time**, not all at once.
- Until wired into a machine's config, the WIP code is dead code. When wired, it MUST pass `check-network`.

**WIP Files:**
- `topology.nix` - Incremental network topology (WireGuard IPs, LAN IPs, peer relations only)
- `lib/topology/mkWireguardSettings.nix` - WireGuard transformer
- `lib/topology/genWireguard.nix` - WireGuard generator
- `lib/topology/mkNginxSettings.nix` - Nginx transformer
- `lib/topology/genNginx.nix` - Nginx generator
- `lib/topology/mkFirewallSettings.nix` - Firewall transformer
- `lib/topology/genFirewall.nix` - Firewall generator
- `lib/topology/mkDnsSettings.nix` - DNS/DHCP transformer
- `lib/topology/genDns.nix` - DNS/DHCP generator
- `lib/topology/mkMonitoringSettings.nix` - Monitoring transformer (shared with production)
- `modules/core-router-topology.nix` - Hub machine module (WIP)
- `modules/enable-wg-topology.nix` - Unified WireGuard module (WIP)

**Status:** WIP — `enable-wg-topology.nix` is deployed on 13 client machines (replaces legacy `enable-wg.nix`). `core-router-topology.nix` is not yet wired into cortex-alpha. Will be integrated incrementally, one machine at a time, and MUST pass golden validation before deployment.

## Common Tasks

### Active Architecture Tasks

#### Validate Against Golden Test
```bash
nix run .#check-network -- cortex-alpha
```
Validates that the current configuration matches the golden test for cortex-alpha.

**Golden tests are sacrosanct** — if this fails, the code is wrong. Never regenerate golden as part of refactoring.

#### Validate All Machines
```bash
nix run .#check-network -- cortex-alpha
nix run .#check-network -- cortex-beta
nix run .#check-network -- cortex-gamma
# ... for all 17 machines
```

#### Generate New Golden File (Config Changes Only)
```bash
nix run .#dump-config -- cortex-alpha | jq -S . > real-topology/golden/cortex-alpha.json
```
**Only run this when making intentional configuration changes** (new ports, added hosts, changed IPs). Never run during restructuring.

#### Add a New Machine to Production Topology (per-machine file)
1. Create `real-topology/<machine-name>.nix` using `_template.nix`
2. Create the machine's config in `flake.nix` (use `mkX86_64` or `mkAarch64`)
3. Import `modules/core-router.nix` in the machine's config
4. Generate golden: `nix run .#dump-config -- <machine-name> | jq -S . > real-topology/golden/<machine-name>.json`
5. Validate: `nix run .#check-network -- <machine-name>`

#### Dump Full Configuration
```bash
nix run .#dump-config -- cortex-alpha > config.json
```

#### Compare Between Revisions
```bash
./scripts/compare-configs.sh cortex-alpha main HEAD
```

### QEMU Bargman Greeter Test Harness

Test the bargman-cinematic LightDM webkit2 greeter in a QEMU VM before deploying to bare metal.

#### Boot the Greeter VM
```bash
nix run .#bargman-greeter-vm
```
Boots a QEMU VM with the full i3wm + bargman-cinematic greeter stack. Use for visual verification.

#### Headless Serial Debug
```bash
nix run .#bargman-greeter-vm-serial
```
Boots the VM in headless mode with serial console output. Use for diagnosing boot/greeter rendering issues.

#### Capture Serial Logs
```bash
./shell/vm-serial-capture.sh              # 120s timeout, /tmp/greeter-boot.log
./shell/vm-serial-capture.sh 60           # 60s timeout
./shell/vm-serial-capture.sh 60 /tmp/custom.log
```

#### Run Golden Screenshot Test
```bash
nix build .#checks.x86_64-linux.bargman-greeter-login-test -L
```
Automated visual regression test — boots the VM, waits for the greeter, takes a screenshot, and compares against golden PNGs.

#### Generate Golden Screenshots
```bash
# First run with comparison disabled to capture screenshots:
# (golden PNGs go in tests/bargman-greeter-login/resources/)
```

### Golden Test Operations

#### Generate Golden from Main Branch
```bash
git worktree add /tmp/nixos-main main
mkdir -p /tmp/nixos-main/real-topology
cp real-topology/default.nix /tmp/nixos-main/real-topology/
cd /tmp/nixos-main && nix eval --json --impure --expr '...' | jq -S . > golden.json
git worktree remove /tmp/nixos-main --force
```

## Repository Structure
- `real-topology/` - Topology data and golden tests
- `lib/topology/` - Transformation functions
- `modules/` - NixOS modules (core-router.nix, enable-wg-topology.nix)
- `documentation/` - Architecture docs and operational references
- `scripts/` - Utility scripts (compare-configs.sh)
- `secrets/` - Encrypted secrets (private keys) and public keys

## Deployment Flow
1. Run golden test: `nix run .#check-network -- cortex-alpha`
2. Verify WireGuard keys exist: `ls secrets/public_keys/wireguard/wg_*_pub`
3. Check for warnings in nix eval output
4. Deploy with appropriate caution