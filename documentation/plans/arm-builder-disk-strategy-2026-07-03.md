# ARM Builder — Disk Strategy Analysis

> **Created:** 2026-07-03
> **Status:** Analysis complete — awaiting decision
> **Parent:** `arm-builder-bootstrap-2026-07-01.md`, `2026-07-03-arm-builder-nvme-failure.md`

## Executive Summary

The WD SN750 NVMe is healthy. **The DockCase DSWC1P USB enclosure is the failure
point** — it disconnects from the USB bus under sustained write load, causing
cascading EXT4 corruption. The fix is a combination of: (1) replacing the enclosure,
(2) moving swap off the NVMe to the SD card, and (3) updating the Pi's EEPROM
firmware.

## Journal Analysis — Failure Pattern

### What Happened (Boot -1, 2026-07-03 ~04:49 UTC)

```
device offline error, dev sda, sector 2104 op 0x1:(WRITE)
device offline error, dev sda, sector 165284400 op 0x1:(WRITE)
device offline error, dev sda, sector 377780792 op 0x1:(WRITE)
... (10 total device offline errors, all WRITE operations)
Buffer I/O error on device sda1, logical block 20659482
Buffer I/O error on dev sda1, logical block 1806351, lost async page write
EXT4-fs error (device sda1): __ext4_get_inode_loc_noinmem: unable to read itable block
EXT4-fs (sda1): This should not happen!! Data will be lost
EXT4-fs (sda1): I/O error while writing superblock
EXT4-fs (sda1): Remounting filesystem read-only
JBD2: I/O error when updating journal superblock for sda1-8
```

### Failure Sequence

1. **USB device disconnects** — the DockCase drops off the USB bus during writes
2. **SCSI layer reports device offline** — all subsequent I/O fails
3. **EXT4 buffer cache loses dirty pages** — async writes already queued are lost
4. **Journal superblock write fails** — EXT4 cannot commit the journal
5. **Filesystem remounts read-only** — protective measure, but damage is done
6. **Swap deactivation fails** — systemd can't swapoff a device that's gone
7. **System haywire** — services that depend on /nix or swap fail

### Key Insight

**This is NOT an NVMe failure.** The NVMe drive is healthy — it's the USB bridge
enclosure that drops the connection. The `device offline error` means the USB device
disappeared from the bus, not that the NVMe media failed. If the NVMe itself had
failed, we'd see `Medium Error` (Sense Key 0x3) or `Uncorrectable Error` — not
`device offline`.

### Current State (Boot 0, verified now)

| Metric | Value |
|---|---|
| NVMe mounted at | `/nix` (ext4, 229GB, 26GB used, 192GB free) |
| Swap | `/dev/sda2` (232.9GB, 1.9MB used) |
| Load average | 4.23 (kernel builds running) |
| Device errors this boot | 0 (so far) |
| USB speed | SuperSpeed (5000M) — correctly negotiated |
| UAS quirk | Applied (BOT mode forced) |

## Root Cause: DockCase DSWC1P Enclosure

The DockCase has three compounding problems:

1. **UAS implementation is broken** — requires kernel quirk to force BOT mode
2. **USB 2.0 negotiation at boot** — consistently negotiates USB 2.0 (480M) on first
   connection, requires physical replug to get USB 3.0 (5000M)
3. **Disconnects under sustained write load** — the USB link drops during heavy I/O,
   causing the `device offline` errors

Problem 3 is the fatal one. Problems 1 and 2 are annoying but survivable. Problem 3
means the enclosure is fundamentally unsuitable for a build server that writes
hundreds of GB to /nix/store.

## Disk Strategy Options

### Option A — Replace the Enclosure (Recommended Primary)

**What:** Buy a known-good USB 3.0 NVMe enclosure. Move the WD SN750 into it.

**Recommended enclosures** (known reliable with Linux, no UAS issues):
- **Sabrent EC-SNVE** — USB 3.2, aluminum, tool-free, UAS works natively
- **ORICO M2PV-C3** — USB 3.2 Gen 2, UASP support, no quirks needed
- **UGREEN CM642** — USB 3.2, widely tested with Pi 4

**Cost:** £15–30

**Pros:**
- Reuses the existing WD SN750 (known good)
- Eliminates all three DockCase problems
- Minimal config change (same /dev/sda, same UUIDs)
- NVMe performance retained for /nix/store

**Cons:**
- Still USB-attached — the Pi 4's VL805 USB controller has known quirks under
  sustained load (though much less severe than the DockCase)
- Still a single point of failure (NVMe + USB bridge)

**Risk:** Low. The WD SN750 is a good drive. A quality enclosure eliminates the
failure mode.

### Option B — Move Swap to SD Card

**What:** Remove swap from the NVMe. Put a swap file or partition on the SD card.

**Why:** Swap on the same device as /nix means a single USB disconnect kills both.
Moving swap to SD isolates the failure domains. The SD card is directly attached to
the SoC (MMC interface) — no USB bridge involved.

