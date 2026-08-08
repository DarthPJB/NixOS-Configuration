# In-House Nix Binary Cache — `cache.johnbargman.net`

> **Created:** 2026-08-03 (refreshed from `opencode/plans/nix-cache-johnbargman-2026-07-22.md`)
> **Status:** ACTIVE
> **Branch:** `main`
> **Parent:** `remote-builder-hub-2026-07-15.md` (Phase 2/3 complete)
> **Blocks:** Fleet build times, CI pipeline reliability

## Executive Summary

Deploy an in-house Nix binary cache on `remote-builder` (10.88.127.51), served as
`cache.johnbargman.net` via cortex-alpha's split-horizon DNS + nginx reverse proxy.
Accessible only to LAN and WireGuard clients — no public internet exposure.

Uses `services.nix-serve` (the standard nixpkgs binary cache server), matching the
proven `infrastructure-2` pattern deployed on `hyperhyper` for `cache.platonic.systems`.

## Prerequisites — ALL SATISFIED

| Prerequisite | Status |
|---|---|
| `overlord-ii-planar-topology` merged | ✅ DONE — topology uses JSON format |
| remote-builder hub config (Phase 2/3) | ✅ DONE — max-jobs=0, GC disabled, 295GB disk |
| Golden tests passing | ✅ CONFIRMED by user |
| Topology JSON format | ✅ `topology/cortex-alpha.json` with `dns.static` and `vhosts` |

## Architecture

```
                    LAN Clients (10.88.128.0/24)
                    dnsmasq → cache.johnbargman.net → 10.88.128.1
                         │
                    ┌────▼──────────────────────────────────────┐
                    │  cortex-alpha (hub, 10.88.128.1/10.88.127.1)│
                    │  ┌──────────────────────────────────────┐  │
                    │  │  nginx (wildcard *.johnbargman.net)   │  │
                    │  │  vhost: cache.johnbargman.net        │  │
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
                    │  └──────────────────────────────────┘  │
                    └───────────────────────────────────────┘
```

---

## Phase 1 — Cache Server on remote-builder

**Goal:** Create the cache server module and wire it into remote-builder.

### Step 1.1: Create `services/nix-cache-serve.nix`

**Agent:** bellana-deepseek
**Action:** Create new file

Create `services/nix-cache-serve.nix` with the following content:

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

**References:**
- `infrastructure-2/services/nix-cache-serve.nix` — reference implementation
- `secrets/cache-priv-key` — will be created in Step 1.3

**Success criteria:** File exists at `services/nix-cache-serve.nix`, valid Nix syntax.

### Step 1.2: Add import to `machines/remote-builder/default.nix`

**Agent:** bellana-deepseek
**Action:** Edit existing file

Add `../../services/nix-cache-serve.nix` to the imports list in `machines/remote-builder/default.nix`.

**Current imports (lines 9-21):**
```nix
imports = [
  ./hardware-configuration.nix
  ../../users/darthpjb.nix
  ../../modifier_imports/flakes.nix
  ../../environments/sshd.nix
  ../../environments/tools.nix
  ../../services/dynamic_domain_gandi.nix
  ../../services/mkRunners.nix
  ../../services/gitlab-credentials.nix
  ../../modifier_imports/remote-builder.nix
  ../../users/build.nix
  ../../modules/enable-wg-topology.nix
];
```

**Add after last import:**
```nix
  ../../services/nix-cache-serve.nix
```

**Success criteria:** Import line present, no syntax errors.

### Step 1.3: Generate and encrypt signing keys

**Agent:** USER (manual, offline operation)
**Action:** Key generation + secrix encryption

**CRITICAL:** The private key must never exist in plaintext on disk. Generate and encrypt in one session.

```bash
# 1. Generate private key (to temp file)
nix key generate-secret --key-name cache.johnbargman.net > /tmp/cache-priv-key

# 2. Extract public key
nix key convert-secret-to-public < /tmp/cache-priv-key > /tmp/cache-pub-key

# 3. Encrypt private key with secrix (all users + remote-builder host)
nix run .#secrix create ./secrets/cache-priv-key -- --all-users -s remote-builder < /tmp/cache-priv-key

# 4. Copy public key to repo
cp /tmp/cache-pub-key secrets/cache-pub-key

# 5. Clean up plaintext
rm /tmp/cache-priv-key /tmp/cache-pub-key

# 6. Verify
ls -la secrets/cache-priv-key secrets/cache-pub-key
cat secrets/cache-pub-key  # Note this value — needed for Phase 3
```

**References:**
- `secrix-fast-encryption.md` — secrix encrypt workflow
- `common-infra-strategies.md` — secrix integration patterns

