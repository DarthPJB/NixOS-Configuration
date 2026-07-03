# rPi4 USB-NVMe Boot Methods — Research Report

> **Date:** 2026-07-01
> **Researcher:** general-purpose research agent
> **Purpose:** Determine the most reliable boot method for a Pi 4 ARM builder that
> needs `/nix/store` and swap on USB-connected NVMe. Input to
> [arm-builder-bootstrap-2026-07-01.md](../plans/arm-builder-bootstrap-2026-07-01.md).

## Critical Terminology Correction

On a stock **Pi 4B**, a USB-attached NVMe enclosure is an ordinary **USB Mass Storage
Device (USB-MSD, boot mode `0x4`)**. The `[NVMe SSD boot]` documentation section and boot
mode `0x6` apply **only** to NVMe attached over the **PCIe** lane (CM4 IO board, Pi 5 +
M.2 HAT+). The Pi 4B has no exposed PCIe, so a "USB NVMe" setup is plain USB-MSD boot for
purposes of the bootloader. Historical unreliability is almost always about the USB
bridge chip / UAS / power, not the NVMe controller.

---

## 1. rPi4 EEPROM USB-MSD boot status (2024-2026)

**Verdict: STABLE / production-ready**

- USB mass storage boot on Pi 4 is "supported by default" once `BOOT_ORDER` includes mode `4`.
- **Current default EEPROM for BCM2711:** `2026-05-26` (promotes `2026-05-17` build,
  Broadcom DDR firmware 2.35). Use the latest default — do not pin an old version.
- **Minimum for reliable USB boot:** Anything from `2022-01-25` default onward. For
  USB-bridge quirks: `2024-07-30` ("USB boot fixes for CM4-S") and `2024-09-05` are
  the relevant recent interop fixes.
- **Known reliability issues (environmental, not firmware bugs):**
  1. **UAS vs USB-Botbridge flip** — a bridge the EEPROM boots fine can drop out after
     Linux switches to UAS; often fails on **reboot** not cold boot.
  2. **Power** — NVMe enclosures drawing > Pi USB budget → intermittent enumeration.
     Use powered enclosure/hub or `usb_max_current_enable=1` (PID 5 documented; Pi4 advisory).
  3. **Enumeration timeout** — default USB-MSD discovery is 2 seconds; slow spin-up
     bridges may need longer.
  4. **Bridge-chip quirks** — cheap JMS583/ASM2362 bridges have firmware quirks; EEPROM
     has accumulated per-bridge interop fixes.

**Bottom line:** Modern firmware + quality bridge + adequate power = reliable.

---

## 2. USB Boot Configuration

**Verdict: STABLE / well-documented**

- **NOT the old `bootorder.bin` / OTP flow** — that's Pi 3. On Pi 4, boot order lives in
  the **EEPROM config block** as a `BOOT_ORDER` property.
- Configure via: `sudo raspi-config` → Advanced → Boot Order → "USB Boot", **or**
  `sudo rpi-eeprom-config --edit` and set the `BOOT_ORDER` line.
- `BOOT_ORDER` values: `0x1`=SD, `0x4`=USB-MSD, `0x6`=NVMe-PCIe (CM4/Pi5 only — NOT Pi 4B),
  `0xf`=RESTART.
- Example EEPROM config:
  ```ini
  BOOT_ORDER=0xf41   # default: SD → USB-MSD → restart
  BOOT_ORDER=0xf14   # force USB when SD present: USB → SD → restart
  BOOT_ORDER=0xf4    # USB only
  ```
- NixOS provides `pkgs.raspberrypi-eeprom` for the tooling.

---

## 3. u-boot on rPi4 + USB-NVMe chainload

**Verdict: WORKS, but offers little over rPi firmware for this use case**

- NixOS rPi4 path uses `u-boot-rpi4.bin` as kernel in FAT firmware partition, with
  `generic-extlinux-compatible.enable = true`. u-boot reads `extlinux.conf` and loads
  mainline kernel + initrd.
- u-boot on BCM2711 **can** enumerate USB-MSD, so SD-u-boot → USB-rootfs is technically
  supported. **However**, u-boot's own USB stack has historically had *more* quirks with
  NVMe bridges than the EEPROM's USB-MSD scanning.
