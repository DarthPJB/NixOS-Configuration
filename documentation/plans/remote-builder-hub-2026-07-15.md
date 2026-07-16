# remote-builder Hub — Build Distribution & Cache Plan

> **Created:** 2026-07-15
> **Updated:** 2026-07-16 23:50 UTC
> **Status:** ACTIVE — Phase 2/3 complete, BLOCKED on cortex-alpha Tailscale forwarding
> **Parent:** `overlord-II-PLAN.md`
> **Blocks:** overlord-II Phase 0 (golden validation), CI pipeline reliability

## Executive Summary

Convert the `remote-builder` machine (10.88.127.51) from an underutilised OpenStack VM
running GitHub runners into the **build-runner hub** — the central node that:

1. **Distributes ALL nix builds** to the existing remote builders (hyperhyper, arm-builder)
   via nix-daemon `ssh-ng` protocol
2. **Never builds locally** (`max-jobs = 0`) — it is a pure coordinator
3. **Runs unlimited GitHub Actions runners** — since builds are distributed, the hub only
   needs storage and network I/O
4. **Contributes to the fleet cache** — pushes built paths to `cache.platonic.systems`
   using the Infrastructure-2 post-build hook pattern

The existing remote builders remain unchanged:
- **hyperhyper** (`100.107.101.14`) — 100+ cores, 1TB RAM, x86_64-linux, hosts `cache.platonic.systems`
- **arm-builder** (`10.88.127.43`) — aarch64-linux

## Why This Is Needed

The current CI pipeline has two problems that block overlord-II:

1. **LINDA is the CI build host** — the `hate-filled` GitHub runner (NixOS-Configuration repo)
   runs on LINDA, which builds locally. LINDA has the hardware (48c Threadripper, 125GiB RAM)
   but is also a desktop/gaming machine with competing workloads.

2. **remote-builder is not registered as a builder** — its entry in
   `modifier_imports/remote-builder.nix` is commented out. No machine dispatches builds
   to it. The machine exists but does nothing useful beyond running 3 lightweight runners
   for other repos.

The hub pattern solves both: remote-builder becomes the CI dispatch node, all builds go
to hyperhyper (100+ cores) or arm-builder, and LINDA is freed from CI build workloads.

## Architecture

```
GitHub Actions
    │
    ▼
remote-builder (hub)
  ├─ GitHub runners (unlimited)
  ├─ nix-daemon (max-jobs = 0)
  ├─ 200+ GB NFS disk (/nix store)
  └─ post-build-hook (sign + push to cache)
        │
        ├──────────────────────┐
        ▼                      ▼
  hyperhyper                arm-builder
  (100.88.101.14)           (10.88.127.43)
  x86_64-linux              aarch64-linux
  100+ cores, 1TB RAM       RPi 4, 4GB RAM
  hosts cache.platonic.systems
```

## Phase 1: Clean Up `modifier_imports/remote-builder.nix`

**Goal:** Remove commented-out entries that conflate the hub with builders.

**Work:**
- Remove the 5 commented-out builder blocks:
  - `100.127.177.30` (pompeii — aarch64-darwin, not in this fleet)
  - `10.88.127.41` (display-1 — kitchen wall display, not a builder)
  - `10.88.127.50` (remote-worker — web server, not a builder)
  - `10.88.127.51` (remote-builder — THIS machine, the hub, not a builder)
  - `10.88.127.21` (terminal-nx-01 — terminal, not a builder)
- Keep the two active entries unchanged:
  - `100.107.101.14` (hyperhyper) — x86_64-linux, speedFactor 10, maxJobs 10
  - `10.88.127.43` (arm-builder) — aarch64-linux, speedFactor 5, maxJobs 3
- Add a header comment explaining the architecture:
  > This file defines the remote build machines that the hub (remote-builder) and
  > other clients dispatch to via nix-daemon ssh-ng protocol. Importing machines
  > should set `nix.settings.max-jobs = 0` to force all builds through distribution.
  > The hub itself is NOT a builder — it is a coordinator.

**Files:** `modifier_imports/remote-builder.nix`

**Exit criteria:** No commented-out builder entries remain; active entries unchanged;
architecture comment present; syntax valid.

---

## Phase 2: Attach External Storage for Nix Store

**Goal:** Attach a 200+ GB OpenStack virtual disk to remote-builder and mount it
as `/nix`. This must happen BEFORE any configuration change so that the storage
layer is stable and verified in isolation.

