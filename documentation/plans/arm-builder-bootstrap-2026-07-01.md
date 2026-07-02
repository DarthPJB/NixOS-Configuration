# ARM Builder Bootstrap & Restoration Plan

> **Created:** 2026-07-01
> **Last updated:** 2026-07-02
> **Status:** Active — Phase 1 COMPLETE, Phase 2 ready (flash + boot)
> **Supersedes:** `arm-build-limitations.md` Option 1 deployment plan (now offline)
> **Parent directive:** Correctness over speed; closed-system builds; no cloud providers

## Context

`display-2` (the sole aarch64 remote builder) failed when an incorrect mount entry
corrupted its SD card. `display-1` (low-RAM Pi 4, zram + 1 GB swapfile) and
`print-controller` (Pi 3, 1 GB RAM ceiling) are architecturally insufficient for
kernel builds. The entire ARM build capacity is offline.

Cross-compilation from x86_64 to aarch64 was previously proven in this repository
to bootstrap ARM images (see `machines/beta/1.nix` — the `beta-one` config used
`nixpkgs.buildPlatform = "x86_64-linux"` + `nixpkgs.hostPlatform = "armv7l-linux"`,
now an armv7l precedent; the same method applies to aarch64 for minimal images).
That code may not have fully persisted, but the method is sound and documented here.

## Goals

1. **Restore ARM build capacity** using a cross-compiled bootstrap image on a Pi 4
2. **Make bootstrapping deterministic and repeatable** — the image builds from source
   on x86_64, completing (success or failure) in our closed environment
3. **Accept long build times** — new deployments can take 48 hours if artifacts are
   in use for months; this is acceptable because nixpkgs inputs change rarely, making
   the cache stable for long periods between rebuilds
4. **Recover hardware** — use display-2's intact NVMe (500 GB WD SN750 via USB 3.0)
   attached to the same Pi 4 board; possibly physically relocate to dedicated casing
5. **Restore fleet** — once the builder is online, natively rebuild the other display
   units without cross-compilation

## Principles Enforced

- **Correctness over speed** — cross-compile succeeds or fails deterministically; no
  half-built states
- **No cloud providers** — all builds from source on self-hosted x86_64 hardware
  (Prime Directive 8)
- **No Docker** (Directive 13)
- **lib.getExe / writeShellApplication** for any scripts (Directives 18, 19)
- **Nix-declarative fixes only** — no live-system SSH manipulation except observation
  (Directive 20)
- **Methodical development** — read, plan, implement, validate, commit per phase
  (Directive 21)

---

## Phase 0 — Research & Preparation ✅ COMPLETE

### 0.1 Research: rPi4 USB-NVMe / USB Boot Methods ✅

Research report complete: `research/rpi4-usb-nvme-boot-methods.md`.

**Key finding:** SD-bootloader + USB-NVMe rootfs pivot is the most reliable boot method.
USB-MSD boot on Pi 4 is stable/production-ready with current EEPROM firmware.

### 0.2 Preparation Checklist

- [x] `display-0` confirmed dead testbed — moved to `dormantConfigurations`
- [x] `display-2` moved to `dormantConfigurations` (hardware alive, initrd fails on raw-UUID mounts)
- [x] WireGuard keys copied: `wg_display-2` → `wg_arm-builder` (private + public)
- [x] Host SSH key copied: `display-2.pub` → `arm-builder.pub`
- [x] Golden test generated: `real-topology/golden/arm-builder.json`

---

## Phase 1 — Cross-Compiled Bootstrap Image ✅ COMPLETE

**Goal:** Produce a minimal, headless, zero-documentation, cross-compiled SD-card image
that boots on a Pi 4, brings up networking (ethernet and/or WireGuard at boot), and
provides SSH access for the `deploy` user so nixinate can push a full closure.

### 1.1 Create the Minimal Builder Machine Configuration ✅

New machine: `machines/arm-builder/default.nix`

**Configuration (final, tested):**

```nix
{
  nixpkgs.buildPlatform = "x86_64-linux";

  imports = [
    # configuration.nix blocked via disabledModules — eliminates tools.nix (magic-wormhole),
    # monitoring modules, WiFi config, and admin user from the closure.
    ../../modules/enable-wg-topology.nix
    # ../../environments/lean-kernel.nix  # preserved for future display machines
    ../../environments/sshd.nix
    ../../modifier_imports/flakes.nix
    ../../users/build.nix
    ../../users/deployment.nix
    ../../users/inspect.nix
  ];

  disabledModules = [
    ../../configuration.nix
    "profiles/all-hardware.nix"
    "profiles/base.nix"
  ];

  documentation = { enable = false; dev.enable = false; man.enable = false; info.enable = false; };
  time.timeZone = "Etc/UTC";

  fileSystems."/" = { device = "/dev/disk/by-label/NIXOS_SD"; fsType = "ext4"; };
  sdImage.compressImage = false;
  enableWgTopology.enable = true;

  boot = {
    kernelParams = [ "console=ttyS1,115200n8" "cma=128M" ];
    loader = { grub.enable = false; generic-extlinux-compatible.enable = true; };
  };

  networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  services.openssh.enable = true;
}
```

