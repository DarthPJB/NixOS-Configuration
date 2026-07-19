# PLAN: Multi-Horizon Gateway Architecture (rev 7)
**Date:** 2026-07-18 (rev 7)
**Author:** OpenCode Agent (minimax-m3)
**Status:** DESIGN — pending user review and approval
**Supersedes:** rev 1, 2, 3, 4, 5, 6
**Path:** `documentation/2026-07-18-MULTI-HORIZON-GATEWAY-PLAN.md`

---

## 0. Foundation (six load-bearing invariants)

This design rests on six architectural invariants. Every transformer, every validation rule, every data field, every phase boundary must trace to one or more of these.

1. **Topology is JSON, hand-edited, source of "what will be."** Per-host files are `topology/<machine>.json` (one file per host, one host per file). Shared data is `topology/shared.json`. The operator edits these by hand. They are the source of truth for the desired state.

2. **The golden is JSON, hand-edited, source of "what was."** `goldens/<machine>.json` is the prior implementation's truth. It is the contract. The generator must produce config that matches it.

3. **The generator is Nix code, one function, `serializeConfig :: Config -> JSON`.** Implemented as `lib/serialize-config.nix`. It is a pure function: given a config (which is itself produced by the topology → transformer → config pipeline), the JSON output is determined. The generator does not produce topology source. **IFD is forbidden.**

4. **Topology defines configuration through consumption by hostname matching.** Every `nixosConfiguration.<machine>` is rendered by the topology transformer pipeline that reads `topology/<machine>.json` (or `topology/shared.json`). No hand-edited per-machine service blocks in `machines/<machine>/default.nix`. The current `machines/remote-worker/default.nix` inline `services.nginx` block is the anti-pattern this design replaces.

5. **The 3D render is a viewer of the topology JSON, not a Nix derivation.** Same data, different visualization. The render is a separate tool that reads the JSON directly. The topology data must be representable as a graph in 3D. The graph is `(subnet, peer_id, trust)`.

6. **Trust is the Z-axis of the 3D graph, not a route-level policy.** Each coordinate has a `trust` value (0..6, like CPU rings). Trust is *metadata* (used by the 3D render and operator reasoning), not *policy* (which routes are allowed). Routes are explicit whitelist entries. The onion-skin rule is dropped. Same-named subnets at different hosts can have different trust values.

**ZERO-TRUST default:** if a route is not declared in the topology JSON, and not certified with manual / cryptographic means, it is **dropped**. The operator implements the topology into reality; the topology declares the structure.

---

## 1. Mental model (cartesian, refined)

### 1.1 The planes — `plane_name + subnet` is an absolute reference

A **plane** is a *subnet* (a /24 or smaller for IPv4). A plane is **identified by the pair `(plane_name, subnet)`** — both are required. The plane_name is an opaque string (whatever the operator wants). The subnet is the address space.

A hub **defines** a plane. The hub is the host at the center of the star-topology on that plane. Peers are at the spokes.

| `plane_name` | `subnet` | Trust | Notes |
|---|---|---|---|
| `cortex-alpha.lan` | 10.88.128.0/24 | 1 (managed-trusted-LAN) | Hub's home LAN, defined by `cortex-alpha` |
| `wg` | 10.88.127.0/24 | 3 (managed-VPN) | Hub's WG plane, defined by `cortex-alpha` |
| `tailscale-platonic` | 100.64.0.0/10 | 2 (unmanaged-trusted-LAN) | Tailscale mesh, defined by `cortex-alpha` |
| `82.5.173.0/24-wan` | 82.5.173.0/24 | 6 (WAN) | Public internet, defined by `cortex-alpha` |
| `dlyon-lan` | 10.99.128.0/24 | 2 (unmanaged-trusted-LAN) | Defined by `dlyon` |
| `building-b.lan` | 10.89.128.0/24 | 2 (unmanaged-trusted-LAN) | Defined by `building-b` |

A plane is **defined by its hub**. The hub *anchors* the plane. The interface is one anchor; the subnet is the coordinate range; the trust is the meaning.

Same `subnet` cannot be on two planes (the registry enforces this). Same `plane_name` cannot be on two subnets (the registry enforces this too). The pair is unique.

### 1.2 The points (hosts) — coordinates are `(plane_name, subnet, peer_id, trust)`

A **host's coordinate** is a list of `(plane_name, subnet, peer_id, trust, ...)` tuples. The `peer_id` is the host's position on the subnet (the /32 host octet, or the host portion of a longer prefix). The `trust` is per-coordinate: a host can be on multiple planes with different trust values per coordinate.

**A coordinate is NOT just a subnet.** The subnet is the plane; the peer_id is the host's position on that plane. Together they identify a point in the 3D space `(subnet, peer_id, trust)`.

