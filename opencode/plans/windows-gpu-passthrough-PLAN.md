# Windows GPU Passthrough Restoration — Living Plan (LDR)

**Machine:** LINDA (AMD Threadripper workstation) — NOT gaming-host-1
**Goal:** Actively run the Windows gaming VM with GPU passthrough using the
prior working stack (GTX 1050 + ASMedia USB 3.1 + Looking Glass + Scream),
fully declarative (NixOS networking + NixVirt libvirt config), with the VM
estate backed up to Backblaze B2 before any mutation.
**Version:** 2.2 — 2026-10-05
**Status:** PHASE 0 COMPLETE. Live bind test done (R23/R24). OVMF corrected to
the 26.05 default (R21). Interim networking under discussion (D-10). Phase 1
(B2 backup) still first execution step.

---

## User Rulings (2026-10-05)

- **D-2 ruling:** "We want nixos-configuration defined networking, ideally for
  our system libvirt configuration also; we may later even expand to local
  subnet routing." → Fully declarative: host networking in Nix config, libvirt
  domains/networks declared in Nix config too. Future phase for local subnet
  routing.
- **D-4 ruling:** "Leave as is; the prior image and configuration is known
  good." → 32 GB / 20 vCPU domain untouched.
- **D-5 ruling:** "See D2." → Golden regeneration authorized as part of the
  declarative work.
- **New requirement 1:** Ensure the current VM image and XML configuration are
  backed up to Backblaze (B2) — as part of this plan, before change.
- **New requirement 2:** Libvirt/VM configuration must be declarative —
  possibly leveraging the platonic.systems VMs toolkit.
- **Round-2 rulings (later 2026-10-05):**
  - Phase 1: local-nas replication; **weekly B2 replication is sufficient**
    (matches the existing Sunday 03:00 pattern).
  - Doctrine clarification: "The machine is defined by Nix, so we can recreate
    it anytime anywhere from windows install manually onwards." → the repo IS
    LINDA; nixos-rebuild is only actuation, not a precious operation. The
    guest's *contents* (manual Windows install onward) are the only
    non-reproducible layer — hence the image backup. See "Recreation Model".
  - Phases 3–5: confirmed — **user-manual** actions (reboot, physical
    verification, Windows/guest bring-up).
  - Phase 6: local subnet routing — "ideally yes" (queued).
  - D-8: scope = per Phase 1 table (confirmed).
  - D-9: long-term = **ZFS snapshot streams to B2**; question of isolated
    pool viability + rclone support answered below (R20/F18/F19).

---

## Recreation Model (user doctrine, 2026-10-05)

The machine is defined by Nix. `nixos-rebuild` is merely actuation — the repo
is LINDA. Recreation path from nothing:

1. **Host layer (fully reproducible):** flake evaluation builds LINDA anywhere —
   hardware config, libvirtd + OVMF + swtpm, VFIO binding, br0 networking,
   Scream/Looking Glass plumbing, and the NixVirt-declared domain/networks all
   derive from this repo. A bare-metal box of the same class + `nixos-rebuild`
   = the machine.
2. **Guest definition (fully reproducible):** the Windows domain XML is
   declared in Nix (Phase 2) and travels with the repo.
3. **Guest contents (NOT reproducible — the manual layer):** the Windows
   installation itself is manual, from a Windows install ISO onwards (drivers,
   Looking Glass host, Scream sender, Steam). This layer is what the
   `win11-base-gaming.qcow2` backup preserves.
4. **Portability caveat (recorded honestly):** the domain's hostdev PCI
   addresses (`0000:46:00.0`, `0000:4d:00.0/.1`) and `vfio-pci ids=` are
   hardware-bound. `ids=` (vendor:device) is portable across identical
   hardware; absolute PCI addresses are not. Phase 2 therefore parameterizes
   hostdev addresses as module options (current values = defaults) so
   "recreate anywhere" means: same hardware class → drop-in; other hardware →
   adjust two options.

---

## Register — Resolved Facts (from live observation, 2026-10-05)

- **R1.** Host kernel 6.18.46, NixOS 26.05. IOMMU is ON (`amd_iommu=on` on
  `/proc/cmdline`). No VFIO modules loaded (removed 2026-06-04, commit `3762764`).
- **R2.** IOMMU groups are clean and ideal:
  - group 54: `0000:21:00.0` + `.1` — RTX 3060 (host primary, nvidia, 3 monitors)
  - group 41: `0000:4d:00.0` + `.1` — **GTX 1050 + HD-audio** (currently NO driver bound)
  - group 37: `0000:46:00.0` — **ASMedia ASM2142 USB 3.1** (currently xhci_hcd)
  - group 38: `0000:47:00.0` — ASM1061 SATA (spare; optional whole-controller passthrough)
