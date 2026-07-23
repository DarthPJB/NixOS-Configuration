# Planar Topology Review Fixes — Phases RF-0 through RF-3

**Created:** 2026-07-21
**Revised:** 2026-07-21 (incorporated user Q1-Q4 decisions)
**Branch:** `overlord-ii-planar-topology`
**Worktree:** `/tmp/nixos-planar-topology/`
**Base:** `1833039` (post-review commit)
**Source:** `/speed-storage/opencode/documentation/2026-07-21-PLANAR-FINAL-REVIEW/SYNTHESIS.md`

## Purpose

Fix all actionable findings from the final adversarial review. dlyon sub-hub is excluded (deferred to later phase). WIP generator wiring is excluded (generators remain as dead code stubs until a dedicated migration phase).

## Architectural Decision: `shared.json` Is Deleted

Per user Q4: "how can a 'shared' json exist, when each json file is a self-declared unit representing a physical machine?"

Each JSON file is a self-contained peer declaration. A cross-host `shared.json` contradicts this model.

- `shared.json` contents (`lan_dhcp`) → move to `cortex-alpha.json` (it's cortex-alpha's DHCP config)
- `wg_peers` → **derived** by `mkRegistry.nix` from all hosts with a `wg` coordinate (already implemented at line ~117). No declaration needed.
- `shared.json` → **deleted**

## Design Decisions (from user)

| Q | Decision |
|---|---------|
| Q1 listenAddresses | Per-plane in vhost entries. Manual review to construct correct split-horizon table. Default: derive from coordinates when absent. |
| Q2 acme_host | Keep in JSON for now (wildcard dns-01). Future: per-domain ACME from topology. |
| Q3 schema shape | Flat fields preferred for firewall/dns/wireguard |
| Q4 shared.json | Delete. `lan_dhcp` → cortex-alpha.json. `wg_peers` derived by registry. |

## Scope

| # | Fix | Source Finding | Severity |
|---|-----|---------------|----------|
| 1 | Remove `listenAddresses` from JSON vhosts; derive from coordinates | Axis 2 #1 | HIGH |
| 2 | Delete `shared.json`; move `lan_dhcp` to cortex-alpha.json | Q4 resolution | HIGH |
| 3 | Populate `routes` in cortex-alpha.json from legacy topology | Axis 1 #6 | HIGH |
| 4 | Add WireGuard peer list to cortex-alpha.json | Axis 1 #1 | HIGH |
| 5 | Add firewall rules to cortex-alpha.json | Axis 1 #2 | HIGH |
| 6 | Add DNS/DHCP config to cortex-alpha.json | Axis 1 #3 | HIGH |
| 7 | Add Tailscale ACL drift validator to mkRegistry | Axis 1 #10 | MEDIUM |
| 8 | Fix stale `unknown-lan` interface placeholders | Axis 2 #4 | MEDIUM |
| 9 | Fix `advertised_tailscale_routes` in cortex-alpha.json | Axis 2 #3 | MEDIUM |
| 10 | Remove `acme_host` and `default_response` from JSON host level | Axis 2 #5 | LOW |

## Delegation Pattern

- **Step executor:** `bellana-deepseek`
- **Verification gate:** `tpol-minimax`
- Steps execute serially. Each phase ends with a gate.
- `nix --option builders ''` for all Nix commands.
- Absolute paths. Commit after each phase. Push after each phase.

---

## Phase RF-0 — Clean Up JSON Data Quality

**Goal:** Fix stale data, remove over-specified fields, delete shared.json.

### Step RF-0.1 — Remove `listenAddresses` from JSON vhosts

**Executor:** `bellana-deepseek`

**Task:** In `topology/cortex-alpha.json` and `topology/remote-worker.json`, remove the `listenAddresses` arrays from all vhost entries. These hardcode IPs that should be derived from coordinates.

