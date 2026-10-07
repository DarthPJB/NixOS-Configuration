# LINDA Windows Gaming VM — GPU Passthrough Stack

**Machine:** LINDA (AMD Threadripper workstation, `machines/LINDA/`)
**Role:** Windows 11 gaming VM host with GPU + USB controller passthrough
**Status:** Restoration in progress (2026-10-05) — see
`opencode/plans/windows-gpu-passthrough-PLAN.md` (living plan / LDR)
**Last updated:** 2026-10-05

---

## Purpose

LINDA hosts a Windows 11 gaming VM (`win-11-gaming-base`) with full GPU
passthrough (GTX 1050 pair), Looking Glass display, Scream audio, and a
virtiofs share. (USB controller passthrough was part of the original stack
but is retired — user ruling 2026-10-05.) The stack worked in
production until 2025-12 (GPU retired to host) / 2026-06 (VFIO stripped in a
cleanup). This document records the architecture, the prior-art inventory, and
the design decisions of the 2026-10 restoration so future development starts
from knowledge, not archaeology.

## Architecture (the three layers)

```
1. HOST LAYER — fully reproducible from this repo (Nix)
   LINDA machine config: hardware, NVIDIA host GPU (RTX 3060),
   libvirtd + OVMF + swtpm, VFIO binding (vfio-pci ids), br0 networking,
   Scream + Looking Glass plumbing, backup targets (genBackup)
                ↓
2. GUEST DEFINITION — fully reproducible from this repo (Nix / NixVirt)
   Domain win-11-gaming-base: q35 + OVMF + hidden-kvm + hostdevs + ivshmem
   + TPM-tis + virtiofs, declared declaratively (NixVirt) and archived as
   XML reference in machines/LINDA/windows-vm/
                ↓
3. GUEST CONTENTS — NOT reproducible (the manual layer)
   The Windows installation itself: install ISO onwards (drivers, Looking
   Glass host app, Scream sender, Steam). This is the ONLY layer that
   requires backup — see "Backup Strategy".
```

**Recreation doctrine (user ruling 2026-10-05):** "The machine is defined by
Nix, so we can recreate it anytime anywhere from windows install manually
onwards." `nixos-rebuild` is actuation, not a precious operation. Portability
caveat: hostdev PCI addresses (`0000:46:00.0`, `0000:4d:00.0/.1`) and
`vfio-pci ids=` are hardware-bound; PCI addresses are parameterized as module
options (current values = defaults) so "anywhere" = same hardware class
drop-in, or two option changes.

## Hardware Map (2026-10-05, verified live)

| PCI | Device | IOMMU group | Role |
|-----|--------|-------------|------|
| `0000:21:00.0/.1` | NVIDIA GA104 — **RTX 3060** + HD-audio (`10de:2487`, `10de:228b`) | 54 | HOST primary (3 monitors: HDMI-A-1 1080p portrait, HDMI-A-2 4K primary, DP-2 1080p portrait) |
| `0000:4d:00.0/.1` | NVIDIA GP107 — **GTX 1050** + HD-audio (`10de:1c81`, `10de:0fb9`) | 41 | PASSTHROUGH → VM |
| `0000:46:00.0` | ASMedia ASM2142 USB 3.1 (`1b21:2142`) | 37 | **HOST** — USB passthrough dropped (user ruling 2026-10-05); carries the HID/webcam/audio set |
| `/dev/zd0` | ZFS zvol `speed-storage/steam-library-win` (788 GB) | — | VM game library disk (virtio) |

VFIO binding: `boot.extraModprobeConfig: options vfio-pci ids=10de:1c81,10de:0fb9`
(D-1 amended: GPU pair only — no USB) plus initrd vfio modules (early bind;
nvidia must not claim the 1050 — it never will, see quirks).

## The Domain — `win-11-gaming-base` (prior working stack)

- **UUID:** `d9377588-28e4-4257-905a-95012babe705`
- **Firmware:** UEFI via the **NixOS 26.05 default loader** — QEMU-bundled
  edk2 (`/run/libvirt/nix-ovmf/edk2-x86_64-code.fd`, firmware autoselect
  `efi`). The legacy `qemu.ovmf.enable`/`OVMFFull` block is NOT used (user
  correction 2026-10-05). NVRAM `win-11-base_VARS.fd` (540,672 B) is
  size-compatible with the modern `edk2-i386-vars.fd` template — no
  migration needed.
