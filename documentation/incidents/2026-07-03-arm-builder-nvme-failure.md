# Incident Report: arm-builder NVMe Failure

> **Date:** 2026-07-03
> **Severity:** High — ARM build capacity offline
> **Status:** Open — not yet remediated
> **Affected:** arm-builder (Raspberry Pi 4 Model B Rev 1.5)

## Summary

During CI-triggered kernel builds, the NVMe disk (WD SN750 500 GB in DockCase DSWC1P
USB enclosure) failed on the arm-builder. The system lost its `/nix` store mount and
became unresponsive. SSH hung at banner exchange; the system was pingable but
inaccessible.

## Timeline

| Time (UTC) | Event |
|---|---|
| ~04:35 | `nix run .#arm-builder -- switch` succeeded — build user added to trusted-users, config deployed |
| ~04:38 | CI triggered on push to `jb/overlord-I` |
| ~04:39 | ARM builds dispatched: arm-builder, display-1, print-controller, beta-one |
| ~04:40 | `linux-rpi` kernel builds dispatched to arm-builder via `ssh-ng` |
| ~04:45 | System became unresponsive to SSH (banner exchange timeout) |
| ~04:47 | User observed "nasty text" in arm-builder journal |
| ~04:48 | NVMe failure confirmed — system lost `/nix` store, went haywire |

## Root Cause

**NVMe hardware failure** under load. The WD SN750 500 GB in the DockCase DSWC1P USB
3.0 enclosure failed during concurrent kernel builds. Contributing factors:

1. **Known DockCase UAS issues** — the enclosure has a broken UAS implementation
   requiring a kernel quirk (`usb_storage.quirks=31db:9210:u`) to force BOT mode.
   The USB connection was also unreliable, only negotiating USB 3.0 after physical
   replug.

2. **Physical replug required at every boot** — the DockCase consistently failed to
   enumerate on first connection (0 bytes reported), requiring physical unplug/replug
   to negotiate USB 3.0 and detect the NVMe.

3. **USB 2.0 negotiation failure** — on first connection after boot, the DockCase
   negotiated USB 2.0 (480M) instead of USB 3.0 (5000M), causing Read Capacity
   failures even with the UAS quirk applied.

4. **Stale EEPROM firmware** — the Pi's SPI EEPROM is from 2023-01-11 (3.5 years
   old). The VL805 USB controller firmware and USB enumeration fixes accumulated since
   then may have contributed to the instability.

5. **Heavy concurrent load** — CI dispatched multiple kernel builds to the arm-builder
   simultaneously, putting extreme memory and I/O pressure on the system (3.7 GB RAM,
   232 GB swap on the same NVMe).

## Impact

- **ARM build capacity offline** — arm-builder cannot serve as a remote builder
- **CI ARM builds failing** — display-1, print-controller, beta-one builds blocked
- **NVMe data potentially lost** — the `/nix` store contents (rsynced from SD card
   earlier today) may be unrecoverable if the NVMe is physically failed

## Previous Warnings

This incident was foreseeable. The following issues were documented but not resolved
before the CI was allowed to dispatch builds to arm-builder:

1. **Firmware remediation plan** (`documentation/plans/arm-builder-firmware-remediation-2026-07-03.md`)
   — documented the stale EEPROM (3.5 years old) and recommended updating before
   production use. Not actioned.

2. **DockCase UAS quirk** — the kernel quirk was applied at runtime but the device
   still required physical replug at every boot. This was treated as a known quirk
   rather than a reliability risk.

3. **Swap on same NVMe** — the swap partition was on the same USB-NVMe device as
   `/nix`. If the NVMe fails, the system loses both its store and its swap, causing
   cascading failure.

## Remediation Required

### Immediate
- [ ] Inspect NVMe physically — is the drive dead, or just the enclosure?
- [ ] If drive is alive: test with a different USB enclosure (eliminate DockCase)
- [ ] If drive is dead: source replacement NVMe

### Before Re-enabling arm-builder
- [ ] **Update Pi EEPROM** to 2026-05-17 — USB enumeration fixes are critical
- [ ] **Update GPU firmware** to 2026-05-21
- [ ] **Replace DockCase enclosure** — the UAS issues and replug requirement make it
  unsuitable for unattended operation
- [ ] **Separate swap from NVMe** — swap should be on SD card or a separate device
  to prevent cascading failure
- [ ] **Limit concurrent CI builds** — the Pi 4 cannot handle multiple kernel builds
  simultaneously; configure `maxJobs = 1` in CI

### CI Changes
- [ ] Remove arm-builder from CI ARM matrix until hardware is stable
- [ ] Add health check before dispatching builds to remote builder

## Related Documents

- `documentation/plans/arm-builder-bootstrap-2026-07-01.md` — original bootstrap plan
- `documentation/plans/arm-builder-firmware-remediation-2026-07-03.md` — firmware
  update plan (not actioned before incident)
