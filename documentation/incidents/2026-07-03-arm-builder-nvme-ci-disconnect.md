# Incident Report: arm-builder NVMe Disconnect During CI Build

> **Date:** 2026-07-03 ~04:45 UTC
> **Severity:** High — ARM CI builds blocked
> **Status:** NVMe recovered; builds failed; root cause confirmed as DockCase enclosure
> **Affected:** arm-builder (Raspberry Pi 4 Model B Rev 1.5)
> **CI Run:** 28638779602 (jb/overlord-I)

## Summary

During CI-triggered `linux-rpi` kernel builds dispatched to arm-builder via `ssh-ng`,
the DockCase DSWC1P USB enclosure dropped from the USB bus under sustained write
load. The nix-daemon on arm-builder lost access to `/nix` (ext4 on NVMe), the CI
runner saw `Nix daemon disconnected unexpectedly`, and both `print-controller` and
`display-1` ARM builds failed.

The NVMe recovered autonomously after the disconnect — the system is currently
operational with no manual intervention. This confirms the WD SN750 NVMe is healthy;
the DockCase enclosure is the failure point.

## Failure Mechanism

This is NOT a sudden disconnect. The USB link degrades under sustained write load
over a period of minutes:

1. **Command stall:** A single SCSI WRITE command (`opcode=0x2a`) was stuck for
   **238 seconds** (`cmd_age=238s`) before the kernel attempted recovery
2. **USB reset loop:** The kernel attempted 4+ USB device resets, all failing with
   `enable of device-initiated U1 failed` (USB low-power state negotiation failure)
3. **SCSI host reset:** `hostbyte=0x05` (DID_RESET) — the kernel reset the SCSI host
   adapter after the device failed to respond
4. **I/O error:** `I/O error, dev sda, sector 244501184 op 0x1:(WRITE)` — the stuck
   write finally failed
5. **Journal blocked:** `jbd2/sda1-8 blocked for more than 241 seconds` — the EXT4
   journal task was stuck waiting for I/O
6. **USB disconnect:** `usb 2-1: USB disconnect, device number 2` — device finally
   dropped off the bus
7. **Cascading failure:** `device offline error` × 10 → journal abort → EXT4 errors
   → filesystem remount read-only → nix-daemon crash → CI build failure

## Detailed Timeline

| Time (UTC) | Source | Event |
|---|---|---|
| 04:40:57 | arm-builder journal | CI dispatched `linux-rpi` build, nix-daemon accepted `build` user |
| 04:40:59 | arm-builder journal | Kernel build started, copying sources to arm-builder |
| ~04:45:02 | arm-builder kernel | EXT4 writeback under heavy I/O (ext4_do_writepages → submit_bio chain) |
| 04:45:17 | arm-builder kernel | `usb 2-1: reset SuperSpeed USB device number 2 using xhci_hcd` — first USB reset |
| 04:45:21 | arm-builder kernel | `usb 2-1: enable of device-initiated U1 failed` |
| 04:45:22 | arm-builder kernel | Second USB reset attempt |
| 04:45:23 | arm-builder kernel | `enable of device-initiated U1 failed` |
| 04:45:27 | arm-builder kernel | Third USB reset attempt |
| 04:45:28 | arm-builder kernel | `enable of device-initiated U1 failed` |
| 04:45:29 | arm-builder kernel | `sd 0:0:0:0: tag#0 UNKNOWN(0x2003) hostbyte=0x05 cmd_age=238s` |
| 04:45:30 | arm-builder kernel | `I/O error, dev sda, sector 244501184` (WRITE) |
| 04:45:33 | arm-builder kernel | `jbd2/sda1-8 blocked for more than 241 seconds` |
| 04:46:35 | CI runner | `error: Nix daemon disconnected unexpectedly (maybe it crashed?)` |
| 04:46:35 | CI runner | `error: write of 8208 bytes: Broken pipe` |
| 04:46:35 | arm-builder systemd | `nix-daemon.service: Deactivated successfully` |
| 04:46:35 | CI runner | print-controller build failed |
| 04:47:57 | CI runner | display-1 build failed (cascading dependency) |
| 04:49:10 | arm-builder kernel | `usb 2-1: USB disconnect, device number 2` |
| 04:49:10 | arm-builder kernel | `device offline error` × 10, journal abort, EXT4 errors |
| ~04:49:14 | arm-builder kernel | USB re-enumeration, NVMe recovered, /nix remounted |

## CI Build Results

| Job | Result | Duration | Cause |
|---|---|---|---|
| Security Scan | ✅ | 1m58s | — |
| Validation & Linting | ✅ | 1m25s | — |
| **print-controller** (ARM) | ❌ | 5m57s | `linux-rpi` build killed by NVMe disconnect |
| arm-builder (ARM) | ✅ | 18s | Config-only, no kernel build |
| **display-1** (ARM) | ❌ | 20s | Cascading failure (dependency on linux-rpi) |
| beta-one (ARM) | ✅ | 11s | Config-only or cached |
| All x86_64 (10 jobs) | ✅ | 11–53s | Don't use arm-builder |

## Hardware Context

| Component | Details |
|---|---|
| Board | Raspberry Pi 4 Model B Rev 1.5, 4GB RAM |
| NVMe | WD SN750 500GB (WDS500G1X0E-00AFY0) |
| Enclosure | DockCase DSWC1P (VID:PID `31db:9210`, serial `202311211944`) |
| USB controller | VL805 (via PCIe Gen 2 x1) |
| Connection | USB 3.0 SuperSpeed (5000M) via `usb 2-1` |
| UAS quirk | `usb_storage.quirks=31db:9210:u` (BOT mode forced) |
| NVMe partitions | `/dev/sda1` ext4 232.9GB (UUID `382a0c33-...`) → `/nix` |
| | `/dev/sda2` swap 232.9GB (UUID `6e9025be-...`) |
| Kernel | 6.18.34 (NixOS) |
| EEPROM | 2023-01-11 (3.5 years old) |

## Pattern Recognition

The user reports this is a **recurring pattern across multiple Pi projects** with
various NVMe-USB caddies — not specific to the DockCase. This suggests:

1. The issue may be systemic to the Pi 4's VL805 USB controller
2. Or systemic to the Linux kernel's USB storage stack under heavy load on ARM
3. Or a combination of both — the VL805 has known quirks under sustained I/O

This needs a **software-level solution** (kernel/OS tweaks), not just hardware
replacement, since the pattern persists across enclosures.

## Recovery

The NVMe recovered autonomously after the disconnect:
- USB re-enumerated at 04:49:14 (SuperSpeed, same device)
- EXT4 filesystem recovered journal
- `/nix` remounted successfully
- Swap reactivated
- System operational at 18:21 UTC (load 0.00, no errors)

**No manual intervention was required.** The system self-healed, but the CI builds
were already lost.

## Related Documents

- `documentation/incidents/2026-07-03-arm-builder-nvme-failure.md` — initial incident
- `documentation/plans/arm-builder-disk-strategy-2026-07-03.md` — disk options
- `documentation/plans/arm-builder-firmware-remediation-2026-07-03.md` — firmware plan
- `documentation/research/` — pending kernel/OS research
