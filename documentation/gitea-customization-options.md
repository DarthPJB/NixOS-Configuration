# Gitea Customisation Options — Nixpkgs, Packaging, and Upstream

**Status:** Research / options survey (corrected 2026-09-29)
**Companion doc:** `documentation/gitea-fabrication-forge.md`
**Subject:** `server_services/gitea.nix`
**Upstream clone:** `/speed-storage/repo/gitea` (full clone, checked out at `v1.27.2`, `origin/main` fetched to `47529e2`)

> **Correction (2026-09-29):** the first revision of this doc used
> `/speed-storage/bargman-tech/nixpkgs_stable` as the version source and claimed
> the deployed Gitea was 1.25.5. That local checkout does **not** match the
> flake.lock revision. The deployed package evaluates to **1.27.2**. See §0.
> Never infer versions from the reference checkouts; evaluate the flake.

> **Implemented (2026-09-29, revised same day).** The recommendations below are
> now in the tree. **Correction:** the first implementation wired OIDC to
> `auth.platonic.systems` — Platonic.Systems' Authentik, not a system this
> fleet owns. That was wrong (third-party identity dependency, and the
> referenced application never existed). It has been purged. Identity is wired
> to the **real, deployed directory: OpenLDAP on cortex-alpha**
> (`server_services/ldap.nix`, LDAPS :636, `dc=johnbargman,dc=net`):
>
> - **Login:** LDAP via anonymous search bind + per-user bind (no shared
>   service credential). `server_services/gitea.nix` (`ldap`, `provisionLdap`,
>   `gitea-ldap-provision`), DNS name `ldap.johnbargman.net -> 10.88.127.1`
>   (WG plane) in `topology/cortex-alpha.json`. Password form is ON — it is
>   the transport for LDAP login.
> - **SSH:** git+ssh on **port 22** over WireGuard via the system sshd
>   (`server_services/git-ssh.nix`, `AllowUsers git@… gitea@…`; Gitea external
>   SSH, `SSH_PORT = 22`).
> - **Theme:** `Fabrication Forge` in `server_services/gitea-branding/`,
>   delivered via tmpfiles symlinks into `custom/`.
> - **Fork:** not used, not required.

---

## 0. What version is actually deployed

This is a declarative system: the deployed Gitea is exactly what `flake.lock`
pins. The locked `nixpkgs_stable` is rev `4382ed2b7a6839d4280a9b386db49cbc5907414d`
(flakehub `0.2605.1009383`). Evaluated against the flake:

```
$ nix eval --raw .#nixosConfigurations.local-nas.config.services.gitea.package.version
1.27.2
```

So:

| Thing | Version | Relationship |
|---|---|---|
| Deployed Gitea (`services.gitea.package`) | **1.27.2** | from the locked nixpkgs |
| `/speed-storage/repo/gitea` clone | **v1.27.2** | identical tag — the clone is *not* ahead |
| Upstream `origin/main` | `47529e2` | a few commits ahead of the deployed tag |
| `/speed-storage/bargman-tech/nixpkgs_stable` on disk | old checkout, Gitea 1.25.5 | **stale vs the lock; do not use for version claims** |

The local reference checkouts (`nixpkgs_stable`, `nixpkgs_unstable`) were last
updated in June 2026; the lock points at July 2026 (stable) and July 2026
(unstable) revisions. Any version/feature claim must be checked with
`nix eval` against the flake, not by reading those directories.

Consequences:

- All settings documented upstream for 1.27.2 apply to the deployed instance.
- To upgrade Gitea, update the flake input (`nix flake update nixpkgs_stable`);
  there is no separate Gitea pin to maintain.
- The clone at `v1.27.2` is the correct reference for the *running* code.

---

## 1. Nixpkgs `services.gitea` module surface

Evaluated option names for the locked module include the renamed/removed stubs
(`cookieSecure`, `disableRegistration`, `domain`, `httpAddress`, `httpPort`,
`log`, `rootUrl`, `staticRootPath`, `useWizard`, `enableUnixSocket`, `ssh`) plus
the live options below. The live surface is unchanged in shape from prior
releases:

| Option | Purpose |
|---|---|
| `enable` | Turn the service on |
| `package` | Swap in a fork/custom build |
| `stateDir` / `customDir` | Data/work dir; `CustomPath` (default `${stateDir}/custom`) |
| `user` / `group` | Service account |
| `database.*` | sqlite3/mysql/postgres, `createDatabase`, `passwordFile` |
| `captcha.*` | image/recaptcha/hcaptcha/mcaptcha/cfturnstile |
| `dump.*` / `lfs.*` | Backups; git-lfs |
| `appName` | Global `APP_NAME` branding |
| `repositoryRoot` | Repo storage root |
| `camoHmacKeyFile`, `mailerPasswordFile`, `metricsTokenFile`, `minioAccessKeyId`, `minioSecretAccessKey` | Secret file paths |
| `settings` | **Freeform `app.ini`** (`freeformType`, no allow-list) |
| `extraConfig` | Deprecated raw append |

