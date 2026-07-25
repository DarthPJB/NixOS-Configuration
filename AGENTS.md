## Build Philosophy

This is professional netrunner infrastructure, not a hobby project.
Every decision flows from these principles.

### Correctness Over Speed
Build-speed is valuable, but irrelevant if the build fails or the output is
corrupt. The ONLY correct build is a build that completes. If evaluation takes
four hours, that is acceptable — provided it *guarantees* correctness.

### Closed-System Build Environment
All builds run on **self-hosted runners** within our own environment.
GitHub-hosted runners are inherently insecure and not acceptable for
proprietary work. Bargman-Tech production infrastructure will be siloed in
closed infrastructure. GitHub is used only for public-facing projects.

### No Implicit Third-Party Intermediaries
Third-party build caching, acceleration, or relay services that have access to
source code or build artifacts must be explicitly reviewed and approved.
Default-on caching (e.g., DetSys "magic nix cache") that may exfiltrate code
is not acceptable without conscious authorization. Builds must complete from
source within our controlled environment unless a specific exception is granted.

**Planned: In-House Binary Cache.** We will operate our own Nix binary cache
server within the closed environment, dogfooding our infrastructure
capabilities. Until the cache is operational, builds complete from source.
No third-party cache is configured in CI. See `ci/README.md` for status.

### Golden Tests Are Ground Truth
Golden tests represent the canonical correct state. If a golden test fails,
the code is wrong — never the golden. Regeneration is only for intentional
configuration changes, never for refactoring. Deployments are blocked on
golden mismatch. See golden test section for operational details.

### Simplicity Over Cleverness
Embrace simplicity. Reject unnecessary complexity. If a Nix expression requires
three paragraphs to explain, it needs rewriting. The topology engine,
transformers, and generators exist to *reduce* cognitive load, not to
demonstrate language prowess.

### Phase Discipline
Development proceeds in phases. Each phase builds on the previous. Do not
jump ahead. Complete the current phase before beginning the next. WIP code
is dead code until wired into a machine's config and validated against golden.

---

## Fleet Status

**19 machines** in `machines/`, **20 goldens** in `goldens/`.
Nginx vhosts managed fleetwide: ~21 active across cortex-alpha (topology-driven),
remote-worker (ad-hoc), gaming-host-1, local-nas, print-controller.

### Active Architecture (Production)

The production architecture uses per-machine topology files with direct transformation:

**Data Flow:**
```
topology/<machine>.nix (per-machine topology data)
↓
lib/topology/*.nix (transformation functions: mkWireguardPeers, mkNginxProxies, mkDhcpDns, etc.)
↓
modules/core-router.nix (NixOS config generation)
```

**Active Files:**
- `topology/<machine>.nix` — Per-machine topology data (DNS, nginx, firewall, WG)
- `topology/shared.nix` — Shared topology data (WireGuard IPs, LAN IPs, hub relationships)
- `topology/default.nix` — Entry point, imports shared + per-machine files
- `goldens/<machine>.json` — Golden test references (sacrosanct)
- `lib/serialize-config.nix` — The one config serializer (used by `dump-config` and `checks.network-config-*`)
- `lib/golden_coverage.nix` — Coverage tracking (audit tool)
- `lib/topology/mkNginxProxies.nix` — Nginx proxy configuration (production)
- `lib/topology/mkWireguardPeers.nix` — WireGuard peer transformation (requires `self`)
- `lib/topology/mkTailscaleConfig.nix` — Tailscale configuration
- `lib/topology/mkDhcpDns.nix` — DHCP/DNS configuration
- `lib/topology/mkForwarding.nix` — nftables forwarding rules
- `lib/topology/mkMonitoringSettings.nix` — Prometheus exporter config
- `lib/topology/validate.nix` — Topology validation
- `lib/topology/utils.nix` — Shared utilities
- `modules/core-router.nix` — Core router module (production)
- `modules/enable-wg-topology.nix` — WireGuard client module (deployed on 13 machines)

### WIP: Two-Layer Topology Architecture

The WIP architecture introduces a **single topology source of truth** with a
two-layer pattern: **Transformers** → **Generators**.

**Architecture Pattern (WIP):**
```
topology/<machine>.nix (shared + per-machine topology data)
↓
lib/topology/mk*Settings.nix (transformers: topology + files → flat pure data)
↓
lib/topology/gen*.nix (generators: settings + hostname → NixOS config)
↓
modules/core-router-topology.nix (hub) or modules/enable-wg-topology.nix (clients)
```

**Key Principles:**
- Transformers + generators must produce **identical output** to the production path.
  Golden tests enforce this.
- Integration is done **one machine at a time**, not all at once.
- Until wired into a machine's config, the WIP code is dead code. When wired,
  it MUST pass `check-network`.