- **Not the recommended path.** Prefer rPi firmware to load bootloader from USB device
  directly (pure USB-MSD), or extend EEPROM's USB-MSD timeout.
- **Known issue:** kernel may try to mount root before USB device ready. Mitigations:
  ensure `xhci_pci`/`uas`/`usb_storage`/`nvme` in `boot.initrd.availableKernelModules`
  (or import `profiles/all-hardware.nix`), prefer label/PARTUUID with udev settle.

---

## 4. SD Bootloader + USB-NVMe Rootfs Pivot

**Verdict: MORE RELIABLE — RECOMMENDED**

- **Why more reliable:** every flaky USB link (enumeration, bridge quirks, power timing)
  only has to succeed *once*, late, during initrd root-mount — which Linux retries and
  waits for. The bootloader (rPi `start.elf` + u-boot) reads SD FAT, which always works;
  only the rootfs mount (and swap) touch USB. initrd retry logic is far more robust than
  one-shot EEPROM scanning.
- **NixOS does NOT ship a turn-key "FAT-on-SD + root-on-USB" image module.** Assemble from:
  1. Build standard aarch64 SD image (`sd-image-aarch64.nix`) — MBR image with FAT
     `/boot/firmware` + ext4 root.
  2. Override root target: `sdImage.rootVolumeLabel = "NIXOS_USB"` → format the USB-NVMe
     partition ext4 with label `NIXOS_USB`; generated `extlinux.conf` `root=` targets it.
  3. Keep **FAT firmware partition on SD card**. For maximum reliability, keep `/boot`
     (extlinux + kernel + initrd) **on the SD card** too — only `/` (i.e. `/nix/store`,
     swap) on USB. Nothing at boot time depends on USB except initrd root mount.
- **Caveat:** `generic-extlinux-compatible` writes extlinux into the *root filesystem's*
  `/boot`. Replicating kernel/initrd onto the SD `/boot` on every `nixos-rebuild` requires
  either mirroring `/boot` to the SD or customizing `populateRootCommands`. This is the one
  non-turn-key piece — and the same wart every Pi 4 + USB user hits.

---

## 5. NixOS-Specific Patterns

**Verdict: STABLE community patterns exist; no first-class USB-NVMe module**

- `sd-image-aarch64.nix` does **not** target USB — but the whole image can be `dd`'d to
  the USB SSD instead of the SD card, and Pi 4 EEPROM boots it as USB-MSD. **This is the
  accepted, verified method** on NixOS Discourse (topic 34522, accepted answer):
  ```bash
  sudo dd if=result/sd-image/*.img of=/dev/sdX bs=64k status=progress
  ```
- Required for USB root: import `profiles/all-hardware.nix` (or manually put
  `xhci_pci`, `uas`, `usb_storage`, `nvme`, `pcie-brcmstb` into
  `boot.initrd.availableKernelModules`). `sd-image.nix` sets
  `hardware.enableAllHardware = true` which pulls in `all-hardware.nix` — so the stock
  image usually Just Works for USB root.