Everything Gitea understands in `app.ini` is reachable through
`services.gitea.settings`; the module only hard-codes a handful of defaults and
injects secrets.

**Not managed by the module:** auth sources (DB state), contents of `customDir`
(templates/assets/locale), firewall, `sshd`, users/orgs/OAuth sources.

---

## 2. Login — declarative, immutable, WireGuard-only LDAP

### 2.1 Why the `wguser` header was wrong (removed)

Gitea previously enabled reverse-proxy auth with a **static**
`X-WEBAUTH-USER: wguser` set by cortex-alpha: every WireGuard client collapsed
to one account, unauthenticated at the app layer. **Removed 2026-09-29.**

### 2.2 What "declarative" can and cannot mean for Gitea auth

Gitea auth sources live in the **database**, not `app.ini` (verified:
`services/auth/source/` types are `db|ldap|oauth2|smtp|pam|sspi` and are rows).
Nix cannot render them. What Gitea *does* provide is a complete offline CLI to
reconcile them:

- `gitea admin auth list`
- `gitea admin auth add-ldap` / `update-ldap --id N` (per-flag updates)
- `gitea admin auth delete --id N`

So the declarative pattern is an idempotent systemd oneshot (same shape as the
existing `gitea-create-admin` / `gitea-minio-provision` units) that lists the
source and adds or updates it to the declared state. This is the closest Gitea
offers to immutable; the DB is still mutable at runtime by an admin, so
"immutable" is enforced by policy + reconciliation, not by the type system.

**The directory is the fleet's own OpenLDAP** on cortex-alpha
(`server_services/ldap.nix`): LDAPS :636, suffix `dc=johnbargman,dc=net`,
inetOrgPerson schema (core/cosine/inetorgperson/nis). Its `olcAccess` grants
`by anonymous auth` on `userPassword` and `by * read` elsewhere — so Gitea
needs **no bind credential**: an anonymous search finds the user DN, then a
per-user bind verifies the password (`services/auth/source/ldap/source_search.go`
— "Proceeding with anonymous LDAP search" when BindDN is empty). No secret is
created, shared, or stored.

Verified in code:

- Empty `BindDN` + empty `BindPassword` → anonymous search bind
  (`source_search.go:306-315`); password check is `l.Bind(userDN, passwd)`
  (`bindUser`, `source_search.go:138-145`).
- `--user-filter` standard shape:
  `(&(objectClass=inetOrgPerson)(uid=%s))` (Gitea integration tests use
  exactly this).
- `add-ldap`/`update-ldap` flags (`cmd/admin_auth_ldap.go`): `--host`, `--port`,
  `--security-protocol LDAPS`, `--user-search-base`, `--user-filter`,
  `--username-attribute`, `--firstname-attribute`, `--surname-attribute`,
  `--email-attribute`, `--admin-filter`, `--restricted-filter`,
  `--public-ssh-key-attribute`, `--enable-groups` + `--group-*`.

### 2.3 Target app.ini — IMPLEMENTED in `server_services/gitea.nix`

```nix
settings = {
  service = {
    DISABLE_REGISTRATION = true;          # accounts come from the directory
    REQUIRE_SIGNIN_VIEW = false;
    SHOW_REGISTRATION_BUTTON = false;
    ENABLE_PASSWORD_SIGNIN_FORM = true;   # the TRANSPORT for LDAP login
    ENABLE_BASIC_AUTHENTICATION = false;
    ENABLE_PASSKEY_AUTHENTICATION = true;
    ENABLE_OPENID_SIGNIN = false;         # legacy OpenID 2.0 out
    ENABLE_REVERSE_PROXY_AUTHENTICATION = false;  # wguser hack gone
    ENABLE_REVERSE_PROXY_AUTHENTICATION_API = false;
    ENABLE_REVERSE_PROXY_AUTO_REGISTRATION = false;
    ENABLE_REVERSE_PROXY_EMAIL = false;
  };
  admin = {
    # Identity is directory-owned.
    EXTERNAL_USER_DISABLE_FEATURES = "change_username,change_full_name,manage_credentials";
  };
};
```

