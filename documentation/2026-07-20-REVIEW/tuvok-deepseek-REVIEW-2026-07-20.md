# tuvok-deepseek-REVIEW-2026-07-20.md

## Summary
Adversarial review reveals significant architectural drift between production and WIP paths, with cortex-alpha caught between competing modules (`core-router.nix` vs `core-router-topology.nix`). Nginx vhost inventory shows 19 distinct virtual hosts across 4 machines, but discovery exposes duplication in test files, orphaned secret keys, and documentation debt. The WIP two-layer architecture exists as dead code in `core-router-topology.nix` while production relies on direct module imports and topology-driven proxies. Critical design risks include silent module conflicts, eval-time filesystem dependencies without validation, and unverified equivalence between production transformers and WIP generators.

## Ground 1: Complete Inventory of All Nginx Vhosts

### Fleetwide Nginx Virtual Host Inventory

| Domain/Server Name | Port/TLS | Upstream/Target | Definition Location | Deploying Machine(s) | Active/Dead | Notes |
|-------------------|----------|-----------------|---------------------|----------------------|-------------|-------|
| `_` (default) | 80/443, TLS via ACME wildcard | Return 444 (close connection) | `topology/cortex-alpha.nix:515-519` | cortex-alpha | Active | Default catch-all vhost |
| `johnbargman.net` | 80/443, TLS forced | Static webroot (`../webroot`) | `topology/cortex-alpha.nix:520-524` | cortex-alpha | Active | Primary domain static site |
| `cortex-alpha.johnbargman.net` | 80/443, TLS forced | Static webroot (`../webroot`) | `topology/cortex-alpha.nix:525-529` | cortex-alpha | Active | Host-specific static site |
| `print-controller.johnbargman.net` | 80/443, TLS optional | `http://10.88.127.30:80` | `topology/cortex-alpha.nix:535-539` | cortex-alpha | Active | Proxy to print-controller (WireGuard IP) |
| `code.johnbargman.net` | 80/443, TLS optional | `http://10.88.127.3:80` | `topology/cortex-alpha.nix:540-544` | cortex-alpha | Active | Proxy to remote-worker (WireGuard IP) |
| `git.johnbargman.net` | 80/443, TLS optional | `http://10.88.127.3:80` | `topology/cortex-alpha.nix:545-549` | cortex-alpha | Active | Proxy to remote-worker (WireGuard IP) |
| `prometheus.johnbargman.net` | 80/443, TLS optional | `http://10.88.127.3:8080` | `topology/cortex-alpha.nix:550-554` | cortex-alpha | Active | Proxy to remote-worker Prometheus |
| `grafana.johnbargman.net` | 80/443, TLS optional | `http://10.88.127.3:3101` | `topology/cortex-alpha.nix:555-559` | cortex-alpha | Active | Proxy to remote-worker Grafana |
| `ap.johnbargman.net` | 80/443, TLS optional | `http://10.88.128.2:80` | `topology/cortex-alpha.nix:560-564` | cortex-alpha | Active | Proxy to LAN device (AP) |
| `gaming-host-1.johnbargman.net` | 80/443, TLS forced | `http://127.0.0.1:8080` | `machines/gaming-host-1/default.nix:70-77` | gaming-host-1 | Active | Local squaremap proxy |
| `default` | 80, no TLS | Return 444 | `machines/remote-worker/default.nix:47-53` | remote-worker | Active | Default catch-all on all interfaces |
| `johnbargman.net` (remote) | 80/443, TLS forced | Static webroot (`../../webroot`) | `machines/remote-worker/default.nix:54-63` | remote-worker | Active | Static site on all interfaces |
| `johnbargman.com` | 80/443, TLS forced | Static webroot (`../../webroot`) | `machines/remote-worker/default.nix:66-74` | remote-worker | Active | .com domain static site |
| `johnbargman.com-wg` | 80/443, TLS forced | Personal site webroot | `machines/remote-worker/default.nix:76-85` | remote-worker | Active | Split-horizon: WireGuard IP only |
| `nextcloud.johnbargman.com` | 80/443, TLS forced | Global redirect to `.net` | `server_services/nextcloud.nix:67-77` | remote-worker | Active | Domain redirect for Nextcloud |
| `nextcloud.johnbargman.net` | 80/443, TLS forced | Nextcloud service | `server_services/nextcloud.nix:78-87` | remote-worker | Active | Primary Nextcloud endpoint |
| `hedgedoc.johnbargman.com` | 80/443, TLS forced | `http://localhost:3333` | `server_services/hedgedoc.nix:12-21` | Unknown | **Dead** | Not imported by any machine config |
| `raw` (gitolite) | 80 WireGuard only, no TLS | `unix:/run/uwsgi/cgit.sock` | `server_services/gitolite.nix:90-138` | Unknown | **Dead** | Not imported by any machine config |
| `csfinancialconsulting.com` | 80/443, TLS forced | Carmel site static | `flake.nix:625-634` | remote-builder | Active | External client site |
| `csfincon.us` | 80/443, TLS forced | Carmel site static | `flake.nix:635-644` | remote-builder | Active | External client site |
| `carmel-staging.johnbargman.net` | 80/443, TLS forced | Carmel site static | `flake.nix:645-654` | remote-builder | Active | Staging site |
| `localhost` | N/A | N/A | Implicit default | remote-builder, others | Active | Default nginx vhost |