- **R3.** The Windows VM estate survived on the ZFS dataset
  `speed-storage/var-lib-libvirt` (mounted at `/var/lib/libvirt`):
  - `images/win11-base-gaming.qcow2` — 107 GB, mtime 2025-10-16 (gaming VM disk)
  - `images/win11-base-Parent.qcow2` — 58 GB, mtime 2023-05-08
  - `qemu/win-11-gaming-base.xml` — 10,186 B, mtime **2025-10-16** (LAST WORKING config)
  - `qemu/win-11-gaming-base-nvidia.xml` — 10,186 B, mtime 2025-10-03 (GPU-swap era)
  - `qemu/win-11-gaming-oldconfig.xml` — 10,186 B, mtime 2025-09-18
  - `nvram/win-11-base_VARS.fd` — mtime 2025-10-16 (matches last working config)
  - `nvram/win-11-gaming_VARS.fd`, `win-11-unity_VARS.fd` (older eras)
  - legacy `qemu/domain-15-win-11-unity/` state dir (2023-era "unity" VM)
- **R4.** Looking Glass plumbing is alive: `/dev/shm/looking-glass` tmpfile
  exists (John88:qemu-libvirtd), `looking-glass-client` B7 + `scream` 4.0 +
  `virtiofsd` + `virt-manager` in LINDA's systemPackages (golden-verified).
- **R5.** `virtualisation-libvirtd.nix` is active on LINDA: libvirtd + qemu +
  `swtpm.enable = true` (Win11 TPM requirement covered). OVMF block is
  **commented out** and must be restored.
- **R6.** LINDA RAM: 125 GB total, ~107 GB used at observation time (AI
  workloads resident). Per D-4 the domain keeps 32 GB as-is (known good).
- **R7.** `scream-ivshmem` user service is loaded but **dead**: it binds `br0`,
  which no longer exists (bridge→bond→plain interfaces history).

### Phase 0 results (privileged reads, 2026-10-05, `deploy@LINDA -p 1108`)

- **R8.** The domain **`win-11-gaming-base` is still DEFINED in libvirt**
  (shut off). UUID `d9377588-28e4-4257-905a-95012babe705`. Also defined:
  linux2024, ubuntu-gpu, ubuntu20.04-desktop/terminal (irrelevant, shut off).
- **R9.** The live domain XML (dumpxml == `win-11-gaming-base.xml`) passes
  exactly: `0000:46:00.0` (ASMedia USB), `0000:4d:00.0` (GTX 1050),
  `0000:4d:00.1` (1050 audio) — managed='yes' hostdevs. Confirms the prior
  working set matches current hardware.
- **R10.** Domain details (the prior working stack in full):
  q35 (`pc-q35-7.1`), OVMF at `/run/libvirt/nix-ovmf/OVMF_CODE.fd` +
  NVRAM `win-11-base_VARS.fd`, 32 GB RAM (memfd/shared), 20 vCPU
  host-passthrough with `<kvm hidden='on'/>` + `hypervisor` feature disabled
  (NVIDIA Code-43 mitigation), TPM tpm-tis v2.0 (swtpm), disk
  `win11-base-gaming.qcow2` (SATA) + **`/dev/zd0` virtio block** =
  zvol `speed-storage/steam-library-win` (788 GB used — game library),
  virtiofs share `/bulk-storage/` → `88_FS`, `<shmem name='looking-glass'>`
  ivshmem-plain 128 MB + `<shmem name='scream'>` ivshmem-plain 2 MB,
  network `<interface type='bridge'><source bridge='br0'/>` virtio,
  SPICE graphics localhost, watchdog itco.
- **R11.** **OVMF runtime links are MISSING** today: `/run/libvirt/nix-ovmf/`
  contains only qemu's bundled edk2 firmware — no `OVMF_CODE.fd`/`OVMF_VARS.fd`
  templates (those appear only when `qemu.ovmf.enable = true`). The domain
  CANNOT boot until OVMF is restored in `virtualisation-libvirtd.nix`.
- **R12.** Disk estate is healthy: `win11-base-gaming.qcow2` is a **standalone
  qcow2** (100 GiB virtual / 72.6 GiB used — NO backing chain; file length
  99.8 GiB), `win11-base-Parent.qcow2` also standalone (legacy). swtpm state
  `tpm2-00.permall` mtime **2025-10-16** for the domain UUID — TPM/BitLocker
  continuity preserved.
- **R13.** Live network: `enp69s0f0` UP with `10.88.128.88/24`; `br0` does not
  exist. Config declares `enp69s0f0.useDHCP = true` (commented-out
  `bridges."br0"` block sits ready in `machines/LINDA/default.nix`). Firewall
  rules for 4010/27015/Sunshine etc. are keyed to `enp69s0f0`.
- **R14.** XML archaeology: `win-11-gaming-base-nvidia.xml` ==
  `win-11-gaming-oldconfig.xml` (identical sha256) — that era passed the
  **RTX 3060** (`21:00.0/.1`). The 2025-10-16 `win-11-gaming-base.xml` is the
  post-swap config passing the 1050 set. Both archived in-repo.

### Toolkit + backup architecture findings (2026-10-05)

- **R15.** The platonic VMs toolkit lives at
  `/speed-storage/repo/platonic.systems/vms/` (lowercase `vms`, own git repo).
  It wraps **NixVirt** (`github:AshleyYakeley/NixVirt`) via
  `modules/platonic-libvirt.nix` (`virtualisation.platonic-vms` options) and
  imports `nixvirt.nixosModules.default`. Capabilities: declarative domains
  (`virtualisation.libvirt.connections."qemu:///system".domains` with
  `domain.writeXML`), declarative networks (`network.writeXML`), storage
  pools, qcow2 image-building services, and SSH power-control users
  (`ssh vm.<name>.poweron@hyperhyper`). VM types: `nixos | linux | windows`
  (windows template exists with `nvram_path` support).