**WIP Files:**
- `lib/topology/mkWireguardSettings.nix` — WireGuard transformer
- `lib/topology/genWireguard.nix` — WireGuard generator
- `lib/topology/mkNginxSettings.nix` — Nginx transformer
- `lib/topology/genNginx.nix` — Nginx generator
- `lib/topology/mkFirewallSettings.nix` — Firewall transformer
- `lib/topology/genFirewall.nix` — Firewall generator
- `lib/topology/mkDnsSettings.nix` — DNS/DHCP transformer
- `lib/topology/genDns.nix` — DNS/DHCP generator
- `lib/topology/mkBackupSettings.nix` — Backup transformer (WIP, no consumer)
- `lib/topology/genBackup.nix` — Backup generator (WIP, no consumer)
- `modules/core-router-topology.nix` — Hub machine module (WIP)

**Status:** `enable-wg-topology.nix` is deployed on 13 client machines.
`core-router-topology.nix` is imported by cortex-alpha but is the WIP path;
AGENTS.md previously stated it was unwired — this is stale (see Finalisation Tasks).

### Topology-Gen Branch (In Progress)

The `planar-topology` branch is actively overhauling the topology system:
- JSON topology files (`topology/<machine>.json`) replacing `.nix` per-machine data
- `modules/topology-derive.nix` — derives NixOS config from JSON topology
- `lib/topology/mkRegistry.nix` — registry pipeline for topology validation
- Goldens regenerated for all 19 machines
- `genNginx.nix` ACME propagation bug fixed
- Extensive test coverage added

**When merged:** The production architecture section above will be superseded.
Until then, both paths coexist.

---

## CRITICAL Constraints

### Formatter Configuration
**DO NOT CHANGE THE FORMATTER CONFIGURATION** without explicit user approval.
- Current formatter: `nixpkgs.nixpkgs-fmt` (declared in `formatter."x86_64-linux"`)
- Formatting enforced via `checks.x86_64-linux.formatting` (`nixpkgs-fmt --check`)
- Dead code enforced via `checks.x86_64-linux.deadnix` (`deadnix --no-lambda-pattern-names`)
- Both run via `nix flake check` and in CI
- Do NOT run `nix fmt` on the entire codebase without explicit permission.

### Git Worktree Workflow

**Always use worktrees for parallel development.**

```bash
# Check which worktree you're in:
git worktree list

# Create a new worktree:
git worktree add /tmp/nixos-<descriptive-name> -b <branch-name>

# Clean up when done:
git worktree remove /tmp/nixos-<descriptive-name>
```

**Rules:**
1. NEVER work on the same branch in two worktrees
2. Always check `git worktree list` before starting work
3. Use descriptive paths: `/tmp/nixos-<purpose>`
4. Use descriptive branch names: `fix/...`, `feat/...`, `refactor/...`
5. Clean up worktrees when done

### Golden Test (Simulation-Driven Development)

The golden test is our primary integrity mechanism.

**Philosophy:**
- Golden tests represent the best possible working state
- All failures are errors — no silent failure; deployment is blocked
- Intended changes require manual golden update
- Coverage grows over time — every new machine eventually gets a golden

```bash
nix run .#check-network -- cortex-alpha
```
**DO NOT DEPLOY** if golden test fails.

### Golden Tests Must NEVER Be Changed by Restructuring

**Rules:**
- Golden regeneration is ONLY for intentional configuration changes
- Code restructuring must NEVER require golden regeneration
- If `check-network` fails after refactoring, the refactoring introduced a side effect
- The user explicitly authorizes all golden updates

### WireGuard Public Keys
Public keys are read from `secrets/public_keys/wireguard/wg_${name}_pub` files
using `builtins.readFile`. The transformation function requires `self` (the flake)
to construct paths. **DO NOT use placeholder keys.**

### Secrex Private Key
WireGuard private key is managed by secrix:
```nix
secrix.services.wireguard-wireg0.secrets.cortex-alpha.encrypted.file =
  ../../secrets/private_keys/wireguard/wg_cortex-alpha;

networking.wireguard.interfaces.wireg0.privateKeyFile =
  config.secrix.services.wireguard-wireg0.secrets.cortex-alpha.decrypted.path;
```

### Nix Script Standards
- **NEVER** use `pkgs.writeShellScript` or `pkgs.writeShellScriptBin`.
  ALWAYS use `pkgs.writeShellApplication` with explicit `runtimeInputs`.
- **NEVER** use bare command names or `${pkgs.foo}/bin/foo`.
  ALWAYS use `lib.getExe` or `lib.getExe'`.
- See prime directives #18 and #19 for examples.

---

## Common Tasks

### Validate Against Golden Test
```bash
nix run .#check-network -- cortex-alpha
```
**Golden tests are sacrosanct** — if this fails, the code is wrong.

### Validate All Machines
```bash
for m in $(ls machines/); do
  nix run .#check-network -- "$m" 2>&1 | tail -1
done
```

### Generate New Golden File (Config Changes Only)
```bash
nix run .#dump-config -- cortex-alpha | jq -S . > goldens/cortex-alpha.json
```
**Only for intentional configuration changes.** Never during restructuring.

