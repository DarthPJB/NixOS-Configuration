# AGENTS.md

**Scope:** Build philosophy, constraints, critical rules, common tasks.
**Not scope:** Repository structure (see documentation/development-guide.md),
project planning (see opencode/plans/), deployments (see documentation/operations-runbooks.md).
**Topology architecture:** See lib/topology/ARCHITECTURE.md for the generator diagram and data flow.

## TOPOLOGY GENERATOR PRINCIPLE (STATED IN FULL — REPEATED)

No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.

No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.

No function in the entire topology toolset reads anything except JSON topology files. It is exclusive, totally isolated, and never touches a single user Nix file. The generators are pure JSON-to-attrset functions. They take JSON data and produce config attrsets. They do not reference, read, access, view, or manipulate any NixOS config, any module system state, or any user Nix file. The resulting attrsets are merged later with system config by the NixOS module system.

topology derived from json to config attrset — json → config attrset, pure function, no bullshit — no module system, no hostname, no legacy paths, just json to attrset — generators read json, produce attrset, period — the json is the source of truth; the generator is a pure transformation — config attrset is produced from json by a pure function; nothing else — topology to config: json in, attrset out, no module system in the middle — a generator is a pure function: topology → attrset, no more, no less — topology derives from json, the generator maps json to config attrset, nothing more — json is parsed, attrset is produced, the generator is pure, the module system is not involved

## Current Issues — 2026-07-26

These are the leading issues on `overlord-ii-planar-topology`. The branch will not
be considered complete or deployable until Phase B core tasks are implemented
and validated against goldens.

### Architecture Boundary — READ THIS FIRST

The two-layer topology architecture enforces a strict boundary.
**This boundary must never be violated by any agent, reviewer, or code change.**

```
topology/<machine>.json  ──→  gen*.nix generators  ──→  minimal skeleton
  (source of truth)              (topology-derived)       (vhost names, listen
                                                          addrs, proxy_to, acme)
                                                              │
machines/<machine>/default.nix  ──→  user Nix config  ───────┤
services/*.nix                                             (forceSSL, roots,
environments/*.nix                                          headers, websockets,
                                                           returns, packages)
                                                              │
                                                   NixOS module merge
                                                              ↓
                                                        final config
                                                              ↓
                                                   golden = ground truth
```

**The generator produces ONLY topology-derived fields.**  It does NOT produce
forceSSL, addSSL, proxyWebsockets, proxy headers, static root resolution,
return codes, or default vhost flags.  Those come from the machine's Nix
configuration and are merged via the NixOS module system.

**The golden is the MERGED result of both sources.**  When a generator is
wired, it replaces the topology-derived portion of the config.  The machine
config remains unchanged.  The combined output MUST match the golden.

**Any agent that claims a generator is "missing features" that originate
from user configuration has fundamentally misunderstood the architecture.**

### Phase B — Core Tasks (blocks completion)

**B4. Wire the two-layer topology architecture into machine configs.**
**COMPLETED.** The `mktopology` function (`lib/topology/mktopology.nix`) wires
`genFirewall`, `genDns`, `genNginx`, and `genBackup` into all machine configs
at the flake level. `genWireguard` is deferred to overlord-iii (see below).

**B5. Wire backup topology pipeline into a module.**
**COMPLETED.** `genBackup.nix` is wired into `mktopology.nix` and activates
conditionally on `topology.backup` keys. At minimum one machine needs `backup`
keys in its topology JSON to validate the pipeline (pending).

### Phase B — Actionable Pending Review

**B1. Cortex-alpha hardcoded IP addresses.**
`machines/cortex-alpha/default.nix` has `enp3s0.ipv4.addresses` hardcoded to
`10.88.128.1/24`. Comment says "managed by topology-derive in later phase."
Data exists in `topology/cortex-alpha.json` — interface derivation requires
a new generator (genNetwork) or manual fix. Deferred to overlord-iii.

**B2. Remote-worker ad-hoc nginx config.**
`flake.nix` has 3 carmelsite vhosts inline in `extraModules` (lines 653-683).
This is the anti-pattern identified by multi-horizon gateway plan invariant #4.
Should move to `topology/remote-worker.json` vhosts.

**B3. Prometheus unlimited retention — no disk monitoring.**
`services/prometheus.nix` has `retentionTime = "0d"` (unlimited, ~500MB/week
growth). Needs disk growth alerting or dashboard. Operational decision.

### Phase C — Deferred

**C1. Ketchup/Secret-Sauce/Mayo library split.**
`lib/topology_library.nix` (53 lines) exists as clean API. `lib/mayo_library.nix`
(24 lines) is a minimal stub. Full split deferred until Phase B generators are
wired and validated.

**C2. GitHub runner custom module.**
Phase 2 goal from overlord-II plan. Not started. Deferred.

---

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

The production architecture uses JSON topology files as the single source of truth,
processed through the `mktopology` pure function at the flake level:

**Data Flow:**
```
topology/<machine>.json (per-machine topology data — single source of truth)
↓
lib/topology/mktopology.nix (flake-level pure function: JSON → config attrset)
↓
topologyConfigs (attrset of hostname → config attrset, merged into modules list)
```