- **R16.** The toolkit is **host-bound to hyperhyper**: its routed network is
  `virbr0` on `100.128.0.0/16` with Tailscale subnet routing in mind
  (`forward.mode = "route"` — their comment: NAT's LIBVIRT_FWI breaks subnet
  routing; route mode + hypervisor-level NAT is the pattern), deployment is
  PR-based onto that host, and IP/MAC allocation is driven by tenant VM IDs.
- **R17.** The B2 pipeline already exists fleet-wide:
  - Machines → rclone (`secrets/rclone-config-file`) → `minio:<bucket>` on local-nas
  - local-nas → rclone (`secrets/rclone-b2-config-file`, user `minio`) →
    `b2:minio-backup-bargman/<bucket>`, Sundays 03:00, bwlimit 5M, B2-tuned
    flags (`--b2-chunk-size 64M` etc.) — see `topology/local-nas.json`
    (`b2-obsidian`, `b2-home`, `b2-bargman-tech`, `b2-minecraft`, `b2-fs-v3-88`,
    `b2-downloads`).
  - `secrets/b2_master_sync_token` held in reserve (user decision 2026-10-05).
- **R18.** LINDA backup targets today (`topology/LINDA.json` → genBackup):
  `obsidian-v3` (bisync 60s), `88-FS-V3` (copy q2h, 10M), `bargman-tech`
  (copy hourly, 10M) — all to `minio:`. rclone services run as **John88**.
- **R19.** The platonic ZFS backup pipeline exists at
  `platonic.systems/infrastructure-2/services/backup-pipeline.nix` (used by
  acropolis/tumulus/springboard): `zfs-snapshot-daily` → `realize-snapshot`
  (`zfs send <latest daily snapshot> | gzip > /tmp/snbk/<host>.gz`) →
  `s3backup` (upload to S3 bucket) → optional `enableRclone` (rclone to B2).
  Pattern shape: **full** `zfs send` per snapshot (stateless one-file restore),
  gzip, oneshot systemd chain. Not incremental (`-I`) today.
- **R20.** rclone has **no native ZFS awareness** (no send/receive/snapshot
  support) — it is transport only. The standard construction is
  `zfs send [-I base snap] | zstd | rclone rcat b2:bucket/stream.zfs.zst`
  (restore: `rclone cat | zstd -d | zfs receive`), with rclone's
  `--b2-chunk-size` handling large objects.

### Round-3 findings (live, 2026-10-05 evening, `deploy@LINDA`)

- **R21.** **OVMF legacy confirmed (user correction).** As of NixOS 26.05 the
  `qemu.ovmf.enable` / `OVMFFull` block is legacy. Verified live:
  `virsh domcapabilities` reports the default loader
  `/run/libvirt/nix-ovmf/edk2-x86_64-code.fd` with firmware autoselect
  (`<enum name='firmware'><value>efi</value></enum>`); QEMU 10.2.4 ships
  firmware descriptors (`share/qemu/firmware/60-edk2-x86_64.json`). The
  descriptor's nvram-template is `edk2-i386-vars.fd` — **540,672 B, exactly
  matching the existing `win-11-base_VARS.fd`** → the domain moves to the
  modern default loader with **zero NVRAM migration**.
- **R22.** **USB topology behind ASMedia `46:00.0` (buses 5+6):** bus 5
  carries HID keyboard + HID mouse, a UVC webcam (+ its audio), a USB audio
  device, and a Billboard device — the deliberate "VM peripheral set".
  Bus 7 (AMD controller) carries a separate HID pair + USB audio (likely the
  host input set). Passing `46:00.0` detaches the bus-5 set from the host —
  intended by design (prior art), but the physical arrangement (host input on
  the AMD controller) must be confirmed before the VFIO reboot.
- **R23.** **`NVRM: ignoring the legacy GPU 0000:4d:00.0`** (dmesg) — the host
  NVIDIA driver rejects the GTX 1050 as a legacy GPU (probe error -1). The
  1050 is *structurally* guaranteed unbound on the host (not luck); zero
  race for vfio-pci. Guest-side: the Windows driver installed in Phase 5 must
  still support GP107 — verify against the NVIDIA support matrix / use the
  last-known-good guest driver from the Oct-2025 era.