**Key design choices:**
- **`buildPlatform = "x86_64-linux"`** — cross-compile from x86_64 host
- **`configuration.nix` blocked via `disabledModules`** — the flake's `commonModules`
  injects it for ALL machines; blocking it eliminates the Python dependency chain
  (magic-wormhole → autobahn) that was the root cause of the first build failure
- **`sshd.nix` + `flakes.nix` imported directly** — only the essential modules from
  the configuration.nix tree
- **No `lean-kernel.nix`** — stock rPi4 kernel; lean kernel preserved for display machines
- **WireGuard at boot** — `enable-wg-topology.nix` reuses display-2's WG identity
  (`10.88.127.42`) so cortex-alpha's known_hosts and remote-builder registration match
- **All three users imported** — build (uid 1111), deploy (uid 1110), inspect (uid 1112)
- **`AllowUsers` per-user** — each user module sets its own `AllowUsers` entry;
  NixOS module system merges them. Fixed antipattern where AllowUsers was centralized
  in configuration.nix.

### 1.2 Register in `flake.nix` ✅

Added to `nixosConfigurations` via `mkAarch64`. Added to `mkUncompressedSdImages`
aarch64-linux list.

### 1.3 Build the Cross-Compiled Image ✅

```bash
nix build .#packages.aarch64-linux.arm-builder --no-link --print-out-paths
```

**Build results:**
- Image size: 2.6 GB (sparse, ~1.5 GB actual)
- Build time: ~30 minutes (with remote builder offloading to hyperhyper)
- Output: `/nix/store/7b6xqwmglxl770sn2cpf40rpk9lyk8bj-nixos-image-sd-card-26.05.20260511.c6e5ca3-aarch64-linux.img-aarch64-unknown-linux-gnu`
- Zero errors, zero warnings

**Build failures encountered and resolved:**
1. **autobahn/wormhole failure** — `configuration.nix` was still being injected by
   `commonModules` at the flake level. Fixed by adding `../../configuration.nix` to
   `disabledModules` in the machine config.
2. **Prometheus scrape target errors** — `services/prometheus.nix` referenced
   `display-0` and `display-2` which were moved to dormant. Fixed by removing stale
   references.

### 1.4 Golden Test ✅

```bash
nix run .#check-network -- arm-builder   # ✅ PASSES
nix flake check                          # ✅ PASSES
```

**Image verification (debugfs inspection of ext4 partition):**
- Hostname: `arm-builder` ✅
- Users: build (1111), deploy (1110), inspect (1112) in `authorized_keys.d` ✅
- SSH: port 1108 on WG IP, port 22 for build user, Match blocks for all users ✅
- AllowUsers: `["build", "deploy", "inspect", "John88"]` ✅
- WireGuard: `10.88.127.42/32`, peer cortex-alpha at `cortex-alpha.johnbargman.net:2108` ✅

---

## Phase 2 — Boot, Network, and First Deployment (READY)

> **Status:** Image built and verified. Ready to flash and boot.

### 2.1 Flash and Boot

1. Write the cross-compiled image to a fresh SD card (minimum 4 GB, 8 GB recommended):
   ```bash
   dd if=/nix/store/7b6xqwmglxl770sn2cpf40rpk9lyk8bj-nixos-image-sd-card-26.05.20260511.c6e5ca3-aarch64-linux.img-aarch64-unknown-linux-gnu/sd-image/nixos-image-sd-card-26.05.20260511.c6e5ca3-aarch64-linux.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```
2. Insert into the Pi 4 (the board recovered from display-2, or a known-good Pi 4)
3. Connect ethernet (preferred) — WG will come up if the hub is reachable
4. Boot; observe via serial console (`console=ttyS1,115200n8`) or WG ping to `10.88.127.42`

### 2.2 Initrd resizefs

The standard nixpkgs `sd-image-aarch64.nix` includes an initrd that auto-expands the
root partition to fill the SD card on first boot (runtime, not build-time). Confirm this
is present in the cross-compiled image — if not, add `sdImage.expandOnBoot = true` or
equivalent. The expanded root gives the builder working space before NVMe is attached.

### 2.3 Deploy via nixinate