```json
{
  "hostname": "cortex-alpha",
  "role": "hub",
  "trust": 5,
  "coordinate": [
    { "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24", "peer_id": 1,   "trust": 1, "interface": "enp3s0" },
    { "plane_name": "wg",                 "subnet": "10.88.127.0/24", "peer_id": 1,   "trust": 3, "interface": "wireg0" },
    { "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10",  "peer_id": 1,   "trust": 2, "interface": "tailscale0" },
    { "plane_name": "82.5.173.0/24-wan",  "subnet": "82.5.173.0/24",  "peer_id": 252, "trust": 6, "interface": "enp2s0" }
  ],
  "hub_of": [
    { "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24" },
    { "plane_name": "wg",                 "subnet": "10.88.127.0/24" },
    { "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10" },
    { "plane_name": "82.5.173.0/24-wan",  "subnet": "82.5.173.0/24" }
  ],
  ...
}
```

**The 3D graph is `(subnet, peer_id, trust)`.** The plane_name is a label. The data carries the name; the topology declares what it represents.

**No "hub is at peer_id 1" convention.** The peer_id is whatever it is. The hub is declared by `hub_of`. The registry validates hub uniqueness per `(plane_name, subnet)` pair.

### 1.3 The hubs (explicit, declared)

```
cortex-alpha    : hub of { (cortex-alpha.lan, 10.88.128.0/24), (wg, 10.88.127.0/24), (tailscale-platonic, 100.64.0.0/10), (82.5.173.0/24-wan, 82.5.173.0/24) }
building-b      : sub-hub; hub of { (building-b.lan, 10.89.128.0/24) }; parent = { host: "cortex-alpha", subnet: "10.88.127.0/24" }
remote-worker   : leaf; coordinate: [(wg, 10.88.127.0/24, peer_id 50, trust 3)]
lindacore-88    : leaf; coordinate: [(cortex-alpha.lan, 10.88.128.0/24, peer_id 88, trust 1), (wg, 10.88.127.0/24, peer_id 88, trust 3)]
```

A **hub** is the named core of a star-topology. The hub is the host whose `hub_of` includes a given `(plane_name, subnet)` pair. A sub-hub is a hub that is itself a leaf on a parent hub's plane.

The star-topology framing: a hub **defines** a plane; peers occupy the spokes at their `peer_id` positions. The hub is at the center; peers are at the periphery.

### 1.4 The routes (whitelist, point-to-point, with reason)

A **route** is a *directed* edge: `{ from_subnet, to_subnet, proto, ports, reason }`. `from_subnet` and `to_subnet` are subnet *addresses* (not host names). A route applies to every hub that has both subnets in its coordinate. The `reason` field is required.

```json
{
  "routes": [
    { "from_subnet": "82.5.173.0/24",  "to_subnet": "10.88.128.0/24", "proto": "tcp", "ports": [22, 80, 443, 2208], "reason": "Public services on LAN" },
    { "from_subnet": "10.88.127.0/24", "to_subnet": "10.88.128.0/24", "proto": "any", "reason": "WG clients reach LAN" }
  ]
}
```

Default: drop. Every route is an explicit allow.

### 1.5 The intersections

Two subnets intersect at a host that sits on both. **Most intersections are at hubs.** But not all: a sub-hub at `10.88.127.100` (within the parent's WG subnet) intersects `10.88.127.0/24` (parent's subnet) and `10.89.128.0/24` (its own subnet) — that's a 2-subnet intersection at a non-hub.

The chain `office-1 → building-b → cortex-alpha → lan-target` is **not** in the data. It's the kernel routing table plus per-hub nftables. The data declares the topology; the kernel renders the routing.

### 1.6 The 3D render

The 3D graph is `(subnet, peer_id, trust)`. The render is a viewer of the topology JSON.

- X = subnet (or some encoding of it)
- Y = peer_id (0..255 for /24)
- Z = trust (0..6)

Planes are translucent surfaces at their trust Z-height. Hosts are nodes at `(subnet, peer_id, trust)`. Routes are arrows between planes, color-coded by trust crossing.

### 1.7 Hub-of-hubs: the dlyon example

`dlyon` is an offsite peer on the WG subnet. Its coordinate is `[(wg, 10.88.127.0/24, peer_id 200, trust 3)]`. From WG → dlyon, dlyon might act as a gateway to its own LAN (dlyon-lan, an unmanaged-trusted subnet at trust 2). This is a sub-hub:

