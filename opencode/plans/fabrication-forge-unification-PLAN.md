# Fabrication Forge Unification Plan

**Date:** 2026-09-20
**Status:** Executed — implementation deviated from original frame-canonical design
**Branch:** `feat/config-codeforge`
**Goal:** Consolidate Gitea, the Fabrication Forge brand, and the `/code/` page into one public code forge.

> **Note:** This plan documents the original *frame-canonical* design
> (`PUBLIC_URL_DETECTION = "never"`, iframe at `/code/frame`). The final
> implementation diverged: it uses **`PUBLIC_URL_DETECTION = "auto"`** with
> **multi-domain** entry points and **reverse-proxy authentication**
> (`X-WEBAUTH-USER`) for WireGuard-only registration. See
> [`documentation/gitea-fabrication-forge.md`](../../documentation/gitea-fabrication-forge.md)
> for the authoritative record of what actually shipped.

---

## Worktree

All work happens in `/speed-storage/worktrees/config-codeforge/` on branch
`feat/config-codeforge`. No changes are made in the main working directory.

```bash
# Verify worktree before starting
git worktree list
# /speed-storage/worktrees/config-codeforge  16a33c3 [feat/config-codeforge]
```

---

## Delegation

| Phase | Agent | Task |
|---|---|---|
| Steps 1-3 | orchestrator | Direct file edits (gitea.nix, remote-worker, cortex-alpha topology) |
| Step 4 | orchestrator | Golden regeneration (`nix run .#dump-config`, `nix run .#validate-goldens`) |
| Step 4 verify | `tpol-minimax` | Validate goldens match expected changes |
| Step 5 | deferred | personal-website-blog is a separate repo (push to GitLab, then `flake update`) |
| Step 6 | manual | DNS A-record for `fabrication-forge.com` |

Steps 1-3 are straightforward config edits — no complex logic, no code generation.
The orchestrator executes them directly. `tpol-minimax` validates the golden output.

---

## Canonical Model: The Frame Is Canonical

Gitea is served at a **sub-path** of the personal website. Every other entry
point is an alias that redirects into the frame.

```
Browser
  └─ https://johnbargman.com/code/          (personal-website static page)
        └─ <iframe src="/code/frame">       (relative — same-origin)
              └─ https://johnbargman.com/code/frame/   (nginx SUBPATH proxy)
                    │  strip /code/frame prefix (Gitea docs rewrite)
                    ▼  WireGuard
                 Gitea  http://10.88.127.3:3000   (local-nas)

Aliases (301 redirect → https://johnbargman.com/code/):
  code.johnbargman.net     (cortex-alpha)
  fabrication-forge.com    (remote-worker)
```

Because `/code/` and `/code/frame` are **same-origin**, the iframe satisfies
Gitea's `X-Frame-Options: SAMEORIGIN` (default) with no header loosening, and
session cookies (`COOKIE_SECURE = true`, `SAME_SITE = lax`) work normally.

---

## URL Contract

| URL | Owner | Content |
|---|---|---|
| `https://johnbargman.com/code/` | personal-website-blog | Curated page; hosts the iframe |
| `https://johnbargman.com/code/frame/` | remote-worker nginx (subpath proxy) | Gitea |
| `https://code.johnbargman.net` | cortex-alpha nginx | 301 → `https://johnbargman.com/code/` |
| `https://fabrication-forge.com` | remote-worker nginx | 301 → `https://johnbargman.com/code/` |
| `https://git.johnbargman.net` | cortex-alpha (legacy, cgit) | Unchanged |

---

## LAN-DNS Masquerade

`cortex-alpha` runs dnsmasq and already resolves the personal website to the
WireGuard LAN:

```
topology/cortex-alpha.json → dns.static:
  { "domain": "johnbargman.com", "ip": "10.88.127.50" }
```

`10.88.127.50` is `remote-worker`'s WireGuard IP. Therefore LAN clients, when
they load `johnbargman.com/code/`, reach remote-worker over WireGuard — they do
not egress to the public internet. The iframe must use a **relative** src
(`/code/frame`) so it inherits this resolution and stays same-origin either way.

---

## Decisions (final)

| # | Decision |
|---|---|
| D1 | Consolidate on Gitea (human UI, runners, LFS, not GitLab) |
| D2 | Frame is canonical; standalone domains are 301 redirects |
| D3 | gitolite/cgit + `git.johnbargman.net` retained as legacy |
| D4 | `REQUIRE_SIGNIN_VIEW = false`, public repos visible, private repos auth-gated |
| D5 | Workflow: local dev → push GitLab → deploy (no `flake update` to path:) |

---

## Changes — NixOS-Configuration

### 1. `server_services/gitea.nix`

In `services.gitea.settings`:

```nix
server = {
  DOMAIN = "johnbargman.com";
  ROOT_URL = "https://johnbargman.com/code/frame/";
  PUBLIC_URL_DETECTION = "never";      # always use ROOT_URL, ignore Host header
  HTTP_ADDR = wgIp;
  HTTP_PORT = httpPort;                # 3000
  DISABLE_SSH = true;
  LANDING_PAGE = "home";               # was "login"
};
service = {
  DISABLE_REGISTRATION = true;
  REQUIRE_SIGNIN_VIEW = false;         # was true
};
security = {
  DISABLE_GIT_HOOKS = true;
  IMPORT_LOCAL_PATHS = false;
  PASSWORD_HASH_ALGO = "argon2";
  REVERSE_PROXY_TRUSTED_PROXIES = "10.88.127.1/32,10.88.128.1/32,10.88.127.50/32";
};
```

