# ARM Build Limitations

> **Status (2026-07-01):** ⚠️ **ARM build capacity OFFLINE.** `display-2` (the only aarch64
> remote builder) failed due to a corrupted SD card caused by an incorrect mount entry.
> `display-1` and `print-controller` are architecturally insufficient to replace it.
> Recovery plan: [plans/arm-builder-bootstrap-2026-07-01.md](plans/arm-builder-bootstrap-2026-07-01.md).

## Device Roles

| Device | Board | Role | Notes |
|--------|-------|------|-------|
| display-0 | Pi 3 | Minimal display (status unverified) | `/home` on separate disk; may not be online — needs reachability check |
| display-1 | Pi 4 (low RAM) | Wall-mounted kitchen display | Fixed location, GUI autostart; scratch is zram + 1 GB `/swapfile`; insufficient for kernel builds |
| display-2 | Pi 4 | ~~Cyberdeck / ARM builder~~ **OFFLINE** | SD card failed (incorrect mount entry); NVMe (500GB WD SN750 via USB) intact but unreachable |
| print-controller | Pi 3 (1 GB cap) | Klipper print server | Headless; 1 GB RAM ceiling — architecturally incapable of kernel builds |

## Problem Statement

ARM-based NixOS configurations (aarch64-linux, armv7l-linux) cannot be built from the primary x86_64-linux build host. This affects 5 machines in the fleet.

## Affected Machines

| Machine | Architecture | Status |
|---------|-------------|--------|
| display-0 | aarch64-linux | Cannot build from x86_64 host |
| display-1 | aarch64-linux | Cannot build from x86_64 host |
| display-2 | aarch64-linux | Cannot build from x86_64 host |
| print-controller | aarch64-linux | Cannot build from x86_64 host |
| beta-one | armv7l-linux | Cannot build from x86_64 host (timeout) |

## Root Causes

### 1. Platform Mismatch

NixOS derivations are platform-specific. A `system.build.toplevel` for aarch64-linux cannot be evaluated or built on an x86_64-linux host without explicit cross-compilation support.

```
error: Cannot build '/nix/store/...-glibc-locales-2.42-61.drv'.
       Reason: platform mismatch
       Required system: 'aarch64-linux'
       Current system: 'x86_64-linux'
```

### 2. Nixpkgs Support for Older ARM Hardware

Nixpkgs has poor support for older ARM SoCs, particularly:

- **Raspberry Pi 2 (armv7l)**: Fundamentally broken upstream support
- **Raspberry Pi 3 (aarch64)**: Works but requires specific kernel/firmware packages
- Pre-"malware" (pre-Pi 4) devices have incomplete or unmaintained device tree support

### 3. Cross-Compilation Limitations

Cross-compilation from x86_64 to aarch64 is limited:

- Can produce a **minimal bootstrap image** (SD card image)
- Cannot cross-compile a **full system closure** with all services
- Many packages fail to cross-compile due to build-time dependency issues
- The bootstrap image is insufficient for deployment — it lacks the full system

## Current Workflow

The only reliable path to a working ARM system:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   x86_64 Host   │────▶│  Bootstrap SD   │────▶│  ARM Hardware   │
│  (cross-compile │     │     Image       │     │ (native build)  │
│   minimal img)  │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                      │
                                                      ▼
                                                ┌─────────────────┐
                                                │ nixos-rebuild   │
                                                │ (on device)     │
                                                │                 │
                                                │ OR              │
                                                │                 │
                                                │ Remote builder  │
                                                │ (SSH from host) │
                                                └─────────────────┘
```

### Step 1: Cross-Compile Bootstrap Image

```bash
# Build SD card image (this works for aarch64)
nix build .#nixosConfigurations.display-0.config.system.build.sdImage

# Write to SD card
dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress
```

### Step 2: Boot on Real Hardware

Insert SD card, boot the Pi. The minimal image provides:
- Basic networking (SSH access)
- Nix daemon
- Enough to receive a full system closure

### Step 3: Build Natively or Deploy via SSH

**Option A: Build on device (slow)**
```bash
# SSH into the Pi
ssh build@display-0

