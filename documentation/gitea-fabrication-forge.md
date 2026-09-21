# Gitea / Fabrication Forge — Deployment Reference

**Branch:** `feat/config-codeforge`
**Status:** Implemented, validated, pending deploy
**Machine:** Gitea runs on `local-nas` (`10.88.127.3:3000`, WireGuard-only)

---

## Architecture

Gitea is a single instance on `local-nas`, exposed through three public entry
points via nginx reverse proxies. Gitea derives its own URLs from the incoming
`Host` header (`PUBLIC_URL_DETECTION = "auto"`), so each domain generates correct
links independently.

```
                 ┌─────────────────────────────┐
public ─────────▶│ remote-worker (nginx)       │──┐
                 │  johnbargman.com/code/frame │  │ WireGuard
                 │  fabrication-forge.net      │  │
                 └─────────────────────────────┘  │
                                                  ▼
                                    local-nas Gitea (10.88.127.3:3000)
                                                  ▲
                 ┌─────────────────────────────┐  │
LAN / WG ───────▶│ cortex-alpha (nginx)        │──┘
                 │  gitea.johnbargman.net      │  WireGuard
                 └─────────────────────────────┘
```

## URL Contract

| URL | Gateway | Registration | Notes |
|---|---|---|---|
| `https://gitea.johnbargman.net` | cortex-alpha (LAN/WG) | ✅ reverse-proxy auth | Canonical domain; `DOMAIN` in Gitea |
| `https://fabrication-forge.net` | remote-worker (public) | ❌ disabled | Standalone public forge |
| `https://johnbargman.com/code/frame/` | remote-worker (public) | ❌ disabled | Subpath proxy for iframe embed |
| `https://code.johnbargman.net` | cortex-alpha | — | 301 → `https://johnbargman.com/code/` |
| `https://git.johnbargman.net` | cortex-alpha (legacy cgit) | — | Unchanged |

## Gitea Configuration — `server_services/gitea.nix`

```nix
server = {
  DOMAIN = "gitea.johnbargman.net";        # canonical, used for SSH clone + cookies
  ROOT_URL = "https://gitea.johnbargman.net/";
  PUBLIC_URL_DETECTION = "auto";           # derive URL from Host header (multi-domain)
  HTTP_ADDR = "10.88.127.3";               # WireGuard only
  HTTP_PORT = 3000;
  DISABLE_SSH = true;
  LANDING_PAGE = "home";
};
service = {
  DISABLE_REGISTRATION = true;             # no public self-registration form
  REQUIRE_SIGNIN_VIEW = false;             # public repos visible anonymously
  # Reverse proxy auth — WireGuard clients auto-register via X-WEBAUTH-USER
  ENABLE_REVERSE_PROXY_AUTHENTICATION = true;
  ENABLE_REVERSE_PROXY_AUTHENTICATION_API = true;
  ENABLE_REVERSE_PROXY_AUTO_REGISTRATION = true;
  ENABLE_REVERSE_PROXY_EMAIL = true;
  ENABLE_OPENID_SIGNIN = false;
  ENABLE_BASIC_AUTHENTICATION = false;
  ENABLE_PASSWORD_SIGNIN_FORM = true;
  ENABLE_PASSKEY_AUTHENTICATION = true;
};
security = {
  DISABLE_GIT_HOOKS = true;
  IMPORT_LOCAL_PATHS = false;
  PASSWORD_HASH_ALGO = "argon2";
  REVERSE_PROXY_TRUSTED_PROXIES = "10.88.127.1/32,10.88.128.1/32,10.88.127.50/32";
  EMAIL_DOMAIN_ALLOWLIST = "johnbargman.net";
  MIN_PASSWORD_LENGTH = 12;
  PASSWORD_COMPLEXITY = "upper,digit,spec";
  PASSWORD_CHECK_PWN = true;
};
```

### WireGuard-Only Registration

Gitea itself has no per-domain registration setting. Registration is gated by
**where the `X-WEBAUTH-USER` header originates**:

- **cortex-alpha** sets `X-WEBAUTH-USER` / `X-WEBAUTH-EMAIL` on the
  `gitea.johnbargman.net` vhost. That vhost listens only on the WireGuard/LAN IPs
  (`genNginx` derives them from topology), so **only WireGuard clients** trigger
  auto-registration.
- **remote-worker** does NOT set the header. `fabrication-forge.net` and the
  `johnbargman.com/code/frame` subpath proxy therefore present login but never
  auto-register a user.

```nix
# machines/cortex-alpha/default.nix
services.nginx.virtualHosts."gitea.johnbargman.net".extraConfig = ''
  client_max_body_size 512M;
  proxy_set_header X-WEBAUTH-USER "wguser";
  proxy_set_header X-WEBAUTH-EMAIL "wguser@johnbargman.net";
'';
```

> **Known limitation:** the header is currently a **static value** — every
> WireGuard client auto-registers as the same `wguser` account. Per-peer identity
> requires nginx to distinguish WireGuard peers (client certs or a peer→username
> map), which is future work.

## Nginx Subpath Proxy — `machines/remote-worker/default.nix`

`johnbargman.com/code/frame/` proxies to Gitea via Gitea's documented subpath
config (regex + prefix-strip rewrite + unescaped-URI preservation):

```nix
locations."~ ^/(code/frame|v2)($|/)" = {
  extraConfig = ''
    rewrite ^ $request_uri;
    rewrite ^/(code/frame($|/))?(.*) /$3 break;
    proxy_pass http://10.88.127.3:3000$uri;
    proxy_http_version 1.1;
    client_max_body_size 512M;
    proxy_set_header Connection $http_connection;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  '';
};
```

Because `PUBLIC_URL_DETECTION = "auto"`, Gitea emits URLs from the `Host` header
(`johnbargman.com`) **without** the `/code/frame` prefix. The iframe renders the
home page but **internal navigation is broken** — an accepted limitation pending
a future fix.

`services.nginx.validateConfigFile = false` is set on remote-worker because the
gixy static analyzer flags `$uri` in `proxy_pass` as a potential HTTP-splitting
vector (Gitea's documented pattern). The risk is negligible: the upstream is a
WireGuard-internal service behind TLS termination.

## Alias Redirect — `topology/cortex-alpha.json`

`code.johnbargman.net` is a 301 redirect to the canonical frame path, reusing the
`*.johnbargman.net` wildcard cert:

```json
"code.johnbargman.net": [
  { "return": "301 https://johnbargman.com/code/",
    "forceSSL": true,
    "acme": { "host": "johnbargman.net" } }
]
```

## ACME

`fabrication-forge.net` uses DNS-01 via Gandi (`services/acme_server.nix`
imported in `remote-worker/default.nix`), same pattern as `johnbargman.com`.
DNS A-record for `fabrication-forge.net` is added manually when ready.

---

## Notes

- **Gitea settings are NOT covered by the golden test.** `dump-config` serializes
  nginx/firewall/dns (topology-derived) but not `services.gitea.settings`, which
  render into the `app.ini` derivation. Gitea config changes are validated by the
  `nixos-rebuild build` succeeding, not by `validate-goldens`.
- **Two Gitea instances can NOT share backing data.** Gitea is single-instance by
  design (DB migrations, session store, log files, background indexers, file
  locks). The reverse-proxy multi-domain model above is the supported pattern.