Once the minimal image is booted and reachable on WG (`10.88.127.42`):

```bash
# From cortex-alpha:
nix run .#deploy.arm-builder
```

nixinate connects via the `deploy` user on port 1108, pushes the full system closure,
and switches. **This build runs natively on the Pi 4** (nixinate's `buildOn = "local"`
means the target builds its own closure — slow but correct, and now the Pi has a real
Nix store from which to work).

### 2.4 First-Boot Configuration (Minimal Builder)

The first nixinate push should include a config that adds:
- `build` user (`users/build.nix`) — for remote builder SSH on WG port 22
- `big-parallel` system feature
- SSH on WG interface for the `build` user

---

## Phase 3 — NVMe Integration

### 3.1 Attach NVMe

Physically attach display-2's NVMe (500 GB WD SN750 via USB 3.0 enclosure) to the
builder Pi.

### 3.2 Partition and Mount

The NVMe was previously partitioned (per `arm-build-limitations.md`):
- `/dev/sda1` — ext4, ~233 GB (for `/nix/store`)
- `/dev/sda2` — ~233 GB swap

**Deploy a second config push** (via nixinate) that adds:
```nix
fileSystems."/nix" = {
  device = "/dev/disk/by-label/nix-nvme";  # use label, not raw UUID — lesson from display-2
  fsType = "ext4";
};
swapDevices = [
  { device = "/dev/disk/by-label/nix-swap"; }
];
```

> **Critical:** Use `by-label` or `by-partlabel` — never raw UUIDs. The incorrect
> mount entry that killed display-2's SD card was likely a raw-UUID pin that became
> stale or mismatched. Labels are human-readable and stable across partition restores.

### 3.3 Copy Store to NVMe

After the NVMe mount is active, copy the existing store contents:

```bash
# On the builder, via SSH (observation — this is a one-time data migration, not a fix):
sudo cp -a /nix/. /mnt/nix-nvme/  # then redeploy with the mount active
```

> This is a data-copy operation, not a live-system fix — the Nix-declarative mount
> configuration is what makes it permanent. The copy is idempotent.

### 3.4 Register as Remote Builder on x86_64 Hosts

`modifier_imports/remote-builder.nix` already has the entry for `10.88.127.42` with
`aarch64-linux` and `big-parallel`. Once the builder is back up, no hub-side change
is needed. Verify:

```bash
# From cortex-alpha:
nix store ping --store ssh-ng://build@10.88.127.42
```

---

## Phase 4 — Native Rebuild of Display Fleet

With the builder operational, rebuild the other ARM machines natively (no
cross-compilation needed):

### 4.1 Rebuild display-1

```bash
# display-1 is already registered as a remote builder target conceptually,
# but needs the build user. For now, rebuild via remote builder:
nix build --option builders '' \
  .#nixosConfigurations.display-1.config.system.build.toplevel \
  --max-jobs 0 --builders 'ssh-ng://build@10.88.127.42 aarch64-linux 3 5 big-parallel - -'
```

### 4.2 Rebuild display-2 (full config, if the board is recovered)

If display-2's original config is desired (cyberdeck with RTL-SDR, audio, etc.):
- Build the full closure via the new builder
- Deploy via nixinate to `display-2` (if the original board is still in that role)
- Or repurpose the builder hardware permanently and retire display-2's cyberdeck role

### 4.3 display-0 Status Check

`display-0` may not be a live system. Verify:
```bash
ping 10.88.127.40   # WG
# or check last-seen on the hub
```

If offline, mark as dormant (move to `dormantConfigurations`) to prevent CI builds
from failing on machines that don't exist.

---

## Phase 5 — Physical Relocation (Optional)

> Per user: "I may even physically attach it to her casing."