```json
{
  "hostname": "dlyon",
  "role": "sub-hub",
  "trust": 4,
  "coordinate": [
    { "plane_name": "wg",         "subnet": "10.88.127.0/24", "peer_id": 200, "trust": 3, "interface": "wireg0", "parent": { "host": "cortex-alpha", "subnet": "10.88.127.0/24" } },
    { "plane_name": "dlyon-lan",  "subnet": "10.99.128.0/24", "peer_id": 1,   "trust": 2, "interface": "enp3s0" }
  ],
  "hub_of": [
    { "plane_name": "dlyon-lan", "subnet": "10.99.128.0/24" }
  ],
  "routes": [
    { "from_subnet": "10.88.127.0/24", "to_subnet": "10.99.128.0/24", "proto": "any", "reason": "WG peers reach dlyon's LAN" },
    { "from_subnet": "10.99.128.0/24", "to_subnet": "10.88.127.0/24", "proto": "any", "reason": "dlyon's LAN reaches WG" }
  ]
}
```

The hostname `dlyon` is just a string. The role is `sub-hub` (declared). The "intranet within the internet" model: WG is the transport; sub-hubs expose private LANs.

### 1.8 The mutable topology: the remote-builder example

`remote-builder` is on the WG subnet (at peer_id 200, trust 3 — managed-VPN). Its current `requires_routes` says it needs to reach `cortex-alpha`, `hyper-hyper`, and `arm-builder`. The current path is:

```
remote-builder → cortex-alpha (via WG, 150 miles) → hyper-hyper (via ???) and arm-builder (via WG)
```

The proposed change:

1. Add a tailscale coordinate to `remote-builder`:
   ```json
   { "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10", "peer_id": 200, "trust": 2, "interface": "tailscale0" }
   ```
2. Add a route from `tailscale-platonic` to wherever hyper-hyper is reachable.
3. `remote-builder` no longer needs to route through cortex-alpha to reach hyper-hyper.

The 150 miles of WG cable is bypassed. The topology is mutable; the operator edits the JSON; the next deploy reflects the change. The golden test catches the change.

---

## 2. Data model (rev 7)

### 2.1 `topology/cortex-alpha.json` (a hub)

```json
{
  "hostname": "cortex-alpha",
  "role": "hub",
  "trust": 5,
  "coordinate": [
    { "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24", "peer_id": 1,   "trust": 1, "interface": "enp3s0" },
    { "plane_name": "wg",                 "subnet": "10.88.127.0/24", "peer_id": 1,   "trust": 3, "interface": "wireg0" },
    { "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10",  "peer_id": 1,   "trust": 2, "interface": "tailscale0" },
    { "plane_name": "82.5.173.0/24-wan",  "subnet": "82.5.173.0/24",  "peer_id": 252, "trust": 6, "interface": "enp2s0" }
  ],
  "hub_of": [
    { "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24" },
    { "plane_name": "wg",                 "subnet": "10.88.127.0/24" },
    { "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10" },
    { "plane_name": "82.5.173.0/24-wan",  "subnet": "82.5.173.0/24" }
  ],
  "advertised_tailscale_routes": ["10.88.128.0/24", "10.88.127.0/24"],
  "icmp_defaults": {
    "pmtud": true,
    "ping": false
  },
  "icmp_override": {
    "enp3s0":     { "ping": true },
    "tailscale0": { "ping": true }
  },
  "routes": [
    { "from_subnet": "82.5.173.0/24",  "to_subnet": "10.88.128.0/24", "proto": "tcp", "ports": [22, 80, 443, 2208], "reason": "Public services on LAN" },
    { "from_subnet": "82.5.173.0/24",  "to_subnet": "10.88.128.0/24", "proto": "udp", "ports": [53, 67, 2108, 27015, 17780, 17781, 17782, 17783, 17784, 17785, 4171, 4175, 4179, 2207], "reason": "Public game servers and DNS" },
    { "from_subnet": "10.88.127.0/24", "to_subnet": "10.88.128.0/24", "proto": "any", "reason": "WG clients reach LAN" },
    { "from_subnet": "100.64.0.0/10",  "to_subnet": "10.88.128.0/24", "proto": "any", "reason": "Tailscale mesh reaches LAN" },
    { "from_subnet": "10.88.128.0/24", "to_subnet": "10.88.127.0/24", "proto": "any", "reason": "LAN reaches WG peers" },
    { "from_subnet": "10.88.127.0/24", "to_subnet": "82.5.173.0/24", "proto": "tcp", "ports": [80, 443], "reason": "WG clients outbound HTTP(S) only" },
    { "from_subnet": "10.88.127.0/24", "to_subnet": "100.64.0.0/10", "proto": "any", "reason": "WG peers reach tailscale mesh" }
  ],
  "vhost_planes": [
    { "vhost": "johnbargman.net", "plane_name": "82.5.173.0/24-wan",  "subnet": "82.5.173.0/24",  "reason": "Public static webroot" },
    { "vhost": "johnbargman.net", "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24", "reason": "LAN clients see webroot" },
    { "vhost": "johnbargman.net", "plane_name": "wg",                 "subnet": "10.88.127.0/24", "reason": "WG clients see webroot" },

    { "vhost": "code.johnbargman.net", "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24", "proxy_to": "10.88.127.3:80", "reason": "Gitea on LAN" },
    { "vhost": "code.johnbargman.net", "plane_name": "wg",                 "subnet": "10.88.127.0/24", "proxy_to": "10.88.127.3:80", "reason": "Gitea on WG" },
    { "vhost": "code.johnbargman.net", "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10",  "proxy_to": "10.88.127.3:80", "reason": "Gitea on tailscale" },

    { "vhost": "git.johnbargman.net", "plane_name": "cortex-alpha.lan",  "subnet": "10.88.128.0/24", "proxy_to": "10.88.127.3:80", "reason": "Gitea (alias)" },
    { "vhost": "git.johnbargman.net", "plane_name": "wg",                 "subnet": "10.88.127.0/24", "proxy_to": "10.88.127.3:80", "reason": "Gitea (alias)" },

    { "vhost": "prometheus.johnbargman.net", "plane_name": "cortex-alpha.lan", "subnet": "10.88.128.0/24", "proxy_to": "10.88.127.3:8080", "reason": "Prometheus" },
    { "vhost": "prometheus.johnbargman.net", "plane_name": "wg",                "subnet": "10.88.127.0/24", "proxy_to": "10.88.127.3:8080", "reason": "Prometheus" },

    { "vhost": "grafana.johnbargman.net", "plane_name": "cortex-alpha.lan", "subnet": "10.88.128.0/24", "proxy_to": "10.88.127.3:3101", "reason": "Grafana" },
    { "vhost": "grafana.johnbargman.net", "plane_name": "wg",                "subnet": "10.88.127.0/24", "proxy_to": "10.88.127.3:3101", "reason": "Grafana" },

    { "vhost": "print-controller.johnbargman.net", "plane_name": "cortex-alpha.lan", "subnet": "10.88.128.0/24", "proxy_to": "10.88.127.30:80", "reason": "Print controller" },

    { "vhost": "ap.johnbargman.net", "plane_name": "cortex-alpha.lan", "subnet": "10.88.128.0/24", "proxy_to": "10.88.128.2:80", "reason": "Access point admin" }
  ],
  "default_response": "404-or-drop"
}
```

