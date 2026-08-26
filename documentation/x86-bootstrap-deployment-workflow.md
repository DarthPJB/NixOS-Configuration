# x86_64 Bootstrap Deployment Workflow

> **Last updated:** 2026-08-26
> **Status:** Active — GRUB EFI removable-media path required for USB boot

## Overview

x86_64 deployments use the assimilator-probe module for bootstrap images. The workflow mirrors ARM deployment but uses raw disk images (not ISOs), and consumes the assimilator-probe NixOS module for SSH, networking, discovery, and diagnostics.

**Two-stage process:**
1. **Bootstrap image** — generic, reusable, gets the device on the network
2. **Actual configuration** — device-specific, deployed over SSH via nixinate

## Stage 1: Build Bootstrap Image

The bootstrap image is a generic raw disk image for ALL x86_64 devices.

**Build:**
```bash
# Build raw disk image (GPT, 20GB, GRUB EFI removable)
nix build .#nixosConfigurations.x86-bootstrap.config.system.build.diskoImages --option builders '' --no-link --print-out-paths

# Output: /nix/store/...-x86-bootstrap-disko-images/main.raw (20GB sparse)
```

**What assimilator-probe provides:**
- SSH on port 1108 (all interfaces, 0.0.0.0)
- Users: John88 (console), deploy (nixinate), inspect (read-only)
- Avahi/mDNS discovery (`x86-bootstrap.local`)
- DHCP networking (eth0)
- Boot-time hardware diagnostics (`/run/diagnostics/hardware.json`)
- SSH login banner with probe identity
- kmscon console with hardware acceleration
- Ed25519-only SSH key enforcement
- No WireGuard — that's part of the actual config
- No baked host key — generated on first boot

**Write to bootable media:**
```bash
# USB flash drive (minimum 4GB, 8GB recommended)
# The image is sparse — dd will only write allocated blocks
dd if=main.raw of=/dev/sdX bs=4M status=progress conv=fsync
```

**Why raw disk, not ISO:**
ISO images are for optical media (CD/DVD). For USB boot, a GPT-partitioned raw disk image with GRUB installed to the removable-media path (`/EFI/BOOT/BOOTX64.EFI`) is required. UEFI firmware on USB does not look at `/grub/grub.cfg` alone.

**Bootloader contract:**
- `boot.loader.grub.efiSupport = true`
- `boot.loader.grub.efiInstallAsRemovable = true`
- `boot.loader.grub.device = "nodev"`
- `boot.loader.efi.canTouchEfiVariables = false`
- Verify after build: ESP must contain `EFI/BOOT/BOOTX64.EFI` plus `kernels/` and `grub/grub.cfg`

## Stage 2: Device Discovery

After booting the bootstrap image:

1. **Avahi/mDNS discovery:**
   ```bash
   avahi-resolve -n x86-bootstrap.local
   # Returns: x86-bootstrap.local	<device-ip>
   ```

2. **Or check DHCP leases** on your router/DHCP server

3. **Verify SSH access:**
   ```bash
   ssh -p 1108 John88@<device-ip>
   ```

4. **Check diagnostics (optional):**
   ```bash
   ssh -p 1108 deploy@<device-ip> "cat /run/diagnostics/hardware.json"
   ```

## Stage 3: Extract Host Key

The device has a fresh SSH host key generated at boot. Capture it for fleet known_hosts.

1. **Extract the host public key:**
   ```bash
   ssh -p 1108 deploy@<device-ip> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub"
   # Returns: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... root@x86-bootstrap
   ```

2. **Store the public key:**
   ```bash
   echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..." > secrets/public_keys/host_keys/<hostname>.pub
   ```

## Stage 4: Generate WireGuard Keys

Each device needs unique WireGuard keys.

1. **Generate key pair:**
   ```bash
   wg genkey | tee /tmp/wg-priv | wg pubkey > /tmp/wg-pub
   ```

2. **Encrypt private key with secrix:**
   ```bash
   cat /tmp/wg-priv | nix run .#secrix encrypt secrets/private_keys/wireguard/wg_<hostname> -- -u John88 -s <hostname>
   ```

3. **Store public key:**
   ```bash
   cp /tmp/wg-pub secrets/public_keys/wireguard/wg_<hostname>_pub
   ```

## Stage 5: Build Actual Configuration

1. **Create machine config** in `machines/<hostname>/default.nix`
2. **Register in flake.nix** (add to `nixosConfigurations`)
3. **Add to topology** with WireGuard IP and hub assignment
4. **Generate golden test:**
   ```bash
   nix run .#dump-config -- <hostname> | jq -S . > goldens/<hostname>.json
   ```

## Stage 6: Deploy

**Temporarily point flake.nix at the device's LAN IP:**

1. **Edit flake.nix** — change the host IP from WireGuard to LAN IP:
   ```nix
   # In the machine's mkX86_64 call:
   host = "<device-lan-ip>";  # e.g., "10.88.128.210"
   ```

2. **Deploy with nixinate:**
   ```bash
   nix run .#<hostname> -- switch
   ```

3. **Reset flake.nix** to WireGuard IP:
   ```nix
   host = topoIp "<hostname>";  # back to WG IP
   ```

4. **Commit and push:**
   ```bash
   git add flake.nix && git commit -m "deploy: reset <hostname> to WG IP"
   ```

## Stage 7: Verify

1. **Check WireGuard connectivity:**
   ```bash
   ping <wg-ip>
   ```

2. **Verify SSH on WG port:**
   ```bash
   ssh -p 1108 deploy@<wg-ip>
   ```

## Key Differences from ARM Bootstrap

| Aspect | ARM Bootstrap | x86 Bootstrap |
|--------|---------------|---------------|
| Image format | SD card (.img) | Raw disk (.raw, GPT) |
| Build target | `packages.aarch64-linux.arm-bootstrap` | `nixosConfigurations.x86-bootstrap.config.system.build.diskoImages` |
| SSH port | 22 | 1108 |
| Module source | Raw NixOS modules | assimilator-probe nixosModule |
| Cross-compilation | Yes (x86_64 → aarch64) | No (native x86_64) |
| Boot loader | extlinux (Raspberry Pi) | GRUB EFI removable (`EFI/BOOT/BOOTX64.EFI`) |
| Partition table | MBR (SD card) | GPT (raw disk) |
| Diagnostics | None | Boot-time hardware JSON |
| Banner | None | SSH login banner |
| kmscon | None | Hardware-accelerated console |

## Key Points

- **Bootstrap image is generic** — one image for ALL x86_64 devices
- **No WireGuard in bootstrap** — WG is part of the actual config
- **No baked host key** — generated on first boot (acceptable for bootstrap)
- **SSH on port 1108** — not port 22 (assimilator-probe default)
- **Deploy user must be trusted** — assimilator-probe sets `nix.settings.trusted-users = [ "deploy" ]`
- **Use `nix run .#<hostname> -- switch`** — nixinate handles SSH port and user
- **Diagnostics available at `/run/diagnostics/hardware.json`** — CPU, memory, disk, network
- **Raw disk image, not ISO** — ISOs are for optical media; raw disk images boot from USB