> ⚠️ **Why this comes before Phase 3:** Deploying an altered nix-daemon configuration
> (max-jobs=0, distributed builds) before the new disk is stable conflates two
> potential failure points. If something fails after deploying both changes at once,
> we cannot determine whether the failure was caused by the store migration or the
> configuration change. The disk must be proven stable first. Phase 3 (hub config)
> deploys only after Phase 2 (disk) is verified.

**Work:**

### 2.1 OpenStack Side

Attach a virtual disk (200+ GB NFS) to the remote-builder VM. This is an OpenStack
operation, not a NixOS config change.

### 2.2 NixOS Config

Add filesystem declaration for the new disk:

```nix
fileSystems."/nix" = {
  device = "/dev/disk/by-label/nix-store"; # or by-uuid, depending on attachment
  fsType = "ext4"; # or "nfs", depending on the attachment method
};
```

### 2.3 Store Migration

Reference: `operational_patterns.md` "Nix Store Migration" section.

1. Mount new storage to temporary location (`/mnt/new-store`)
2. Copy: `sudo cp -a /nix/. /mnt/new-store/`
3. Verify item count matches
4. **CRITICAL:** Re-copy after any new system closures are built — new derivations
   won't be in the original copy
5. Update NixOS config with new mount points
6. Rebuild and switch

> ⚠️ **Never switch mount points before ensuring the new store contains all required paths.**

**Prior art:**
- arm-builder NVMe migration (`documentation/arm-build-limitations.md` lines 231-244)
- display-2 store migration (same document)
- `operational_patterns.md` "Nix Store Migration" section

### 2.4 Verify Storage in Isolation

Before proceeding to Phase 3, confirm the new disk is stable:

1. **Verify mount:** `df -h /nix` shows the new disk
2. **Verify store integrity:** `nix store verify --no-contents /nix/store/...` on a
   known path
3. **Verify nix-daemon still works:** `nix build nixpkgs#hello --no-link` should
   succeed (building locally, since max-jobs is not yet 0)
4. **Monitor for I/O errors:** `journalctl -k | grep -i 'error\|offline'` — no
   device offline or I/O errors

**Files:** `machines/remote-builder/default.nix` (or `hardware-configuration.nix`), OpenStack API

**Exit criteria:** 200+ GB disk attached; `/nix` mounted on new storage; store contents
verified; nix-daemon works normally; no I/O errors for 24h.

---

## Phase 3: Configure remote-builder Machine as Hub

**Goal:** Configure the remote-builder machine to be a pure dispatch/runner/cache node.
This phase deploys AFTER the new disk is stable (Phase 2), so any failures can be
isolated to the configuration change alone.

**Work:**

### 3.1 Import `modifier_imports/remote-builder.nix`

Currently `machines/remote-builder/default.nix` does NOT import this file. Add it to
the imports list. This brings in:

