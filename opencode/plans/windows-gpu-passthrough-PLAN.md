# Windows GPU Passthrough Restoration — Living Plan (LDR)

**Machine:** LINDA (AMD Threadripper workstation) — NOT gaming-host-1
**Goal:** Actively run the Windows gaming VM with GPU passthrough using the
prior working stack (GTX 1050 + ASMedia USB 3.1 + Looking Glass + Scream).
**Version:** 1.0 — 2026-10-05
**Status:** DIAGNOSTICS COMPLETE — plan gated on open decisions (D-1…D-6)

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

## Register — Open Decisions (human authority — execution is GATED on these)

- **D-1. Passthrough device set.** Proposal: GTX 1050 (`10de:1c81` + `10de:0fb9`)
  and ASMedia USB 3.1 (`1b21:2142`) — exactly the last working set. RTX 3060
  remains the host GPU. *Confirm or amend.*
- **D-2. VM network model.** Prior `br0` bridge is gone. Options:
  (a) libvirt `virbr0` NAT (simplest; Scream binds virbr0; no LAN presence),
  (b) macvtap/bridge on `enp69s0f0` (LAN presence for game streaming/Sunshine
  from the VM — matches the open firewall ports),
  (c) restore a `br0` bridge over `enp69s0f0`. *Recommendation: (b) if LAN
  visibility for the VM is wanted, else (a).*
- **D-3. Audio path.** Scream unicast on the chosen interface (fix `br0`→new
  iface, port 4010 already firewalled) vs. Scream ivshmem (`/dev/shm/scream`
  tmpfile, prior LINDACORE-era). *Recommendation: keep unicast, one-line fix.*
- **D-4. VM RAM budget.** With ~107/125 GB host usage, decide VM memory (e.g.
  16–32 GB) and whether to reserve explicit hugepages (2 MB pages × N) or rely
  on normal pages. *Recommendation: 16 GB normal pages first; hugepages later
  if latency demands it.*
- **D-5. Golden regeneration authorization.** VFIO restore is an intentional
  config change; `goldens/LINDA.json` must be regenerated and this requires
  express user authorization per AGENTS.md. *Required before deploy.*
- **D-6. Domain XML custody.** Recover `win-11-gaming-base.xml` into the repo
  (proposal: `machines/LINDA/windows-vm/win-11-gaming-base.xml`) as the recorded
  source of truth, with the domain still managed by libvirt/virt-manager
  (imperative define), OR keep XML out-of-band only. *Recommendation: recover
  into repo.*

## Phased Plan (execution order; each phase gates the next)

### Phase 0 — Recover prior-art artifacts (read-only + one privileged read)
1. As John88 on LINDA (or user-assisted sudo): copy
   `/var/lib/libvirt/qemu/win-11-gaming-base.xml`,
   `win-11-gaming-base-nvidia.xml`, `win-11-gaming-oldconfig.xml` to the repo
   (D-6 location).
2. `qemu-img info --backing-chain` on `win11-base-gaming.qcow2` and
   `win11-base-Parent.qcow2` — record chain, format, and virtual sizes.
3. `virsh -c qemu:///system list --all` + `net-list --all` as John88 — confirm
   whether any domain is still *defined* (vs. only XML files on disk).
4. Record `ls /var/lib/libvirt/swtpm/` — confirm TPM state file survives
   (Win11 requires TPM continuity).
**Acceptance:** XMLs + backing-chain report + TPM state inventory archived in
the repo; findings appended to F-register.

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
3. Fix Scream per D-3 (interface name update).
4. Regenerate `goldens/LINDA.json` (D-5 authorization), validate:
   `nix run .#validate-goldens -- LINDA`.
**Acceptance:** eval clean, golden matches regenerated baseline, nixos-rebuild
test passes on LINDA.

### Phase 2 — Reboot + binding verification (observation)
1. Reboot LINDA. Verify:
   - `lspci -nnk`: `4d:00.0`, `4d:00.1`, `46:00.0` → "Kernel driver in use: vfio-pci"
   - `21:00.0` still nvidia; all 3 monitors correct (KMS names HDMI-A-1/A-2/DP-2)
   - `lsmod | grep vfio` populated; `dmesg | grep -i "AMD-Vi\|vfio"` clean
2. Host sanity: Sunshine, Ollama, WireGuard unaffected.
**Acceptance:** vfio-pci owns group 41 + group 37; host display stack intact.

### Phase 3 — Domain restore
1. `virsh define` from recovered `win-11-gaming-base.xml` (adjust disk/nvram
   paths if anything moved; they should not have).
2. Reconcile XML against Phase 2 reality: hostdev addresses (`0000:4d:00.0/1`,
   `0000:46:00.0`), ivshmem/looking-glass device, sound device, TPM backend
   (swtpm), network per D-2.
3. Do NOT snapshot/restore across the GPU swap — cold boot the domain.
**Acceptance:** `virsh dumpxml win-11-gaming-base` shows expected hostdevs; VM
boots to Windows login.

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

---

**Version 1.0 — 2026-10-05 — Janeway (USS-Voyager).**
**Next action:** user answers D-1…D-6 → Phase 0 privileged reads → Phase 1 edits.