- **CPU/RAM:** 20 vCPU host-passthrough, 32 GB memfd/shared,
  `<kvm hidden='on'/>` + `hypervisor` feature disabled (NVIDIA Code-43
  mitigation) — known-good, leave as-is (user ruling)
- **Disks:** `win11-base-gaming.qcow2` (SATA, standalone qcow2, 100 GiB
  virtual / 72.6 GiB used — NO backing chain) + `/dev/zd0` (virtio, steam
  library zvol)
- **TPM:** tpm-tis v2.0 via swtpm (state at
  `/var/lib/libvirt/swtpm/d9377588-…/tpm2/tpm2-00.permall` — **preserve;
  BitLocker continuity**)
- **Display:** Looking Glass — `<shmem name='looking-glass' ivshmem-plain
  128M>` maps `/dev/shm/looking-glass` (tmpfile, John88:qemu-libvirtd);
  host client `looking-glass-client` B7; SPICE graphics on localhost as fallback
- **Audio:** Scream unicast → host `br0:4010` (service `scream-ivshmem`;
  `<shmem name='scream' ivshmem-plain 2M>` in XML is vestigial — host
  switched to unicast 2025-07-21)
- **Network:** `<interface type='bridge'><source bridge='br0'/>` virtio —
  br0 is a HOST bridge over `enp69s0f0` (declared in NixOS networking)
- **Share:** virtiofs `/bulk-storage/` → guest `88_FS`

Full-fidelity XML archived in `machines/LINDA/windows-vm/`:
- `win-11-gaming-base.xml` — the last working config (2025-10-16, post GPU-swap)
- `win-11-gaming-base-nvidia.xml` — the pre-swap era (passed RTX 3060 `21:00.x`);
  identical to `win-11-gaming-oldconfig.xml`

## Design Decisions (2026-10-05 restoration)

1. **Declarative libvirt via NixVirt (not the platonic VMs toolkit).**
   `platonic.systems/vms/` wraps NixVirt (`AshleyYakeley/NixVirt`) with a
   multi-tenant control layer — but its deployment machinery is host-bound to
   hyperhyper, its network model is a 100.128/16 routed tenant fabric, and its
   domain templates cannot reproduce this full-fidelity domain. We import
   `nixvirt.nixosModules.default` directly and declare the domain/networks in
   this repo. Acceptance test: generated XML diff-clean against the archived
   XML. The toolkit remains *pattern prior art* for the future local-subnet-
   routing work (its `forward.mode = "route"` + hypervisor-NAT design solves
   the LIBVIRT_FWI breakage that NAT suffers under subnet routing).
2. **Networking = NixOS-defined br0** (user ruling). Bridge over `enp69s0f0`,
   DHCP + firewall keys move to `br0`. macvtap ruled out (guest→host is broken
   on macvtap by design — kills Scream). Reboot-gated; deploy with the fleet
   standard `nix run .#LINDA -- switch`, then reboot — the change takes
   effect at that same reboot.
3. **Backup before mutation** (user requirement). See Backup Strategy.

## Backup Strategy

**v1 (Phase 1, immediate):** rclone two-hop through the fleet pipeline —
LINDA → `minio:linda-win11-vm` (image + `/var/lib/libvirt/qemu/` XMLs +
NVRAM + swtpm state) → local-nas replicates weekly (Sun 03:00) to
`b2:minio-backup-bargman/linda-win11-vm`. Scope excludes `win11-base-Parent.qcow2`
(legacy) and the steam zvol (re-downloadable game data). Weekly B2 cadence is
sufficient (user ruling). Permission gap: rclone runs as John88 but the estate
is root-600 — ACL grant or per-target user required.

**Long-term (Phase 6):** ZFS snapshot streams to B2. The estate lives on the
isolated dataset `speed-storage/var-lib-libvirt`; `zfs send | zstd | rclone
rcat b2:…/streams/` (restore: `rclone cat | zstd -d | zfs receive`). rclone has
no native ZFS support (transport only). Copy the platonic pipeline shape
(`infrastructure-2/services/backup-pipeline.nix`: snapshot → realize
(`zfs send | gzip`) → upload) with the incremental `zfs send -I` upgrade if
weekly full sends prove heavy. An isolated *dataset* suffices; a separate pool
adds only I/O isolation.