- `nix.buildMachines` — hyperhyper + arm-builder registration
- `nix.distributedBuilds = true` — enables build distribution
- `builders-use-substitutes = true` — builders fetch from caches before building
- SSH known hosts for hyperhyper and pompeii
- `sshMultiplex.exclusions` for builder hosts — prevents ControlMaster corruption
  of the ssh-ng protocol handshake (NixOS/nix#14132)
- The `build@*` SSH block disabling multiplexing for builder connections

### 3.2 Set `nix.settings.max-jobs = 0`

This forces the nix-daemon to NEVER build locally. All builds are dispatched to
hyperhyper and arm-builder. The machine becomes a pure coordinator — it only
receives completed paths back from the builders.

### 3.3 Secrix Secrets (Already Handled)

`modifier_imports/remote-builder.nix` declares two secrix secrets:

| Secret | Secrix Path | Purpose | Encrypted Blob |
|--------|-------------|---------|----------------|
| hyper_build_private_key | `secrix.services.nix-daemon.secrets.hyperhyper` | SSH key for hyperhyper (build user) | `secrets/hyper_build_private_key` |
| builder-key | `secrix.services.nix-daemon.secrets.personal-builder` | SSH key for arm-builder (build user) | `secrets/builder-key` |

Both encrypted blobs already exist in the repo. When remote-builder imports the
file, secrix will decrypt them to `/run/nix-daemon-keys/` at activation time.
No new secrets needed for Phase 3.

### 3.4 Keep Existing Runners

`services/github_runners.nix` stays imported — the 3 existing runners (disgust,
rat-infested, entropy-is-origin) continue working. Since all builds are distributed,
the machine can handle unlimited runners. The `hate-filled` runner (NixOS-Configuration
CI) stays on LINDA for now but could move here later.

### 3.5 Verify Build User

Already configured via `users/build.nix` (imported by `machines/remote-builder/default.nix`):
- `build` user (uid 1111) with SSH authorized keys from `secrets/builder-key.pub`
- `trusted-users = [ "build" ]` (from `configuration.nix`)
- SSH listens on WireGuard IP, port 22
- Firewall rule for port 22 on wireg0

**Files:** `machines/remote-builder/default.nix`

**Exit criteria:** `modifier_imports/remote-builder.nix` imported; `max-jobs = 0` set;
secrix secrets declared; build user verified; nix-daemon dispatches to hyperhyper/arm-builder.

---

## Phase 4: Configure Cache Contribution

**Goal:** Configure remote-builder to push built paths to `cache.platonic.systems`
using the Infrastructure-2 post-build hook pattern. This phase deploys AFTER the
hub configuration is active (Phase 3).

**Reference (IMMUTABLE):** `/speed-storage/repo/platonic.systems/infrastructure-2/services/cache-push.nix`

### How the Infrastructure-2 Pattern Works

1. A `post-build-hook` runs after every nix build
2. It signs each output path with `nix store sign --key-file <cache-priv-key>`
3. It copies each signed path to the cache via
   `nix copy --to ssh-ng://nix-ssh@<cache-address>?ssh-key=<cache-ssh-key>`
4. The cache (`cache.platonic.systems`) runs `nix.sshServe` + `services.nix-serve`
   on hyperhyper

### Why It Works for the Hub

Even with `max-jobs = 0` (set in Phase 3), the hub's nix-daemon receives completed
paths from the remote builders via ssh-ng. When those paths arrive, the post-build-hook
triggers, signs them, and pushes them to the cache. The hub becomes a cache contributor
without ever building anything itself.

### Work

#### 4.1 Create `services/cache-push.nix`

Replicate the Infrastructure-2 pattern in the NixOS-Configuration repo:

```nix
# services/cache-push.nix
# Post-build hook: sign and push to cache.platonic.systems
# Reference: /speed-storage/repo/platonic.systems/infrastructure-2/services/cache-push.nix
#            (IMMUTABLE — do not modify the reference)
```

Key elements from the reference:
- `sign-command`: `nix store sign --key-file <cache-priv-key>`
- `copy-command`: `nix copy --to ssh-ng://nix-ssh@<cache-address>?ssh-key=<cache-ssh-key>`
- `post-build-hook`: shell script that iterates `$OUT_PATHS`, signs each, copies each
- Retry logic: copy fails once → sleep 1s → retry once → continue
- `nix.extraOptions`: `post-build-hook = <path-to-hook-script>`

#### 4.2 Declare Secrix Secrets for Cache Credentials

Two additional secrets needed:

| Secret | Secrix Path | Purpose | Source |
|--------|-------------|---------|--------|
| cache-priv-key | `secrix.system.secrets.cache-priv-key` | Signing key for cache paths | From Infrastructure-2 `secrets/cache-priv-key` |
| nix-ci-cache-ssh-key | `secrix.system.secrets.nix-ci-cache-ssh-key` | SSH key for cache push (nix-ssh user) | From Infrastructure-2 `secrets/nix-ci/nix_cache_private_ssh` |

These secrets need to be re-encrypted for this repo's secrix context (remote-builder's
host key). The encrypted blobs should be placed in `secrets/` and declared in the
cache-push module.

**Encryption command:**
```bash
nix run .#secrix encrypt secrets/cache-priv-key -- --all-users -s remote-builder
nix run .#secrix encrypt secrets/nix-ci-cache-ssh-key -- --all-users -s remote-builder
```

#### 4.3 Import Cache-Push Module

Add `../../services/cache-push.nix` to `machines/remote-builder/default.nix` imports.
This is additive to the imports added in Phase 3.

#### 4.4 Enable Cache Verification Fleet-Wide

Uncomment the `cache.platonic.systems` trusted-public-key in `configuration.nix`:

```nix
# CURRENTLY (line 155):
#        "cache.platonic.systems:ePE43vrTvMW4177G3LfAYWCSdZkSBA5gY3WZCO1Y3ew="

# SHOULD BE:
        "cache.platonic.systems:ePE43vrTvMW4177G3LfAYWCSdZkSBA5gY3WZCO1Y3ew="
```

Without this, the fleet cannot verify signed paths from the cache. The
`trusted-substituters` already includes the URL (line 151), but the public key
is needed for signature verification.

**Files:** `services/cache-push.nix` (new), `machines/remote-builder/default.nix`,
`configuration.nix`, `secrets/` (encrypted blobs)

**Exit criteria:** Cache-push module created; secrix secrets encrypted and declared;
`cache.platonic.systems` public key uncommented; post-build-hook configured.

---

## Phase 5: Verify and Deploy

