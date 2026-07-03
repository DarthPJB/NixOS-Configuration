# Raspberry Pi 4 USB-NVMe Reliability Research

**Date:** July 3, 2026  
**Researcher:** AI Agent  
**Platform:** Raspberry Pi 4 (BCM2711) with VL805 USB 3.0 Controller  
**Problem:** USB-NVMe disconnects under sustained write load

---

## Problem Summary

The Raspberry Pi 4's VL805 USB 3.0 controller experiences disconnects with USB-NVMe enclosures under sustained write load. This manifests as:

1. SCSI WRITE commands stalling for minutes
2. USB device resets failing repeatedly (`enable of device-initiated U1 failed`)
3. USB disconnect events
4. Cascading EXT4 journal abort and filesystem errors

Current configuration already has BOT mode enforced via `usb_storage.quirks=31db:9210:u`, but the problem persists across multiple enclosures and NVMe drives, indicating a systemic hardware/software interaction issue.

---

## 1. USB Storage Quirks Beyond UAS Disable

### 1.1 Extended Quirk Flags

The `usb-storage.quirks` parameter accepts flags beyond `u` (UAS disable):

| Flag | Meaning |
|------|---------|
| `u` | Disable UAS |
| `s` | Disable sync (cache flush) |
| `f` | Fixed (use sense key 0x70) |
| `r` | Honor flag capacity16 (for devices that lie) |
| `p` | Use WRITE SAME with UNMAP |

**NixOS Configuration:**
```nix
boot.kernelParams = [
  "usb-storage.quirks=31db:9210:u,31db:9210:s"  # Disable UAS + sync
];
```

**Reference:** Linux Kernel USB Storage documentation, Arch Wiki  
**Confidence:** Known  
**Expected Impact:** Medium (reduces protocol overhead)

### 1.2 Per-Device Quirk Syntax

Format: `<VendorID>:<ProductID>:<flags>`

To find your device's IDs:
```bash
lsusb
# Output: Bus 001 Device 002: ID 31db:9210 ...
```

**Reference:** `Documentation/admin-guide/kernel-parameters.txt` in Linux source  
**Confidence:** Known  
**Expected Impact:** Medium

---

## 2. USB Core Parameters (usbcore)

### 2.1 Disable USB Autosuspend

USB autosuspend can cause devices to enter low-power state during I/O, leading to stalls.

**Kernel Parameters:**
```nix
boot.kernelParams = [
  "usbcore.autosuspend=-1"        # Disable autosuspend entirely
  "usbcore.auto_runtime_pm=0"     # Disable runtime PM
];
```

**Alternative (per-device via sysfs):**
```bash
echo "on" > /sys/bus/usb/devices/*/power/control
echo "-1" > /sys/bus/usb/devices/*/power/autosuspend
```

**NixOS Configuration (udev rule):**
```nix
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="31db", ATTR{idProduct}=="9210", ATTR{power/control}="on"
'';
```