- **Alternative: PFTF UEFI firmware** (mainline kernel, systemd-boot) — puts
  [pftf/RPi4](https://github.com/pftf/RPi4) UEFI firmware on USB SSD's FAT ESP, uses
  `boot.loader.systemd-boot.enable = true`, GPT disk. Still USB-MSD boot at the EEPROM
  level; gives vanilla NixOS bootloader stack + mainline kernel. **GPIO pins not
  functional** with this stack on mainline kernel.
- `nixos-hardware/raspberry-pi/4/default.nix` sets `generic-extlinux-compatible.enable =
  true`; no USB-specific option.

**Bottom line:** Verified pattern exists (dd stock image to USB SSD). No NixOS module
for "bootloader-on-SD, root-on-USB" split image — assemble from
`sdImage.rootVolumeLabel` + `fileSystems` overrides.

---

## 6. Partition Layout / Bootloader Requirements

**Verdict: VERIFIED**

- **Partition table:** `sd-image.nix` builds **MBR** (DOS label). rPi bootloader supports
  MBR and GPT (release notes `2024-10-10` removes GPT array location requirement).
  For PFTF UEFI route, use **GPT** with ESP.
- **Firmware partition:** Must be **FAT** (FAT32; FAT16 supported since `2021-10-04`).
  `sd-image.nix`: vfat, label `FIRMWARE`, ~30 MiB, MBR type `0x0b`.
- **Root:** ext4 by default; btrfs drop-in via `sdImage.rootFilesystemCreator`.
- **Does boot partition need FAT32 on SD if root is on USB?** **Yes, the FAT firmware
  partition must exist** on whatever device the rPi firmware reads from. Linux root +
  `/nix/store` can be ext4/btrfs on USB; FAT partition is *only* for bootloader artifacts
  (`config.txt`, `start4.elf`, `fixup4.dat`, `u-boot-rpi4.bin`, DTBs).

---

## Recommendation

### Primary: "SD Bootloader + USB-NVMe Rootfs" (Option A)

Most defensible for production-infrastructure correctness — the only USB-dependent step is
the initrd root-mount, which Linux retries.

**Concrete NixOS steps:**
1. **Flash latest EEPROM** to the Pi 4 (default `2026-05-17/05-26` or newer).
   Set `BOOT_ORDER=0xf41` (SD bootloader first; USB for root only).
2. **Build** aarch64 SD image via `sd-image-aarch64.nix` (import
   `nixos-hardware.nixosModules.raspberry-pi-4` for DT/kernel). Keep
   `hardware.enableAllHardware = true` so USB/xhci/uas/nvme are in initrd.
3. **Point root at USB:** set `sdImage.rootVolumeLabel = "NIXOS_USB"` (or override
   `fileSystems."/".device` to `/dev/disk/by-label/NIXOS_USB`). Format the USB-NVMe
   partition ext4 with label `NIXOS_USB`. Generated extlinux `root=` targets USB.
4. **Known-good bridge/power:** ASM2362 or quality JMS583 enclosure, **externally
   powered**. If bridge flaps under UAS, disable via
   `usbcore.quirks=<vid>:<pid>:u` in `boot.kernelParams`.
5. **Separate boot artifacts:** Write SD card's FAT/`/boot` from built image; put root
   ext4 (with `/nix/store`) on USB-NVMe. To keep `/boot` (kernel+initrd+extlinux) on SD
   for zero USB dependency at boot, mirror SD `/boot` after each `nixos-rebuild`
   (custom `postBuildCommands`/activation script — the one non-turn-key piece).

### Fallback: Pure USB-MSD

If SD-bootloader USB-root proves flaky: `dd` the entire `sd-aarch64` image onto the USB
NVMe (FAT firmware partition lives on the USB device), as Discourse 34522 accepted-answer
users do. Equivalent reliability with current EEPROM + good bridge. Avoid relying on
u-boot's own USB enumeration.

### Avoid

- Boot mode `0x6` (NVMe) — does not exist on stock Pi 4B.
- Old `bootorder.bin` / `program_usb_boot_mode=1` OTP flow — that's Pi 3, not Pi 4.

---

## Sources

- Official Raspberry Pi documentation (boot modes, EEPROM, BOOT_ORDER, USB mass storage boot)
- `raspberrypi/rpi-eeprom` firmware-2711 release notes (through 2026-05-26)
- `NixOS/nixpkgs` `sd-image-aarch64.nix` + `sd-image.nix` + `make-ext4-fs.nix`
- `NixOS/nixos-hardware` `raspberry-pi/4/default.nix`
- NixOS Discourse topics: 34522 (accepted answer), 50798, 16866
- Community configs: `kotatsuyaki/rpi4-usb-uefi-nixos-config`, `eisfunke.com`,
  `carjorvaz.com`, `mtlynch.io`

## Unverifiable Items (honest disclosure)

- Could not find an authoritative vendor "USB-NVMe on Pi 4B is production-grade" statement.
  The "stable" verdict synthesizes: default-on support + accumulated interop fixes through
  2026-05 + multiple independent verified user reports. Not an explicit vendor SLA.
- **If zero variance required:** validate *your specific bridge + SSD combo* on a golden
  harness before committing.