- **R24.** **Live bind test (user-directed):** IDs double-checked against
  live lspci — exact match (`10de:1c81`, `10de:0fb9`, `1b21:2142`).
  `0000:4d:00.0` **bound to vfio-pci successfully** (`Kernel driver in use:
  vfio-pci`, `/dev/vfio/41` group device created). `0000:4d:00.1` late-bind
  **hangs**: sysfs writes to it block (power-control write never landed,
  bind never completes) — its `reset_method` is `bus`-only and its power is
  interlocked with the GPU via vga_switcheroo ("D0 power state depends on
  0000:4d:00.0"). This demonstrates precisely why the prior art claims devices
  **at boot via `vfio-pci ids=`** (before snd_hda_intel/vga_switcheroo take
  hold): boot-time claim is the deterministic path. 46:00.0 was NOT touched
  (R22 — input devices aboard). 4d:00.0 remains vfio-bound (inert, desired
  end-state; `driver_override` is not persistent across reboot).

## Register — Findings (F*)

- **F1.** No Windows domain XML ever lived in the repo — the working stack was
  virt-manager-driven, state on the ZFS dataset. The XMLs on disk are the
  authoritative prior art and are now recovered into the repo (root-600;
  recovered via `deploy` channel in Phase 0).
- **F2.** The last working passthrough device set (commit `a30466f`, 2025-10-03
  "swap GPUs", preserved in the Oct-16 XML era):
  `vfio-pci ids=10de:1c81,10de:0fb9,1b21:2142` at
  `0000:4d:00.0 0000:4d:00.1 0000:46:00.0`. RTX 3060 (`21:00.x`) stayed host-side.
- **F3.** Prior art bugs to NOT re-introduce: the `0000:21:00:.0` typo in
  `preDeviceCommands`; the broken `echo "vfio-pci > /sys/..."` redirect (fixed
  in `2e95c4a` as `echo "vfio-pci" > /sys/...`).
- **F4.** Scream's `br0` reference becomes valid again once br0 returns
  (D-2 ruling = declarative br0 restoration).
- **F5.** The 2026-06-04 VFIO removal (`3762764`) was clean ("verified 0 devices
  bound") — restoring is a pure re-add, no conflicting state expected. The
  historical recipe is recoverable via `git show 3762764^:machines/LINDA/default.nix`
  and `git show 709c553^:machines/LINDACORE.nix.save` (fullest state).
- **F6.** GTX 1050 currently has **no kernel driver bound** (nvidia is bound
  only to `21:00.0`) — the cleanest possible pre-state for vfio-pci binding.
- **F7.** Domain XMLs and `win11-base-gaming.qcow2` are root-600; the `inspect`
  account (observation channel) cannot read them. `deploy` has passwordless sudo.
- **F8.** `modifier_imports/virtualisation-vmware.nix` is also active on LINDA
  (VMware Workstation vGPU) and sets `transparent_hugepage=never`. Any
  hugepages plan for the Windows VM must use explicit hugetlb reservation, not
  THP.
- **F9.** The domain is defined and complete — restoration is host-side only
  (VFIO + OVMF + br0). No domain surgery required for the baseline path.
- **F10.** macvtap/direct attachment is ruled out for D-2: guest→host traffic
  on macvtap is broken by design, which would kill Scream unicast audio
  (guest→host). The bridge model is required by the prior working stack.
- **F11.** Restoring `br0` moves the host's LAN identity (IP/firewall) from
  `enp69s0f0` to `br0`. This must go in via `nixos-rebuild boot` + reboot
  (same reboot as VFIO), NEVER `switch` — a live network move would sever the
  deployment session mid-change.
- **F12.** The guest's Scream sender mode is in-guest state we cannot read;
  host-side Oct-2025 reality was unicast `-i br0 -p 4010` (tmpfile
  `/dev/shm/scream` was removed 2025-07-21). The `<shmem name='scream'>`
  device in the XML is therefore vestigial as a receiver path — keep it
  (harmless) but expect unicast.
- **F13.** **Toolkit verdict:** the platonic wrapper cannot host LINDA's VM
  (its deployment machinery targets hyperhyper; its network model is the
  100.128/16 routed tenant fabric; its domain templates would not reproduce
  our full-fidelity domain). The correct move is **NixVirt directly** in
  NixOS-Configuration — the same engine the toolkit wraps — declaring the
  domain, networks, and pools in this repo (the fleet's source of truth).
  The toolkit stays as *pattern prior art* for the future local-subnet-routing
  phase (R16 route-mode + hypervisor NAT design).
- **F14.** Declarative-domain acceptance test: the NixVirt-generated domain
  XML must diff-clean against
  `machines/LINDA/windows-vm/win-11-gaming-base.xml` (modulo libvirt's
  canonical formatting). Full-fidelity path: declare the domain with the exact
  archived XML text (`pkgs.writeText`) via NixVirt's `definition`, not a
  hand-rolled attrset — zero drift risk.
- **F15.** Backup economics: rclone copies whole files; `win11-base-gaming.qcow2`
  file length is 99.8 GiB, so the initial B2 upload is ~100 GiB, and any guest
  write (mtime change) triggers a full weekly re-upload at the 5M bwlimit
  (~5.7 h). Acceptable v1; upgrade path is ZFS snapshot + `zfs send`
  incremental streams via `rclone rcat` (the estate is on ZFS). Flagged D-9.
- **F16.** rclone on LINDA runs as John88 but the VM image/XML are root-600 —
  the backup target needs either a per-target `user` extension in
  `lib/rclone-target.nix`/`genBackup.nix`, or tmpfiles/ACL grants for John88
  on the scoped paths. Implementation detail of Phase 1.
- **F17.** Backup must land BEFORE any mutation (VFIO/NixVirt changes) — the
  known-good state is currently unprotected offsite.
- **F18.** **Isolated pool verdict (D-9):** viable and clean, but an isolated
  *dataset* already provides snapshot scoping — `speed-storage/var-lib-libvirt`
  IS such a dataset. `zfs send` of that dataset captures exactly the VM estate
  (image + XML + nvram + swtpm), sparse-aware (~72.6 GiB logical, not the
  99.8 GiB file length). A dedicated pool adds only I/O isolation and
  pool-level property control (compression/dedup) — a hardware/layout
  decision, not a backup-architecture requirement.
- **F19.** **Long-term backup shape (D-9):** adopt the platonic pipeline shape
  (R19: snapshot → realize → upload) with one upgrade over it — incremental
  `zfs send -I` chains instead of weekly full sends. Trade-off: full send =
  trivial restore (one object) but ~50–60 GiB/week gzip'd; incremental chain =
  small weekly deltas but needs a manifest + retention of the base. Weekly B2
  cadence is confirmed sufficient (user ruling); if full-send weekly at the
  Sunday window is acceptable, the platonic pattern verbatim is the simplest
  correct answer. Hand-rolled chain management or `zfsbackup-go` (purpose-built
  full+incremental streams to S3/B2 with manifests) if incrementals are wanted.
- **F20.** **The OVMF fix belongs in the domain definition, not the module.**
  With the 26.05 default loader (R21), the declarative domain simply uses
  firmware autoselect (`firmware='efi'`) or the explicit
  `edk2-x86_64-code.fd` loader path — the legacy `qemu.ovmf.enable` block
  stays retired. The existing NVRAM file needs no migration (size-verified).
- **F21.** **Interim networking (user hesitant re br0).** The VM can run on
  libvirt's existing `default` NAT network (virbr0) with zero host network
  changes — no LAN identity move, no networking risk in the VFIO reboot.
  Trade-off: no LAN IP for the guest (no inbound LAN-to-VM, e.g.
  Moonlight/Sunshine *from* the guest); guest outbound is full (Steam,
  matchmaking via NAT); Scream moves to virbr0/192.168.122.1 (one-line
  service change); guest→host works over the gateway. macvtap stays ruled
  out (F10) unless audio moves to ivshmem. br0 remains the D-2 endgame and
  can land later in its own deliberate window, alongside the subnet-routing
  phase.

## Register — Decisions

- **D-1. Passthrough device set. — RESOLVED** (user directive "prior working
  stack" + R9): GTX 1050 (`10de:1c81` + `10de:0fb9`) + ASMedia USB 3.1
  (`1b21:2142`) at `0000:4d:00.0/.1` + `0000:46:00.0`. RTX 3060 stays host.
- **D-2. VM network model. — ENDGAME per user ruling (2026-10-05):** declarative
  NixOS-defined networking — `br0` bridge over `enp69s0f0` in
  `machines/LINDA/default.nix`, DHCP + firewall keys on `br0`, domain NIC
  unchanged. Libvirt networks declared (NixVirt). Local subnet routing = later
  phase (R16 pattern). **Interim (user hesitant re the network move):** see
  D-10 — the initial re-activation may run the VM on libvirt `default` NAT
  with zero host network changes; br0 then lands in its own window.
- **D-10. Interim networking for initial re-activation. — OPEN (user asked to
  discuss).** Options: (a) **libvirt `default` NAT (virbr0)** — recommended:
  zero host risk, no reboot-network change, Scream rebinds to virbr0/192.168.122.1;
  guest loses LAN presence until br0. (b) macvtap — LAN IP without bridge,
  but guest→host broken (Scream dies unless audio moves to ivshmem — the XML's
  `scream` shmem device would have to be revived). (c) br0 now — endgame
  fidelity, but the identity move the user is hesitant about.
  Recommendation: (a) now, (c) in its own deliberate window with the
  subnet-routing work.
- **D-3. Audio path. — RESOLVED** (prior art, F12): Scream unicast on br0:4010.
- **D-4. VM RAM budget. — RESOLVED by user ruling:** leave as-is (32 GB known
  good; ballooning already in XML).
- **D-5. Golden regeneration. — AUTHORIZED by user ruling** ("see D2") as part
  of the declarative work.
- **D-6. Domain XML custody. — DONE (Phase 0)** and superseded by D-7: XMLs
  archived in-repo become the *template* for the declarative NixVirt definition.
- **D-7. Declarative toolkit. — RESOLVED by architecture analysis (F13):**
  NixVirt direct in NixOS-Configuration (`nixvirt.nixosModules.default` +
  `domain.writeXML`/`network.writeXML`); platonic wrapper NOT imported (wrong
  host, multi-tenant machinery); toolkit consulted for the future
  subnet-routing phase.
- **D-8. Backup scope. — RESOLVED** ("see phase 1"): `win11-base-gaming.qcow2`
  + `/var/lib/libvirt/qemu/` (XMLs) + `nvram/win-11-base_VARS.fd` + swtpm
  state for domain UUID → `minio:linda-win11-vm` → `b2:…/linda-win11-vm`
  weekly. Excluded: `win11-base-Parent.qcow2` (legacy), `steam-library-win`
  zvol (re-downloadable game data).
- **D-9. Backup transport long-term. — RESOLVED with path:** v1 = Phase 1
  rclone file-copy (immediate protection). Long-term = ZFS snapshot streams to
  B2 per F18/F19: dataset-scoped `zfs send | zstd | rclone rcat` to
  `b2:minio-backup-bargman/linda-win11-vm-streams/`, weekly, adopting the
  platonic pipeline shape (R19); incremental `-I` chains optional if weekly
  full sends prove too heavy. Isolated pool NOT required (isolated dataset
  suffices); revisit if I/O isolation is wanted.

## Phased Plan (execution order; each phase gates the next)

### Phase 0 — Recover prior-art artifacts — COMPLETE (2026-10-05)
1. ~~Copy domain XMLs~~ DONE — both generations archived in
   `machines/LINDA/windows-vm/` (sha256 match host originals: base
   `a6ad7d4f…`, nvidia/oldconfig `aa22e3ba…`).
2. ~~Backing-chain check~~ DONE — standalone qcow2s, no chain.
3. ~~virsh inventory~~ DONE — `win-11-gaming-base` DEFINED (shut off).
4. ~~swtpm state~~ DONE — `tpm2-00.permall` present, mtime 2025-10-16.
**Acceptance:** MET.

### Phase 1 — B2 offsite backup of the known-good state (NEW — before mutation)
1. `topology/LINDA.json` backup targets (drives genBackup):
   - `win11-gaming-image`: `/var/lib/libvirt/images/win11-base-gaming.qcow2`
     → `minio:linda-win11-vm` (mode copy, bwlimit to be set per D-9)
   - `win11-gaming-qemu`: `/var/lib/libvirt/qemu/` → `minio:linda-win11-vm/qemu`
   - `win11-gaming-nvram`: `/var/lib/libvirt/qemu/nvram/` → `minio:linda-win11-vm/nvram`
   - `win11-gaming-tpm`: `/var/lib/libvirt/swtpm/d9377588-28e4-4257-905a-95012babe705/`
     → `minio:linda-win11-vm/tpm`
2. `topology/local-nas.json`: add `b2-linda-win11-vm` target
   (`minio:linda-win11-vm` → `b2:minio-backup-bargman/linda-win11-vm`, copy,
   Sun 03:00, standard B2 flag set — pattern of `b2-obsidian`). **Weekly B2
   replication confirmed sufficient** (user ruling).
3. Solve the read-permission gap (F16): per-target `user` support in
   `lib/rclone-target.nix` + `lib/topology/genBackup.nix`, or tmpfiles ACL
   grants for John88 on the four scoped paths. Prefer ACL (no module churn).
4. Deploy local-nas (backup-only change — low risk) and LINDA (backup-only
   change first; `switch` is SAFE here — no networking/VFIO in this phase).
5. Trigger initial sync; VERIFY objects present in the B2 bucket before
   Phase 2 begins (deploy user: `sudo systemctl start rclone-sync-…`;
   verify on local-nas / B2 per backup_operations_standard.md).
**Acceptance:** `win11-base-gaming.qcow2` + XMLs + NVRAM + TPM state visible
and verified in `b2:minio-backup-bargman/linda-win11-vm`. Confirms D-8 scope.

### Phase 2 — Declarative stack (Nix changes, single coherent change-set)
1. **NixVirt wiring** (D-7): add `nixvirt` flake input (nixpkgs follows);
   import `nixvirt.nixosModules.default` on LINDA. New
   `machines/LINDA/windows-vm/default.nix`:
   - domain `win-11-gaming-base` via `domain.writeXML` (or `pkgs.writeText`
     full-fidelity — F14) from the archived XML; `active = false` initially,
     `restart = false`; UUID `d9377588-28e4-4257-905a-95012babe705`.
   - **hostdev PCI addresses as module options** (defaults = `46:00.0`,
     `4d:00.0`, `4d:00.1`) per the Recreation Model portability caveat.
   - libvirt network(s) declared via `network.writeXML` (keep the existing
     `default` NAT network managed/declared; `br0` remains a *host* bridge per
     D-2, referenced by the domain as before).
   - acceptance eval: generated domain XML diff-clean vs
     `machines/LINDA/windows-vm/win-11-gaming-base.xml` (F14).
2. **Firmware (R21/F20):** the domain's `<os>` section moves to the 26.05
   default — firmware autoselect (`firmware='efi'`) or explicit loader
   `/run/libvirt/nix-ovmf/edk2-x86_64-code.fd` + existing NVRAM
   `win-11-base_VARS.fd` (size-verified compatible). The legacy `qemu.ovmf`
   module block stays retired.
3. `machines/LINDA/default.nix`:
   - initrd `availableKernelModules`: re-add `vfio_pci`, `vfio_iommu_type1`, `vfio`;
     initrd `kernelModules`: `[ "vfio_pci" ]`
   - `kernelModules`: re-add `vfio_pci`, `vfio_iommu_type1`, `vfio`
   - `boot.extraModprobeConfig`: `options vfio-pci ids=10de:1c81,10de:0fb9,1b21:2142`
     — **boot-time claim is mandatory** (R24: late binding of the audio
     function hangs on vga_switcheroo/bus-reset; the ids= path claims both
     functions before the host HDA stack, as the prior art did)
   - optional belt-and-braces: `initrd.preDeviceCommands` driver_override for
     `0000:4d:00.0 0000:4d:00.1 0000:46:00.0` — FIXED redirect form (F3).
   - **Networking:** per D-10 outcome — interim (a): domain NIC → `default`
     NAT, Scream → virbr0, no host network changes; OR endgame (c): the br0
     restoration (F11 reboot-gated rules apply).
4. Regenerate `goldens/LINDA.json` (D-5 authorized):
   `nix run .#dump-config -- LINDA | jq -S . > goldens/LINDA.json`, then
   `nix run .#validate-goldens -- LINDA`.
5. Deploy with `nixos-rebuild boot` (NOT `switch`) — F11: br0 + VFIO take
   effect only at reboot.
**Acceptance:** eval clean; generated domain XML matches archived XML; golden
regenerated + validated; boot entry staged on LINDA.

### Phase 3 — Reboot + binding verification (USER-MANUAL + observation)
1. **User action:** reboot LINDA (physical presence for the display check).
   Verify:
   - `lspci -nnk`: `4d:00.0`, `4d:00.1`, `46:00.0` → "Kernel driver in use: vfio-pci"
   - `21:00.0` still nvidia; all 3 monitors correct (KMS names HDMI-A-1/A-2/DP-2)
   - `lsmod | grep vfio` populated; `dmesg | grep -i "AMD-Vi\|vfio"` clean
   - `br0` up with `10.88.128.88/24` (or DHCP lease); SSH/Sunshine reachable
2. Host sanity: Scream service alive on br0; Ollama/vLLM, WireGuard unaffected.
**Acceptance:** vfio-pci owns group 41 + group 37; host display + network intact.

### Phase 4 — Domain bring-up (declarative; USER-MANUAL trigger)
1. NixVirt has reconciled the definition (or `virsh define` fallback matches
   the declarative XML). **User action:** `virsh start win-11-gaming-base`.
2. Cold boot only — do NOT snapshot/restore across the GPU swap.
3. Verify boot to Windows login (OVMF + NVRAM + TPM continuity per R12).
**Acceptance:** VM boots to Windows login under declarative management.

### Phase 5 — Guest-side bring-up (USER-MANUAL)
1. **User action (at the machine):** Windows side — NVIDIA driver (GTX 1050),
   Looking Glass host app (B7 era matches host client), Scream sender
   (unicast → host br0:4010), virtio drivers if storage was virtio.
2. Verify: LG client on host renders guest; audio via Scream; USB devices on
   the ASMedia controller work in guest; Steam/game smoke test.
**Acceptance:** playable Windows session with GPU, audio, USB, LG display.

### Phase 6 — Hardening + future (after stable) — CONFIRMED WANTED
1. Backup hygiene: after the VM is steady-state, migrate to ZFS snapshot
   streams to B2 (D-9 long-term shape: platonic pipeline pattern R19 +
   optional incremental `-I` chains).
2. Scream/LG systemd polish; keep D-4 as-is unless host pressure demands.
3. Optional (NOT prior art — separate decision): `kvmfr` instead of
   `/dev/shm/looking-glass` file; hugepages (explicit hugetlb, F8).
4. **Local subnet routing expansion (D-2 "later" — user: "ideally yes"):**
   adopt the platonic routed-network pattern (R16): libvirt network
   `forward.mode = "route"` + `networking.nat`/forwarding on LINDA, or routing
   between br0 subnet and wireg0/LAN planes. Separate plan when the user
   calls it.
5. Update AGENTS.md fleet status + close this LDR with outcome.

## Evidence Appendix (reproduction → observed)

| # | Command | Observed |
|---|---------|----------|
| E1 | `ssh inspect-linda 'cat /proc/cmdline'` | `amd_iommu=on amd_pstate=active video=HDMI-A-1:... video=HDMI-A-2:... video=DP-2:...` kernel 6.18.46 |
| E2 | `ssh inspect-linda 'lsmod \| grep vfio'` | NO_VFIO_MODULES |
| E3 | `ssh inspect-linda 'lspci -nnk'` | 21:00.0/1 = GA104 RTX 3060 `10de:2487`/`10de:228b` (nvidia); 4d:00.0/1 = GP107 GTX 1050 `10de:1c81`/`10de:0fb9` (no driver in use); 46:00.0 = ASM2142 `1b21:2142` (xhci_hcd) |
| E4 | IOMMU group walk | group 54 = {21:00.0, 21:00.1}; group 41 = {4d:00.0, 4d:00.1}; group 37 = {46:00.0}; group 38 = {47:00.0} |
| E5 | `ls /var/lib/libvirt/images` | `win11-base-gaming.qcow2` 107 GB (2025-10-16), `win11-base-Parent.qcow2` 58 GB (2023-05-08), `efi-vars.fd` |
| E6 | `ls /var/lib/libvirt/qemu` | `win-11-gaming-base.xml` (2025-10-16), `win-11-gaming-base-nvidia.xml` (2025-10-03), `win-11-gaming-oldconfig.xml` (2025-09-18), `domain-15-win-11-unity/` |
| E7 | `ls /var/lib/libvirt/qemu/nvram` | `win-11-base_VARS.fd` (2025-10-16), `win-11-gaming_VARS.fd`, `win-11-unity_VARS.fd`, `linux2024_VARS.fd` |
| E8 | `ls /dev/shm` | `looking-glass` 0660 John88:qemu-libvirtd (alive) |
| E9 | `systemctl --user status scream-ivshmem` | loaded, **inactive (dead)** — binds nonexistent `br0` |
| E10 | `git show 3762764^:machines/LINDA/default.nix` | prior VFIO recipe: initrd vfio modules, `extraModprobeConfig ids=1b21:2142,10de:1c81,10de:0fb9`, `DEVS="0000:46:00.0 0000:4d:00.0 0000:4d:00.1"` override loop |
| E11 | `git show 709c553^:machines/LINDACORE.nix.save` | fullest prior stack: vfio + OVMF + swtpm + LG + Scream ivshmem + br0 bridge |
| E12 | `free -g` | 125 GB total, 107 used, 18 available |
| E13 | `ssh deploy@LINDA -p 1108 'sudo virsh list --all'` | `win-11-gaming-base` DEFINED, shut off (also linux2024, ubuntu-gpu, ubuntu20.04-*) |
| E14 | `sudo virsh dumpxml win-11-gaming-base` | hostdevs `0000:46:00.0`, `0000:4d:00.0`, `0000:4d:00.1`; loader `/run/libvirt/nix-ovmf/OVMF_CODE.fd`; 32 GB; 20 vCPU; kvm hidden; TPM tpm-tis; bridge `br0`; shmem looking-glass 128 MB + scream 2 MB; disk sda=`win11-base-gaming.qcow2`, vda=`/dev/zd0` |
| E15 | `ls /run/libvirt/nix-ovmf/` | only qemu-bundled edk2 files — **no `OVMF_CODE.fd`/`OVMF_VARS.fd` templates** |
| E16 | `sudo zfs list -t volume` | `/dev/zd0` = `speed-storage/steam-library-win` (788 GB referenced) |
| E17 | `sudo find /var/lib/libvirt/swtpm/d9377588-…` | `tpm2-00.permall` 9,220 B, mtime 2025-10-16 (TPM continuity OK) |
| E18 | `sudo qemu-img info --backing-chain win11-base-gaming.qcow2` | standalone qcow2, 100 GiB virtual / 72.6 GiB used / 99.8 GiB file length — no backing file |
| E19 | `sudo diff win-11-gaming-base-nvidia.xml win-11-gaming-base.xml` | hostdevs `21:00.0/.1+46:00.0` (old) → `46:00.0+4d:00.0/.1` (final); same loader/nvram paths |
| E20 | `ip link show br0` | does not exist; `enp69s0f0` = 10.88.128.88/24 |
| E21 | `ls /speed-storage/repo/platonic.systems/vms/` | NixVirt-based flake: `modules/platonic-libvirt.nix` + `modules/options.nix`; `vms/` per-tenant defs; README documents hyperhyper SSH control endpoints |
| E22 | `grep b2: topology/local-nas.json` | six `b2:minio-backup-bargman/*` replication targets, Sun 03:00, 5M, `--b2-chunk-size 64M` |
| E23 | `systemctl cat rclone-sync-obsidian-v3.service` (LINDA) | `rclone … bisync … minio:obsidian-v3` runs as User=John88, config decrypted to `/run/rclone-sync-*-keys/config-file` |
| E24 | `grep rclone LINDA + local-nas topology` | LINDA: 3 minio targets (user John88); local-nas: B2 replication (user minio, config `secrets/rclone-b2-config-file`) |
| E25 | `sudo virsh domcapabilities --virttype kvm` + firmware descriptor read | default loader `/run/libvirt/nix-ovmf/edk2-x86_64-code.fd`, firmware autoselect `efi`; `60-edk2-x86_64.json` maps nvram-template `edk2-i386-vars.fd` (540,672 B == existing `win-11-base_VARS.fd`) |
| E26 | `lsusb -t` + `/sys/bus/pci/devices/0000:46:00.0/usb*` | buses 5+6 behind ASMedia; bus 5 = HID keyboard + mouse + UVC webcam + USB audio (VM peripheral set); NOT bound to vfio (input aboard) |
| E27 | `sudo dmesg \| grep -i "nvrM\|vfio\|4d:00"` | `NVRM: ignoring the legacy GPU 0000:4d:00.0` (probe -1); `vfio-pci 0000:4d:00.0: vgaarb: VGA decodes changed` |
| E28 | live bind test (driver_override + sysfs bind) | `4d:00.0` → vfio-pci ✓, `/dev/vfio/41` ✓; `4d:00.1` bind/power writes hang (`reset_method: bus`, vga_switcheroo interlock) — boot-time `ids=` required (R24) |

---

**Version 2.2 — 2026-10-05 — Janeway (USS-Voyager).** OVMF corrected (26.05
default loader, NVRAM-compatible); live bind test done (GPU ✓, audio function
teaches the boot-time-ids lesson); USB peripheral set mapped; D-10 interim
networking open (recommendation: NAT now, br0 later).
**Next action:** user picks D-10 option → Phase 1 execution (B2 backup) →
Phase 2 change-set.
