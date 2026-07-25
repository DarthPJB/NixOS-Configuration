# In-House Nix Binary Cache — `cache.johnbargman.net`

> **Created:** 2026-07-22
> **Status:** PLANNING — Blocked on topology implementation completion
> **Parent:** `remote-builder-hub-2026-07-15.md` (Phase 2/3 complete, line 233: "Future work")
> **Blocks:** Fleet build times, CI pipeline reliability, overlord-II performance targets

## Executive Summary

Deploy an in-house Nix binary cache on `remote-builder` (10.88.127.51), served as
`cache.johnbargman.net` via cortex-alpha's split-horizon DNS + nginx reverse proxy.
Accessible only to LAN and WireGuard clients — no public internet exposure.

Uses `services.nix-serve` (the standard nixpkgs binary cache server), matching the
proven `infrastructure-2` pattern deployed on `hyperhyper` for `cache.platonic.systems`.

## Prerequisites

**This plan CANNOT be executed until the topology implementation is complete.**

| Prerequisite | Why |
|---|---|
| `overlord-ii-planar-topology` branch merged | All nginx proxy vhosts and dnsmasq static entries flow through the topology system. Adding cache entries before the topology overhaul lands creates merge conflicts and violates the "one source of truth" principle. |
| `remote-builder-hub-2026-07-15.md` Phase 2/3 complete | Already done — remote-builder is the hub, GC disabled, `max-jobs = 0`. |
| Golden tests passing for all 19 machines | Topology changes require golden regeneration. Must start from a clean baseline. |

**Post-topology the topology files may be `.json` instead of `.nix`.** The changes
described below reference the current `topology/cortex-alpha.nix` format. When the
`planar-topology` branch lands, equivalent entries go into the JSON topology format
(`topology/cortex-alpha.json` → `dns.static` and `nginx.proxies` arrays).

## Architecture

```
                    LAN Clients (10.88.128.0/24)
                    dnsmasq → cache.johnbargman.net → 10.88.128.1
                         │
                    ┌────▼──────────────────────────────────────┐
                    │  cortex-alpha (hub, 10.88.128.1/10.88.127.1)│
                    │  ┌──────────────────────────────────────┐  │
                    │  │  nginx (wildcard *.johnbargman.net)   │  │
                    │  │  proxy: cache.johnbargman.net        │  │
                    │  │    → http://10.88.127.51:5001        │  │
                    │  │  TLS: existing ACME wildcard cert    │  │
                    │  │  listen: 10.88.128.1 + 10.88.127.1   │  │
                    │  └──────────────┬───────────────────────┘  │
                    │                 │                          │
                    │  ┌──────────────▼───────────────────────┐  │
                    │  │  dnsmasq                              │  │
                    │  │  address=/cache.johnbargman.net/      │  │
                    │  │          10.88.128.1                  │  │
                    │  └──────────────────────────────────────┘  │
                    └─────────────────┬──────────────────────────┘
                                      │ WireGuard (encrypted)
                    ┌─────────────────▼──────────────────────┐
                    │  remote-builder (10.88.127.51)         │
                    │  ┌──────────────────────────────────┐  │
                    │  │  services.nix-serve               │  │
                    │  │  bindAddress: 10.88.127.51       │  │
                    │  │  port: 5001                      │  │
                    │  │  secretKeyFile: secrix-decrypted │  │
                    │  │  Serves signed /nix/store paths  │  │
                    │  └──────────────────────────────────┘  │
                    │  ┌──────────────────────────────────┐  │
                    │  │  nix.settings                     │  │
                    │  │  secret-key-files: [cache-priv]  │  │
                    │  │  gc.automatic: false (existing)  │  │
                    │  │  max-jobs: 0 (existing)          │  │
                    │  └──────────────────────────────────┘  │
                    │  ┌──────────────────────────────────┐  │
                    │  │  nix.sshServe (future)            │  │
                    │  │  protocol: ssh-ng, write=true    │  │
                    │  │  CI push target                  │  │
                    │  └──────────────────────────────────┘  │
                    └───────────────────────────────────────┘
```

### How split-horizon works for this service

1. **LAN clients** query cortex-alpha's dnsmasq → `cache.johnbargman.net` resolves to
   `10.88.128.1` (LAN gateway). Nginx on cortex-alpha proxies to remote-builder at
   `10.88.127.51:5001` over the WireGuard tunnel.

