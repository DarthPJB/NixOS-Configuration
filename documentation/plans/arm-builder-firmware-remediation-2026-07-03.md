# ARM Builder — Firmware & EEPROM Remediation

> **Created:** 2026-07-03
> **Last updated:** 2026-07-03
> **Status:** Pending — not yet scheduled
> **Parent:** `arm-builder-bootstrap-2026-07-01.md` (Phase 2/3)
> **Parent directive:** Correctness over speed; closed-system builds; firmware maintenance is a fact of life

## Context

The `arm-builder` (Raspberry Pi 4 Model B Rev 1.5) has a DockCase DSWC1P USB 3.0
enclosure (VID:PID `31db:9210`, serial `202311211944`) containing a WD SN750 500 GB
NVMe. The NVMe is partitioned as:
- `/dev/sda1` — ext4, 232.9 GB (UUID `382a0c33-7680-412a-bc69-df162c790f81`, intended for `/nix`)
- `/dev/sda2` — swap, 232.9 GB (UUID `6e9025be-928a-4224-86ae-964922839929`)

The DockCase has a known broken UAS (USB Attached SCSI) implementation. The Linux
kernel quirk (`usb_storage.quirks=31db:9210:u`) forces BOT mode and works correctly
once the kernel is running. However, **U-Boot fails to boot if the DockCase is
connected at power-on**. This is the primary blocker for unattended boot with NVMe
attached.

## Root Cause: Stale Firmware

The boot chain on Raspberry Pi 4 is:

```
BCM2711 SoC ROM
  → SPI EEPROM bootloader (initializes USB, loads GPU firmware)
    → start4.elf (GPU firmware, loads U-Boot)
      → U-Boot (enumerates USB, loads kernel from extlinux.conf)
        → Linux kernel (applies UAS quirk, mounts NVMe)
```

The DockCase causes failures in the EEPROM bootloader or U-Boot stages — before
Linux ever runs. Neither the EEPROM firmware nor U-Boot have a mechanism equivalent
to `usb_storage.quirks` to force BOT mode for specific devices.

## Current Firmware Versions

| Component | Installed | Latest Available | Age |
|---|---|---|---|
| **SPI EEPROM** | `2023-01-11` (`8ba17717...`) | `2026-05-17` | **3.5 years** |
| **GPU Firmware** (start4.elf) | `2025-04-30` (`5560078d...`) | `2026-05-21` | ~14 months |
| **U-Boot** | `2026.04` (Apr 06 2026) | `2026.04` | Current |

## USB-Related Fixes Since Installed EEPROM (2023-01-11)

The EEPROM firmware is 3.5 years behind. USB-related changes in that period:

- **2024-07-30:** USB boot fixes for CM4-S and interop improvements; improved
  compatibility for booting from some USB SD card readers
- **2024-09-05:** USB boot — ignore RP2/RP3 MSD device in BOOTSEL mode
- **2023-01-04:** VL805 firmware update to 138C0 (fix for handling of split
  transactions)
- Multiple USB timeout/retry improvements and partition-walk fixes for USB MSD boot

The VL805 USB controller firmware update (2023-01-04) and subsequent USB interop
fixes are the most likely candidates to resolve the DockCase enumeration failure.

## The U-Boot Error: READ_CAP ERROR

When the DockCase DSWC1P is connected at boot, U-Boot reports:

```
READ_CAP ERROR
```

This is the SCSI `Read Capacity(10)` command failing. The same error occurs in
Linux when the UAS quirk is not applied:

```
sd 0:0:0:0: [sda] Read Capacity(10) failed: Sense Key: 0x5 (Illegal Request)
sd 0:0:0:0: [sda] ASC=0x20 ASCQ=0x0
```

The DockCase bridge chip rejects the Read Capacity command because its UAS
implementation is broken. Linux works around this with
`usb_storage.quirks=31db:9210:u` which forces BOT mode. U-Boot has no equivalent
mechanism.