**Config change:**
```nix
# Remove NVMe swap
# swapDevices = [ { device = "/dev/disk/by-uuid/6e9025be-..."; } ];

# Add SD card swap (file or partition)
swapDevices = [
  { device = "/swapfile"; size = 4096; }  # 4GB swapfile on SD card root
];
```

**Pros:**
- Swap failure can't cascade to /nix
- SD card is directly attached (no USB bridge failure mode)
- Swap is barely used (1.9MB of 232GB) — 4GB is plenty
- Simple config change

**Cons:**
- SD card has limited write endurance (but swap is barely used)
- SD card is slower (but swap is barely used)
- Doesn't fix the NVMe disconnect issue — only prevents cascading

**Risk:** Very low. Swap usage is negligible. SD card can handle it.

### Option C — All-SD Setup (Nuclear Option)

**What:** Abandon the NVMe entirely. Move /nix/store to the SD card.

**Current state:** SD card has 52GB free. /nix/store uses 26GB. It fits — barely.

**Pros:**
- Eliminates USB entirely from the equation
- No enclosure to fail
- Simpler hardware

**Cons:**
- SD card write endurance is poor — /nix/store is write-heavy during builds
- 52GB free leaves almost no headroom for future growth
- SD card is much slower than NVMe for build I/O
- If the SD card dies (like display-2), the system is dead

**Risk:** High. SD cards are not designed for the write patterns of a build server.

### Option D — Network Block Device (iSCSI / NBD)

**What:** Export a block device from cortex-alpha over the network. Mount it on
arm-builder as /nix.

**Pros:**
- Storage is on cortex-alpha's reliable hardware
- No USB involved
- Can be expanded easily

**Cons:**
- Network latency adds overhead to every I/O operation
- Depends on cortex-alpha being up and WireGuard being stable
- Complex setup (iSCSI target on cortex-alpha, initiator on arm-builder)
- Network congestion during builds could cause stalls

**Risk:** Medium. Adds a network dependency that didn't exist before.

### Option E — NVMe HAT (Native PCIe)

**What:** Use a Raspberry Pi NVMe HAT (e.g., Pimoroni NVMe Base) to attach the
NVMe directly via PCIe, eliminating USB entirely.

**Pros:**
- Native PCIe — no USB bridge, no UAS issues, no enclosure failure
- Best possible performance
- Most reliable long-term solution

**Cons:**
- Requires a different Pi 4 board (the current one is a standard Pi 4, not a Pi 5)
- Pi 4 has limited PCIe (Gen 2 x1) — still faster than USB 3.0
- Requires buying a HAT + possibly a different case
- Board must be physically accessible to install the HAT

**Risk:** Low (hardware is well-tested). But requires physical hardware changes.

## Recommendation

**Combined approach: Option A + Option B**

1. **Immediate (config change):** Move swap to SD card (`Option B`). This prevents
   the cascading failure where a USB disconnect kills both /nix and swap.

2. **Next hardware cycle:** Replace the DockCase enclosure with a Sabrent EC-SNVE
   or similar (`Option A`). This eliminates the root cause.

3. **Update EEPROM** while we're at it — the 3.5-year-old firmware has USB fixes that
   may help with the VL805 controller reliability.

4. **Long-term:** Consider an NVMe HAT (`Option E`) if the arm-builder becomes a
   permanent piece of infrastructure. This is the only option that eliminates USB
   entirely.

### What NOT to do

- **Don't use all-SD** (`Option C`) — SD cards can't handle build server write loads
- **Don't use network storage** (`Option D`) — adds complexity and a network dependency
  for marginal benefit over a better enclosure

## Implementation: Swap to SD Card

The swap change is a one-line config edit:

```nix
# machines/arm-builder/default.nix

# REMOVE:
swapDevices = [
  { device = "/dev/disk/by-uuid/6e9025be-928a-4224-86ae-964922839929"; }
];

# ADD:
swapDevices = [
  { device = "/swapfile"; size = 4096; }
];
```

This creates a 4GB swapfile on the SD card root filesystem at first boot. The NVMe
swap partition (`/dev/sda2`) becomes unused.

## Open Questions

1. **Does the WD SN750 work reliably in a different enclosure?** — Must be tested
   before committing to Option A. If the drive itself has issues, we need a
   replacement NVMe.

2. **Does the EEPROM update help with USB stability?** — The 3.5-year-old firmware
   has known USB enumeration fixes. Worth testing before buying new hardware.

3. **Is the Pi 4's VL805 USB controller itself the problem?** — If even a good
   enclosure disconnects under load, the issue may be the Pi 4's USB controller,
   not the enclosure. In that case, Option E (NVMe HAT) is the only real fix.

## Related Documents

- `documentation/incidents/2026-07-03-arm-builder-nvme-failure.md` — incident report
- `documentation/plans/arm-builder-firmware-remediation-2026-07-03.md` — firmware plan
- `documentation/plans/arm-builder-bootstrap-2026-07-01.md` — bootstrap plan