**Key changes from rev 6:**
- `hub_of` is a list of `{plane_name, subnet}` objects, both required. One without the other is incomplete.
- `vhost_planes` is a list of `{vhost, plane_name, subnet, reason, proxy_to?}` entries. Each entry declares which vhost appears on which `(plane_name, subnet)` pair. Multiple entries for the same vhost on different planes are allowed.
- Coordinates explicitly carry `peer_id` (the /32 host on the /24 plane). The plane is `(plane_name, subnet)`; the coordinate on the plane is `peer_id`.

### 2.2 `topology/building-b.json` (a sub-hub)

```json
{
  "hostname": "building-b",
  "role": "sub-hub",
  "trust": 4,
  "coordinate": [
    { "plane_name": "wg",              "subnet": "10.88.127.0/24", "peer_id": 100, "trust": 3, "interface": "wireg0", "parent": { "host": "cortex-alpha", "subnet": "10.88.127.0/24" } },
    { "plane_name": "building-b.lan",  "subnet": "10.89.128.0/24", "peer_id": 1,   "trust": 2, "interface": "enp3s0" }
  ],
  "hub_of": [
    { "plane_name": "building-b.lan", "subnet": "10.89.128.0/24" }
  ],
  "routes": [
    { "from_subnet": "10.88.127.0/24", "to_subnet": "10.89.128.0/24", "proto": "any", "reason": "WG peers reach building-b's LAN" },
    { "from_subnet": "10.89.128.0/24", "to_subnet": "10.88.127.0/24", "proto": "any", "reason": "building-b's LAN reaches WG" }
  ]
}
```

### 2.3 `topology/remote-builder.json` (a leaf, mutable topology)

**Current (rev 7 baseline):**

```json
{
  "hostname": "remote-builder",
  "role": "leaf",
  "trust": 4,
  "coordinate": [
    { "plane_name": "wg", "subnet": "10.88.127.0/24", "peer_id": 200, "trust": 3, "interface": "wireg0" }
  ],
  "icmp_override": {
    "wireg0": { "ping": true }
  },
  "requires_routes": [
    { "to_subnet": "10.88.128.0/24", "via_subnet": "10.88.127.0/24", "reason": "remote-builder needs to reach the LAN" }
  ]
}
```

**After the topology mutation (add tailscale intersection, change the path to hyper-hyper):**