2. **WireGuard clients** use `https://10.88.127.1` as the substituter URL — cortex-alpha's
   WG IP, where nginx already listens for all proxy vhosts. The wildcard TLS cert covers
   `*.johnbargman.net`, and WireGuard peers trust it if the CA is configured. Alternatively,
   if WireGuard clients are configured to use cortex-alpha as their DNS resolver (dnsmasq
   on `wireg0`), they can use the domain name directly.

3. **No public internet exposure.** The nginx proxy vhost intentionally omits the WAN
   listen address (`82.5.173.252`), matching the existing pattern for all internal services
   (git, code, prometheus, grafana, etc.). Public DNS is not configured for this subdomain.

### Comparison with `infrastructure-2` pattern

| Aspect | `infrastructure-2` | This plan | Notes |
|---|---|---|---|
| Cache server | `services.nix-serve` on hyperhyper | Same, on remote-builder | |
| TLS termination | nginx reverse proxy | Same, via cortex-alpha's nginx | |
| Network gating | Tailscale-only | WireGuard-only (via cortex-alpha proxy omit-WAN pattern) | |
| DNS | OctoDNS → Cloudflare | dnsmasq split-horizon on cortex-alpha | |
| Signing keys | Shared fleet key (secrix) | Same pattern | |
| SSH push | `nix.sshServe` (ssh-ng) | Deferred to follow-up | Not needed for initial deployment |
| Per-machine keys + converge | Yes | Deferred | Future P2P cache sharing |
| ACME | DNS-01 via Cloudflare | DNS-01 via Gandi LiveDNS (existing) | |
| `cache-push.nix` | post-build-hook | Not yet | CI auto-push is separate work |

## Changes Required

### Phase 1 — Cache Server on remote-builder

#### 1.1 New module: `services/nix-cache-serve.nix`

```nix
# services/nix-cache-serve.nix
# Nix binary cache server — serves signed /nix/store paths over plain HTTP.
# TLS termination is handled by cortex-alpha's nginx reverse proxy.
# Matches the infrastructure-2 pattern (services/nix-cache-serve.nix on hyperhyper).

{ config, lib, self, ... }:
{
  # HTTP binary cache server
  services.nix-serve = {
    enable = true;
    secretKeyFile = config.secrix.services.nix-serve.secrets.cache-priv-key.decrypted.path;
    bindAddress = "10.88.127.51";   # WireGuard IP only — not reachable from public internet
    port = 5001;
  };

  # Sign locally-built derivations with the cache key so they can be served
  nix.settings.secret-key-files = [
    config.secrix.services.nix-serve.secrets.cache-priv-key.decrypted.path
  ];

  # Secrix: decrypt signing key at runtime
  secrix.services.nix-serve.secrets.cache-priv-key.encrypted.file =
    "${self}/secrets/cache-priv-key";
}
```

**Design decisions:**
- **Plain HTTP on port 5001** — TLS is handled by cortex-alpha's nginx. The
  cortex-alpha→remote-builder hop traverses WireGuard (already encrypted).
- **Bind to `10.88.127.51` only** — no exposure on the public interface.
- **Secrix for key management** — private key encrypted at rest, decrypted to
  `/run/` at boot. Matches infrastructure-2's approach.

#### 1.2 Modify `machines/remote-builder/default.nix`

Add one import to the existing imports list:

```diff
  imports = [
    ./hardware-configuration.nix
    ../../users/darthpjb.nix
    ../../modifier_imports/flakes.nix
    ../../environments/sshd.nix
    ../../environments/tools.nix
    ../../services/dynamic_domain_gandi.nix
    ../../services/github_runners.nix
    ../../services/mkRunners.nix
    ../../services/gitlab-credentials.nix
    ../../modifier_imports/remote-builder.nix
    ../../users/build.nix
    ../../modules/enable-wg-topology.nix
+   ../../services/nix-cache-serve.nix
  ];
```

No other changes needed — existing config is already correct:
- `nix.gc.automatic = lib.mkForce false` — cache is never garbage-collected
- `nix.settings.max-jobs = 0` — builds are distributed, not local
- WireGuard client to cortex-alpha already configured via `enable-wg-topology.nix`

#### 1.3 New secrets