### Key Findings:
1. **Active vhosts**: 19 distinct virtual hosts across cortex-alpha (9), remote-worker (6), gaming-host-1 (1), remote-builder (3)
2. **Dead vhosts**: 2 (hedgedoc, gitolite) - defined but not imported by any machine
3. **TLS coverage**: Mixed - some force TLS, some optional, some no TLS (WireGuard-only internal)
4. **Architecture**: Hybrid - cortex-alpha uses topology-driven proxies; others use direct config
5. **Duplication**: `johnbargman.net` defined in both cortex-alpha (static) and remote-worker (static) - serves same content from different machines

## Ground 2: Suggested Paths to Clean Up or Remove

### High Priority

1. **`snippets/test-new-architecture.nix`** (Duplication)
   - **Path**: `/tmp/nixos-overlord-II-cleaning-review/snippets/test-new-architecture.nix`
   - **Evidence**: Identical to `tests/test-new-architecture.nix` (byte-for-byte match)
   - **Recommended Action**: Delete snippet file, keep tests/ version

2. **`server_services/hedgedoc.nix`** (Dead Service)
   - **Path**: `/tmp/nixos-overlord-II-cleaning-review/server_services/hedgedoc.nix`
   - **Evidence**: Defines nginx vhost but not imported by any machine config (`grep -r "hedgedoc" machines/` returns empty)
   - **Recommended Action**: Archive or delete unless planned for future use

3. **Orphaned WireGuard Public Key: `wg_acropolis_pub`**
   - **Path**: `/tmp/nixos-overlord-II-cleaning-review/secrets/public_keys/wireguard/wg_acropolis_pub`
   - **Evidence**: Not referenced in cortex-alpha topology peer list (19 peers listed, acropolis not among them)
   - **Recommended Action**: Remove public key file and corresponding private key if exists

4. **`lib/topology_library.nix`** (Dead Library)
   - **Path**: `/tmp/nixos-overlord-II-cleaning-review/lib/topology_library.nix`
   - **Evidence**: Defines `ketchup` library but not imported anywhere (`grep -r "topology_library" --include="*.nix" .` shows only self-reference)
   - **Recommended Action**: Delete - appears to be WIP library split artifact never completed

### Medium Priority

5. **`snippets/enable-wg.nix`** (Legacy Module)
   - **Path**: `/tmp/nixos-overlord-II-cleaning-review/snippets/enable-wg.nix`
   - **Evidence**: Superseded by `modules/enable-wg-topology.nix` (used by 13 machines). Contains hardcoded `builtins.readFile` reference.
   - **Recommended Action**: Delete - replaced by topology-driven architecture