**Success criteria:**
- `secrets/cache-priv-key` exists (encrypted, secrix-managed)
- `secrets/cache-pub-key` exists (plaintext, public key)
- Public key format: `cache.johnbargman.net:<base64>`

### Phase 1 Verification Gate (tpol-minimax)

- [ ] `services/nix-cache-serve.nix` exists and is syntactically valid
- [ ] Import added to `machines/remote-builder/default.nix`
- [ ] `secrets/cache-priv-key` exists (encrypted)
- [ ] `secrets/cache-pub-key` exists (plaintext)
- [ ] No plaintext private key on disk

---

## Phase 2 — DNS + Nginx on cortex-alpha

**Goal:** Add cache.johnbargman.net to cortex-alpha's topology (DNS + nginx vhost).

### Step 2.1: Add DNS static entry to `topology/cortex-alpha.json`

**Agent:** bellana-deepseek
**Action:** Edit existing file

Add to `dns.static` array in `topology/cortex-alpha.json`:

```json
{
  "domain": "cache.johnbargman.net",
  "ip": "10.88.128.1"
}
```

**Current `dns.static` structure (example entry):**
```json
{
  "domain": "git.johnbargman.net",
  "ip": "10.88.128.1"
}
```

**Success criteria:** New entry in `dns.static` array, valid JSON.

### Step 2.2: Add nginx vhost to `topology/cortex-alpha.json`

**Agent:** bellana-deepseek
**Action:** Edit existing file

Add to `vhosts` object in `topology/cortex-alpha.json`:

```json
"cache.johnbargman.net": [
  {
    "proxy_to": "10.88.127.51:5001",
    "proxy_headers": true
  }
]
```

**Current `vhosts` structure (example entry):**
```json
"git.johnbargman.net": [
  {
    "proxy_to": "10.88.127.3:80",
    "regex_prefix": true,
    "proxy_headers": true
  }
]
```

**Success criteria:** New vhost entry, valid JSON, proxy_to points to remote-builder:5001.

### Phase 2 Verification Gate (tpol-minimax)

- [ ] DNS static entry present in `topology/cortex-alpha.json`
- [ ] Nginx vhost present in `topology/cortex-alpha.json`
- [ ] JSON is valid (`jq . topology/cortex-alpha.json > /dev/null`)
- [ ] No other topology files modified

---

## Phase 3 — Fleet-Wide Trust Configuration

**Goal:** Configure all fleet machines to trust the cache.

### Step 3.1: Modify `configuration.nix`

**Agent:** bellana-deepseek
**Action:** Edit existing file

Add `cache.johnbargman.net` to `nix.settings` in `configuration.nix`:

**Current (around line 145):**
```nix
trusted-substituters = [
  "https://cache.nixos.org"
];
trusted-public-keys = [
  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
];
```

**Add (FIRST in each list for priority):**
```nix
trusted-substituters = [
  "https://cache.johnbargman.net"    # ADD THIS
  "https://cache.nixos.org"
];
trusted-public-keys = [
  "cache.johnbargman.net:<PUBLIC_KEY>"    # ADD THIS — replace with actual key
  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
];
```

**Note:** `<PUBLIC_KEY>` is the content of `secrets/cache-pub-key`.

**Success criteria:** Both lists updated, cache is first in substituters list.

### Step 3.2: Modify `flake.nix`

**Agent:** bellana-deepseek
**Action:** Edit existing file

Add to `nixConfig` block in `flake.nix`:

**Current (around line 5):**
```nix
nixConfig = {
  extra-substituters = [ "https://install.determinate.systems" ];
  extra-trusted-public-keys = [
    "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    "install.determinate.systems:a7GMGXFqz7lFjOE45sTRq1g/RX6KFHRKHXOHTi1uFhM="
  ];
};
```

**Add:**
```nix
nixConfig = {
  extra-substituters = [
    "https://cache.johnbargman.net"    # ADD THIS
    "https://install.determinate.systems"
  ];
  extra-trusted-public-keys = [
    "cache.johnbargman.net:<PUBLIC_KEY>"    # ADD THIS — replace with actual key
    "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    "install.determinate.systems:a7GMGXFqz7lFjOE45sTRq1g/RX6KFHRKHXOHTi1uFhM="
  ];
};
```

**Success criteria:** Both lists updated, cache is first in substituters list.

### Phase 3 Verification Gate (tpol-minimax)

- [ ] `configuration.nix` has cache in `trusted-substituters` and `trusted-public-keys`
- [ ] `flake.nix` has cache in `extra-substituters` and `extra-trusted-public-keys`
- [ ] Public key is consistent across all 4 locations
- [ ] Cache is first in substituters priority

---

## Phase 4 — Golden Regeneration + Validation

**Goal:** Regenerate cortex-alpha golden and validate all machines.