## Known Quirks (verified live, 2026-10-05)

1. **Host nvidia rejects the 1050:** dmesg `NVRM: ignoring the legacy GPU
   0000:4d:00.0` (probe error -1). The card is structurally unbound on the
   host — vfio-pci has zero race for it. **Guest caveat:** the Windows driver
   must still support GP107 — use a known-good branch (the Oct-2025 era
   driver worked).
2. **Boot-time vfio binding is mandatory:** the 1050's HD-audio function
   (`4d:00.1`) cannot be late-bound — sysfs writes hang (its `reset_method`
   is `bus`-only; power is interlocked with the GPU via vga_switcheroo).
   The prior art's `vfio-pci ids=` + initrd modules claim both functions at
   boot before `snd_hda_intel`/vga_switcheroo engage. Live test: `4d:00.0`
   bound cleanly (`/dev/vfio/41` created); `4d:00.1` hung — do not retry the
   late bind.
3. **ASMedia USB (`46:00.0`) stays on the host (D-1 amended, 2026-10-05):**
   USB passthrough is no longer required. Buses 5+6 behind the controller
   (HID keyboard + mouse, UVC webcam, USB audio) remain host devices — the
   input-set risk is retired. Guest USB rides the emulated qemu-xhci + SPICE
   `redirdev` channels already present in the domain XML.

## Current Work

Living plan with full findings register, evidence appendix, and phased
execution: **`opencode/plans/windows-gpu-passthrough-PLAN.md`** (v2.1,
2026-10-05). Phase 0 (prior-art recovery) complete; Phase 1 (B2 backup) next;
Phases 3–5 (reboot, physical verification, Windows bring-up) are user-manual.

## Prior-Art Git Archaeology (key commits)

| Commit | Date | Content |
|--------|------|---------|
| `b42b338` | 2023-04 | First LINDA IOMMU/passthrough (RTX 3060 era) |
| `ca99d24` | 2023-04 | OVMF, swtpm, Looking Glass, `/dev/shm/looking-glass` |
| `a30466f` | 2025-10 | "swap GPUs" — vfio set → GTX 1050 + ASMedia USB |
| `4d20770` | 2025-12 | "restore all GPU power to host" — VFIO disabled |
| `3762764` | 2026-06 | VFIO modules removed ("verified 0 devices bound") |

Recover the pre-removal recipe: `git show 3762764^:machines/LINDA/default.nix`;
the fullest historical stack: `git show 709c553^:machines/LINDACORE.nix.save`.
Known bugs NOT to re-introduce: the `0000:21:00:.0` typo in
`preDeviceCommands`; the broken `echo "vfio-pci > /sys/..."` redirect (fixed in
`2e95c4a`).

## Future Work (queued)

1. **Local subnet routing** (user: "ideally yes") — platonic routed-network
   pattern: libvirt `forward.mode = "route"` + `networking.nat`/forwarding on
   LINDA, or routing between br0 subnet and wireg0/LAN planes.
2. **ZFS-stream B2 backup** (replaces file-copy once VM is steady-state).
3. Optional: `kvmfr` device instead of the `/dev/shm/looking-glass` file;
   explicit hugetlb hugepages (NOT transparent THP — VMware module sets
   `transparent_hugepage=never`).

## Operations Quick-Reference

```bash
# Observe (read-only)
ssh -p 1108 inspect@LINDA 'lspci -nnk; lsmod | grep vfio'
ssh -p 1108 deploy@LINDA 'sudo virsh -c qemu:///system list --all'

# Domain control (after restoration)
ssh -p 1108 deploy@LINDA 'sudo virsh -c qemu:///system start win-11-gaming-base'
ssh -p 1108 deploy@LINDA 'sudo virsh -c qemu:///system shutdown win-11-gaming-base'

# Looking Glass / Scream (host, user session)
looking-glass-client        # connects to /dev/shm/looking-glass
systemctl --user status scream-ivshmem

# Golden validation before any deploy
nix run .#validate-goldens -- LINDA
```