**Active Files:**
- `topology/<machine>.json` — Per-machine topology data (coordinates, planes, DNS, nginx, firewall, WireGuard)
- `goldens/<machine>.json` — Golden test references (sacrosanct)
- `lib/topology/mktopology.nix` — Flake-level topology-to-config function (called at flake.nix:44)
- `lib/topology/genFirewall.nix` — Firewall generator (conditional on topology.firewall)
- `lib/topology/genDns.nix` — DNS/DHCP generator (conditional on topology.dns / lan_dhcp)
- `lib/topology/genNginx.nix` — Nginx proxy generator
- `lib/topology/genBackup.nix` — Backup generator (conditional on topology.backup)
- `lib/topology/genWireguard.nix` — WireGuard generator (wired separately, deferred to overlord-iii)
- `lib/topology/mkRegistry.nix` — Registry pipeline for topology validation
- `lib/topology/validate.nix` — Topology validation
- `lib/topology/utils.nix` — Shared utilities
- `lib/topology/PRINCIPLE.md` — Canonical architecture principle
- `lib/serialize-config.nix` — The one config serializer (used by `dump-config` and `checks.network-config-*`)
- `lib/golden_coverage.nix` — Coverage tracking (audit tool)
- `modules/enable-wg-topology.nix` — WireGuard client module (deployed on 14 machines; pending migration to genWireguard in overlord-iii)
- `topologyConfigs` — Attrset merged into each `nixosConfiguration` via `modules` list (flake.nix:147, 187)

### Two-Layer Topology Architecture (Active)

The mktopology architecture implements the pure JSON-to-config generator pattern
at the flake level, eliminating the need for a NixOS module for topology. The
architecture uses pure generators (gen*.nix) called by the `mktopology` function:

**Architecture Pattern:**
```
topology/<machine>.json (single source of truth — JSON data)
↓
gen*.nix generators (pure functions: JSON → config attrset)
↓
mktopology.nix (orchestrator: merges generator outputs per machine)
↓
topologyConfigs (attrset of hostname → config attrset)
↓
flake.nix (merges into each nixosConfiguration's modules list)
│
NixOS module merge (user machine config + topology config)
↓
final configuration
```

**Key Principles:**
- Generators are pure JSON-to-attrset functions — no module system, no user Nix
- mktopology is a pure function: `path → { hostname = config attrset; ... }`
- WireGuard is NOT wired into mktopology — deferred to overlord-iii
- `specialArgs = { inherit topologyData; }` still passes raw JSON to machines for backward compat

**Generator Files:**
- `lib/topology/genFirewall.nix` — Firewall generator (conditional)
- `lib/topology/genDns.nix` — DNS/DHCP generator (conditional)
- `lib/topology/genNginx.nix` — Nginx proxy generator (always active)
- `lib/topology/genBackup.nix` — Backup generator (conditional)
- `lib/topology/genWireguard.nix` — WireGuard generator (deferred to overlord-iii)

**Status:** `mktopology` is live for all machines with topology JSON files.
`enable-wg-topology.nix` remains deployed for WireGuard (pending migration in overlord-iii).
`topology-derive.nix` is archived at `lib/topology/archive/topology-derive.nix`.

### Topology-Gen Branch (Merged)

The `planar-topology` / `overlord-ii-planar-topology` branches overhauled the topology system:
- JSON topology files (`topology/<machine>.json`) replacing `.nix` per-machine data
- `lib/topology/mktopology.nix` — flake-level pure function replaces topology-derive.nix module
- `lib/topology/gen*.nix` — pure generators (firewall, DNS, nginx, backup, wireguard)
- Generators wired via `topologyConfigs` in flake.nix, not via commonModules
- `topology-derive.nix` archived to `lib/topology/archive/`
- WireGuard integration deferred to overlord-iii
- Goldens regenerated for all 19 machines
- `genNginx.nix` ACME propagation bug fixed
- Extensive test coverage added

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
- Golden tests validate that configuration hasn't changed from prior state
- This is regression testing — completely separate from topology generation
- Topology generates config; goldens validate config. Related but unrelated.
- All failures are errors — no silent failure; deployment is blocked
- Intended changes require manual golden update
- Coverage grows over time — every new machine eventually gets a golden

```bash
nix run .#validate-goldens -- cortex-alpha
```
**DO NOT DEPLOY** if golden test fails.

### Golden Tests Must NEVER Be Changed by Restructuring

**Rules:**
- Golden regeneration is ONLY for intentional configuration changes
- Code restructuring must NEVER require golden regeneration
- If `validate-goldens` fails after refactoring, the refactoring introduced a side effect
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
nix run .#validate-goldens -- cortex-alpha
```
**Golden tests are sacrosanct** — if this fails, the code is wrong.

### Validate All Machines
```bash
for m in $(ls machines/); do
  nix run .#validate-goldens -- "$m" 2>&1 | tail -1
done
```

### Generate New Golden File (Config Changes Only)
```bash
nix run .#dump-config -- cortex-alpha | jq -S . > goldens/cortex-alpha.json
```
**Only for intentional configuration changes.** Never during restructuring.

### Add a New Machine to Topology
1. Create `topology/<machine-name>.json` (use `_template.json` as reference)
2. Create the machine's config in `flake.nix` (use `mkX86_64` or `mkAarch64`)
3. Register in `flake.nix` with `mkX86_64` or `mkAarch64` — topology config is automatically merged via `topologyConfigs`
4. Generate golden: `nix run .#dump-config -- <machine-name> | jq -S . > goldens/<machine-name>.json`
5. Validate: `nix run .#validate-goldens -- <machine-name>`

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

## Deployment Flow
1. Run golden test: `nix run .#validate-goldens -- <machine>`
2. Verify WireGuard keys exist: `ls secrets/public_keys/wireguard/wg_*_pub`
3. Check for warnings in nix eval output
4. Deploy with appropriate caution