### Step 4.1: Regenerate cortex-alpha golden

**Agent:** bellana-deepseek
**Action:** Run commands

```bash
# Regenerate cortex-alpha golden
nix run .#dump-config -- cortex-alpha | jq -S . > goldens/cortex-alpha.json

# Validate cortex-alpha
nix run .#check-network -- cortex-alpha
```

**Success criteria:** Golden regenerated, validation passes.

### Step 4.2: Validate all machines

**Agent:** bellana-deepseek
**Action:** Run commands

```bash
for m in $(ls machines/); do
  nix run .#check-network -- "$m" 2>&1 | tail -1
done
```

**Success criteria:** All machines pass golden validation.

### Step 4.3: Verify nix eval

**Agent:** bellana-deepseek
**Action:** Run commands

```bash
# Verify flake evaluates
nix eval --json .#nixosConfigurations.remote-builder.config.services.nix-serve.enable --option builders ''
# Should output: true

# Verify cortex-alpha has the new vhost
nix eval --json .#ci.ci.github-actions --option builders '' > /dev/null
# Should succeed
```

**Success criteria:** Nix evaluation succeeds, nix-serve is enabled on remote-builder.

### Phase 4 Verification Gate (tpol-minimax)

- [ ] cortex-alpha golden regenerated
- [ ] cortex-alpha golden validation passes
- [ ] All other machines pass golden validation
- [ ] Nix evaluation succeeds
- [ ] Only cortex-alpha golden changed (no other golden diffs)

---

## Phase 5 — Deployment (Manual, User-Executed)

**Goal:** Deploy remote-builder and cortex-alpha, verify cache operation.

### Step 5.1: Deploy remote-builder

**Agent:** USER (manual)
**Action:** Deploy

```bash
nix run .#remote-builder -- switch
```

### Step 5.2: Verify nix-serve on remote-builder

**Agent:** USER (manual)
**Action:** Verify

```bash
# Check service status
ssh -p 1108 deploy@10.88.127.51 "systemctl status nix-serve.service"

# Check port binding
ssh -p 1108 deploy@10.88.127.51 "ss -tlnp | grep 5001"

# Check secrix secret
ssh -p 1108 deploy@10.88.127.51 "ls -la /run/nix-serve-keys/"
```

### Step 5.3: Deploy cortex-alpha

**Agent:** USER (manual)
**Action:** Deploy

```bash
nix run .#cortex-alpha -- switch
```

### Step 5.4: Verify DNS resolution

**Agent:** USER (manual)
**Action:** Verify

```bash
# From a LAN client
dig cache.johnbargman.net @10.88.128.1
# Should resolve to 10.88.128.1
```

### Step 5.5: Verify cache operation

**Agent:** USER (manual)
**Action:** Verify

```bash
# Ping the cache
nix store ping --store https://cache.johnbargman.net

# Test substitution
nix build nixpkgs#hello --substituters https://cache.johnbargman.net --no-link
```

### Step 5.6: Update plan status

**Agent:** bellana-deepseek
**Action:** Update docs

Update `docs/nix-cache-PLAN.md` status to COMPLETE.

---

## Files Changed Summary

| File | Phase | Action |
|---|---|---|
| `services/nix-cache-serve.nix` | 1 | **NEW** |
| `machines/remote-builder/default.nix` | 1 | Add 1 import |
| `secrets/cache-priv-key` | 1 | **NEW** (encrypted) |
| `secrets/cache-pub-key` | 1 | **NEW** (plaintext) |
| `topology/cortex-alpha.json` | 2 | Add DNS + vhost |
| `configuration.nix` | 3 | Add substituters + keys |
| `flake.nix` | 3 | Add substituters + keys |
| `goldens/cortex-alpha.json` | 4 | Regenerate |

## Deployment Sequence

1. ✅ Verify prerequisites
2. Generate signing keys (USER, offline)
3. Create `services/nix-cache-serve.nix` (bellana-deepseek)
4. Add import to remote-builder (bellana-deepseek)
5. Add topology entries (bellana-deepseek)
6. Add fleet-wide trust (bellana-deepseek)
7. Regenerate golden + validate (bellana-deepseek)
8. Deploy remote-builder (USER)
9. Deploy cortex-alpha (USER)
10. Verify cache operation (USER)

## References

- `opencode/plans/nix-cache-johnbargman-2026-07-22.md` — original plan
- `opencode/plans/remote-builder-hub-2026-07-15.md` — parent plan
- `infrastructure-2/services/nix-cache-serve.nix` — reference implementation
- `secrix-fast-encryption.md` — secrix encrypt workflow
- `common-infra-strategies.md` — secrix integration patterns
- `AGENTS.md` — planned in-house binary cache