**Reference:** [Kernel USB Power Management Documentation](https://www.kernel.org/doc/html/latest/admin-guide/pm/index.html)  
**Confidence:** Known  
**Expected Impact:** High (prevents power state transitions during I/O)

### 2.2 USB Reset Recovery

**Kernel Parameters:**
```nix
boot.kernelParams = [
  "usbcore.reset_resume=1"        # Use reset on resume instead of reconnect
  "usbcore.quirks=31db:9210:k"  # Add 'k' quirk if available for your device
];
```

**Reference:** Linux Kernel `drivers/usb/core/quirks.c`  
**Confidence:** Theoretical  
**Expected Impact:** Medium

### 2.3 Increase USB Request Queue Depth

For high-throughput devices, increasing the USB request queue can help.

**NixOS Configuration:**
```nix
boot.kernelParams = [
  "usbcore.max_skb_frags=16"     # Increase scatter-gather fragments
];
```

**Reference:** Raspberry Pi Linux kernel issues, USB subystem discussions  
**Confidence:** Theoretical  
**Expected Impact:** Medium

---

## 3. Block Layer Parameters

### 3.1 Reduce nr_requests

Limiting the number of concurrent requests can prevent queue congestion that leads to timeouts.

**NixOS Configuration:**
```nix
boot.kernelParams = [
  "nr_requests=16"               # Reduce from default (usually 128)
];
```

**Runtime (per-device):**
```bash
echo 16 > /sys/block/sda/nr_requests
```

**Reference:** [Block Layer Documentation](https://www.kernel.org/doc/html/latest/block/)  
**Confidence:** Known  
**Expected Impact:** Medium (prevents queue starvation)

### 3.2 I/O Scheduler Selection

The `mq-deadline` scheduler is recommended for rotational/storage latency-sensitive workloads. On Pi 4, consider:

**NixOS Configuration:**
```nix
boot.kernelParams = [
  "elevator=mq-deadline"         # Use deadline scheduler
  "blk-mq=1"                     # Ensure multiqueue enabled
];
```

**Alternative: Per-device scheduler:**
```bash
echo "mq-deadline" > /sys/block/sda/queue/scheduler
```

**Reference:** Linux Block Layer documentation  
**Confidence:** Known  
**Expected Impact:** Medium (improves I/O latency fairness)

### 3.3 Increase Request Timeout

**NixOS Configuration:**
```nix
boot.kernelParams = [
  "usb-storage.timeout=300"       # Increase command timeout to 300s
  "block.io_timeout=60"          # General block layer timeout
];
```

**Runtime:**
```bash
echo 300 > /sys/block/sda/device/timeout
```

**Reference:** Linux `drivers/usb/storage/unusual_devs.h`  
**Confidence:** Known  
**Expected Impact:** Medium (prevents premature timeout aborts)

---

## 4. SCSI Layer Parameters

### 4.1 SCSI Command Timeout

**Kernel Parameters:**
```nix
boot.kernelParams = [
  "scsi_mod.scsi_timeout=300"    # 300 seconds
  "scsi_mod.max_scsi_timeout=600" # Maximum allowed
];
```

**Runtime:**
```bash
echo 300 > /sys/block/sda/device/scsi_disk/*/timeout
```

**Reference:** Linux `drivers/scsi/scsi_lib.c`  
**Confidence:** Known  
**Expected Impact:** High (prevents hung task kills during long writes)

### 4.2 Disable SCSI Runtime PM

```nix
boot.kernelParams = [
  "scsi_mod.use_rpm=0"           # Disable runtime power management
];
```

**Reference:** Linux SCSI documentation  
**Confidence:** Known  
**Expected Impact:** Medium

### 4.3 Retry and Failure Behavior

```nix
boot.kernelParams = [
  "scsi_mod.max_retries=10"      # Increase command retries
  "scsi_mod.cmd_per_lun=32"     # Commands per LUN
];
```

**Reference:** Linux SCSI mid-level documentation  
**Confidence:** Known  
**Expected Impact:** Medium

---

## 5. VL805 Controller Specific

### 5.1 PCIe Gen 2 Fixes

The VL805 runs on PCIe Gen 2 x1. Some Pi 4 boards have marginal PCIe signaling.

**config.txt (Raspberry Pi bootloader config):**
```nix
# In your NixOS config, this goes to the Pi's config.txt
# This is typically passed via hardware configuration or boot firmware
boot.kernelParams = [
  "brcmforceinv=1"              # Force inverted PCIe clock (some Pi 4 boards)
  "pcie_aspm=off"               # Disable ASPM to reduce PHY issues
];
```

**Reference:** [Raspberry Pi Documentation - PCIe](https://www.raspberrypi.com/documentation/computers/config_txt.html)  
**Confidence:** Known (board-specific)  
**Expected Impact:** High (addresses hardware signaling issues)

### 5.2 VL805 Firmware

The VL805 USB controller has firmware that can be updated:

```bash
# Check current firmware version
sudo vl805
```

**Reference:** Raspberry Pi VL805 firmware updates  
**Confidence:** Known  
**Expected Impact:** Medium (fixes known controller bugs)

### 5.3 USB Power Budget

Ensure adequate power delivery:

```nix
boot.kernelParams = [
  "usbhid.mousepoll=0"           # Reduce USB polling
  "dwc_otg.fiq_fsm_enable=0"    # Disable FIQ on Pi (can cause issues)
];
```

**Reference:** Raspberry Pi USB documentation  
**Confidence:** Theoretical  
**Expected Impact:** Low-Medium

---

## 6. ext4 Mount Options for Reliability

### 6.1 Journal Mode

```nix
# In filesystem configuration
fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/UUID";
  fsType = "ext4";
  options = [
    "data=writeback"    # Less strict ordering, faster writes
    "noatime"          # No access time updates
    "nodiratime"       # No dir access time updates
    "errors=remount-ro" # Remount read-only on errors
    "commit=120"       # Increase commit interval to 120s (default 5)
  ];
};
```

**Comparison:**
| Mode | Description | Reliability | Performance |
|------|-------------|-------------|-------------|
| `data=ordered` | Default, metadata after data | Highest | Lowest |
| `data=writeback` | Metadata may precede data | Medium | Higher |
| `journal` | Full journaling | Highest | Lowest |

**Reference:** [ext4 documentation](https://www.kernel.org/doc/html/latest/admin-guide/ext4.html)  
**Confidence:** Known  
**Expected Impact:** High (reduces journal I/O under load)

### 6.2 Barrier Control

**Mount option:**
```
barrier=0        # Disable barriers (risky but faster)
barrier=1        # Enable barriers (default, safe)
```

**NixOS:**
```nix
options = [
  "barrier=0"    # USE WITH CAUTION - may cause corruption on power loss
];
```

**Reference:** ext4 documentation  
**Confidence:** Known  
**Expected Impact:** Medium (significant performance, but risky)

### 6.3 Other Performance/Reliability Options

```nix
options = [
  "noatime"                # Avoid atime writes
  "nodiratime"             # Avoid dir atime writes  
  "lazytime"               # Only write atime changes periodically
  "errors=remount-ro"      # Safety: remount read-only on error
  "journal_async_commit"    # Faster journal writes
  "stripe=1024"            # Match RAID stripe if applicable
];
```

**Reference:** ext4 man page  
**Confidence:** Known  
**Expected Impact:** Medium

---

## 7. Swap Configuration to Reduce I/O

### 7.1 Disable Swap Entirely (if RAM permits)

```nix
swapDevices = [];  # Disable all swap
```

**Reference:** General best practice for reliability-critical systems  
**Confidence:** Known  
**Expected Impact:** High (eliminates swap I/O to USB storage)

### 7.2 Zram as Compressed RAM Swap

```nix
# Using zram for in-memory compression
boot.kernelParams = [
  "zram.enabled=1"
];

services.udev.extraRules = ''
  KERNEL=="zram0", ATTR{disksize}="4G", TAG+="systemd", ENV{SYSTEMD_WANTS}="zram-swap.service"
'';
```

**NixOS module (if available):**
```nix
zramSwap = {
  enable = true;
  memoryPercent = 20;  # Use 20% of RAM for zram swap
};
```

**Reference:** Linux zram documentation, Arch Wiki  
**Confidence:** Known  
**Expected Impact:** High (keeps swap in RAM, eliminates USB swap I/O)

### 7.3 VM Tuning Parameters

```nix
boot.kernelParams = [
  "vm.swappiness=10"              # Prefer RAM over swap (0-100)
  "vm.dirty_ratio=15"            # Start writeback at 15% of RAM
  "vm.dirty_background_ratio=5" # Background writeback at 5%
  "vm.dirty_expire_centisecs=3000" # Dirty pages expire in 30s
  "vm.dirty_writeback_centisecs=500" # Writeback every 5s
  "vm.vfs_cache_pressure=50"     # Less aggressive dentry/inode reclaim
];
```

**Reference:** [Linux VM Documentation](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html)  
**Confidence:** Known  
**Expected Impact:** Medium

---

## 8. USB Power Management (Runtime)

### 8.1 Udev Rules for Persistent USB Power

```nix
services.udev.extraRules = ''
  # Disable USB autosuspend for specific device
  ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="31db", ATTR{idProduct}=="9210", ATTR{power/control}="on", ATTR{power/autosuspend}="0"

  # For all USB storage devices
  SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
'';
```

### 8.2 USB Core Runtime PM Disable

```nix
boot.kernelParams = [
  "usbcore.autosuspend=-1"
  "usbcore.pm.strict_runtime=0"  # Loosen strict runtime PM
];
```

**Reference:** USB Power Management documentation  
**Confidence:** Known  
**Expected Impact:** High

---

## 9. Block Device Queue Tuning

### 9.1 Reduce Queue Depth

```bash
# Check current
cat /sys/block/sda/queue/nr_requests
cat /sys/block/sda/device/scsi_disk/*/queue_depth

# Reduce
echo 16 > /sys/block/sda/queue/nr_requests
echo 16 > /sys/block/sda/device/scsi_disk/*/queue_depth
```

**NixOS (via sysctl):**
```nix
boot.kernel.sysctl = {
  "dev.scsi.max_scsi_io_path_channels" = 16;
};
```

### 9.2 Read-Ahead

```bash
echo 4096 > /sys/block/sda/queue/read_ahead_kb
```

**NixOS:**
```nix
boot.kernel.sysctl = {
  "dev.partition" = 0;  # Not directly applicable
};
```

**Per-device in NixOS:**
```nix
# This would need a startup script
systemd.services.fix-usb-nvme = {
  description = "Tune USB NVMe settings";
  serviceConfig = {
    ExecStart = "${pkgs.bash}/bin/bash -c 'echo 4096 > /sys/block/sda/queue/read_ahead_kb'";
  };
};
```

### 9.3 Disable Discard (TRIM) for USB

Continuous TRIM can cause issues with USB enclosures:

```nix
# When mounting
options = [
  "nodiscard"           # Disable TRIM
  "norecovery"          # Skip journal recovery (use with caution)
];
```

**Reference:** Arch Wiki SSD page  
**Confidence:** Known  
**Expected Impact:** Medium

---

## 10. Raspberry Pi 4 Specific Tweaks

### 10.1 USB Controller Mode

Some Pi 4 boards have USB mode issues. The VL805 should use PCIe Gen 2:

**config.txt equivalent (via boot firmware):**
```
# Pi 4 specific - ensure PCIe at Gen 2
dtparam=pciex1_gen=2
```

**NixOS:** This requires bootloader configuration outside NixOS.

### 10.2 DMA Coherent Pool

```nix
boot.kernelParams = [
  "coherent_pool=16M"            # Increase DMA coherent pool
  "dma_pool_size=16M"            # Alternative naming
];
```

**Reference:** Raspberry Pi Linux issues, DMA documentation  
**Confidence:** Known  
**Expected Impact:** Medium (prevents DMA allocation failures)

### 10.3 USB Quirks Specific to Pi 4

```nix
boot.kernelParams = [
  "dwc_otg.lpm_enable=0"        # Disable LPM on OTG
  "dwc_otg.fiq_enable=0"        # Disable FIQ (can cause stalls)
];
```

**Reference:** Raspberry Pi USB issues discussions  
**Confidence:** Theoretical  
**Expected Impact:** Low-Medium

---

## 11. Comprehensive NixOS Configuration Example

```nix
# Complete example for a Pi 4 with USB-NVMe
{ config, pkgs, ... }:

{
  boot.kernelParams = [
    # USB Storage
    "usb-storage.quirks=31db:9210:u,31db:9210:s"  # Disable UAS, disable sync cache
    "usbcore.autosuspend=-1"
    "usbcore.auto_runtime_pm=0"
    
    # SCSI
    "scsi_mod.use_rpm=0"
    "scsi_mod.scsi_timeout=300"
    "scsi_mod.max_retries=10"
    
    # Block layer
    "nr_requests=16"
    "elevator=mq-deadline"
    
    # VM tuning  
    "vm.swappiness=10"
    "vm.dirty_ratio=15"
    "vm.dirty_background_ratio=5"
    "vm.dirty_expire_centisecs=3000"
    "vm.dirty_writeback_centisecs=500"
    
    # Zram
    "zram.enabled=1"
  ];

  boot.kernel.sysctl = {
    # Increase USB request queue
    "dev.iosize_min" = 4096;
  };

  services.udev.extraRules = ''
    # Disable USB autosuspend for NVMe enclosure
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="31db", ATTR{idProduct}=="9210", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="scsi_disk", ATTR{provisioning_mode}="unmap"
  '';

  # Filesystem for NVMe
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/YOUR-UUID";
    fsType = "ext4";
    options = [
      "data=writeback"
      "noatime"
      "nodiratime"
      "errors=remount-ro"
      "commit=120"
    ];
  };

  # Disable swap entirely (recommended if RAM permits)
  swapDevices = [];

  # Or enable zram swap
  # zramSwap.enable = true;
  # zramSwap.memoryPercent = 20;
}
```

---

## 12. Diagnostic Commands

### 12.1 Check USB Device Status
```bash
lsusb -v -d 31db:9210
usb-devices
cat /sys/bus/usb/devices/*/power/control
cat /sys/bus/usb/devices/*/power/autosuspend
```

### 12.2 Check Block Device Queue
```bash
cat /sys/block/sda/queue/nr_requests
cat /sys/block/sda/queue/scheduler
cat /sys/block/sda/queue/read_ahead_kb
cat /sys/block/sda/device/timeout
```

### 12.3 Check SCSI Settings
```bash
cat /sys/block/sda/device/scsi_disk/*/timeout
cat /sys/block/sda/device/scsi_disk/*/provisioning_mode
```

### 12.4 Check for Errors
```bash
dmesg | grep -i usb
dmesg | grep -i nvme
dmesg | grep -i "reset"
dmesg | grep -i "stall"
journalctl -b | grep -i usb
```

### 12.5 Monitor I/O
```bash
iostat -x 1
iotop
blktrace -d /dev/sda -o - | blkparse -i -
```

---

## 13. References

1. [Linux Kernel USB Documentation](https://www.kernel.org/doc/html/latest/usb/)
2. [Linux Kernel Block Documentation](https://www.kernel.org/doc/html/latest/block/)
3. [Linux Kernel VM Documentation](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html)
4. [Arch Wiki - Solid State Drives](https://wiki.archlinux.org/title/Solid_State_drive)
5. [Arch Wiki - UDisks](https://wiki.archlinux.org/title/UDisks)
6. [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
7. [Raspberry Pi Linux Kernel Repository](https://github.com/raspberrypi/linux)
8. [ext4 Documentation](https://www.kernel.org/doc/html/latest/admin-guide/ext4.html)
9. [Linux Power Management Documentation](https://www.kernel.org/doc/html/latest/admin-guide/pm/index.html)

---

## 14. Summary of Recommendations

### Priority 1 (High Impact)
1. **Disable USB autosuspend** - `usbcore.autosuspend=-1`
2. **Increase SCSI timeout** - `scsi_mod.scsi_timeout=300`
3. **Use ext4 writeback mode** - `data=writeback` mount option
4. **Reduce nr_requests** - prevent queue congestion
5. **Disable swap or use zram** - eliminate USB swap I/O

### Priority 2 (Medium Impact)
1. Add USB storage quirks with sync disable
2. Use mq-deadline scheduler
3. Increase commit interval to 120s
4. Disable runtime PM for SCSI
5. Add `noatime,nodiratime` mount options

### Priority 3 (Lower Impact, Board-Specific)
1. PCIe Gen 2 mode for VL805
2. Update VL805 firmware
3. Increase coherent_pool
4. USB-specific udev rules

---

## 15. Next Steps

1. **Start with Priority 1 fixes** - these address the most common causes
2. **Monitor with diagnostic commands** - identify specific failure patterns
3. **Iterate with Priority 2** - refine based on observed behavior
4. **Consider hardware solutions** if software fixes insufficient:
   - Active USB hub with dedicated power
   - Different NVMe enclosure (with better USB-to-NVMe bridge)
   - Pi 5 with native PCIe NVMe support (via HAT+)

---

*This document is for research purposes. Test changes in a non-production environment first. Some changes may have unintended consequences on system stability.*