| File | Type | Purpose | Generated via |
|---|---|---|---|
| `secrets/cache-priv-key` | Encrypted | Binary cache signing private key | `nix key generate-secret --key-name cache.johnbargman.net > secrets/cache-priv-key` then encrypt with secrix |
| `secrets/cache-pub-key` | Plaintext | Public key for fleet-wide trust | `nix key convert-secret-to-public < secrets/cache-priv-key > secrets/cache-pub-key` |

The public key will take the form: `cache.johnbargman.net:<base64-encoded-public-key>`

**Key generation must be done on a secure machine, offline.** The private key
should never exist in plaintext on disk. Encrypt immediately after generation.

### Phase 2 — DNS + Nginx on cortex-alpha

#### 2.1 Add DNS static entry

In the topology file (current: `topology/cortex-alpha.nix`, post-topology: `topology/cortex-alpha.json`):

```nix
# In topology/cortex-alpha.nix → dns.static (add to existing list)
{ domain = "cache.johnbargman.net"; ip = "10.88.128.1"; }
```

This generates the dnsmasq directive:
```
address=/cache.johnbargman.net/10.88.128.1
```

LAN clients querying cortex-alpha's dnsmasq on `enp3s0` will resolve
`cache.johnbargman.net` to the LAN gateway IP. Nginx catches it there.

If post-topology uses JSON format:
```json
{ "domain": "cache.johnbargman.net", "ip": "10.88.128.1" }
```

#### 2.2 Add nginx proxy vhost

In the topology file (same location, `nginx.proxies`):

```nix
# In topology/cortex-alpha.nix → nginx.proxies (add to existing list)
"cache.johnbargman.net" = {
  backend = "http://10.88.127.51:5001";
  forceSSL = true;
  websockets = false;
};
```

This generates an nginx server block that:
- Listens on `10.88.128.1:443` and `10.88.127.1:443` (LAN + WG interfaces)
- Uses the existing `*.johnbargman.net` wildcard ACME certificate
- Proxy-passes to `http://10.88.127.51:5001` (remote-builder over WireGuard)
- Adds standard proxy headers (`X-Real-IP`, `X-Forwarded-For`, etc.)

**No WAN listen** — `82.5.173.252` is intentionally omitted, matching the pattern
used by all other internal service proxies (git, code, prometheus, grafana, etc.).
This ensures the cache is only reachable within the trusted network.

If post-topology uses JSON format:
```json
{
  "cache.johnbargman.net": {
    "backend": "http://10.88.127.51:5001",
    "forceSSL": true,
    "websockets": false
  }
}
```

#### 2.3 WireGuard client DNS resolution (optional follow-up)

WireGuard peers currently don't use cortex-alpha's dnsmasq by default. To enable
domain-name resolution for WG clients:

**Option A (zero-config):** WG clients use `https://10.88.127.1` as the substituter
URL directly. Cortex-alpha's nginx already listens on this IP for all proxy vhosts
and will route to remote-builder based on SNI. This works immediately.

**Option B (preferred):** Add `wireg0` to dnsmasq's interface list in the topology
so WG peers can query `10.88.127.1:53` for DNS. This would be a separate topology
change and is not required for the cache to function — clients can use the IP directly.

### Phase 3 — Fleet-Wide Trust Configuration

#### 3.1 Modify `configuration.nix`

Add the cache to the existing `nix.settings` block:

```diff
  nix.settings = {
    # ... existing settings ...
    trusted-substituters = [
+     "https://cache.johnbargman.net"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
+     "cache.johnbargman.net:<public-key-hash>"
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
```

The `<public-key-hash>` placeholder is replaced with the actual base64 value from
`secrets/cache-pub-key`.

**Design decision:** `cache.johnbargman.net` is placed FIRST in the substituters
list so Nix checks the in-house cache before falling back to `cache.nixos.org`.
This reduces WAN bandwidth and improves build speed for frequently-used derivations.

#### 3.2 Modify `flake.nix`

Add to the `nixConfig` block for `nix flake` subcommands:

```diff
  nixConfig = {
    extra-substituters = [
+     "https://cache.johnbargman.net"
      "https://install.determinate.systems"
    ];
    extra-trusted-public-keys = [
+     "cache.johnbargman.net:<public-key-hash>"
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "install.determinate.systems:a7GMGXFqz7lFjOE45sTRq1g/RX6KFHRKHXOHTi1uFhM="
    ];
  };
```

### Phase 4 — Golden Test Regeneration