**Before (cortex-alpha.json):**
```json
"_": [
  {
    "default": true,
    "return": "444",
    "listenAddresses": ["10.88.128.1", "10.88.127.1", "82.5.173.252"]
  }
]
```

**After:**
```json
"_": [
  {
    "default": true,
    "return": "444"
  }
]
```

Do this for ALL vhost entries in cortex-alpha.json and remote-worker.json.

Then update `modules/topology-derive.nix` so that when `listenAddresses` is absent, the module derives listen addresses from the host's coordinate IPs (using `subnetPeerToIP` on each coordinate entry). Use the same `firstIP` logic already in the module for exporters.

**Note:** remote-worker's `johnbargman.com-wg` vhost has `listenAddresses: ["10.88.127.50"]` (WG IP only). This is a split-horizon vhost that should only listen on WG. When removing `listenAddresses`, add a `planes` field to specify which planes the vhost listens on:
```json
"johnbargman.com-wg": [
  {
    "plane": "wg",
    "static": { "root": "../../webroot" },
    "acme": { "enable": true },
    "forceSSL": true,
    "server_name": "johnbargman.com"
  }
]
```

**Success criteria:**
- No `listenAddresses` key in any vhost entry in any JSON file
- `topology-derive.nix` derives listen addresses from coordinates when absent
- remote-worker's WG-only vhost uses `plane: "wg"` to restrict listening
- Golden tests still pass for cortex-alpha and remote-worker

### Step RF-0.2 — Fix stale `unknown-lan` interface placeholders

**Executor:** `bellana-deepseek`

**Task:** 5 files have `interface: "unknown-lan"`:
- `lindacore-87.json`, `lindacore-89.json`, `linda-wm.json`, `michel-248.json`, `michel-wifi-247.json`

These are DHCP-only hosts on the LAN. For each:
1. Check `topology/cortex-alpha.nix` for the actual interface name or MAC address
2. If found, set the interface to the real value
3. If not found, set to a descriptive MAC-based reference (e.g., `"mac:<mac-address>"`)

Also check `terminal-zero.json` for any remaining `unknown-lan-2` placeholder.

**Success criteria:**
- No `unknown-lan` or `unknown-lan-2` in any JSON file
- All interfaces have real values or MAC references

### Step RF-0.3 — Delete `shared.json`; move `lan_dhcp` to cortex-alpha.json

**Executor:** `bellana-deepseek`

**Task:**
1. Read `topology/shared.json` — contains `lan_dhcp` (range + interface)
2. Add `lan_dhcp` field to `topology/cortex-alpha.json`:
   ```json
   "lan_dhcp": {
     "range": "10.88.128.128,10.88.128.254,24h",
     "interface": "enp3s0"
   }
   ```
3. Delete `topology/shared.json`
4. Update `mkRegistry.nix` to not read `shared.json` (or remove `shared` from its output)
5. Update `flake.nix` if it references `shared.json`
6. Update any tests that reference `shared.json`

**Note:** `wg_peers` is NOT added to any JSON file — it's derived by the registry from coordinates. The registry already computes peers at line ~117.

**Success criteria:**
- `topology/shared.json` deleted
- `cortex-alpha.json` has `lan_dhcp` field
- mkRegistry still passes (0 errors)
- All unit tests pass

### Step RF-0.4 — Fix `advertised_tailscale_routes` in cortex-alpha.json

**Executor:** `bellana-deepseek`

**Task:** `cortex-alpha.json` advertises other hosts' IPs (`10.88.128.88/32`, `10.88.127.107/32`, etc.) as Tailscale routes. These are subnets that cortex-alpha routes TO (subnet routing), not its own subnets.

Verify against `topology/cortex-alpha.nix` (legacy) to confirm the route list is accurate. The legacy file was recently updated (remote-builder route removed). Ensure JSON matches.

**Success criteria:**
- `advertised_tailscale_routes` in cortex-alpha.json matches legacy `.nix` file
- No stale routes

