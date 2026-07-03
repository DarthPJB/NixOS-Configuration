# ARM Builder — USB-NVMe Reliability Action Plan

> **Created:** 2026-07-03
> **Status:** Ready for review
> **Parent:** `2026-07-03-arm-builder-nvme-ci-disconnect.md`
> **Research:** `documentation/research/rpi4-usb-nvme-kernel-tuning.md`,
>              `documentation/research/rpi4-usb-nvme-firmware-research.md`

## Problem Statement

The Raspberry Pi 4 experiences USB disconnects under sustained write load with
USB-NVMe enclosures. This is a **recurring pattern across multiple enclosures**,
not specific to the DockCase. The failure mechanism:

1. SCSI WRITE commands stall for minutes under heavy I/O
2. USB device resets fail (`enable of device-initiated U1 failed`)
3. USB device disconnects from the bus
4. Cascading EXT4 journal abort → service crashes → CI builds fail

The NVMe recovers autonomously after disconnect, but running work is lost.

## Root Cause Analysis

Three interacting failure modes (confirmed by research):

| Factor | Finding | Confidence |
|---|---|---|
| **VL805 U1 link state bug** | The Pi 4's USB 3.0 controller fails to negotiate low-power link states with certain bridges, causing resets | Confirmed |
| **Power headroom** | Pi 4 (3A PSU) + NVMe sustained writes peak ~4.3A — brownout under load | Confirmed |
| **Bridge chip quality** | DockCase VL716 bridge has known UAS bugs and marginal power regulation | Reported |
| **VL805 firmware** | Already at latest (0138C0) — no update available | Confirmed |
| **Bootloader EEPROM** | 3.5 years stale — USB timeout handling improved since 2023 | Confirmed |

## Action Plan — Four Phases

All phases are implementable in NixOS configuration via cross-compilation from
x86_64. No manual SSH manipulation required.

---

### Phase 1 — Kernel Tuning (Software Only, Zero Cost)

**Goal:** Eliminate the most common causes of USB disconnect via kernel parameters
and mount options. All changes are declarative in `machines/arm-builder/default.nix`.

**Changes to `machines/arm-builder/default.nix`:**

```nix
boot.kernelParams = [
  "console=ttyS1,115200n8"
  "cma=128M"

  # USB storage — disable UAS + disable sync cache flush
  "usb-storage.quirks=31db:9210:u,31db:9210:s"

  # USB power management — prevent link state transitions during I/O
  "usbcore.autosuspend=-1"
  "usbcore.auto_runtime_pm=0"

  # SCSI — extend timeouts, disable runtime PM, increase retries
  "scsi_mod.scsi_timeout=300"
  "scsi_mod.max_retries=10"
  "scsi_mod.use_rpm=0"

  # Block layer — reduce queue depth to prevent congestion
  "nr_requests=16"
];

# Swap to SD card (remove NVMe swap)
swapDevices = [
  { device = "/swapfile"; size = 4096; }
];

# NVMe mount with reduced write pressure
fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/382a0c33-7680-412a-bc69-df162c790f81";
  fsType = "ext4";
  options = [
    "nofail"
    "data=writeback"       # Less strict journal ordering
    "noatime"              # No access time writes
    "nodiratime"           # No dir access time writes
    "commit=120"           # Journal commit every 120s (default 5)
    "errors=remount-ro"    # Safety: remount read-only on error
  ];
};

# Udev rules to prevent USB autosuspend for the enclosure
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="31db", ATTR{idProduct}=="9210", ATTR{power/control}="on", ATTR{power/autosuspend}="0"
'';

# Zram swap (compressed RAM) — eliminates swap I/O to NVMe
zramSwap = {
  enable = true;
  memoryPercent = 50;  # ~1.9GB of 3.7GB RAM
};
```

**Expected impact:** High. These changes address:
- USB autosuspend causing link state transitions during I/O (primary suspect)
- SCSI command timeouts triggering premature resets
- EXT4 journal write pressure amplifying I/O contention
- Swap I/O on the same USB device as /nix

**Validation:** Deploy, then run a kernel build. Monitor for `device offline error`
in journal. If no disconnects during a full `linux-rpi` build, Phase 1 succeeded.

**Risk:** Low. All parameters are well-documented kernel features. `data=writeback`
slightly reduces crash consistency (metadata may precede data) but this is
acceptable for a build server where /nix contents are reproducible.

---

### Phase 2 — Firmware Update (Requires Physical Access)

**Goal:** Update the Pi's bootloader EEPROM from 2023-01-11 to 2026-05-17.

**What this fixes:**
- 2025-11-27: USB boot timeout/retry limit assert fix
- 2026-04-14: Automatic reboot after fatal errors (power, HATs, temperature)
- 2026-05-17: SDRAM firmware 2.35 (memory stability under load)