```json
{
  "hostname": "remote-builder",
  "role": "leaf",
  "trust": 4,
  "coordinate": [
    { "plane_name": "wg",                 "subnet": "10.88.127.0/24", "peer_id": 200, "trust": 3, "interface": "wireg0" },
    { "plane_name": "tailscale-platonic", "subnet": "100.64.0.0/10",  "peer_id": 200, "trust": 2, "interface": "tailscale0" }
  ],
  "icmp_override": {
    "wireg0":     { "ping": true },
    "tailscale0": { "ping": true }
  },
  "requires_routes": [
    { "to_subnet": "10.88.128.0/24", "via_subnet": "10.88.127.0/24", "reason": "remote-builder needs to reach the LAN" }
  ]
}
```

The change: add a tailscale coordinate. The 150 miles of WG cable is bypassed.

### 2.4 `topology/LINDA.json` (a leaf, two subnets)

```json
{
  "hostname": "LINDA",
  "role": "workstation",
  "trust": 3,
  "coordinate": [
    { "plane_name": "cortex-alpha.lan", "subnet": "10.88.128.0/24", "peer_id": 88, "trust": 1, "interface": "enp69s0f0" },
    { "plane_name": "wg",                "subnet": "10.88.127.0/24", "peer_id": 88, "trust": 3, "interface": "wireg0" }
  ],
  "icmp_override": {
    "enp69s0f0": { "ping": true },
    "wireg0":    { "ping": true }
  }
}
```

### 2.5 `topology/dlyon.json` (an offsite sub-hub)

```json
{
  "hostname": "dlyon",
  "role": "sub-hub",
  "trust": 4,
  "coordinate": [
    { "plane_name": "wg",         "subnet": "10.88.127.0/24", "peer_id": 200, "trust": 3, "interface": "wireg0", "parent": { "host": "cortex-alpha", "subnet": "10.88.127.0/24" } },
    { "plane_name": "dlyon-lan",  "subnet": "10.99.128.0/24", "peer_id": 1,   "trust": 2, "interface": "enp3s0" }
  ],
  "hub_of": [
    { "plane_name": "dlyon-lan", "subnet": "10.99.128.0/24" }
  ],
  "icmp_override": {
    "wireg0": { "ping": false },
    "enp3s0": { "ping": false }
  },
  "routes": [
    { "from_subnet": "10.88.127.0/24", "to_subnet": "10.99.128.0/24", "proto": "any", "reason": "WG peers reach dlyon's LAN" },
    { "from_subnet": "10.99.128.0/24", "to_subnet": "10.88.127.0/24", "proto": "any", "reason": "dlyon's LAN reaches WG" }
  ]
}
```

### 2.6 `topology/shared.json` (cross-host data)

```json
{
  "wg_peers": {
    "cortex-alpha":   { "public_key_file": "secrets/public_keys/wireguard/wg_cortex-alpha_pub", "peer_id": 1 },
    "remote-worker":  { "public_key_file": "secrets/public_keys/wireguard/wg_remote-worker_pub", "peer_id": 50 },
    "remote-builder": { "public_key_file": "secrets/public_keys/wireguard/wg_remote-builder_pub", "peer_id": 200 },
    "lindacore-88":   { "public_key_file": "secrets/public_keys/wireguard/wg_lindacore-88_pub", "peer_id": 88 },
    "dlyon":          { "public_key_file": "secrets/public_keys/wireguard/wg_dlyon_pub", "peer_id": 200 }
  },
  "lan_dhcp": {
    "range": "10.88.128.128,10.88.128.254,24h",
    "interface": "enp3s0"
  }
}
```

### 2.7 Filename ↔ hostname binding (resolves B1)

The registry (Phase 0) enforces: `topology/<X>.json` MUST contain `"hostname": "<X>"`. Mismatch is a build error.

---

## 3. The transformation pipeline (rev 7)

### 3.1 `lib/topology/mkRegistry.nix` — the topology registry (Phase 0)

Reads every `topology/*.json` via `builtins.readDir` + `builtins.readFile` + `builtins.fromJSON`. Produces:

```nix
{
  hosts = {
    "cortex-alpha" = {
      file = "topology/cortex-alpha.json";
      role = "hub";
      hub_of = [
        { plane_name = "cortex-alpha.lan"; subnet = "10.88.128.0/24"; }
        { plane_name = "wg"; subnet = "10.88.127.0/24"; }
        ...
      ];
      coordinate = [ { plane_name; subnet; peer_id; trust; interface; }; ... ];
      ...
    };
    "remote-worker" = { ... };
    ...
  };
  # plane identifier → host that defines it
  planes = {
    ("cortex-alpha.lan", "10.88.128.0/24") = "cortex-alpha";
    ("wg", "10.88.127.0/24") = "cortex-alpha";
    ("building-b.lan", "10.89.128.0/24") = "building-b";
    ("dlyon-lan", "10.99.128.0/24") = "dlyon";
    ...
  };
  routes = [ { from_subnet; to_subnet; proto; ports; reason; }; ... ];
  errors = [ ... ];
  warnings = [ ... ];
}
```