### Step RF-0.5 — Remove `acme_host` and `default_response` from JSON host level

**Executor:** `bellana-deepseek`

**Task:** Remove host-level `acme_host` and `default_response` from:
- `cortex-alpha.json`: remove `acme_host` and `default_response`
- `remote-worker.json`: remove `default_response`
- `gaming-host-1.json`: remove `default_response`
- `_template.json`: remove `default_response`

The `default_response` behavior is provided by the `_` vhost entry in `vhosts` (which has `"return": "444"`). The `acme_host` is kept per-user-decision (Q2) — it stays in JSON for now as a host-level default.

Wait — Q2 says "acme_host stays." Let me re-read: "acme_host via wildcard cert is currently expected for dns-01 as standard security; however in future we will need to set up acme per-domain via dns-01."

So `acme_host` **stays** in JSON. Only `default_response` is removed (it's redundant with the `_` vhost entry).

**Revised task:**
- Remove `default_response` from cortex-alpha.json, remote-worker.json, gaming-host-1.json, _template.json
- Keep `acme_host` in cortex-alpha.json

**Success criteria:**
- No `default_response` key in any JSON file
- `acme_host` retained in cortex-alpha.json
- `_` vhost entry provides default response behavior
- Golden tests still pass

### Phase RF-0 Verification Gate

**Executor:** `tpol-minimax`

**Criteria:**
1. No `listenAddresses` in any JSON vhost entry
2. No `unknown-lan` placeholders
3. `shared.json` deleted; `lan_dhcp` in cortex-alpha.json
4. `advertised_tailscale_routes` matches legacy
5. No `default_response` at host level; `acme_host` retained
6. All unit test suites pass
7. cortex-alpha golden passes

---

## Phase RF-1 — Populate Missing Topology Data

**Goal:** Add routes, WireGuard peer list, firewall rules, and DNS config to cortex-alpha.json.

### Step RF-1.1 — Populate `routes` in cortex-alpha.json

**Executor:** `bellana-deepseek`

**Task:** Read `topology/cortex-alpha.nix` lines 367-442 (forwarding rules). Convert the TCP/UDP forwarding entries into `routes` entries in `cortex-alpha.json`.

Schema:
```json
"routes": [
  {
    "from": "wan",
    "port": 2208,
    "proto": "tcp",
    "to": "10.88.128.3:22",
    "reason": "SSH to local-nas"
  }
]
```

Map all TCP and UDP forwarding entries from the legacy file.

**Success criteria:**
- `cortex-alpha.json` has non-empty `routes` array
- All forwarding entries from legacy file are represented
- JSON valid

### Step RF-1.2 — Add WireGuard peer list to cortex-alpha.json

**Executor:** `bellana-deepseek`

**Task:** Read `topology/cortex-alpha.nix` lines 569-598 (WireGuard peer list). Add a `wireguard` field to `cortex-alpha.json`:

```json
"wireguard": {
  "interface": "wireg0",
  "listen_port": 2108,
  "peers": ["LINDA", "alpha-one", "alpha-three", ...]
}
```

This is the hub's WireGuard configuration — who the hub peers with. The peer list comes from the legacy file. The registry already derives `wg_peers` from coordinates (line ~117), but the hub needs an explicit peer list for WireGuard config generation.

**Success criteria:**
- `cortex-alpha.json` has `wireguard` field with interface, listen_port, peers
- All peers from legacy file are included
- JSON valid

### Step RF-1.3 — Add firewall rules to cortex-alpha.json

**Executor:** `bellana-deepseek`

**Task:** Read `topology/cortex-alpha.nix` lines 601-650 (firewall rules). Add a `firewall` field to `cortex-alpha.json`:

```json
"firewall": {
  "allowed_tcp_ports": [22, 636, 1108],
  "allowed_udp_ports": [],
  "interfaces": {
    "wireg0": { "tcp": [443, 3100, 3101, 3102], "udp": [1108] },
    "enp3s0": { "tcp": [443, 2208], "udp": [1108, 2108, 67, 53] },
    "enp2s0": { "tcp": [2208], "udp": [2108, 2207, 17780, 17781, 17782, 17783, 17784, 17785, 27015, 4175, 4179, 4171] }
  }
}
```

**Success criteria:**
- `cortex-alpha.json` has `firewall` field
- All firewall rules from legacy file are represented
- JSON valid

### Step RF-1.4 — Add DNS/DHCP config to cortex-alpha.json

**Executor:** `bellana-deepseek`

**Task:** Read `topology/cortex-alpha.nix` lines 456-502 (DNS/DHCP). Add a `dns` field to `cortex-alpha.json`:

```json
"dns": {
  "interface": "enp3s0",
  "static": [
    { "domain": "git.johnbargman.net", "ip": "10.88.128.1" },
    { "domain": "code.johnbargman.net", "ip": "10.88.128.1" },
    ...
  ],
  "dhcp": {
    "range": "10.88.128.128,10.88.128.254,24h",
    "interface": "enp3s0"
  },
  "servers": ["208.67.220.220", "208.67.222.222", "1.0.0.1", "8.8.8.8"]
}
```

**Success criteria:**
- `cortex-alpha.json` has `dns` field
- All DNS static entries from legacy file are represented
- DHCP range matches legacy
- JSON valid

### Phase RF-1 Verification Gate

**Executor:** `tpol-minimax`

**Criteria:**
1. `cortex-alpha.json` has `routes` (non-empty), `wireguard`, `firewall`, `dns`
2. All data matches legacy `.nix` file
3. mkRegistry: 0 errors, 0 warnings
4. All unit tests pass
5. cortex-alpha golden passes

---

## Phase RF-2 — Add Tailscale Validator + Full Verification

**Goal:** Add Tailscale ACL drift validator. Full verification of all fixes.

### Step RF-2.1 — Implement `vTailscaleRoutes` validator

**Executor:** `bellana-deepseek`

**Task:** Add a new validator to `lib/topology/mkRegistry.nix`:

For each host that has `advertised_tailscale_routes`:
1. For each route CIDR in the list, check if it overlaps with any of the host's coordinate subnets
2. If no overlap, emit a warning: `"WARNING: ${hostname}: advertised_tailscale_routes entry '${route}' does not overlap with any coordinate subnet"`

This is a WARNING, not an error — Tailscale can advertise routes for subnets the host doesn't directly sit on (that's the point of subnet routing). But it should flag drift.

