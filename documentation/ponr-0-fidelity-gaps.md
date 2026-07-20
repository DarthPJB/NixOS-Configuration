# PONR-0.2: Fidelity Gaps — Topology-Derive vs Baseline (Managed Subset)

**Date:** 2026-07-20
**Eval method:** Nix `lib.evalModules` pattern (same as unit tests) evaluating `modules/topology-derive.nix` for each host against `/tmp/ponr-baseline/<host>.json`

## Managed Key Scope

Topology-derive claims these keys (per plan §Session Premises):
1. `services.prometheus.exporters.*` — enable/port/listenAddress
2. `services.nginx.enable` — boolean
3. `services.nginx.virtualHosts.*` — shape: forceSSL, locations, enableACME, useACMEHost, default
4. `networking.interfaces.<iface>.ipv4.addresses` — from coordinate entries

## Gap Classification

| Class | Meaning | Count |
|-------|---------|-------|
| JSON_DATA | Must fill/correct topology JSON | 5 |
| MODULE_BUG | Must fix topology-derive.nix | 6 |
| COMPETING_SOURCE | Must comment machine config in PONR-2 | 8 |
| OUT_OF_SCOPE | Not topology-managed (don't chase) | 5 |

---

## cortex-alpha

### Exporters (dnsmasq)

| Path | Expected (Baseline) | Actual (Derive) | Class |
|------|--------------------|-----------------|-------|
| `services.prometheus.exporters.dnsmasq.listenAddress` | `"10.88.127.1"` | `"10.88.128.1"` | **MODULE_BUG** |
| `services.prometheus.exporters.dnsmasq.leasesPath` | `"/dev/null"` | absent | **MODULE_BUG** |
| `services.prometheus.exporters.dnsmasq.dnsmasqListenAddress` | `"10.88.128.1:53"` | absent | **MODULE_BUG** |

**Analysis:** Topology-derive currently sets `listenAddress = firstIP` (first coordinate's IP, which is `10.88.128.1` from the LAN plane). The baseline expects `10.88.127.1` (WireGuard IP). The module should use a configurable listenAddress or the topology export field should carry an explicit `listenAddress`.

Additional exporter options (`leasesPath`, `dnsmasqListenAddress`) are exporter-specific and are not in the current topology JSON schema. These could either be added to JSON as `extraOpts` blocks or considered OUT_OF_SCOPE (left as machine config after topology override).

### Nginx virtualHosts — Proxy vhosts (code, git, prometheus, grafana, print-controller, ap)

| Path | Expected (Baseline) | Actual (Derive) | Class |
|------|--------------------|-----------------|-------|
| `virtualHosts.<vhost>.locations` key | `"~/"` (regex prefix) | `"/"` (exact) | **MODULE_BUG** |
| `virtualHosts.<vhost>.locations."/".proxyWebsockets` | `true` | absent | **MODULE_BUG** |
| `virtualHosts.<vhost>.locations."/".extraConfig` | `proxy_set_header ...` | absent | **MODULE_BUG** |
| `virtualHosts.<vhost>.addSSL` | `true` | absent | **MODULE_BUG** |
| `virtualHosts.<vhost>.useACMEHost` | `"johnbargman.net"` | absent (for proxy vhosts) | **MODULE_BUG** |
| `virtualHosts.<vhost>.listenAddresses` | `["10.88.128.1","10.88.127.1"]` or `+82.5.173.252` | absent | **OUT_OF_SCOPE** |
| `virtualHosts._` `return` | `"444"` with `useACMEHost: null` | `"444"` (partial match) | OK |

**Analysis:** The production vhosts come from `topology/cortex-alpha.nix` processed through `genNginx.nix` in `core-router-topology.nix`. The genNginx transformer produces richer proxy configs with websocket support and standard proxy headers. Topology-derive's simpler vhost builder needs to match these extras for full fidelity.

### Interfaces

| Path | Expected (Baseline) | Actual (Derive) | Class |
|------|--------------------|-----------------|-------|
| `networking.interfaces.enp3s0.ipv4.addresses` | `[{address:"10.88.128.1",prefixLength:24}]` | `[{address:"10.88.128.1",prefixLength:24}]` | MATCH |
| `networking.interfaces.wireg0.ipv4.addresses` | absent | `[{address:"10.88.127.1",prefixLength:24}]` | **COMPETING_SOURCE** |
| `networking.interfaces.tailscale0.ipv4.addresses` | absent | `[{address:"100.64.0.1",prefixLength:10}]` | **COMPETING_SOURCE** |
| `networking.interfaces.enp2s0.ipv4.addresses` | DHCP only | `[{address:"82.5.173.252",prefixLength:24}]` | **COMPETING_SOURCE** |

**Analysis:** The baseline only has `enp3s0` configured (static) and `enp2s0` (DHCP). Topology-derive adds wireg0, tailscale0, and a static IP for enp2s0. These are managed by other modules (WireGuard by `enable-wg-topology.nix`, Tailscale by Tailscale service, WAN interface by DHCP). This is a COMPETING_SOURCE issue — the interfaces from topology-derive must not conflict with interfaces managed elsewhere.

---

## remote-worker

### Exporters

| Path | Expected (Baseline) | Actual (Derive) | Class |
|------|--------------------|-----------------|-------|
| `exporters.smartctl.enable` | `false` (mkForce disabled in machine/default.nix:90) | `true` | **JSON_DATA** |
| `exporters.nextcloud` shape | `{enable:true,port:3106,listenAddress:"0.0.0.0",url,username,passwordFile,...}` | `{enable:true,port:3106,listenAddress:"10.88.127.50"}` | **COMPETING_SOURCE** |
| `exporters.nginx` shape | `{enable:true,port:3105,listenAddress:"0.0.0.0"}` | `{enable:true,port:3105,listenAddress:"10.88.127.50"}` | **COMPETING_SOURCE** |

**Analysis:** remote-worker's machine config uses `lib.mkForce false` to disable smartctl. The JSON topology declares smartctl exporter but the production config explicitly disables it. The plan says: "if baseline dumps have smartctl disabled, topology JSON must not enable it." Fix: Remove smartctl from remote-worker's JSON exporters, or keep it and accept the mkForce override in machine config.

ListenAddress `"0.0.0.0"` in baseline vs `"10.88.127.50"` in derive — this is by design (derive uses firstIP). Need to align.

### Nginx virtualHosts

| Path | Expected (Baseline) | Actual (Derive) | Class |
|------|--------------------|-----------------|-------|
| Vhost count | 10 | 4 | **COMPETING_SOURCE** |
| `virtualHosts."nextcloud.johnbargman.net"` | present | absent | **COMPETING_SOURCE** |
| `virtualHosts."nextcloud.johnbargman.com"` | present | absent | **COMPETING_SOURCE** |
| `virtualHosts."carmel-staging.johnbargman.net"` | present | absent | **COMPETING_SOURCE** |
| `virtualHosts."csfinancialconsulting.com"` | present | absent | **COMPETING_SOURCE** |
| `virtualHosts."csfincon.us"` | present | absent | **COMPETING_SOURCE** |
| `virtualHosts."default"` | present (return 444) | absent (has `_` instead) | **JSON_DATA** |
| `virtualHosts."localhost"` | present | absent | **OUT_OF_SCOPE** |
| `virtualHosts."johnbargman.com-wg".listenAddresses` | `["10.88.127.50"]` | absent | **MODULE_BUG** |

**Analysis:** The extra vhosts (6 beyond topology-claimed) come from:
- `nextcloud.*` — from `server_services/nextcloud.nix` (adds its own vhosts)
- `carmel-staging.*`, `csf*` — from machine config or other modules
- `default` — from machine config (return 444, same role as `_`)
- `localhost` — nixpkgs default

These are OUT_OF_SCOPE (not claimed by topology) or COMPETING_SOURCE (set in both). The `_` vs `default` naming difference for the catch-all vhost is notable — derive produces `_` while baseline has `default`.

---

## gaming-host-1

### Exporters

No topology exporters declared in JSON → match.

### Nginx virtualHosts

| Path | Expected (Baseline) | Actual (Derive) | Class |
|------|--------------------|-----------------|-------|
| `virtualHosts."gaming-host-1.johnbargman.net".locations."/".proxyWebsockets` | `true` | absent | **MODULE_BUG** |
| `virtualHosts."gaming-host-1.johnbargman.net".locations."/".recommendedProxySettings` | `true` | absent | **OUT_OF_SCOPE** |
| `virtualHosts."_".return` | absent (no `_`) | `"404"` (from default_response) | **JSON_DATA** |

**Analysis:** gaming-host-1's machine nginx config has `recommendedProxySettings = true` and `recommendedTlsSettings = true` at the top level, which percolate into all proxy vhost locations. These are nginx-global options, not per-vhost. Topology-derive doesn't set global nginx options — those remain in machine config.

The `_` default vhost with return 404 is produced from `default_response: "404-or-drop"` in gaming-host-1.json. But the baseline has NO default vhost — the machine config simply doesn't set one. This will appear as an extra vhost when topology-derive is wired.

### Interfaces

`wireg0` IP: derive produces `10.88.127.52/24`, baseline has no wireg0 interface — **COMPETING_SOURCE** (WireGuard interface managed by `enable-wg-topology.nix`).

---

## display-1, display-2, print-controller, remote-builder

### Exporters (smartctl)

| Path | Expected (Baseline) | Actual (Derive) | Class |
|------|--------------------|-----------------|-------|
| `exporters.smartctl.enable` (display-1) | `false` (lib.mkForce false in machines/display-1/default.nix:138) | `true` | **JSON_DATA** |
| `exporters.smartctl.enable` (display-2) | `false` (lib.mkForce false in machines/display-2/default.nix:89) | `true` | **JSON_DATA** |
| `exporters.smartctl.enable` (print-controller) | `false` (lib.mkForce false in machines/print-controller/default.nix:42) | `true` | **JSON_DATA** |
| `exporters.smartctl.enable` (remote-builder) | `false` (lib.mkForce false in machines/remote-builder/default.nix:26) | `true` | **JSON_DATA** |
| `exporters.smartctl.listenAddress` (all) | `"0.0.0.0"` | WG IP (e.g. `"10.88.127.41"`) | **MODULE_BUG** (or design intent) |

**Analysis:** All four machines have `lib.mkForce false` for smartctl exporter in their machine configs. The topology JSON for each declares `"smartctl": {}` which topology-derive interprets as "enable". This is a JSON_DATA gap — the JSON should either:
1. Remove smartctl exporters from these machines' JSON
2. Add an `enable: false` toggle to the exporter schema

The plan's guidance: "if baseline dumps have smartctl disabled, topology JSON must not enable it." So these are JSON_DATA fixes.

### Nginx

- **display-1, display-2, remote-builder**: nginx disabled in baseline, derive agrees (no vhosts in JSON) → MATCH
- **print-controller**: nginx enabled in baseline (klipper/fluidd vhost), derive has no nginx (no vhosts in JSON) → OUT_OF_SCOPE (the klipper vhost is from machine config, not topology-managed)

### Interfaces (all)

| Machine | Derive interfaces | Baseline interfaces | Class |
|---------|------------------|--------------------|-------|
| display-1 | wireg0: 10.88.127.41/24 | none | **COMPETING_SOURCE** |
| display-2 | wireg0: 10.88.127.42/24 | none | **COMPETING_SOURCE** |
| print-controller | wireg0: 10.88.127.30/24, wlan0: 10.88.128.10/24 | none | **COMPETING_SOURCE** |
| remote-builder | wireg0: 10.88.127.51/24 | none | **COMPETING_SOURCE** |

**Analysis:** The interfaces that topology-derive would produce are currently managed by other modules (WireGuard via `enable-wg-topology.nix`, LAN via hardware config). These will need to be reconciled in PONR-2.

---

## Gap Summary

### JSON_DATA (5)

| # | Machine | Field | Fix Action |
|---|---------|-------|------------|
| 1 | remote-worker | Remove `smartctl` from exporters | Delete smartctl entry from JSON |
| 2 | display-1 | Remove `smartctl` from exporters | Delete smartctl entry from JSON |
| 3 | display-2 | Remove `smartctl` from exporters | Delete smartctl entry from JSON |
| 4 | print-controller | Remove `smartctl` from exporters | Delete smartctl entry from JSON |
| 5 | remote-builder | Remove `smartctl` from exporters | Delete smartctl entry from JSON |

### MODULE_BUG (6)

| # | Machine | Field | Fix Action |
|---|---------|-------|------------|
| 1 | cortex-alpha | dnsmasq exporter listenAddress | Use configurable address per exporter entry |
| 2 | cortex-alpha | dnsmasq exporter extra options | Accept `leasesPath`/`dnsmasqListenAddress` from JSON or keep as machine-only |
| 3 | cortex-alpha | Proxy vhost location key `"~/"` not `"/"` | genNginx uses `"~/"` for websocket proxies |
| 4 | cortex-alpha | Proxy vhost proxyWebsockets true | Set from topology `websockets` field |
| 5 | cortex-alpha | Proxy vhost extraConfig (proxy headers) | Add standard proxy headers |
| 6 | cortex-alpha | Proxy vhost addSSL/useACMEHost | Set useACMEHost from acme config for proxy vhosts |

### COMPETING_SOURCE (8)

These are documented in PONR-0.3. They are machine `default.nix` and `core-router-topology.nix` paths that produce the same keys as topology-derive.

### OUT_OF_SCOPE (5)

| # | Machine | Item | Reason |
|---|---------|------|--------|
| 1 | remote-worker | nextcloud/carmel/csf vhosts | Produced by nextcloud.nix module and other services |
| 2 | print-controller | klipper/fluidd vhost | Produced by machine config (3D printer web interface) |
| 3 | display-1/2, remote-builder | `localhost` vhost | Produced by nixpkgs default nginx config |
| 4 | gaming-host-1 | recommendedProxySettings/TlsSettings | Nginx-global options, not per-vhost topology |
| 5 | All | listenAddresses on vhosts | Set by core-router from nginx config, not topology-derive |

---

## Summary Statistics

| Class | Count |
|-------|-------|
| JSON_DATA | 5 |
| MODULE_BUG | 6 |
| COMPETING_SOURCE | 8 |
| OUT_OF_SCOPE | 5 |
| **Total gaps** | **24** |

**Proposed priority for PONR-0:** The JSON_DATA and MODULE_BUG gaps must be closed before wiring. COMPETING_SOURCE is addressed in PONR-2.