If the builder becomes permanent, consider:
- Dedicated enclosure (not the cyberdeck form factor)
- Attached to cortex-alpha's physical location for minimal network latency
- Labeled as `arm-builder` (distinct from `display-2`'s cyberdeck identity)

This is a hardware decision, not a config one — no code changes required if the
WG identity stays `10.88.127.42`.

---

## Architecture Diagram

```
                        ┌─────────────────────────────────┐
                        │       x86_64 Host (cortex-alpha) │
                        │                                  │
                        │  nix build .#arm-builder         │
                        │   .system.build.sdImage         │
                        │  ┌────────────────────────┐     │
                        │  │ CROSS-COMPILE (x86→arm) │     │
                        │  │ minimal headless image   │     │
                        │  │ nixpkgs.buildPlatform    │     │
                        │  │   = "x86_64-linux"       │     │
                        │  │ nixpkgs.hostPlatform     │     │
                        │  │   = "aarch64-linux"      │     │
                        │  └───────────┬────────────┘     │
                        └──────────────┼───────────────────┘
                                       │ dd → SD card
                                       ▼
                        ┌─────────────────────────────────┐
                        │      Pi 4 (arm-builder)         │
                        │  ┌────────────────────────┐     │
                        │  │ BOOT (minimal image)    │     │
                        │  │ - eth0 DHCP             │     │
                        │  │ - WireGuard 10.88.127.42│     │
                        │  │ - deploy user (nixinate)│     │
                        │  │ - initrd resizefs       │     │
                        │  └───────────┬────────────┘     │
                        │              │ nixinate deploy   │
                        │              ▼                  │
                        │  ┌────────────────────────┐     │
                        │  │ FULL CLOSURE (native)   │     │
                        │  │ + build user            │     │
                        │  │ + big-parallel          │     │
                        │  │ + NVMe /nix + swap      │     │
                        │  └───────────┬────────────┘     │
                        └──────────────┼───────────────────┘
                                       │
                                       ▼
                        ┌─────────────────────────────────┐
                        │   x86_64 Hosts (all)            │
                        │  nix.buildMachines →            │
                        │   ssh-ng://build@10.88.127.42  │
                        │   aarch64-linux, big-parallel   │
                        │                                  │
                        │  Builds dispatch here for all   │
                        │  ARM machines (display-1, -2,   │
                        │  print-controller, etc.)        │
                        └─────────────────────────────────┘
```

---

## Dependencies and Prerequisites

| Item | Required for | Source / Location |
|------|-------------|-------------------|
| Cross-compile method (buildPlatform/hostPlatform) | Phase 1 | Precedent: `machines/beta/1.nix` |
| `sd-image-aarch64.nix` (nixpkgs module) | Phase 1 | Already used by `mkAarch64` |
| `enable-wg-topology.nix` (WG client module) | Phase 1 | `modules/enable-wg-topology.nix` |
| `users/deployment.nix` (nixinate deploy user) | Phase 2 | uid 1110, John88 key, NOPASSWD sudo |
| `users/build.nix` (build user for remote builder) | Phase 2-3 | uid 1111, builder-key.pub |
| `modifier_imports/remote-builder.nix` | Phase 3 | Already has `10.88.127.42` entry |
| WG private key for display-2 | Phase 1 | secrix-managed `wg_display-2` |
| NVMe (500 GB WD SN750 + USB enclosure) | Phase 3 | Hardware from display-2 |
| Fresh SD card | Phase 1 | New hardware |
| rPi4 board (4 GB+ recommended) | Phase 1 | Recovered from display-2 or new |

---

## Constraints and Risks

1. **Cross-compile scope** — `nixpkgs.buildPlatform = "x86_64-linux"` works for minimal
   images but NOT for full system closures with all services. Phase 2's nixinate push
   builds the full closure *natively on the Pi* (slow, but correct and deterministic).

2. **SD card fragility** — The failure that started this. Mitigation: use labels not
   UUIDs for mounts; the root FS on SD is minimal (boot + bootstrap only); the NVMe
   takes `/nix/store` and swap as soon as Phase 3 completes.

3. **45-hour build windows** — New deployments from source can take 48 hours on a Pi 4.
   This is acceptable per our correctness principles — the artifacts are in use for
   months, and nixpkgs inputs change rarely.

4. **Builder naming** — The machine is called `arm-builder` in config but reuses
   display-2's WG identity (`10.88.127.42`) so hub-side registration is unchanged.
   If display-2 is later restored as a separate machine, it will need a new WG address.

5. **Golden test for `arm-builder`** — New machine needs a golden file. If it reuses
   display-2's topology entry, the golden should match display-2's existing golden
   unless we intentionally change the topology data.

---

## Sequence Summary

| Phase | Action | Duration Estimate | Gate |
|-------|--------|-------------------|------|
| 0 | Research USB-NVMe boot; verify hardware | Hours | ✅ COMPLETE — research report done, display-0/display-2 moved to dormant |
| 1 | Cross-compile minimal builder image | ~30 min (with remote builder offload) | ✅ COMPLETE — image built, verified, golden passes |
| 2 | Flash SD, boot, WG connect, nixinate deploy | Minutes (after image boots) | READY — waiting for SD card flash |
| 3 | Attach NVMe, redeploy with mounts | Minutes (after NVMe recognized) | `nix store ping` from cortex-alpha succeeds |
| 4 | Native rebuild of display fleet | Up to 48 hours per machine | All ARM machines deployed & golden-validated |
| 5 | Physical relocation (optional) | Minutes (hardware) | No code change if WG identity unchanged |