6. **`snippets/syncthing_server.nix`** (Commented-Out Config)
   - **Path**: `/tmp/nixos-overlord-II-cleaning-review/snippets/syncthing_server.nix`
   - **Evidence**: Entire file commented out, not imported anywhere
   - **Recommended Action**: Delete or uncomment and integrate if needed

7. **`documentation/` Debt**
   - **Paths**: Multiple files referencing abandoned plans
   - **Evidence**: `2026-07-18-MULTI-HORIZON-GATEWAY-PLAN.md`, `dual-tailscale-plan.md`, `phase-c-library-split-design.md` describe unimplemented architectures
   - **Recommended Action**: Consolidate or move to archive directory; update status in master documentation

8. **Duplicate Core Router Snippet**
   - **Path**: `/tmp/nixos-overlord-II-cleaning-review/snippets/core-router.nix`
   - **Evidence**: Similar to `modules/core-router.nix` but with different import pattern
   - **Recommended Action**: Delete snippet, ensure modules/ version is canonical

### Low Priority

9. **Orphaned Host Key Files**
   - **Paths**: `secrets/public_keys/host_keys/alpha-two.pub`, `secrets/public_keys/host_keys/local-worker.pub`, `secrets/public_keys/host_keys/display-0.pub`, etc.
   - **Evidence**: Machines `alpha-two`, `local-worker`, `display-0` not in nixosConfigurations list
   - **Recommended Action**: Audit and remove unused host keys

10. **`snippets/` Directory Overall**
    - **Evidence**: 10 snippet files, none imported by machine configs (no `../../snippets/` imports found)
    - **Recommended Action**: Full audit - either integrate into modules or delete entire directory

## Ground 3: Obvious Practical Issues with Codebase

### Critical Bugs (Severity: High)

1. **Module Conflict Risk: `core-router.nix` vs `core-router-topology.nix`**
   - **File:Line**: `modules/core-router-topology.nix:66` (default = true), `machines/cortex-alpha/default.nix:23` (imports WIP module)
   - **Issue**: cortex-alpha imports `core-router-topology.nix` (WIP) which defaults to enabled. No machine imports `core-router.nix` (production). This creates silent drift: WIP code path active for hub machine without validation against production.
   - **Risk**: Golden tests may pass for WIP path while production path untested.
   - **Fix**: Explicitly disable WIP module (`coreRouterTopology.enable = false`) until migration complete, or wire production module and validate equivalence.

2. **Unvalidated Generator Equivalence**
   - **Files**: `lib/topology/mkNginxProxies.nix` (production) vs `lib/topology/mkNginxSettings.nix` + `lib/topology/genNginx.nix` (WIP)
   - **Issue**: No automated validation that WIP generators produce byte-identical output to production transformers. Comment in `genNginx.nix:3-4` states "Must produce byte-identical virtualHosts" but no check exists.
   - **Risk**: Silent divergence between architectures; golden tests only capture current active path.
   - **Fix**: Add derivation that compares outputs of both paths for each machine.

3. **Missing Error Handling for `builtins.readFile`**
   - **File:Line**: `lib/topology/mkWireguardPeers.nix` (multiple lines), `flake.nix` mkX86_64/mkAarch64 functions
   - **Issue**: `builtins.readFile` fails hard if file missing. No graceful fallback or validation.
   - **Example**: `builtins.readFile "${self}/secrets/public_keys/wireguard/wg_${peer}_pub"` - if file missing, entire eval fails.
   - **Fix**: Add existence check with informative error: `if builtins.pathExists path then builtins.readFile path else throw "Missing WG pubkey for ${peer}: ${path}"`

### Design Risks (Severity: Medium)

4. **Hybrid Nginx Architecture**
   - **Evidence**: cortex-alpha uses topology-driven proxies; remote-worker/gaming-host-1 use direct config; remote-builder uses flake.nix config
   - **Risk**: Inconsistent patterns, harder to reason about fleet-wide proxy configuration.
   - **Fix**: Unify on topology-driven approach or document clear separation criteria.

