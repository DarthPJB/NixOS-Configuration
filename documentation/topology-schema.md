# Topology Schema (Planar)

> **Status:** This document is the canonical description of the new planar topology schema
> (post-Phase 0). The old schema (in `.nix` files like `topology/cortex-alpha.nix` and
> `topology/shared.nix`) is preserved for reference but is **no longer the source of truth**.
> The JSON schema in `topology/<machine>.json` files is the canonical source of truth.
> See `documentation/2026-07-18-MULTI-HORIZON-GATEWAY-PLAN.md` (rev 8, §3) for the full
> design specification.

## Overview

- `topology/<machine>.json` is the per-host source of truth (one file per host, one host
  per file). Filename and `hostname` field MUST match — this is enforced by the registry.
- `topology/shared.json` holds cross-host data (WireGuard peer metadata, DHCP ranges, etc.).
- `topology/_template.json` is the machine-readable template for new hosts — operators copy
  this file, rename it, and fill in the fields.
- `lib/topology/mkRegistry.nix` reads every `topology/*.json` (excluding `shared.json` and
  `_template.json`) via `builtins.readDir` + `builtins.readFile` + `builtins.fromJSON` and
  produces a validated registry attrsect: `{ hosts, shared, planes, errors, warnings }`.
- `lib/topology/mkHorizons.nix` is the per-machine horizon transformer: it consumes the
  registry and a hostname, then produces the host's resolved settings (coordinate, hub_of,
  effective ICMP, applicable routes, vhostPlanes, errors, warnings).

## Schema Fields (13 per-host fields)

### `hostname` (required)

- **Type:** String
- **Description:** The canonical hostname of the machine. MUST match the filename stem
  (e.g., a file named `topology/cortex-alpha.json` MUST have `"hostname": "cortex-alpha"`).
  Mismatch is a build error enforced by `lib/topology/mkRegistry.nix`.
- **Example:**
  ```json
  "hostname": "cortex-alpha"
  ```

### `role` (required)

- **Type:** String (enum)
- **Description:** The machine's network role. The registry uses this for categorization;
  specific values are:
  - `"leaf"` — A pure leaf node with no `hub_of` entries.
  - `"hub"` — Defines one or more planes (has non-empty `hub_of`).
  - `"sub-hub"` — A hub that also has a parent coordinate with a `parent` reference.
  - `"workstation"` — User workstation.
  - `"server"` — Server (non-hub).
  - `"bastion"` — Bastion/jump host.
  - `"ap"` — Access point.
  - `"iot"` — IoT device.
  - `"client"` — Generic client device.
- **Example:**
  ```json
  "role": "hub"
  ```

### `trust` (optional, default `3`)

- **Type:** Integer (0–6)
- **Description:** The host's overall trust level. This is a summary value; per-coordinate
  trust is specified in each `coordinate` entry. Trust is metadata for operator reasoning
  and the 3D render — it is NOT route-level policy (routes are explicit whitelist entries).
  See [Trust levels](#trust-levels) below for the full scale.
- **Example:**
  ```json
  "trust": 5
  ```

### `coordinate` (required, array)

- **Type:** Array of objects
- **Description:** The host's position on every network plane it participates in. Each
  coordinate entry is one tuple `(plane_name, subnet, peer_id, trust, interface)`.
  A coordinate is NOT just a subnet — the subnet is the plane, the peer_id is the host's
  position on that plane, and together `(subnet, peer_id, trust)` form a point in 3D space.
- **Required fields per entry:**
  - `plane_name` (string) — Opaque identifier for the plane (e.g., `"cortex-alpha.lan"`).
  - `subnet` (string, CIDR) — The subnet in CIDR notation (e.g., `"10.88.128.0/24"`).
  - `peer_id` (integer) — The host's position on the subnet (the /32 host octet, or host
    portion of a longer prefix). Unique per `(plane_name, subnet)` pair across the registry.
  - `trust` (integer, 0–6) — Per-coordinate trust value for this plane.
  - `interface` (string) — The local interface name (e.g., `"enp3s0"`, `"wireg0"`).
- **Optional fields:**
  - `parent` (object or null) — For sub-hubs, a reference to the parent hub:
    `{ "host": "<parent-hostname>", "subnet": "<parent-subnet>" }`.
- **Example:**
  ```json
  "coordinate": [
    { "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24", "peer_id": 1,   "trust": 1, "interface": "enp3s0" },
    { "plane_name": "wg",                 "subnet": "10.88.127.0/24", "peer_id": 1,   "trust": 3, "interface": "wireg0" },
    { "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10",  "peer_id": 1,   "trust": 2, "interface": "tailscale0" }
  ]
  ```