# Build and switch (very slow on Pi hardware)
sudo nixos-rebuild switch --flake github:DarthPJB/NixOS-Configuration#display-0
```

**Option B: Build on x86_64, deploy to Pi (requires remote builder)**
```bash
# From x86_64 host, if the Pi is registered as a remote builder
nix build .#nixosConfigurations.display-0.config.system.build.toplevel
# Then deploy the closure
```

## Failed Approaches

### Remote Builders (Previously Working — Now OFFLINE)

The flake configures remote builders at:
- `10.88.127.42` (display-2 — **OFFLINE since 2026-07-01**, SD card failure)
- `10.88.127.41` (display-1 — commented out, kitchen display, insufficient for builds)

> **⚠️ Stale registration:** `modifier_imports/remote-builder.nix` (lines 36–46) still
> registers `10.88.127.42` as an `aarch64-linux` builder with `big-parallel`. Dispatches to
> this address will hang/time out until the builder is restored. The new bootstrap plan
> intentionally resurrects this same WG address (reusing existing keys + cortex-alpha's
> known config) so no hub-side registration change is required once the builder is back up.

**Issues Found and Fixed (historical):**

1. **SSH known hosts missing IP addresses** — The `mkKnownHosts` function in `flake.nix` only generated hostname and domain entries, not IP addresses. Since nix-daemon connects via WireGuard IP, SSH host key verification always failed. Fixed in commit `db866ce` by reading IPs from `topology.nix`.

2. **`big-parallel` feature not advertised** — The RPi kernel build requires the `big-parallel` feature, but display-2's builder config had `supportedFeatures = [ ]` (commented out). Fixed in commit `03ba281` by adding `"big-parallel"` to the feature list.

**Current Remote Builder Configuration (`modifier_imports/remote-builder.nix`):**
```nix
{
  hostName = "10.88.127.42"; # Display-2
  protocol = "ssh-ng";
  sshUser = "build";
  sshKey = config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path;
  systems = [ "aarch64-linux" ];
  maxJobs = 3;
  speedFactor = 5;
  supportedFeatures = [ "big-parallel" ];
  mandatoryFeatures = [ ];
}
```

**SSH Access Model:**
- Port 22: `build` user only (WireGuard 10.88.127.0/24), for nix remote builder
- Port 1108: `John88`/`deploy` users, for administration
- `deploy` user has passwordless sudo for remote management

### QEMU User-Mode Emulation

In theory, `qemu-aarch64` user-mode emulation can run aarch64 binaries on x86_64. In practice:

- Extremely slow (10-50x slower than native)
- Many packages fail to build under emulation
- Not reliable for full system closures
- Useful only for testing individual packages, not entire systems

### Nix Distributed Build Protocol

Nix supports distributed builds via `nix.buildMachines` configuration. This requires:

1. An aarch64-linux machine accessible via SSH
2. The machine registered in `/etc/nix/machines` or `nix.buildMachines`
3. The machine must have the Nix daemon running

**This is the correct long-term solution** — but requires a dedicated ARM builder.

## Recommended Solutions

### Option 1: Dedicated ARM Builder (display-2) — OFFLINE, recovery in progress

**Status: ⚠️ OFFLINE since 2026-07-01.** SD card corrupted by an incorrect mount entry.
Recovery via [cross-compiled bootstrap plan](plans/arm-builder-bootstrap-2026-07-01.md).
The device's prior assets (NVMe, WG identity, builder config) are the basis for the restore.

Historically this device already had:
- Working NixOS aarch64 configuration
- WireGuard connectivity (10.88.127.42)
- SSH access (port 1108, user John88; port 22, user build)
- Remote builder connection verified (builds dispatch and complete)
- NVMe installed (500GB WD Black SN750 via USB 3.0)
- Swap active (233GB total — NVMe + swapfile)

**Hardware Status:**
| Component | Status |
|-----------|--------|
| NVMe | ✓ Installed, 500GB WD Black SN750 |
| `/dev/sda1` | ✓ ext4, 232.9GB (for `/nix/store`) |
| `/dev/sda2` | ✓ 232.9GB swap active |
| Total swap | 233GB |
| RAM | 3.7GB (2.5GB available) |

**Issues Resolved:**
1. **SSH known hosts** — `mkKnownHosts` in `flake.nix` was missing IP addresses from topology. Fixed in commit `db866ce`.
2. **Remote builder features** — `big-parallel` feature was commented out for display-2. Fixed in commit `03ba281`.

#### Deployment Plan

**Phase 1: NVMe Installation & Swap**

1. ~~Install NVMe physically~~ ✓
2. ~~Configure NVMe partition for swap (RAM overflow for builds)~~ ✓
3. ~~Rebuild display-1 using display-2 as remote builder~~ — In progress (RPi kernel building)
4. ~~Rebuild display-2 using display-2 as remote builder~~ — In progress (RPi kernel building)
5. Switch display-1 configuration and reboot (validate)
6. Switch display-2 configuration and reboot (validate)

**Phase 2: NVMe `/nix/store` Migration**

7. ~~Create partition on NVMe for `/nix/store`~~ ✓
8. ~~Copy `/nix/store` to NVMe partition~~ ✓ (13GB, 1880 items)
9. **IMPORTANT:** After Phase 1 builds are deployed, clone `/nix/store` again — the new system closure will have additional paths not in the original copy
10. Remount/kexec to use NVMe-backed `/nix/store`
11. Deploy display-2 with correct mount points (swap + `/nix`)
12. Final reboot and validation

> **⚠️ Critical:** The current `/nix/store` copy was made before the new system closures were built. After deploying display-1 and display-2, the store will contain new derivations (kernel, modules, etc.) that must be present on the NVMe before switching mount points. Running `sudo cp -a /nix/. /mnt/nix-nvme/` again after deployment will sync the delta.

**Expected Final State:**
- NVMe partition 1: swap (RAM overflow)
- NVMe partition 2: `/nix/store` (fast build storage)
- SD card: root filesystem
- Remote builder accepting aarch64 builds from all x86_64 hosts
# Headless builder config — remove GUI imports
imports = [
  ../../configuration.nix
  ../../modules/enable-wg-topology.nix
  # Remove: ../../environments/i3wm.nix
  # Remove: ../../environments/browsers.nix
];

# NVMe for build storage
fileSystems."/nix" = {
  device = "/dev/nvme0n1p1";  # TBD: confirm actual device path
  fsType = "ext4";
};

# Builder settings
nix.settings = {
  max-jobs = 4;
  cores = 4;
  system-features = [ "big-parallel" ];
};

# Keep SSH for management
services.openssh.enable = true;
```