**What this does NOT fix:**
- VL805 firmware stays at 0138C0 (no newer version exists)
- No explicit "fix USB disconnect under load" entry in changelog

**Procedure:**
1. SSH to arm-builder as `deploy` user
2. Download `pieeprom-2026-05-17.bin` from `raspberrypi/rpi-eeprom` releases
3. Stage on FIRMWARE partition (`/dev/mmcblk0p1`)
4. Reboot — `recovery.bin` flashes automatically
5. EEPROM has built-in rollback if update fails

**Validation:** After update, verify with `vcgencmd bootloader_version`. Then run
a kernel build to test.

**Risk:** Low. EEPROM updates have built-in rollback. Physical access available.

---

### Phase 3 — Power Supply Verification (Requires Physical Inspection)

**Goal:** Ensure the Pi 4 has adequate power for sustained NVMe writes.

**Power budget:**
| Component | Peak Draw |
|---|---|
| Pi 4 (loaded) | ~1.5A |
| VL805 controller | ~0.3A |
| DockCase + SN750 (write) | ~2.5A |
| **Total** | **~4.3A** |

The official Pi 4 PSU delivers 3A — **insufficient**.

**Actions:**
1. Check current PSU rating (label on the adapter)
2. If < 5A: replace with Raspberry Pi 27W PSU (5V/5A) or equivalent
3. Add `usb_max_current_enable=1` to FIRMWARE partition `config.txt`:
   ```ini
   usb_max_current_enable=1
   ```
   This raises per-port USB current from 600mA to 1.2A.

**Validation:** Monitor `vcgencmd get_throttled` during builds — non-zero means
power issues.

**Risk:** None. `usb_max_current_enable=1` is safe with an adequate PSU.

---

### Phase 4 — Hardware Definitive Fix (Requires Purchase)

**Goal:** Eliminate USB entirely by switching to native PCIe NVMe via HAT.

**Options (in order of preference):**

| Option | Price | Effort | Impact |
|---|---|---|---|
| **Raspberry Pi M.2 HAT+** | ~£15 | Physical install | **Definitive** — eliminates USB layer entirely |
| **Replace DockCase** with ASM2362-based enclosure | ~£20 | Swap enclosure | High — ASMedia bridges are known reliable |
| **Both** (HAT + keep DockCase as backup) | ~£35 | Physical install | Best of both worlds |

**Why NVMe HAT+ is the definitive fix:**
- No USB protocol layer (no UAS/BOT, no SCSI translation)
- No VL805 controller involvement (no U1/U2 link state bugs)
- Dedicated power via PCIe slot (no shared USB rail)
- 2-4x faster (PCIe Gen 2: ~400 MB/s vs USB BOT: ~180 MB/s)

**NixOS config change for HAT:**
```nix
# Replace USB mount with NVMe device
fileSystems."/nix" = {
  device = "/dev/nvme0n1p1";  # or by-label/by-uuid
  fsType = "ext4";
  options = [ "nofail" "noatime" ];
};

# Remove USB quirks from kernelParams (no longer needed)
# Remove swap from NVMe (use zram instead)
```

**Validation:** Full kernel build with no disconnects.

**Risk:** Low. NVMe HAT is well-tested hardware. Requires physical access to install.

---

## Implementation Sequence

| Phase | Action | Requires | Cost | Expected Impact |
|---|---|---|---|---|
| **1** | Kernel tuning | NixOS config change only | Zero | High — may fully resolve |
| **2** | EEPROM update | Physical access (reboot) | Zero | Medium — bootloader fixes |
| **3** | Power supply | Physical inspection | £0–12 | High — power headroom |
| **4** | NVMe HAT+ | Purchase + install | ~£15 | Definitive |

**Approach:** Implement Phase 1 first (pure software, cross-compilable). If the
issue persists, proceed through Phases 2–4 sequentially. Each phase is independently
valuable and additive.

## What NOT to Do

- **Don't replace the DockCase with another USB enclosure as the primary fix** —
  the pattern persists across enclosures, suggesting the VL805 controller is the
  common factor
- **Don't use all-SD storage** — SD cards can't handle build server write loads
- **Don't add network storage** — adds complexity and a network dependency
- **Don't disable UAS quirk** — the DockCase's UAS implementation is broken;
  BOT mode is correct for this device

## Related Documents

- `documentation/incidents/2026-07-03-arm-builder-nvme-ci-disconnect.md`
- `documentation/incidents/2026-07-03-arm-builder-nvme-failure.md`
- `documentation/plans/arm-builder-disk-strategy-2026-07-03.md`
- `documentation/plans/arm-builder-firmware-remediation-2026-07-03.md`
- `documentation/research/rpi4-usb-nvme-kernel-tuning.md`
- `documentation/research/rpi4-usb-nvme-firmware-research.md`
