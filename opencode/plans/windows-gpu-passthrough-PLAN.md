# Windows GPU Passthrough Restoration — Living Plan (LDR)

**Machine:** LINDA (AMD Threadripper workstation) — NOT gaming-host-1
**Goal:** Actively run the Windows gaming VM with GPU passthrough using the
prior working stack (GTX 1050 + ASMedia USB 3.1 + Looking Glass + Scream).
**Version:** 1.1 — 2026-10-05
**Status:** PHASE 0 COMPLETE (via `deploy@LINDA -p 1108`, user-granted) —
execution gated on D-2, D-4, D-5

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
  workloads resident). VM memory must be budgeted against this.
- **R7.** `scream-ivshmem` user service is loaded but **dead**: it binds `br0`,
  which no longer exists (bridge→bond→plain interfaces history).

### Phase 0 results (privileged reads, 2026-10-05, `deploy@LINDA -p 1108`)

- **R8.** The domain **`win-11-gaming-base` is still DEFINED in libvirt**
  (shut off). UUID `d9377588-28e4-4257-905a-95012babe705`. No `virsh define`
  needed — only `virsh start`. Also defined: linux2024, ubuntu-gpu,
  ubuntu20.04-desktop/terminal (irrelevant, shut off).
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
  qcow2** (100 GiB virtual / 72.6 GiB used — NO backing chain),
  `win11-base-Parent.qcow2` also standalone (legacy). swtpm state
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

## Register — Findings (F*)

- **F1.** No Windows domain XML ever lived in the repo — the working stack was
  virt-manager-driven, state on the ZFS dataset. The XMLs on disk are the
  authoritative prior art and must be recovered into the repo (root-600; needs
  John88/sudo read — see Phase 0).
- **F2.** The last working passthrough device set (commit `a30466f`, 2025-10-03
  "swap GPUs", preserved in the Oct-16 XML era):
  `vfio-pci ids=10de:1c81,10de:0fb9,1b21:2142` at
  `0000:4d:00.0 0000:4d:00.1 0000:46:00.0`. RTX 3060 (`21:00.x`) stayed host-side.
- **F3.** Prior art bugs to NOT re-introduce: the `0000:21:00:.0` typo in
  `preDeviceCommands`; the broken `echo "vfio-pci > /sys/..."` redirect (fixed
  in `2e95c4a` as `echo "vfio-pci" > /sys/...`).
- **F4.** Scream's `br0` reference is stale; VM networking model must be chosen
  (D-2) before Scream can be fixed.
