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
4. **IS the fleet cache** — retains all built closures locally; GC disabled

The existing remote builders remain unchanged:
- **hyperhyper** (`100.107.101.14`) — 100+ cores, 1TB RAM, x86_64-linux
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
  ├─ 300GB disk (/nix store) — IS the fleet cache, GC disabled
  └─ receives completed paths from builders
        │
        ├──────────────────────┐
        ▼                      ▼
  hyperhyper                arm-builder
  (100.88.101.14)           (10.88.127.43)
  x86_64-linux              aarch64-linux
  100+ cores, 1TB RAM       RPi 4, 4GB RAM
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

## Phase 4: Cache Strategy

**Goal:** remote-builder IS the fleet cache. No external cache push needed.

**Status:** SUPERSEDED — the original plan called for pushing to an external cache
via post-build hook. This is no longer the design. remote-builder retains all
closures locally with GC disabled (`nix.gc.automatic = false`). The 300GB disk
provides sufficient capacity for the fleet's build outputs.

**Why this changed:** The hub accumulates all CI build outputs from hyperhyper
and arm-builder via ssh-ng. These paths stay in the store permanently. Other
machines in the fleet can use remote-builder as a substituter (via WireGuard)
once a serving mechanism is configured.

**Future work:** Configure `nix.sshServe` or `nix-serve` on remote-builder to
serve its store as a substituter for the fleet. This is a separate task from
the hub configuration.

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

6. **Monitor store growth** on the 300GB disk:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'df -h /nix'
   ```

7. **Run golden tests**:
   ```bash
   nix run .#check-network -- remote-builder
   ```

8. **Verify GC is disabled**:
   ```bash
   ssh deploy@10.88.127.51 -p 1108 'systemctl is-enabled nix-gc.timer'
   ```
   Should show `masked` or `disabled`.

**Files:** None (operational)

**Exit criteria:** Builds dispatch to hyperhyper/arm-builder; `max-jobs = 0` confirmed;
secrix secrets present; GC disabled; golden test passes.

---

## Summary of All Changes

| Phase | File | Change |
|-------|------|--------|
| 1 | `modifier_imports/remote-builder.nix` | Remove 5 commented-out builder blocks; add architecture comment |
| 2 | `machines/remote-builder/default.nix` | Add `fileSystems."/nix"` for 200+ GB external disk; store migration |
| 3 | `machines/remote-builder/default.nix` | Import `modifier_imports/remote-builder.nix`; set `nix.settings.max-jobs = 0` |
| 4 | `machines/remote-builder/default.nix` | Disable GC (`nix.gc.automatic = false`) — machine IS the cache |

## Secrets Summary

| Secret | Secrix Path | Purpose | Status |
|--------|-------------|---------|--------|
| `hyper_build_private_key` | `secrix.services.nix-daemon.secrets.hyperhyper` | SSH key for hyperhyper | ✅ Already in `secrets/` |
| `builder-key` | `secrix.services.nix-daemon.secrets.personal-builder` | SSH key for arm-builder | ✅ Already in `secrets/` |

## Key Design Principles

- **remote-builder never builds locally** — `max-jobs = 0` forces all builds to
  hyperhyper and arm-builder
- **hyperhyper and arm-builder remain unchanged** — they are the actual builders
- **Unlimited runners are fine** — builds are distributed, the hub only needs storage
  and network I/O
- **300GB disk** provides store capacity for the hub to hold all closures
- **remote-builder IS the cache** — GC disabled, all closures retained permanently
- **Secrix manages all secrets** — SSH keys encrypted at rest, decrypted only at
  service runtime
- **`modifier_imports/remote-builder.nix` is the client config** — it defines what
  machines to USE as builders, not how to BE a builder

## Current State (2026-07-17 — validated via code inspection)

### remote-builder (10.88.127.51) — DEPLOYED

| Component | Status | Notes |
|-----------|--------|-------|
| `/nix` store | ✅ 300G disk (`/dev/vdb`, label `nix-store`) | Live-migrated from `/dev/vda1` |
| `max-jobs = 0` | ✅ Active | Builds distributed, never local |
| `/etc/nix/machines` | ✅ hyperhyper + arm-builder registered | secrix keys decrypted |
| WireGuard `allowedIPs` | ✅ Includes `100.107.101.14/32` | For hyperhyper via cortex-alpha |
| Static route | ✅ `100.107.101.14 dev wireg0` | Via `networking.localCommands` |
| secrix keys | ✅ `hyperhyper`, `personal-builder` | At `/run/nix-daemon-keys/` |
| GitHub runners | ✅ 4 active | disgust, rat-infested, entropy-is-origin, **hate-filled** |
| GitLab netrc | ✅ Available | Via `gitlab-credentials.nix` + secrix |
| **Connectivity to hyperhyper** | ✅ **Working** | CI can contact hyperhyper |

### Previous Blocker: cortex-alpha Tailscale nftables rules — RESOLVED

The Tailscale forwarding issue has been resolved. CI is able to freely contact
hyperhyper on remote-builder. The `hate-filled` runner and netrc have been migrated
from LINDA to remote-builder (commit `d723f05`).

| Risk | Mitigation |
|------|------------|
| Store migration loses paths | Re-copy after any new closures; verify item counts |
| Secrix secret decryption fails | Verify host key in `secrets/public_keys/host_keys/` |
| `max-jobs = 0` breaks local operations | None expected — hub only coordinates |
| SSH multiplexing corrupts ssh-ng | Already handled by `sshMultiplex.exclusions` in the module |

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