**Validation:**
- Every `hub_of` entry has both `plane_name` and `subnet` (one without the other is incomplete — build error).
- Every `coordinate` entry has `plane_name`, `subnet`, `peer_id`, `trust`, `interface`.
- Every `(plane_name, subnet)` pair is unique (no two planes share a name AND subnet, and no two subnets share a name AND subnet).
- Exactly one host per `(plane_name, subnet)` declares `hub_of` for that plane.
- Every `parent = { host, subnet }` reference resolves to a known hub.
- Cycle detection in the parent graph.
- Every route has `from_subnet`, `to_subnet`, `proto`, `ports?` (or `any`), `reason`.

If `errors` is non-empty, the build fails. **Model B from the rev 3 review: flake-level let + per-machine assertions.**

### 3.2 `lib/topology/mkHorizons.nix` — the horizon transformer (Phase A)

Consumes the registry, produces per-machine horizon settings. Resolves:
- The host's coordinate (from the registry).
- The host's `hub_of` (if hub) or the parent's `hub_of` (if sub-hub).
- The host's effective ICMP allow-list: hub's `icmp_defaults` + host's `icmp_override` (per interface). New interfaces (not in `icmp_override` and no hub default) → **black-station drop**.
- The `applicable_routes`: routes that involve subnets in this host's coordinate.
- The `requires_routes` validation: each required route must have a path in the registry's routes (or via a chain of hubs).

```nix
{
  coordinate = [ { plane_name; subnet; peer_id; trust; interface; }; ... ];
  hub_of = [ { plane_name; subnet; }; ... ];
  effective_icmp = { "enp3s0" = { pmtud = true; ping = true; }; "wireg0" = { pmtud = true; ping = true; }; ... };
  applicable_routes = [ ... ];
  vhostPlanes = [ { vhost; plane_name; subnet; reason; proxy_to?; }; ... ];
  errors = [ ... ];
}
```

**`requires_routes` validation (7.5, 7.8):** the suggested hub must have access to **both** requested subnets. If a single hub has both, the error names that hub:

```
error: no route available for remote-builder from 10.88.127.0/24 to <target-subnet>
peers [cortex-alpha] share plane intersections: cortex-alpha has 10.88.127.0/24 and <target-subnet>
suggest: add route from 10.88.127.0/24 to <target-subnet> on cortex-alpha
```

If no single hub has both, the error names the chain:

```
error: no route available for office-1 from 10.99.128.0/24 to 10.88.128.0/24
peers [dlyon, cortex-alpha] share plane intersections: dlyon has 10.99.128.0/24, cortex-alpha has 10.88.128.0/24
suggest: chain through dlyon and cortex-alpha; add route from 10.99.128.0/24 to 10.88.127.0/24 on dlyon, and from 10.88.127.0/24 to 10.88.128.0/24 on cortex-alpha
```

### 3.3 `lib/topology/genNginx.nix` — per-subnet vhost stanzas (resolves B4, N1, 7.6)

For every vhost in `vhost_planes`, the generator emits the vhost structure. The vhost name and the listen address are derived from the topology. The backend (`root` or `proxyPass`) is filled in by the machine's nix config.

**Backend is NOT in the topology** (except for `proxy_to` which is a coordinate). The webroot is a nix-store-path or local-filepath set by the machine's nix config.

```nix
mkVhostStanza = vhostEntry: hostConfig:
  let
    listenAddress = computeListenAddress hostConfig.coordinate vhostEntry.subnet vhostEntry.peer_id;
  in
  {
    serverName = vhostEntry.vhost;
    listenAddresses = [ listenAddress ];
    forceSSL = true;
    enableACME = (vhostEntry.subnet == WAN_subnet);
    useACMEHost = "johnbargman.net";
    # vhostEntry.proxy_to is informational; the actual proxyPass is set by the machine's nix config
  };
```

**ALPN required (N1):** nginx must respond correctly to HTTP/2 ALPN or drop. No 444. Default: `404-or-drop` (nginx 404 with `server_tokens off`, ALPN-correct; kernel drops for unknown subnets).

**Check-phase (7.6):** the generator's check-phase walks every `vhost_planes` entry and verifies that the machine's nix config has either `root` (if no `proxy_to` in topology) or `proxyPass` matching the topology's `proxy_to`. If not, the build fails with a clear message.