### Add a New Machine to Topology
1. Create `topology/<machine-name>.nix` (use existing as template)
2. Create `topology/<machine-name>.json` (planar-topology format)
3. Create the machine's config in `flake.nix` (use `mkX86_64` or `mkAarch64`)
4. Import the appropriate module (`core-router.nix` or `core-router-topology.nix`)
5. Generate golden: `nix run .#dump-config -- <machine-name> | jq -S . > goldens/<machine-name>.json`
6. Validate: `nix run .#check-network -- <machine-name>`

### Dump Full Configuration
```bash
nix run .#dump-config -- cortex-alpha > config.json
```

### Compare Between Revisions
```bash
./scripts/compare-configs.sh cortex-alpha main HEAD
```

### Long-Running Build Monitoring
Use tmux + log files for any build > 30 seconds:
```bash
tmux new-session -d -s build-<machine> \
  "nix build .#nixosConfigurations.<machine>.config.system.build.toplevel \
  --no-link --print-out-paths 2>&1 | tee /tmp/build-<machine>.log; \
  echo BUILD_DONE | tee -a /tmp/build-<machine>.log"

# Monitor:
tail -5 /tmp/build-<machine>.log        # progress
grep -i "error:" /tmp/build-<machine>.log  # errors
grep BUILD_DONE /tmp/build-*.log        # completion
```

### QEMU Bargman Greeter Test Harness
```bash
nix run .#bargman-greeter-vm           # visual verification
nix run .#bargman-greeter-vm-serial    # headless serial debug
nix build .#checks.x86_64-linux.bargman-greeter-login-test -L  # golden screenshot
```

---

## Repository Structure
- `topology/` — Topology data (cortex-alpha.nix, shared.nix, default.nix; JSON on planar-topology)
- `goldens/` — Golden test files (sacrosanct; 20 machines)
- `lib/topology/` — Transformation functions (production + WIP transformers + generators)
- `lib/serialize-config.nix` — The one config serializer
- `lib/golden_coverage.nix` — Coverage tracking (audit tool)
- `modules/` — NixOS modules (core-router.nix, core-router-topology.nix, enable-wg-topology.nix, ssh-multiplex.nix, etc.)
- `machines/` — Per-machine NixOS configurations (19 machines)
- `server_services/` — Service definitions (nextcloud, gitolite, hedgedoc, klipper, etc.)
- `documentation/` — Architecture docs and operational references
- `snippets/` — Reference snippets, retired configs, archived plans (not active code)
- `scripts/` — Utility scripts
- `secrets/` — Encrypted secrets (private keys) and public keys
- `ci/` — CI pipeline configuration

## Deployment Flow
1. Run golden test: `nix run .#check-network -- <machine>`
2. Verify WireGuard keys exist: `ls secrets/public_keys/wireguard/wg_*_pub`
3. Check for warnings in nix eval output
4. Deploy with appropriate caution

---

## Finalisation Tasks

Tasks remaining from the cleaning review (2026-07-20) and topology-gen branch
completion. These are tracked here for visibility; execute in order.

### HIGH — Before topology-gen merge

| # | Task | Evidence |
|---|---|---|
| F1 | **Delete `server_services/hedgedoc.nix`** — orphaned service+vhost, zero imports | grep confirms no consumers |
| F2 | **Fix `AGENTS.md:219,252`** — stale claim that `core-router-topology.nix` "is not yet wired into cortex-alpha" when `machines/cortex-alpha/default.nix` imports it | cortex-alpha/default.nix:23 |
| F3 | **Delete `snippets/overlord-II-PLAN.md` topology sections** — moved to snippets, topology phases superseded by planar-topology | Done (2026-07-20) |

### MEDIUM — Code quality sweep

| # | Task | Location(s) |
|---|---|---|
| F4 | **Extract hardcoded IPs** to `topology/shared.nix` — `193.16.42.101`, `10.0.1.42`, `82.5.173.252` repeated with `#todo` comments | `flake.nix:622-652`, `server_services/nextcloud.nix`, `machines/remote-worker/default.nix` |
| F5 | **Convert `writeShellScript` → `writeShellApplication`** — 3 instances | `lib/rclone-target.nix:150`, `flake.nix:437`, `modules/sysdiag.nix:43,69` |
| F6 | **Convert `${pkgs.foo}/bin/foo` → `lib.getExe`** — 9 instances | `cortex-alpha/default.nix:125`, `core-router-topology.nix:126`, `rclone-target.nix:127,129`, `LINDA/default.nix:244`, `terratech.nix:336-338`, `dragonwilds.nix:58`, `energy_saving.nix:19`, `tests/minecraft-server/default.nix:88,104`, `locale/input-methods.nix:127` |

### LOW — Documentation hygiene

| # | Task | Location |
|---|---|---|
| F7 | **Update `documentation/plans/overlord-II-PLAN.md`** — references deleted `real-topology/` (lines 80, 90-91, 96, 118) | Moved to snippets; remaining refs stale |