**Goal:** Validate the entire chain works end-to-end.

**Work:**

1. **Deploy remote-builder** with the new config:
   ```bash
   nix run .#remote-builder -- switch
   ```

2. **Verify `/etc/nix/machines`** on remote-builder includes hyperhyper and arm-builder:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'cat /etc/nix/machines'
   ```

3. **Verify `max-jobs = 0`**:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'nix show-config | grep max-jobs'
   ```

4. **Verify secrix secrets**:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'ls -la /run/nix-daemon-keys/'
   ```
   Should show `hyperhyper` and `personal-builder`.

5. **Test a build dispatch** — trigger a CI job or manually build on remote-builder:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'nix build nixpkgs#hello --no-link'
   ```
   Should dispatch to hyperhyper, not build locally.

6. **Verify post-build-hook** — after a build completes, check cache:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'journalctl -u nix-daemon --since "5 min ago" | grep push-to-cache'
   ```

7. **Monitor store growth** on the new 200+ GB disk:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'df -h /nix'
   ```

8. **Run golden tests**:
   ```bash
   nix run .#check-network -- remote-builder
   ```

9. **Fleet-wide cache verification** — on any machine:
   ```bash
   nix build nixpkgs#hello --substituters https://cache.platonic.systems --no-link
   ```

**Files:** None (operational)

**Exit criteria:** Builds dispatch to hyperhyper/arm-builder; `max-jobs = 0` confirmed;
secrix secrets present; post-build-hook pushes to cache; golden test passes.

---

## Summary of All Changes

| Phase | File | Change |
|-------|------|--------|
| 1 | `modifier_imports/remote-builder.nix` | Remove 5 commented-out builder blocks; add architecture comment |
| 2 | `machines/remote-builder/default.nix` | Add `fileSystems."/nix"` for 200+ GB external disk; store migration |
| 3 | `machines/remote-builder/default.nix` | Import `modifier_imports/remote-builder.nix`; set `nix.settings.max-jobs = 0` |
| 4 | `services/cache-push.nix` (new) | Post-build hook: sign + push to `cache.platonic.systems` |
| 4 | `machines/remote-builder/default.nix` | Import `services/cache-push.nix` |
| 4 | `configuration.nix` | Uncomment `cache.platonic.systems` trusted-public-key |
| 4 | `secrets/` | Re-encrypt `cache-priv-key` and `nix-ci-cache-ssh-key` for remote-builder |

## Secrets Summary

| Secret | Secrix Path | Purpose | Status |
|--------|-------------|---------|--------|
| `hyper_build_private_key` | `secrix.services.nix-daemon.secrets.hyperhyper` | SSH key for hyperhyper | ✅ Already in `secrets/` |
| `builder-key` | `secrix.services.nix-daemon.secrets.personal-builder` | SSH key for arm-builder | ✅ Already in `secrets/` |
| `cache-priv-key` | `secrix.system.secrets.cache-priv-key` | Signing key for cache paths | ⬜ Needs re-encryption for this repo |
| `nix-ci-cache-ssh-key` | `secrix.system.secrets.nix-ci-cache-ssh-key` | SSH key for cache push | ⬜ Needs re-encryption for this repo |

## Key Design Principles

- **remote-builder never builds locally** — `max-jobs = 0` forces all builds to
  hyperhyper and arm-builder
- **hyperhyper and arm-builder remain unchanged** — they are the actual builders
- **Unlimited runners are fine** — builds are distributed, the hub only needs storage
  and network I/O
- **200+ GB disk** provides store capacity for the hub to hold all closures
- **Cache contribution** uses the Infrastructure-2 post-build hook pattern
  (immutable reference)
- **Secrix manages all secrets** — SSH keys and cache credentials are encrypted at
  rest, decrypted only at service runtime
- **`modifier_imports/remote-builder.nix` is the client config** — it defines what
  machines to USE as builders, not how to BE a builder

## Current State (2026-07-16 23:50 UTC)

### remote-builder (10.88.127.51) — DEPLOYED

| Component | Status | Notes |
|-----------|--------|-------|
| `/nix` store | ✅ 300G disk (`/dev/vdb`, label `nix-store`) | Live-migrated from `/dev/vda1` |
| `max-jobs = 0` | ✅ Active | Builds distributed, never local |
| `/etc/nix/machines` | ✅ hyperhyper + arm-builder registered | secrix keys decrypted |
| WireGuard `allowedIPs` | ✅ Includes `100.107.101.14/32` | For hyperhyper via cortex-alpha |
| Static route | ✅ `100.107.101.14 dev wireg0` | Via `networking.localCommands` |
| secrix keys | ✅ `hyperhyper`, `personal-builder` | At `/run/nix-daemon-keys/` |
| GitHub runners | ✅ All 3 active | disgust, rat-infested, entropy-is-origin |
| **Connectivity to hyperhyper** | ❌ **BLOCKED** | Packets enter WG tunnel but cortex-alpha can't forward to Tailscale |