### `hub_of` (optional, default `[]`)

- **Type:** Array of objects
- **Description:** The planes this host anchors. Each entry declares that this host is the
  hub of the given `(plane_name, subnet)` pair. A host with `hub_of: []` is a pure leaf
  (valid edge case). Exactly one host per `(plane_name, subnet)` pair may declare `hub_of`.
- **Required fields per entry:**
  - `plane_name` (string)
  - `subnet` (string, CIDR)
- **Example:**
  ```json
  "hub_of": [
    { "plane_name": "cortex-alpha.lan", "subnet": "10.88.128.0/24" },
    { "plane_name": "wg",               "subnet": "10.88.127.0/24" }
  ]
  ```

### `icmp_defaults` (optional, default `{ "pmtud": true, "ping": false }`)

- **Type:** Object
- **Description:** Default ICMP policy for all interfaces on this host. The two recognized
  keys are `pmtud` (allow ICMP type 3 destination-unreachable for PMTUD) and `ping` (allow
  ICMP echo-request/echo-reply). Per-interface overrides in `icmp_override` take precedence.
- **Example:**
  ```json
  "icmp_defaults": {
    "pmtud": true,
    "ping": false
  }
  ```

### `icmp_override` (optional, default `{}`)

- **Type:** Object keyed by interface name
- **Description:** Per-interface ICMP policy overrides. Each key is an interface name; each
  value is an object with `pmtud` and/or `ping` booleans. Every key MUST match an interface
  in the host's `coordinate[*].interface` (enforced by the registry as a warning).
  Resolution order: `icmp_override[iface] ?? icmp_defaults ?? { pmtud: true, ping: false }`.
- **Example:**
  ```json
  "icmp_override": {
    "enp3s0":     { "ping": true },
    "tailscale0": { "ping": true }
  }
  ```

### `routes` (optional, default `[]`)

- **Type:** Array of objects
- **Description:** Explicit whitelist of allowed traffic between subnets. The default is
  DROP — every route is an explicit allow. A route applies to every hub that sits on both
  `from_subnet` and `to_subnet`. The `reason` field is required for auditability.
- **Required fields per entry:**
  - `from_subnet` (string, CIDR) — Source subnet.
  - `to_subnet` (string, CIDR) — Destination subnet.
  - `proto` (string) — Protocol: `"tcp"`, `"udp"`, or `"any"`.
  - `reason` (string) — Human-readable justification.
- **Optional fields:**
  - `ports` (array of integers) — Required when `proto` is `"tcp"` or `"udp"`.
- **Example:**
  ```json
  "routes": [
    { "from_subnet": "82.5.173.0/24",  "to_subnet": "10.88.128.0/24", "proto": "tcp", "ports": [22, 80, 443], "reason": "Public services on LAN" },
    { "from_subnet": "10.88.127.0/24", "to_subnet": "10.88.128.0/24", "proto": "any",                    "reason": "WG clients reach LAN" }
  ]
  ```

### `requires_routes` (optional, default `[]`)

- **Type:** Array of objects
- **Description:** Declares that this host needs a route from `via_subnet` to `to_subnet`.
  The registry and horizon transformer validate that such a route exists or suggest the hub
  that provides it. If the host is already on `to_subnet` (via its own coordinate), no route
  is required — skipped automatically. Multi-hop BFS pathfinding is used when no single hub
  spans both subnets.
- **Required fields per entry:**
  - `via_subnet` (string, CIDR) — The subnet the host is on (the entry point).
  - `to_subnet` (string, CIDR) — The target subnet the host needs to reach.
  - `reason` (string) — Human-readable justification.
- **Example:**
  ```json
  "requires_routes": [
    { "to_subnet": "10.88.128.0/24", "via_subnet": "10.88.127.0/24", "reason": "remote-worker needs to reach the LAN" }
  ]
  ```

### `vhostPlanes` (optional, default `{}`)

- **Type:** Object keyed by vhost name (string), values are arrays of plane entries
- **Description:** Declares which planes each virtual host (vhost) is served on. Each
  vhost entry is a list of `{ plane_name, subnet, reason, proxy_to? }` objects — one per
  plane the vhost is reachable on. This drives per-subnet nginx vhost stanzas.
- **Required fields per vhost entry:**
  - `plane_name` (string)
  - `subnet` (string, CIDR)
  - `reason` (string)
- **Optional fields per vhost entry:**
  - `proxy_to` (string) — Backend in `"ip:port"` format. If present, the generator emits
    `proxyPass`. If absent, the vhost is static (operator fills in `root` in the machine's
    Nix config).