**The error is identical at both layers.** The difference is that Linux has a
quirk table and U-Boot does not.

## Why U-Boot Cannot Be Patched

- U-Boot 2026.04 has **no UAS support** — only BOT (Bulk-Only Transport)
- **No quirk mechanism** exists (no equivalent to `usb_storage.quirks`)
- **No Kconfig option** to blacklist USB devices by VID:PID
- **No environment variable** to skip USB storage probing
- No `config.txt` option exists to delay or disable USB probing before U-Boot
- **No way to suppress the Read Capacity probe** for a specific device

If the EEPROM update does not resolve the issue, the only U-Boot-side option is a
custom build that removes `usb start` from the boot script — but this is a hack,
not a proper fix.

## Affected Boot Scenarios

1. **Boot with DockCase connected at power-on:** U-Boot fails — device will not boot
2. **Boot without DockCase, connect after Linux starts:** Works — kernel quirk forces BOT mode
3. **Reboot with DockCase connected:** Same as scenario 1 — fails at U-Boot

This means unattended reboots are broken if the NVMe is physically connected.

## Remediation Plan

### Phase 1 — EEPROM Update (Low Risk)

1. Download `pieeprom-2026-05-17.bin` from
   `raspberrypi/rpi-eeprom` → `firmware-2711/default/`
2. Stage the update on the FIRMWARE partition (`/dev/mmcblk0p1`)
3. Reboot — `recovery.bin` flashes the EEPROM automatically
4. EEPROM has built-in rollback if the update fails
5. Test boot with DockCase connected at power-on

**Expected outcome:** USB enumeration improvements in 3.5 years of EEPROM updates
may resolve the DockCase failure. The VL805 firmware update alone is significant.

### Phase 2 — GPU Firmware Update (Low Risk)

1. Update `start4.elf` and associated firmware files from `raspberrypi/firmware` repo
2. Current: 2025-04-30 → Target: 2026-05-21
3. Test boot with DockCase connected

### Phase 3 — If Firmware Updates Do Not Help

Options (in order of preference):
1. **Custom U-Boot build** — remove `usb start` from boot script so U-Boot never
   probes USB storage. NVMe is only needed after Linux boots anyway.
2. **Accept workaround** — DockCase must be disconnected before reboot, connected
   after Linux is running. Fragile for unattended operation.
3. **Different enclosure** — a DockCase without UAS issues, or a native NVMe HAT
   for the Pi 4 (eliminates USB entirely).

## NixOS-Specific Notes

- `rpi-eeprom` is not packaged in nixpkgs. EEPROM updates must be done manually
  or via a custom derivation.
- The FIRMWARE partition is `/dev/mmcblk0p1` (FAT32, label `FIRMWARE`)
- The `config.txt` on the FIRMWARE partition is standard NixOS rPi4 config:
  `kernel=u-boot-rpi4.bin`, `arm_64bit=1`, `enable_uart=1`
- The `arm-builder/default.nix` already has `usb_storage.quirks=31db:9210:u` in
  `boot.kernelParams` — this is correct and sufficient for post-boot operation

## Dependencies

| Item | Source | Status |
|---|---|---|
| `pieeprom-2026-05-17.bin` | `raspberrypi/rpi-eeprom` GitHub releases | Needs download |
| Latest GPU firmware | `raspberrypi/firmware` repo, `boot/` directory | Needs download |
| Physical access to Pi 4 | Required for SD card removal if EEPROM recovery needed | Available |
| Serial console | `console=ttyS1,115200n8` in kernel params | Available |

## Sequence Summary

| Phase | Action | Risk | Gate |
|---|---|---|---|
| 1 | Update EEPROM to 2026-05-17 | Low (rollback built-in) | DockCase boots at power-on? |
| 2 | Update GPU firmware to 2026-05-21 | Low | DockCase boots at power-on? |
| 3 | Custom U-Boot or accept workaround | Medium | If phases 1-2 fail |