### 3.4 `lib/topology/genNftablesMatrix.nix` — the ruleset (resolves B3, B5, N12, 7.4, 7.7, 7.11)

Composes the routes + the host's coordinate + the effective ICMP allow-list. The default chain policy is `drop`. **Black station default: new interfaces without explicit ICMP config → drop.**

```nft
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept
    iif lo accept
    # PMTUD ICMP: always allowed on all interfaces
    ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept comment "PMTUD"
    # Per-interface ping (from icmp_override; inherited from icmp_defaults if not overridden)
    # If no icmp_override AND no icmp_defaults → DROP (black station)
    iifname "enp3s0"     ip protocol icmp icmp type { echo-request, echo-reply } accept comment "cortex-alpha.lan: ping"
    iifname "tailscale0" ip protocol icmp icmp type { echo-request, echo-reply } accept comment "tailscale-platonic: ping"
    # Per-subnet INPUT allows
    iifname "enp3s0"     tcp dport { 22, 80, 443, 2208 } accept comment "cortex-alpha.lan: hub access"
    iifname "wireg0"     tcp dport { 80, 443 } accept        comment "wg: ACME + services"
    iifname "tailscale0" tcp dport { 80, 443 } accept        comment "tailscale-platonic: ACME + services"
    iifname "enp2s0"     tcp dport { 22, 80, 443, 2208 } accept comment "82.5.173.0/24-wan: SSH + ACME + services"
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    # Composed routes
    iifname "enp2s0" oifname "enp3s0" tcp dport { 22, 80, 443, 2208 } accept comment "82.5.173.0/24-wan → cortex-alpha.lan"
    iifname "wireg0" oifname "enp3s0" accept comment "wg → cortex-alpha.lan"
    ...
  }
}
```

**ICMP resolution (7.4, 7.7, 7.11):**
```
effective_icmp[interface] = host.icmp_override[interface] ?? hub.icmp_defaults
```

If neither is set → **drop** (black station). The default `icmp_defaults` is `{ pmtud: true, ping: false }`. PMTUD is always allowed (the kernel has it as a default-on across all interfaces). Ping is opt-in per interface.

**Interface validation** (B5): the registry checks that every `coordinate[].interface` matches a key in `networking.interfaces`. Mismatch is a build error.

**DNAT and FORWARD unified** (N12): the new `genNftablesMatrix.nix` replaces both `mkForwarding.nix` (DNAT) and produces the FORWARD whitelist.

### 3.5 `lib/topology/genDnsmasqHorizons.nix` — per-subnet dnsmasq (resolves N8)

Single dnsmasq instance with per-subnet `--auth-server` directives. Listens on all addresses derived from the host's coordinate.

### 3.6 The 3D render (N/A)

The 3D render is a separate application that reads `topology/*.json` directly.

### 3.7 Validator additions in `lib/topology/validate.nix`

- **Filename/hostname binding** (B1): `topology/<X>.json` MUST contain `"hostname": "<X>"`.
- **Plane identifier completeness** (7.10): every `hub_of` entry has both `plane_name` and `subnet`. Every `coordinate` entry has `plane_name`, `subnet`, `peer_id`, `trust`, `interface`.
- **Plane identifier uniqueness** (7.9): no two planes share the same `(plane_name, subnet)` pair.
- **Per-plane `default` impossible** (B4): per-subnet vhost stanzas.
- **Interface validation** (B5): every coordinate's `interface` matches `networking.interfaces`.
- **Subnet size ≤ /24** (B6).
- **Hub uniqueness** (N5).
- **Sub-hub parent resolution** (N6).
- **Route requirements** (N2, N4, 7.5, 7.8).
- **Vhost plane binding** (N1, N7, 7.6): backend is `proxy_to` (IP:port) for proxies, or absent for static. The webroot is in the machine's nix config.
- **No wildcard vhost names** (B4-adjacent).
- **Default response is `"404-or-drop"`** (N1): ALPN required.
- **Backend `proxy_to` is a coordinate** (N7).
- **Black-station ICMP default** (7.11): new interfaces without explicit ICMP config → drop.

---

## 4. Phase ordering (rev 7)

Same as rev 5 and rev 6. Six phases.

### Phase 0 — Registry + ICMP + interface validation (no behavior change)
- Add `lib/topology/mkRegistry.nix`.
- Add `lib/topology/validate.nix` updates.
- Add `lib/topology/genNftablesMatrix.nix` — gated.
- **No behavior change.**

### Phase A — Schema additions (no behavior change)
- Add new fields to `topology/_template.nix`.
- Add `lib/topology/mkHorizons.nix` (transformer).

### Phase B — Dead code (with unit-test goldens)
- Add `lib/topology/genNginx.nix` updates.
- Add `lib/topology/genDnsmasqHorizons.nix`.