Note the counter-intuitive bit: the password form **must** stay enabled for
LDAP, because it is the form that performs the LDAP bind. "Login method is
LDAP" is expressed by the auth source, not by hiding the form.

### 2.4 Provisioning unit — IMPLEMENTED as `gitea-ldap-provision`

`server_services/gitea.nix` (`provisionLdap`) reconciles the source each boot:
`admin auth list` → `add-ldap` or `update-ldap --id N`, with
`--security-protocol LDAPS --host ldap.johnbargman.net --port 636
--user-search-base dc=johnbargman,dc=net --user-filter
'(&(objectClass=inetOrgPerson)(uid=%s))' --username-attribute uid
--firstname-attribute givenName --surname-attribute sn --email-attribute mail`.
No `--bind-dn`/`--bind-password` — anonymous search by design.

### 2.5 Connectivity and trust path

- `topology/cortex-alpha.json` `dns.static` gains
  `ldap.johnbargman.net -> 10.88.127.1` (cortex-alpha's **WireGuard** address),
  so the Gitea→LDAP leg rides the WireGuard plane only.
- TLS: the OpenLDAP server uses cortex-alpha's ACME cert
  (`*.johnbargman.net`), so `LDAPS` hostname verification passes without
  `--skip-tls-verify`.
- Users: the DIT must contain `inetOrgPerson` entries with `uid`, `mail`,
  `givenName`, `sn` under `dc=johnbargman,dc=net`. Gitea auto-creates its
  account record on first successful directory login. Admin remains local
  break-glass (`gitea-create-admin` CLI); optional later: `--admin-filter` /
  `--enable-groups` + `--group-team-map` once directory groups exist.


---

## 3. SSH git connectivity (system sshd, port 22 over WireGuard) — IMPLEMENTED

### 3.1 The port-22 git-ssh plane

The fleet already separates planes: human/admin SSH is port 1108
(`environments/sshd.nix` + `modules/enable-wg-topology.nix` binds
`ListenAddress <wgIp>:1108`; `users/deployment.nix` / `users/inspect.nix` add
per-user `Match LocalPort 1108` blocks), and **port 22 on the WireGuard
address is the git-ssh plane**. MinIO uses 2222 and is unrelated.

`server_services/git-ssh.nix` (new) owns that plane:

```nix
services.openssh.extraConfig = ''
    Match LocalPort 22
      AllowUsers git@10.88.127.0/24 gitea@10.88.127.0/24
      PermitRootLogin no
      PasswordAuthentication no
'';
services.openssh.listenAddresses = [ { addr = wgIp; port = 22; } ];
networking.firewall.interfaces."wireg0".allowedTCPPorts = [ 22 ];
```

`gitolite.nix` (deleted 2026-10-01) previously held this policy for the legacy
`git` user; the policy now lives in `git-ssh.nix` and admits `git` (Gitea's
published clone identity) and `gitea`. The legacy cgit/gitolite stack was
retired 2026-10-01.

OpenSSH first-match semantics were verified with `sshd -T` before writing this:
the `Match LocalPort 22` `AllowUsers` wins over the global
`AllowUsers [ "John88" ]` from `environments/sshd.nix` for connections on22.

### 3.2 Gitea external-SSH config (implemented in `gitea.nix`)

```nix
services.gitea.settings.server = {
  DISABLE_SSH = false;
  START_SSH_SERVER = false;          # system sshd, not Gitea's builtin
  SSH_DOMAIN = "gitea.johnbargman.net";
  SSH_PORT = 22;
};
```

How it works (verified in `services/asymkey/`):

- `SSH_ROOT_PATH` defaults to `~gitea/.ssh`, and the gitea user's home is
  `stateDir` (`/bulk-storage/gitea`); sshd's default
  `AuthorizedKeysFile %h/.ssh/authorized_keys` finds it. The nixpkgs module
  creates `.ssh` with mode 0700.
- Gitea rewrites `authorized_keys` with a forced command:
  `command="{{AppPath}} --config={{CustomConf}} serv key-<id>",restrict ...`
  (`models/asymkey/ssh_key_authorized_keys.go`). `AppPath` is the **Gitea
  store path**, so it changes on every Gitea rebuild; the module's `preStart`
  runs `gitea admin regenerate keys` when the file exists, rotating the paths.
- `--ssh-public-key-claim-name` is available on the OIDC source: if Authentik
  supplies an SSH key claim, key provisioning flows through identity and the
  authorized_keys rewrite happens at each login. Deliberately not enabled yet
  (an absent claim must not wipe existing keys); enable once the IdP claim is
  guaranteed.
- `SSH_AUTHORIZED_PRINCIPALS_*` / `SSH_TRUSTED_USER_CA_KEYS` are available if
  short-lived SSH certificates from an internal CA are preferred.

### 3.3 Why nginx is not involved

nginx can proxy raw TCP (`services.nginx.streamConfig`, `withStream` is on by
default) but it is the wrong tool for SSH: OpenSSH does not speak PROXY
protocol, so sshd would see nginx as the client and every
`AllowUsers ...@10.88.127.0/24` / `Match Address` policy would be meaningless.
SSH also has no SNI, so nginx can only route by port — which `listenAddresses`
already does. The git-ssh policy (`server_services/git-ssh.nix`, which
superseded the deleted `server_services/gitolite.nix`) binds
sshd directly to the WireGuard address; Gitea follows the same pattern.

---

## 4. Theming — IMPLEMENTED as `server_services/gitea-branding/`

The `Fabrication Forge` theme ships in `server_services/gitea-branding/`:
`theme-fabrication-forge.css` (full Gitea dark-derived variable set with the
forge palette), `logo.svg`/`favicon.svg` (hex-forge mark), PNG renditions
built with `resvg`, and template hooks (`header`, `footer`, `extra_links`).
`server_services/gitea.nix` builds the `custom/`-shaped tree and symlinks it
in whole (`tmpfiles` `L+ ${customDir}/public` and `L+ ${customDir}/templates`),
with `ui.DEFAULT_THEME = "fabrication-forge"` and `appName = "Fabrication Forge"`.

What the module exposes (for reference):

Exposed as first-class NixOS options:

- `services.gitea.appName` — global `APP_NAME`.
- `services.gitea.customDir` — the `CustomPath` root that the runtime layers
  over built-in assets.
- `services.gitea.stateDir`.

Exposed through freeform `services.gitea.settings` (app.ini keys):

- `ui.DEFAULT_THEME`, `ui.THEMES`, `ui.FILE_ICON_THEME`, `ui.FOLDER_ICON_THEME`
- `ui.meta.AUTHOR/DESCRIPTION/KEYWORDS`
- `other.SHOW_FOOTER_VERSION/TEMPLATE_LOAD_TIME/POWERED_BY`
- `server.LANDING_PAGE`, `ui.CUSTOM_EMOJIS`, `ui.REACTIONS`

**Not** module options — these are files under `${customDir}` that we must
deliver ourselves:

| Thing | Where it goes |
|---|---|
| Logo | `${customDir}/public/assets/img/logo.svg` (and `logo.png` for OpenGraph) |
| Favicon | `${customDir}/public/assets/img/favicon.svg` / `.png` |
| Custom theme | `${customDir}/public/assets/css/theme-<name>.css` with a `gitea-theme-meta-info` block |
| Template hooks | `${customDir}/templates/custom/{header,footer,body_*,extra_links,extra_links_footer,extra_tabs}.tmpl` |
| Full overrides | `${customDir}/templates/**` |
| Locale strings | `${customDir}/options/locale/locale_en-US.json` |
| robots.txt | `${customDir}/public/robots.txt` |

Delivery pattern (upgrade-safe, declarative): build a `branding` derivation and
symlink its subtrees into `customDir` with `systemd.tmpfiles` `L+` entries.
Caveat: the existing module rule `Z ${stateDir}/custom` recursively touches
ownership there; verify it does not follow the new symlinks, or scope it to
`customDir/conf`.

Theme discovery is real and file-based (`services/webtheme/webtheme.go`): any
`assets/css/theme-*.css` is picked up from the layered asset FS (custom wins),
and `ui.THEMES = ""` allows all of them.

---

## 5. Fork: is it required?

**No**, for everything in this document:

- Immutable-ish OIDC login → app.ini + `gitea admin auth` provisioning.
- System-sshd git over a dedicated port → app.ini + sshd config.
- Branding/theming → runtime files under `customDir`.
- WG-only exposure → nginx/firewall (already the model).

A fork would only be needed for Go-level behaviour changes or baking assets
into an image. It is expensive: the nixpkgs package builds front-end assets in a
separate derivation that captures the original `src`/`version`, so
`overrideAttrs { src = ...; }` rebuilds the backend from the fork but the
front-end from upstream. A real fork needs a bespoke derivation and ongoing
rebases against 1.27.x template/CSS churn. Defer.

---

## 6. How to verify claims (use these, not the reference checkouts)

```bash
# Deployed Gitea version (source of truth)
nix eval --raw .#nixosConfigurations.local-nas.config.services.gitea.package.version

# Live module options in the locked nixpkgs
nix eval --json .#nixosConfigurations.local-nas.options.services.gitea \
  --apply 'builtins.attrNames'

# Whether an IdP has a NixOS module in the locked nixpkgs
nix eval --json .#nixosConfigurations.local-nas.options \
  --apply 'x: { authentik = x.services ? authentik; keycloak = x.services ? keycloak;
                kanidm = x.services ? kanidm; lldap = x.services ? lldap; }'

# Upstream reference
git -C /speed-storage/repo/gitea describe --tags
git -C /speed-storage/repo/gitea log --oneline -1 origin/main
```

---

## 7. Cutover and risks

### 7.1 Golden impact (expected)

`lib/serialize-config.nix` captures `services.openssh`, `services.nginx`,
`services.dnsmasq` and `networking.*` — so the identity/SSH changes are
golden-tracked. `services.gitea.*` is NOT serialized (theme + login settings
are golden-free). Current `validate-goldens` results:

| Machine | Diff | Cause |
|---|---|---|
| local-nas | `services.openssh.extraConfig` gains `gitea@10.88.127.0/24` | port-22 git-ssh policy |
| cortex-alpha | nginx vhost loses `X-WEBAUTH-*` lines | wguser holdover removed |
| cortex-alpha | `services.dnsmasq` gains `ldap.johnbargman.net` | LDAP reachability |

**Status: goldens NOT regenerated (user decision 2026-09-29).** Both machines
stay blocked on golden mismatch until the user authorizes:

```bash
nix run .#dump-config -- local-nas    | jq -S . > goldens/local-nas.json
nix run .#dump-config -- cortex-alpha | jq -S . > goldens/cortex-alpha.json
```

### 7.2 Cutover checklist (login)

1. Ensure the directory contains `inetOrgPerson` entries (`uid`, `mail`,
   `givenName`, `sn`) under `dc=johnbargman,dc=net`.
2. Deploy cortex-alpha (DNS entry `ldap.johnbargman.net -> 10.88.127.1`).
3. Deploy local-nas; `gitea-ldap-provision` registers the LDAP source on boot.
4. Log in with a directory account; confirm Gitea auto-creates the user record
   and that identity fields cannot be edited in Gitea
   (`EXTERNAL_USER_DISABLE_FEATURES`).
5. Break-glass remains the local admin via `gitea admin` CLI
   (`gitea-create-admin` unit).

### 7.3 Risks

- **DB-backed identity:** auth sources and users are runtime state; the
  declarative guarantee is a reconciled oneshot, not the Nix store. Back up
  Postgres (`server_services/postgres.nix`).
- **Anonymous LDAP search:** by design (the directory's own `olcAccess` already
  allows it). If that policy tightens later, a dedicated low-privilege bind DN
  must be created **by the user** and added to `provisionLdap`.
- **Directory is empty of users until populated** — login works for nobody
  until `inetOrgPerson` entries exist. Account provisioning is human authority.
- **`customDir` is on `/bulk-storage`** (not in the Nix store) but is now fully
  declarative: `conf/` is generated, `public/` + `templates/` are store symlinks.
- **Golden tests do not cover Gitea** (`dump-config` serialises nginx/firewall/
  dns/openssh only). Validate Gitea changes with `nixos-rebuild build`.
- **Authorized_keys path churn:** the forced command embeds the Gitea store
  path; rely on the module's `preStart` regeneration and verify after upgrades.
- **Public login paths** are 404-gated at nginx on the public faces; the
  sign-in form and LDAP live only on `gitea.johnbargman.net` (WG plane). The
  public faces remain read-only. Re-verify that gate before exposing any new
  face.

## 8. References

- NixOS module (deployed, via lock): `nixpkgs_stable/nixos/modules/services/misc/gitea.nix`
- Upstream config: `/speed-storage/repo/gitea/custom/conf/app.example.ini`
- LDAP CLI: `cmd/admin_auth_ldap.go`, `cmd/admin_auth.go`
- LDAP auth mechanics: `services/auth/source/ldap/source_search.go`
  (anonymous search bind, `bindUser`)
- The directory: `server_services/ldap.nix` (cortex-alpha), DNS:
  `topology/cortex-alpha.json` (`dns.static`)
- SSHD mechanics: `models/asymkey/ssh_key_authorized_keys.go`, `modules/setting/ssh.go`
- Fleet SSH prior art: `server_services/git-ssh.nix` (port-22 plane; supersedes
  deleted `server_services/gitolite.nix`), `environments/sshd.nix`, `users/build.nix`
- Current deployment: `documentation/gitea-fabrication-forge.md`
- nginx stream support: nixpkgs `nginx/default.nix` (`streamConfig`), `nginx/generic.nix` (`withStream`)