5. **Dead WIP Architecture Files**
   - **Files**: `mk*Settings.nix`, `gen*.nix` in `lib/topology/`
   - **Issue**: Extensive WIP code (8+ files) only partially integrated. `core-router-topology.nix` exists but may not be fully functional.
   - **Risk**: Codebase bloat, maintenance burden, confusion for new contributors.
   - **Fix**: Complete integration or remove WIP files; no half-implemented architectures.

6. **Secret Management Gaps**
   - **File:Line**: `server_services/klipper.nix:263-264` references `"${self}/secrets/ldap_master_password"` but no validation file exists.
   - **Issue**: Secrets referenced but existence not guaranteed; fails at runtime rather than eval-time.
   - **Fix**: Add pre-deployment validation hook checking all referenced secret files.

7. **Formatter/Linter Configuration Risk**
   - **Documented in AGENTS.md**: "DO NOT CHANGE THE FORMATTER CONFIGURATION without explicit user approval"
   - **Issue**: Hardcoded coupling between `nixpkgs.nixpkgs-fmt` and `lint-utils.linters.x86_64-linux.nixpkgs-fmt`
   - **Risk**: Accidental divergence breaks CI; manual synchronization required.
   - **Fix**: Derive linter from formatter package to guarantee consistency.

### Nits and Code Smells (Severity: Low)

8. **`writeShellScript` Usage**
   - **File:Line**: `flake.nix` (multiple), `modules/sysdiag.nix`
   - **Issue**: `writeShellScript` used instead of `writeShellApplication` for some cases. Not wrong but inconsistent.
   - **Fix**: Standardize on `writeShellApplication` for binaries, `writeShellScript` for internal scripts.

9. **Hardcoded IP Addresses**
   - **Files**: `server_services/nextcloud.nix:72-85`, `flake.nix:628`, etc.
   - **Issue**: IP addresses repeated with comment "todo: handle this assignment in a fixed fashion"
   - **Fix**: Extract to shared network configuration or topology.

10. **Obsolete Option Warnings**
    - **Evidence**: Golden test output shows 20+ "Obsolete option" traces during evaluation
    - **Impact**: Build noise, potential future breakage when options removed
    - **Fix**: Systematic update of deprecated options

11. **Inconsistent Backend Reference Patterns**
    - **File:Line**: `topology/cortex-alpha.nix:536` vs `machines/gaming-host-1/default.nix:74`
    - **Issue**: Some proxies use WireGuard IPs (`10.88.127.x`), others use localhost (`127.0.0.1`)
    - **Fix**: Document clear pattern: external→WG IP, internal→localhost

## Things I Could Not Verify

1. **Live System State**: Cannot verify which nginx vhosts are actually serving traffic (passive review constraint)
2. **Secret File Contents**: Cannot examine encrypted `.age` files or validate decryption works
3. **WireGuard Peer Connectivity**: Cannot test actual VPN connections between machines
4. **ACME Certificate Status**: Cannot verify Let's Encrypt certificates are properly issued/renewed
5. **Service Health**: Cannot check if proxied services (Nextcloud, Grafana, etc.) are actually running behind nginx
6. **Performance Impact**: Cannot assess nginx configuration efficiency or connection handling

## Overall Assessment

The codebase exhibits significant **architectural drift** with competing implementations (production vs WIP) and **incomplete migration** from legacy patterns. While golden tests provide some safety net, they don't validate equivalence between code paths. The extensive WIP architecture (`mk*Settings`/`gen*` pattern) represents unfinished work that increases cognitive load without delivering value.

**Highest risk**: cortex-alpha using WIP `core-router-topology.nix` module while production `core-router.nix` exists but unused. This creates an unvalidated code path for the network hub.

**Recommendation priority**: 
1. Resolve module conflict (choose single architecture for cortex-alpha)
2. Validate WIP generator equivalence against production transformers  
3. Clean up dead code (snippets, orphaned secrets, unused documentation)
4. Unify nginx configuration patterns across fleet