After all topology changes:

```bash
# Regenerate cortex-alpha golden
nix run .#dump-config -- cortex-alpha | jq -S . > goldens/cortex-alpha.json

# Validate
nix run .#check-network -- cortex-alpha

# Validate all machines
for m in $(ls machines/); do
  nix run .#check-network -- "$m" 2>&1 | tail -1
done
```

The golden diff for cortex-alpha should show:
- One new entry in `services.dnsmasq.settings.address`
- One new nginx virtual host in `services.nginx.virtualHosts`

No other golden files should change.

## Files Changed Summary

| File | Action | Approx Lines |
|---|---|---|
| `services/nix-cache-serve.nix` | **NEW** | ~20 |
| `machines/remote-builder/default.nix` | Add 1 import line | +1 |
| `topology/cortex-alpha.nix` (or `.json`) | Add 1 DNS entry + 1 nginx proxy | +8 |
| `configuration.nix` | Modify substituters + public keys | +2 lines, 2 existing modified |
| `flake.nix` | Modify extra-substituters + extra-trusted-public-keys | +2 lines, 2 existing modified |
| `goldens/cortex-alpha.json` | Regenerate (intentional config change) | ~10 lines added |
| `secrets/cache-priv-key` | **NEW** (encrypted, generated offline) | — |
| `secrets/cache-pub-key` | **NEW** (plaintext) | — |

**Total: 6 file modifications, 2 new files, 2 new secrets. Zero changes to topology
transformers or generators** — `mkNginxProxies.nix` and `mkDhcpDns.nix` already handle
new entries in the topology data structures automatically.

## What This Plan Does NOT Cover

| Feature | Reason | Follow-up Plan |
|---|---|---|
| `nix.sshServe` (SSH push endpoint) | Not needed for initial read-only cache deployment | Separate plan: CI auto-push |
| Per-machine signing keys + converge propagation | Optimization for P2P cache sharing between peers | Post-stabilization |
| `post-build-hook` for automatic CI push | Requires CI runner changes and SSH key management | After SSH push endpoint is live |
| Public DNS for `cache.johnbargman.net` | Cache is deliberately internal-only | Not planned |
| Cache metrics/alerting | Standard node_exporter + nixos-deployment-exporter already cover the machine | Monitor after deployment |
| `nix-serve-ng` or attic | `nix-serve` is the standard nixpkgs module; attic adds complexity we don't need yet | Revisit if scale demands it |

## Deployment Sequence

1. **Verify prerequisites** — topology implementation merged, golden tests clean
2. **Generate signing keys** — `nix key generate-secret` on secure machine, encrypt with secrix
3. **Create `services/nix-cache-serve.nix`** — module with nix-serve + secrix binding
4. **Add import to remote-builder** — single line in `machines/remote-builder/default.nix`
5. **Add topology entries** — DNS + nginx proxy in `topology/cortex-alpha.{nix,json}`
6. **Regenerate cortex-alpha golden** — `nix run .#dump-config -- cortex-alpha | jq -S . > goldens/cortex-alpha.json`
7. **Validate all goldens** — `for m in $(ls machines/); do nix run .#check-network -- "$m"; done`
8. **Add fleet-wide trust** — `configuration.nix` + `flake.nix` substituters and public keys
9. **Build and deploy remote-builder** — `nixos-rebuild` to activate nix-serve
10. **Build and deploy cortex-alpha** — `nixos-rebuild` to activate DNS + nginx proxy
11. **Verify cache operation** — `nix store ping --store https://cache.johnbargman.net` from a client
12. **Test substitution** — `nix build --substituters https://cache.johnbargman.net ...` from LINDA or terminal-zero

## References

- `infrastructure-2/services/nix-cache-serve.nix` — the reference implementation on hyperhyper
- `infrastructure-2/modules/proxy-host.nix` — nginx reverse proxy pattern
- `infrastructure-2/secrets/cache-pub-key.pem` — example public key format
- `remote-builder-hub-2026-07-15.md` — parent plan (Phase 2/3 complete)
- `topology-rectification-2026-06-23.md` — topology overhaul plan (prerequisite)
- `AGENTS.md` lines 46-49 — planned in-house binary cache
- NixOS manual: `services.nix-serve` — [nix-serve documentation](https://nixos.org/manual/nixos/stable/#module-services-nix-serve)