Add to `allWarnings` aggregation. Update unit tests to expect the warnings.

**Success criteria:**
- `vTailscaleRoutes` validator added to `mkRegistry.nix`
- Warning emitted for cortex-alpha's non-overlapping routes
- Unit tests updated
- mkRegistry: 0 errors (warnings OK)

### Step RF-2.2 — Full golden suite + unit tests + commit

**Executor:** `bellana-deepseek`

**Task:** Run all 16 golden checks and all 6 unit test suites. Commit all changes. Push.

**Success criteria:**
- All 16 golden-enabled machines: PASS_IDENTICAL or PASS_NIXPKGS_DRIFT
- All 6 unit test suites pass
- mkRegistry: 0 errors, warnings for Tailscale ACL drift only
- Commit pushed to origin

### Phase RF-2 Final Verification Gate

**Executor:** `tpol-minimax`

**Criteria:**
1. All golden tests pass
2. All unit tests pass
3. mkRegistry: 0 errors
4. No `listenAddresses` in JSON vhosts
5. No `unknown-lan` placeholders
6. No `default_response` at host level
7. `cortex-alpha.json` has `routes`, `wireguard`, `firewall`, `dns`, `lan_dhcp`
8. `shared.json` deleted
9. `vTailscaleRoutes` validator active
10. Commit pushed to origin
11. **APPROVED** — review fixes complete