### Phase C — Wire-in (opt-in)
- Modify `lib/topology/mkNginxSettings.nix` and `genDns.nix` (gated).

### Phase D — Switch over (one machine, one golden diff)
- New nftables ruleset replaces old.
- `topology/cortex-alpha.json` migrated.

### Phase E — Hub-of-hubs (multi-machine)
- Add `topology/dlyon.json`, `topology/building-b.json`, `topology/office-1.json`, `topology/office-2.json`.
- Migrate `topology/remote-worker.json` and `topology/remote-builder.json`.

### Phase F — Migrate 16 client machines

---

## 5. Golden test workflow (already correct)

```bash
nix run .#dump-config -- <machine> | jq -S . > /tmp/current.json
diff -u goldens/<machine>.json /tmp/current.json
```

---

## 6. Resolved findings (rev 7)

### BLOCKERs (all addressed)

| # | Finding | Resolution |
|---|---|---|
| B1 | Registry failure mode underspecified | Phase 0 adds `mkRegistry.nix` with Model B. |
| B2 | Phase C 404 default contradicts ship criterion | Gated. |
| B3 | ICMP / PMTUD missing | `genNftablesMatrix.nix` includes PMTUD + per-subnet per-interface echo. |
| B4 | Per-plane `default` flag impossible | Per-subnet vhost stanzas. |
| B5 | Interface-rename lockout | Registry validates `coordinate[].interface` against `networking.interfaces`. |
| B6 | Topology JSON as metadata leak | 3D render is a viewer of the topology JSON. /24 bound. |

### NEEDS-FIXes (all addressed)

| # | Finding | Resolution |
|---|---|---|
| N1 | 404 default + ALPN leakage | `404-or-drop`. ALPN required. No 444. |
| N2 | Trust enum / onion rule | Onion-skin rule dropped. Trust is metadata. |
| N3 | acmePlanes: port-80 enumeration | ACME uses DNS-01 only. |
| N4 | Registry + git/worktree state divergence | Registry takes a git tree object. |
| N5 | Cross-machine validation invisible to single-machine golden | `check-network` depends on the registry. |
| N6 | 3D render cycle risk + ambiguous merge | 3D render is not a Nix derivation. Cycle detection. |
| N7 | vhostPlanes long/short form: per-plane options | All options per-subnet in the long form. Backend is `proxy_to` (IP:port) for proxies, or absent for static. |
| N8 | dnsmasq `--auth-server` requires listening on ALL plane interfaces | `genDnsmasqHorizons.nix` listens on all addresses. |
| N9 | "Two serializers" hallucination | RESOLVED. One generator. |
| N10 | Phase F changes 16 goldens | Acknowledged. Per-machine rollout. |
| N11 | Big-bang `shared.nix` dependency | Shared topology JSON is hand-edited. |
| N12 | DNAT vs FORWARD relationship | `genNftablesMatrix.nix` unifies DNAT and FORWARD. |

### User-driven changes from this round (rev 6 → rev 7)

| Change | Rationale |
|---|---|
| 7.10 `hub_of` is `plane_name + subnet` | One without the other is incomplete. Peers on this subnet should still have `plane_name + subnet` in their coordinate. |
| 7.10 Coordinates are `(plane_name, subnet, peer_id, trust)` | The /24 /32 are the subnet + peer_id — they are not different things, they are coordinates in the plane. |
| Star-topology framing | A hub defines the plane. Peers occupy the spokes at their `peer_id` positions. The hub is the center; peers are at the periphery. |
| 7.11 Black-station default | New interfaces with no `icmp_override` and no hub-default → drop. |
| 7.8 Intersection rule: hub must have access to both planes | The suggested hub must have both requested subnets in its coordinate. If no single hub has both, the error names the chain. |

---

## 7. Open questions (rev 7 — resolved, all confirmed)

All 12 open questions from rev 6 are confirmed. The design is ready for Phase 0.

---

## 8. Files

- This plan: `documentation/2026-07-18-MULTI-HORIZON-GATEWAY-PLAN.md` (rev 7)
- Reviews: `documentation/2026-07-18-MULTI-HORIZON-PLAN-REVIEW/`
- Generator: `lib/serialize-config.nix`
- Coverage audit: `lib/golden_coverage.nix`
- Golden test workflow: `documentation/network-topology-golden.md`
- **Deleted in this pass:** `lib/golden_generator.nix` (dead code)

---

## 9. What I have NOT done

- No code changes beyond the `git rm lib/golden_generator.nix` cleanup.
- No new transformers written (Phase 0 onward, gated on user approval).
- No migration of any machine's topology JSON (Phase D onward).
- The plan is untracked in the repo.
- All 12 open questions are resolved. **Phase 0 can begin** with user approval.