### cortex-alpha (10.88.127.1) — DEPLOYED (reverted)

| Component | Status | Notes |
|-----------|--------|-------|
| nftables | ⚠️ Reverted to original | Broken nftables ruleset change removed |
| Tailscale `ip filter` table | ❌ **MISSING** | `ts-forward` and `ts-input` chains wiped by nftables reload |
| Direct ping to hyperhyper | ✅ Works | Tailscale handles local traffic without forward chain |
| Forwarding from WireGuard → Tailscale | ❌ **BROKEN** | Missing `ts-forward` chain drops forwarded packets |

### BLOCKER: cortex-alpha Tailscale nftables rules

The `ip filter` table containing Tailscale's `ts-forward` and `ts-input` chains was
wiped when `networking.nftables.ruleset` was set on cortex-alpha (commit `3635617`).
The nftables service uses `nft -f` which replaces the entire ruleset. Tailscale's
runtime-managed rules were not preserved.

The revert (commit `dd550e9`) removed the broken ruleset, but Tailscale's rules were
not restored. The nftables service needs to be reloaded AND Tailscale needs to
re-inject its rules.

**Resolution needed:** Restart Tailscale on cortex-alpha to restore its nftables
rules, OR implement the forward rule correctly within the topology engine architecture
(see "Correct Approach" below).

### Correct Approach for Forward Rule

The forward rule MUST be implemented within the existing topology engine architecture,
NOT via raw `networking.nftables.ruleset`:

1. **Option A: `networking.firewall.extraCommands`** — Add nftables rules to the
   `inet nixos-fw` table's forward chain via the NixOS firewall module. This
   integrates with the existing firewall structure.

2. **Option B: Extend `topology.forwarding`** — Add a new forwarding type to the
   topology engine (e.g., `forwarding.wireguardToTailscale`) and generate the
   appropriate nftables rules in `mkForwarding.nix`.

3. **Option C: Restore Tailscale rules** — Simply restart Tailscale on cortex-alpha
   to restore its runtime nftables rules. The existing FORWARD policy is `accept`,
   so forwarding from WireGuard to Tailscale should work once the `ts-forward`
   chain is restored.

**Option C is the immediate fix.** Options A/B are the long-term declarative solution.

### Commits

| Commit | Description | Status |
|--------|-------------|--------|
| `3635617` | remote-builder hub config + cortex-alpha nftables (BROKE TAILSCALE) | partial revert |
| `222d87b` | localCommands route fix (dhcpcd compat) | ✅ deployed |
| `771f31c` | WireGuard allowedIPs for hyperhyper | ✅ deployed |
| `dd550e9` | Revert cortex-alpha nftables change | ✅ deployed

| Risk | Mitigation |
|------|------------|
| Store migration loses paths | Re-copy after any new closures; verify item counts |
| Cache push fails silently | Retry logic in hook; journal logging for debugging |
| Secrix secret decryption fails | Verify host key in `secrets/public_keys/host_keys/` |
| `max-jobs = 0` breaks local operations | None expected — hub only coordinates |
| SSH multiplexing corrupts ssh-ng | Already handled by `sshMultiplex.exclusions` in the module |
| Cache public key missing | Phase 4.4 uncomments it fleet-wide |

## References

- `modifier_imports/remote-builder.nix` — client-side builder config (what to dispatch to)
- `modifier_imports/central-builder.nix` — alternative config dispatching to LINDA
- `machines/remote-builder/default.nix` — hub machine config
- `services/github_runners.nix` — runners currently on remote-builder
- `users/build.nix` — build user config (shared across fleet)
- `configuration.nix` — common config (trusted-users, substituters, public keys)
- `modules/ssh-multiplex.nix` — SSH multiplexing with exclusions
- `operational_patterns.md` — nix store migration pattern
- `documentation/arm-build-limitations.md` — prior store migration work
- `documentation/incidents/2026-07-03-remote-builder-stale-machines-file.md` — incident
  showing `/etc/nix/machines` is declaratively generated
- Infrastructure-2 `services/cache-push.nix` — IMMUTABLE reference for cache-push pattern
- Infrastructure-2 `services/nix-cache-serve.nix` — IMMUTABLE reference for cache-serve
- Infrastructure-2 `systems/hyperhyper/default.nix` — how hyperhyper uses the cache