- **Example:**
  ```json
  "vhostPlanes": {
    "code.johnbargman.net": [
      { "plane_name": "cortex-alpha.lan", "subnet": "10.88.128.0/24", "proxy_to": "10.88.127.3:80", "reason": "Gitea on LAN" },
      { "plane_name": "wg",               "subnet": "10.88.127.0/24", "proxy_to": "10.88.127.3:80", "reason": "Gitea on WG" }
    ]
  }
  ```

### `default_response` (optional, default `"404-or-drop"`)

- **Type:** String
- **Description:** The default HTTP response for vhosts not explicitly configured. The value
  `"404-or-drop"` returns a 404 for HTTP and drops the connection for non-HTTP traffic.
  This prevents ALPN leakage. Future values may be added (e.g., `"444"`, `"deny"`).
- **Example:**
  ```json
  "default_response": "404-or-drop"
  ```

### `advertised_tailscale_routes` (optional, default `[]`)

- **Type:** Array of strings (CIDR notation)
- **Description:** Subnets to advertise to the Tailscale mesh. The registry emits a warning
  if any subnet in this list is NOT in the host's own coordinate (Tailscale ACL drift
  detection). Each entry should be a /32 for a single host or a larger subnet for routing.
- **Example:**
  ```json
  "advertised_tailscale_routes": ["10.88.128.0/24", "10.88.127.0/24"]
  ```

### `public_key_file` (optional, default `null`)

- **Type:** String (path) or null
- **Description:** Path (relative to the repository root) to the WireGuard public key file
  for this host. If non-null, the file MUST exist on disk (enforced by the registry).
  Convention: `"secrets/public_keys/wireguard/wg_<hostname>_pub"`.
- **Example:**
  ```json
  "public_key_file": "secrets/public_keys/wireguard/wg_cortex-alpha_pub"
  ```

### `_` (optional, documentation comments)

- **Type:** String
- **Description:** A documentation comment field. Not consumed by any transformer; purely
  for human readers. Use this to annotate the file with notes, conventions, or reminders.
- **Example:**
  ```json
  "_": "This host is the primary LAN gateway for the homestead."
  ```

## Trust Levels

Trust is a 7-level scale (0–6) modeled on CPU protection rings:

| Level | Name | Description |
|-------|------|-------------|
| 0 | `loopback` | Intra-unit / high-trust-LAN / airgap |
| 1 | `managed-trusted-LAN` | Managed, trusted LAN (e.g., cortex-alpha.lan) |
| 2 | `unmanaged-trusted-LAN` | Unmanaged but trusted LAN (e.g., dlyon-lan, building-b.lan) |
| 3 | `managed-VPN` | Managed VPN (e.g., WireGuard plane) |
| 4 | `unmanaged-VPN` | Unmanaged VPN / third-party tunnel |
| 5 | `untrusted-LAN` | Untrusted LAN (guest network, DMZ) |
| 6 | `WAN` | Public internet |

Trust is **metadata** (used by the 3D render and operator reasoning), not **policy**
(which routes are allowed). Routes are explicit whitelist entries. The Z-axis of the 3D
graph is trust — planes are rendered at their trust height, hosts at their per-coordinate
trust height within each plane.

## Cross-References

| Reference | Description |
|-----------|-------------|
| `documentation/2026-07-18-MULTI-HORIZON-GATEWAY-PLAN.md` (rev 8, §3) | Full design specification with data model, examples, and rationale |
| `topology/_template.json` | Machine-readable template for new hosts |
| `lib/topology/mkRegistry.nix` | Registry implementation — reads, indexes, and validates all JSON files |
| `lib/topology/mkHorizons.nix` | Per-machine horizon transformer — resolves ICMP, applicable routes, and requires_routes |
| `topology/cortex-alpha.json` | Example: a hub with 4 planes (LAN, WG, tailscale, WAN), routes, and vhost planes |
| `topology/local-nas.json` | Example: a leaf host on two planes (LAN and WG) |
| `topology/remote-worker.json` | Example: a leaf with `requires_routes` and ICMP overrides |
| `topology/dlyon.json` | Example: a sub-hub with a parent reference to cortex-alpha |

## Validation Rules

The registry (`lib/topology/mkRegistry.nix`) validates all JSON files with the following
checks. Errors cause a build failure; warnings are informational.

