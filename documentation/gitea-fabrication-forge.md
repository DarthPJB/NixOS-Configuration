# Gitea / Fabrication Forge — Deployment Reference

**Branch:** `feat/config-codeforge`
**Status:** Implemented, validated, pending deploy
**Machine:** Gitea runs on `local-nas` (`10.88.127.3:3000`, WireGuard-only)

> **2026-09-25:** personal-site `/code/` now embeds `fabrication-forge.com`
> cross-origin (iframe nav works natively); public faces are read-only
> (login 404'd at the nginx edge, WireGuard faces keep full login).

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
                 │  fabrication-forge.com      │  │
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
| `https://gitea.johnbargman.net` | cortex-alpha (LAN/WG) | ✅ reverse-proxy auth | Canonical domain; `DOMAIN` in Gitea; full login surface |
| `https://fabrication-forge.com` | remote-worker (public) | ❌ disabled | Standalone public forge; **embedded cross-origin** by `johnbargman.com/code/` |
| `https://johnbargman.com/code/frame/` | remote-worker (public) | ❌ disabled | Subpath proxy for iframe embed |
| `https://code.johnbargman.net` | cortex-alpha | — | 301 → `https://johnbargman.com/code/` |
| `https://git.johnbargman.net` | cortex-alpha (legacy cgit) | — | Unchanged |

## Cross-Origin Embed (johnbargman.com `/code/` → fabrication-forge.com)

The personal site embeds `https://fabrication-forge.com/` in a **cross-origin**
iframe. Gitea's `PUBLIC_URL_DETECTION = "auto"` therefore builds correct
per-host links at the domain root — no `/code/frame` prefix problem, and no
`sub_filter` rewriting. Changes on `remote-worker`:

```nix
"fabrication-forge.com" = {
  extraConfig = ''
    client_max_body_size 512M;
  '';
  locations."~/".extraConfig = ''
    if ($request_uri ~ "^/(user|login)([/?]|$)") { return 302 https://fabrication-forge.com/; }
    proxy_hide_header X-Frame-Options;
    add_header Content-Security-Policy "frame-ancestors https://johnbargman.com http://localhost:9090" always;
  '';
};
```

- `X-Frame-Options: SAMEORIGIN` (Gitea default) would block the cross-origin
  embed — hidden and replaced with an explicit `frame-ancestors` allowlist.
- LAN/WG split-horizon: `dns.static` maps `fabrication-forge.com` →
  `10.88.127.50` (remote-worker WG IP) and the vhost listens on that address,
  so LAN clients reach the forge over WireGuard with no egress.

## Public Endpoints Are Read-Only (no login outside WireGuard)

Gitea has no per-domain auth settings. Login is disabled at the **nginx edge**
on public faces only. Account paths are not a dead end — they redirect home:

- `fabrication-forge.com` → `/user/*` and `/login*` 302 → `https://fabrication-forge.com/`
- `johnbargman.com/code/frame/*` (public subpath) → same gate, same redirect

WireGuard-only faces keep the full login surface:

- `gitea.johnbargman.net` (cortex-alpha) — untouched; reverse-proxy auth +
  form login work as before
- `johnbargman.com-lan` (WG staging subpath) — untouched

`if` + `return 302` is one of nginx's safe `if` uses; it fires in the rewrite
phase before any `proxy_pass`.

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
  # Login is LDAP against cortex-alpha's OpenLDAP — see server_services/gitea.nix
  ENABLE_PASSWORD_SIGNIN_FORM = true;      # the TRANSPORT for LDAP login
  ENABLE_BASIC_AUTHENTICATION = false;
  ENABLE_OPENID_SIGNIN = false;
  ENABLE_PASSKEY_AUTHENTICATION = true;
  ENABLE_REVERSE_PROXY_AUTHENTICATION = false;   # wguser header removed 2026-09-29
  ENABLE_REVERSE_PROXY_AUTHENTICATION_API = false;
  ENABLE_REVERSE_PROXY_AUTO_REGISTRATION = false;
  ENABLE_REVERSE_PROXY_EMAIL = false;
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

### WireGuard-Only Identity (LDAP against the fleet's OpenLDAP)

Login identity comes from the **OpenLDAP directory on cortex-alpha**
(`server_services/ldap.nix`, LDAPS :636, `dc=johnbargman,dc=net`), registered
declaratively by `gitea-ldap-provision` in `server_services/gitea.nix`.
The previous static `X-WEBAUTH-USER: wguser` header was an unauthenticated
identity — every WireGuard client collapsed into one account — and has been
removed (2026-09-29).

- Gitea authenticates with an **anonymous search bind + per-user bind** — the
  directory's `olcAccess` already permits `anonymous auth` on `userPassword`
  and `* read` elsewhere, so **no shared service credential exists**.
- `DISABLE_REGISTRATION = true` stays; Gitea auto-creates its account record on
  first successful directory login (`inetOrgPerson` entries with `uid`/`mail`/
  `givenName`/`sn`).
- The sign-in form stays enabled — it is the transport for LDAP login.
- Identity is directory-owned: `admin.EXTERNAL_USER_DISABLE_FEATURES` blocks
  username/fullname/credential edits inside Gitea.
- The WireGuard-only constraint is structural: Gitea's HTTP listener binds the
  WireGuard address, and the Gitea→LDAP leg uses
  `ldap.johnbargman.net -> 10.88.127.1` (WG plane, wildcard-cert TLS). Public
  faces keep their nginx `/user/*` + `/login*` 404 gate.
- Break-glass is CLI-only (`gitea admin` via the `gitea-create-admin` unit).

### git+ssh (port 22, WireGuard)

Gitea serves git+ssh through the **system sshd** on port 22 of the WireGuard
address (human/admin SSH stays on 1108). `server_services/git-ssh.nix` owns the
port-22 auth policy (`AllowUsers git@10.88.127.0/24 gitea@10.88.127.0/24`);
Gitea runs external SSH (`START_SSH_SERVER = false`, `SSH_PORT = 22`) and keeps
`authorized_keys` in `~gitea/.ssh`.

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
home page but **internal navigation is broken** — an accepted limitation. The
site therefore embeds `https://fabrication-forge.com/` cross-origin (domain
root, `auto` detection correct) rather than this subpath; the subpath remains
for `code.johnbargman.net` aliasing and direct access.

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

`fabrication-forge.com` uses DNS-01 via Gandi (`services/acme_server.nix`
imported in `remote-worker/default.nix`), same pattern as `johnbargman.com`.
DNS A-record for `fabrication-forge.com` is added manually when ready.

---

## Notes

- **Gitea settings are NOT covered by the golden test.** `dump-config` serializes
  nginx/firewall/dns (topology-derived) but not `services.gitea.settings`, which
  render into the `app.ini` derivation. Gitea config changes are validated by the
  `nixos-rebuild build` succeeding, not by `validate-goldens`.
- **Two Gitea instances can NOT share backing data.** Gitea is single-instance by
  design (DB migrations, session store, log files, background indexers, file
  locks). The reverse-proxy multi-domain model above is the supported pattern.