**Registration on x86_64 host (cortex-alpha):**
```nix
nix.buildMachines = [{
  hostName = "10.88.127.42";
  system = "aarch64-linux";
  maxJobs = 4;
  speedFactor = 2;
  supportedFeatures = [ "big-parallel" ];
  mandatoryFeatures = [ ];
  sshUser = "John88";
  sshKey = "/root/.ssh/id_ed25519";
  protocol = "ssh-ng";
}];
nix.distributedBuilds = true;
```

**Pros:**
- No additional hardware cost
- Reuses existing device and configuration
- NVMe provides fast build storage
- WireGuard connectivity already configured

**Cons:**
- Single point of failure (one builder for all ARM machines)
- Pi 4 has limited RAM (4GB or 8GB depending on model)
- Repurposes cyberdeck from portable use to fixed builder role

### Option 2: Bootstrap + Native Build Workflow

**Status: Currently the only working approach**

Use cross-compiled bootstrap images, then build natively on the target hardware.

**Pros:**
- No additional hardware
- Works with existing fleet

**Cons:**
- Very slow (Pi 3 builds take hours)
- Pi 2 (armv7l) may not be viable at all
- Ties up the target device during builds

### Option 3: Cloud ARM Builder

**Status: Not explored**

Use a cloud-based ARM instance (AWS Graviton, Oracle Cloud free tier) as a remote builder.

**Pros:**
- No additional physical hardware
- Scales on demand
- Oracle Cloud offers free ARM instances

**Cons:**
- Ongoing cost (except Oracle free tier)
- Requires internet connectivity for builds
- Security considerations for build secrets

## Impact on Development

### Golden Tests

Golden tests for ARM machines work correctly — they evaluate the NixOS configuration and compare against golden files. The evaluation happens on x86_64 (Nix evaluation is platform-agnostic for most options), but the build requires the target platform.

### CI/CD

Any CI/CD pipeline must either:
1. Have access to ARM builders
2. Skip building ARM machines
3. Use cross-compilation for bootstrap images only

### Deployment

ARM machines cannot be deployed from the x86_64 host without:
1. A reachable ARM remote builder, OR
2. Building on the target device itself

## References

- NixOS Wiki: [Cross Compiling](https://nixos.wiki/wiki/Cross_Compiling)
- Nix Manual: [Distributed Builds](https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html)
- Nixpkgs: [Raspberry Pi Support](https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi)