| # | Validator | Description |
|---|-----------|-------------|
| 1 | Filename/hostname binding | `topology/<X>.json` MUST contain `"hostname": "<X>"` |
| 2 | Plane identifier completeness | Every `hub_of` entry MUST have both `plane_name` and `subnet` |
| 3 | Plane identifier uniqueness | No two distinct `(plane_name, subnet)` pairs may be identical |
| 4 | Hub uniqueness | Exactly one host per `(plane_name, subnet)` may declare `hub_of` |
| 5 | Sub-hub parent resolution | Every `parent = { host, subnet }` reference resolves to a known hub |
| 6 | Cycle detection | No cycles in the parent graph (DFS traversal) |
| 7 | Route requirements | Every route MUST have `from_subnet`, `to_subnet`, `proto`, and `reason` |
| 8 | Coordinate requirements | Every coordinate MUST have `plane_name`, `subnet`, `peer_id`, `trust`, and `interface` |
| 9 | Public key file existence | If `public_key_file` is non-null, the file MUST exist on disk |
| 10 | Dangling coordinate detection | Every coordinate's `(plane_name, subnet)` must appear in some host's `hub_of` |
| 11 | Peer ID uniqueness | No two coordinates share the same `(plane_name, subnet, peer_id)` triple |
| 12 | ICMP override interface validation | Every key in `icmp_override` must match a coordinate's interface (warning) |
| 13 | Subnet size validation | `/N` for `N ≤ 24` accepted; `N > 24` rejected |
| 14 | Orphan wg_peer warning | A `shared.json` wg_peers entry without a matching `topology/<name>.json` produces a warning |

Additional validation in `lib/topology/mkHorizons.nix`:

| # | Validator | Description |
|---|-----------|-------------|
| 15 | Host existence | The requested hostname must exist in the registry |
| 16 | Coordinate emptiness | A host with no coordinate entries is an error |
| 17 | requires_routes field completeness | Every entry must have `via_subnet`, `to_subnet`, and `reason` |
| 18 | requires_routes local-subnet shortcut | If `to_subnet` is already in the host's coordinate, skip |
| 19 | requires_routes multi-hub selection | Sorted by trust ascending, then alphabetically |
| 20 | requires_routes N-hop chain | BFS pathfinding across the hub graph |

## Phase 0 Cleanup History

This schema was developed through the planar topology design (Phase 0 and earlier). Key
milestones:

- **Phase -2 (Data Cleanup):** Per-host JSON files were created from the existing LAN
  hosts. Sub-hub data was extracted. Public key files were mapped to the WG peer identifier
  convention. `_`-prefixed fields were consolidated into `_legacy` objects. The `role` field
  was removed from per-host files (the registry derives it from `hub_of` and `parent`).
  Plane names were standardized to `cortex-alpha.lan` convention. The `trust` field was
  added based on max coordinate trust.

- **Phase -1 (Nix-to-JSON Conversion):** The old `topology/cortex-alpha.nix` and
  `topology/shared.nix` were converted to JSON manually. Both formats coexist during
  migration.

- **Phase 0a (Registry as Dormant Code):** `lib/topology/mkRegistry.nix` was implemented
  as a standalone validator. Not yet wired into any machine's evaluation.

- **Phase 0b (Registry Wired):** The registry is consumed by `core-router-topology.nix`
  instead of the raw Nix `import`. A `useNewPipeline` flag in `flake.nix` toggles between
  the old pipeline (Nix files) and the new pipeline (JSON files + registry).

- **Phase A (Schema Additions):** This document and `topology/_template.json` were created.
  `lib/topology/mkHorizons.nix` was implemented.

**Current state:**

- The old schema (`.nix` files) is preserved in `topology/cortex-alpha.nix` and
  `topology/shared.nix` for reference but is **not the source of truth**.
- The new schema (`.json` files) in `topology/` is the canonical source of truth.
- A `useNewPipeline` flag in `flake.nix` allows toggling between the two pipelines for
  safe migration.

## Adding New Machines

To add a new machine to the planar topology:

1. **Copy the template:** `cp topology/_template.json topology/<machine>.json`
2. **Fill in the fields:** Set `hostname`, `role`, `trust`, and at least one `coordinate`
   entry. Add `hub_of` if the machine is a hub. Add `routes` if it needs to declare traffic
   rules. Add `public_key_file` if it has WireGuard.
3. **Validate:** `nix flake check` — the registry validates all files.
4. **Run golden tests:** `nix run .#check-network -- <machine>` ensures golden parity.
5. **Deploy:** Wire the machine into the appropriate NixOS module.

See `documentation/2026-07-18-MULTI-HORIZON-GATEWAY-PLAN.md` (Phase A) and
`topology/_template.json` for the complete procedure.