**Critical fix:** `10.88.127.50/32` (remote-worker WireGuard IP) MUST be added
to `REVERSE_PROXY_TRUSTED_PROXIES`. Without it Gitea ignores remote-worker's
`X-Forwarded-For`/`X-Forwarded-Proto` headers.

`PUBLIC_URL_DETECTION = "never"` (default is `"auto"`) is what makes the frame
canonical: Gitea always emits `ROOT_URL`-prefixed links regardless of which
Host header arrives.

### 2. `machines/remote-worker/default.nix`

Add to the `services.nginx.virtualHosts."johnbargman.com"` overlay a subpath
proxy location using Gitea's documented regex + prefix-strip rewrite:

```nix
"johnbargman.com" = {
  locations."/".root = lib.mkForce personal-site.packages.${pkgs.stdenv.hostPlatform.system}.personal-site;
  locations."~ ^/(code/frame|v2)($|/)" = {
    # extraConfig-only: no proxyPass/proxyWebsockets options.
    # The nginx module would generate a second proxy_pass directive from
    # proxyPass, creating dead code.  The rewrite + break + proxy_pass $uri
    # pattern requires the single proxy_pass with $uri suffix to carry the
    # rewritten path.  This matches Gitea's documented subpath config exactly.
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
};
```

Notes:
- The `(code/frame|v2)` alternation keeps the container registry's fixed root
  `/v2` path reachable (Gitea requirement), even though the registry is unused today.
- The rewrite strips the `/code/frame` prefix and preserves the unescaped URI so
  `a%2Fb` clone paths survive.
- This lives in the machine overlay because `genNginx` produces only
  `~/"` regex-prefix or `/` exact locations — it cannot emit sub-path rewrites.
- `extraConfig`-only avoids the nginx NixOS module generating a conflicting
  `proxy_pass` directive from its `proxyPass` option.  The rewrite + break +
  `proxy_pass $uri` pattern is the Gitea-documented subpath config.

Add a redirect vhost for the alias domain (machine-level, or via topology):

```nix
"fabrication-forge.com" = {
  forceSSL = true;
  enableACME = true;
  locations."/".return = "301 https://johnbargman.com/code/";
};
```

And import its ACME provider (DNS-01 via Gandi, same pattern as
`johnbargman.com`):

```nix
(import ../../services/acme_server.nix { fqdn = "fabrication-forge.com"; })
```

### 3. `topology/cortex-alpha.json`

Repoint `code.johnbargman.net` from the cgit proxy to a 301 redirect using the
existing wildcard cert:

```json
"code.johnbargman.net": [
  {
    "return": "301 https://johnbargman.com/code/",
    "forceSSL": true,
    "acme": { "host": "johnbargman.net" }
  }
]
```

`genNginx` applies `useACMEHost`/`acmeConfig` to return vhosts; setting
`acme.host = "johnbargman.net"` reuses the `*.johnbargman.net` wildcard cert.

Leave `git.johnbargman.net` (cgit, `10.88.127.3:80`) untouched.

### 4. Goldens

Regenerate and validate:

```bash
nix run .#dump-config -- cortex-alpha | jq -S . > goldens/cortex-alpha.json
nix run .#validate-goldens -- cortex-alpha
nix run .#dump-config -- remote-worker | jq -S . > goldens/remote-worker.json
nix run .#validate-goldens -- remote-worker
```

---

## Changes — personal-website-blog (separate repo)

### 5. `site/code/index.html.nix`

Add a relative iframe (carries the curated content above/below if desired):

```nix
h.iframe {
  src = "/code/frame";
  # full-bleed frame; min-height to fill the panel
}
```

The `src` is relative so it resolves through whatever host the visitor used
(public or LAN masquerade) and remains same-origin.

### 6. `content/release.json` + `content/staging.json`

Update `pages.code.githubSection` CTA to the canonical frame URL
(`/code/` or `/code/frame`), and optionally retarget `forgeProjects[].href` to
`https://johnbargman.com/code/frame/<owner>/<repo>` for repos hosted on Gitea.

**Note:** pushed to GitLab, then `nix flake update personal-site` in
NixOS-Configuration (not a `path:` solution).

---

## DNS (manual — when ready)

| Domain | Record | Target |
|---|---|---|
| `johnbargman.com` | A (public) | remote-worker public IP |
| `fabrication-forge.com` | A (public) | remote-worker public IP |
| `code.johnbargman.net` | A | cortex-alpha |

`fabrication-forge.com` ACME uses DNS-01 via Gandi (same `gandi_dns01_token`,
or a new secrix secret if a different Gandi account owns the zone).

---

## Execution Order

All paths relative to `/speed-storage/worktrees/config-codeforge/`.

1. `server_services/gitea.nix` — config values (ROOT_URL, detection, public access, trusted proxies)
2. `machines/remote-worker/default.nix` — subpath proxy + alias redirect + ACME import
3. `topology/cortex-alpha.json` — `code.johnbargman.net` 301
4. Golden regenerate + validate (cortex-alpha, remote-worker)
5. personal-website-blog — iframe + content (separate repo, push + `flake update`)
6. DNS manual (fabrication-forge.com)

---

## Risks

| Risk | Mitigation |
|---|---|
| Subpath proxying is "not recommended" by Gitea | Accepted trade-off for the frame-canonical model; regex + `/v2` rule from Gitea docs |
| Remote-worker not in trusted proxies | Fixed explicitly (`10.88.127.50/32`) |
| Clickjacking/`X-Frame-Options` | Same-origin frame; keep `SAMEORIGIN` default, do NOT set `unset` |
| LFS large uploads | `client_max_body_size 512M` on the subpath proxy location |
| Container registry `/v2` | Covered by the `(code/frame\|v2)` location alternation |