- **F5.** The 2026-06-04 VFIO removal (`3762764`) was clean ("verified 0 devices
  bound") — restoring is a pure re-add, no conflicting state expected. The
  historical recipe is recoverable via `git show 3762764^:machines/LINDA/default.nix`
  and `git show 709c553^:machines/LINDACORE.nix.save` (fullest state).
- **F6.** GTX 1050 currently has **no kernel driver bound** (nvidia is bound
  only to `21:00.0`) — the cleanest possible pre-state for vfio-pci binding.
- **F7.** Domain XMLs and `win11-base-gaming.qcow2` are root-600; the `inspect`
  account (observation channel) cannot read them. `sudo -n` is not passwordless.
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
  device in the XML is therefore vestigial as a receiver path — keep it (harmless)
  but expect unicast.

## Register — Open Decisions (human authority — execution is GATED on these)

- **D-1. Passthrough device set. — RESOLVED by user directive ("use the prior
  working stack") + R9:** GTX 1050 (`10de:1c81` + `10de:0fb9`) and ASMedia USB
  3.1 (`1b21:2142`) at `0000:4d:00.0/.1` + `0000:46:00.0`. RTX 3060 stays host.
- **D-2. VM network model. — REFINED by R10/F10:** the domain XML requires
  `br0`; Scream requires guest→host comms. The faithful path is **restore `br0`
  bridge over `enp69s0f0`** (uncomment the ready-made block in
  `machines/LINDA/default.nix`), move firewall keys to `br0`, keep the domain
  XML untouched. *This is a reboot-gated network change (F11) — needs explicit
  user GO.* Alternative (deviation from prior art): rewrite the domain NIC to
  `virbr0` NAT + Scream to virbr0 — no host network risk, but the VM loses LAN
  presence (no LAN game streaming/Sunshine-from-guest).
- **D-3. Audio path. — RESOLVED by prior art (F12):** Scream unicast on br0
  port 4010 (service exists; becomes functional again once br0 returns).
  No host change beyond D-2.
- **D-4. VM RAM budget. — OPEN.** Domain wants 32 GB (prior art) but host runs
  ~107/125 GB used. Options: (a) trust ballooning (memballoon virtio is in the
  XML) and start as-is; (b) reduce `currentMemory` to 16 GB; (c) stop/trim AI
  services while gaming. *Recommendation: (a) first — start the VM, watch
  `free`, reduce only if the host swaps.*
- **D-5. Golden regeneration authorization. — OPEN (express user authority
  required).** VFIO + OVMF + br0 restore changes LINDA's config;
  `goldens/LINDA.json` must be regenerated after the change lands and before
  deploy.
- **D-6. Domain XML custody. — DONE (Phase 0).** Both XML generations archived
  at `machines/LINDA/windows-vm/` (sha256-verified against host). Domain stays
  imperative (libvirt-defined, already defined on host) with repo-archived XML
  as the recorded source of truth.

## Phased Plan (execution order; each phase gates the next)

### Phase 0 — Recover prior-art artifacts — COMPLETE (2026-10-05)
1. ~~As John88 on LINDA: copy domain XMLs~~ DONE — both generations archived
   in `machines/LINDA/windows-vm/` (sha256 match host originals: base
   `a6ad7d4f…`, nvidia/oldconfig `aa22e3ba…`).
2. ~~Backing-chain check~~ DONE — `win11-base-gaming.qcow2` standalone qcow2,
   100 GiB virtual / 72.6 GiB used; `win11-base-Parent.qcow2` standalone legacy.
3. ~~virsh inventory~~ DONE — `win-11-gaming-base` DEFINED (shut off); default
   NAT network active; pools: default, iso, nvram, pool, result, testing-qcow,
   Z-images.
4. ~~swtpm state~~ DONE — `tpm2-00.permall` (9,220 B) present for domain UUID,
   mtime 2025-10-16. TPM continuity preserved.
**Acceptance:** MET — XMLs + chain report + TPM inventory in repo/plan.

### Phase 1 — Declarative VFIO restoration (Nix changes)
1. `modifier_imports/virtualisation-libvirtd.nix`: uncomment OVMF block
   (`ovmf.enable = true; packages = [ pkgs.OVMFFull.fd ];`).
2. `machines/LINDA/default.nix`:
   - initrd `availableKernelModules`: re-add `vfio_pci`, `vfio_iommu_type1`, `vfio`;
     initrd `kernelModules`: `[ "vfio_pci" ]`
   - `kernelModules`: re-add `vfio_pci`, `vfio_iommu_type1`, `vfio`
   - `boot.extraModprobeConfig`: `options vfio-pci ids=10de:1c81,10de:0fb9,1b21:2142`
     (F2 set; amend per D-1)
   - optional belt-and-braces: `initrd.preDeviceCommands` driver_override for
     `0000:4d:00.0 0000:4d:00.1 0000:46:00.0` — with the FIXED redirect form
     (`echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override`) per F3.
3. Per D-2 (if br0 GO): uncomment the `bridges."br0"` block over `enp69s0f0`,
   move `enp69s0f0.useDHCP` to `br0`, mirror the `firewall.interfaces`
   keys onto `br0` (keep `wireg0` as-is).
4. Regenerate `goldens/LINDA.json` (D-5 authorization), validate:
   `nix run .#validate-goldens -- LINDA`.
5. Deploy with `nixos-rebuild boot` (NOT `switch`) — F11: the br0 move must
   only take effect at reboot, together with VFIO.
**Acceptance:** eval clean, golden matches regenerated baseline, boot entry
staged on LINDA.

### Phase 2 — Reboot + binding verification (observation)
1. Reboot LINDA. Verify:
   - `lspci -nnk`: `4d:00.0`, `4d:00.1`, `46:00.0` → "Kernel driver in use: vfio-pci"
   - `21:00.0` still nvidia; all 3 monitors correct (KMS names HDMI-A-1/A-2/DP-2)
   - `lsmod | grep vfio` populated; `dmesg | grep -i "AMD-Vi\|vfio"` clean
2. Host sanity: Sunshine, Ollama, WireGuard unaffected.
**Acceptance:** vfio-pci owns group 41 + group 37; host display stack intact.

### Phase 3 — Domain restore (now: verify, not define)
1. Domain is ALREADY defined (R8) — no `virsh define` needed. Verify only:
   `virsh dumpxml win-11-gaming-base` matches `machines/LINDA/windows-vm/win-11-gaming-base.xml`.
2. Reconcile against Phase 2 reality: hostdev addresses (`0000:4d:00.0/1`,
   `0000:46:00.0`), ivshmem/looking-glass device, TPM backend (swtpm),
   network per D-2 (br0 present).
3. Do NOT snapshot/restore across the GPU swap — cold boot the domain.
**Acceptance:** `virsh start win-11-gaming-base` succeeds; VM boots to Windows login.

### Phase 4 — Guest-side bring-up
1. Windows: NVIDIA driver (GTX 1050), Looking Glass host app (B7 era matches
   host client), Scream sender (IP/port per D-2/D-3), virtio drivers if storage
   was virtio.
2. Verify: LG client on host renders guest; audio via Scream; USB devices on the
   ASMedia controller work in guest; Steam/game smoke test.
**Acceptance:** playable Windows session with GPU, audio, USB, LG display.

### Phase 5 — Hardening / hygiene (after stable)
1. Decide whether domain stays imperative (virt-manager) with repo-archived XML
   — or moves to declarative definition (NixOS `virtualisation.libvirtd`
   hooks/verbatim). Prior art stays imperative; recommend staying unless D-6
   says otherwise.
2. Scream/LG systemd polish; memory budget tuning per D-4.
3. Optional improvements (explicitly NOT prior art — separate decision):
   `kvmfr` device instead of `/dev/shm/looking-glass` file; hugepages.
4. Update AGENTS.md fleet status + this LDR with outcome.

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
| E10 | `git show 3762764^:machines/LINDA/default.nix` | prior VFIO recipe: initrd vfio modules, `extraModprobeConfig ids=1b21:2142,10de:1c81,10de:0fb9`, `DEVS="0000:46:00.0 0000:4d:00.0 0000:4d:00.1"` override loop (commented even then) |
| E11 | `git show 709c553^:machines/LINDACORE.nix.save` | fullest prior stack: vfio + OVMF + swtpm + LG + Scream ivshmem + br0 bridge |
| E12 | `free -g` | 125 GB total, 107 used, 18 available (D-4 relevance) |
| E13 | `ssh deploy@LINDA -p 1108 'sudo virsh list --all'` | `win-11-gaming-base` DEFINED, shut off (also linux2024, ubuntu-gpu, ubuntu20.04-*) |
| E14 | `sudo virsh dumpxml win-11-gaming-base` | hostdevs `0000:46:00.0`, `0000:4d:00.0`, `0000:4d:00.1`; loader `/run/libvirt/nix-ovmf/OVMF_CODE.fd`; 32 GB; 20 vCPU; kvm hidden; TPM tpm-tis; bridge `br0`; shmem looking-glass 128 MB + scream 2 MB; disk sda=`win11-base-gaming.qcow2`, vda=`/dev/zd0` |
| E15 | `ls /run/libvirt/nix-ovmf/` | only qemu-bundled edk2 files — **no `OVMF_CODE.fd`/`OVMF_VARS.fd` templates** (OVMF module option commented out → VM cannot boot today) |
| E16 | `sudo zfs list -t volume` | `/dev/zd0` = `speed-storage/steam-library-win` (788 GB referenced) |
| E17 | `sudo find /var/lib/libvirt/swtpm/d9377588-…` | `tpm2-00.permall` 9,220 B, mtime 2025-10-16 (TPM continuity OK) |
| E18 | `sudo qemu-img info --backing-chain win11-base-gaming.qcow2` | standalone qcow2, 100 GiB virtual / 72.6 GiB used — no backing file |
| E19 | `sudo diff win-11-gaming-base-nvidia.xml win-11-gaming-base.xml` | hostdevs `21:00.0/.1+46:00.0` (old) → `46:00.0+4d:00.0/.1` (final); same loader/nvram paths |
| E20 | `ip link show br0` | does not exist; `enp69s0f0` = 10.88.128.88/24 |

---

**Version 1.1 — 2026-10-05 — Janeway (USS-Voyager).** Phase 0 complete;
D-1/D-3/D-6 resolved; D-2/D-4/D-5 open.
**Next action:** user answers D-2 (br0 GO?), D-4 (RAM), D-5 (golden authority)
→ Phase 1 Nix edits.
