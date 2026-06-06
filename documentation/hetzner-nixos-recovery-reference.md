# Hetzner Bare-Metal NixOS: Recovery & Debugging Reference

**Last updated:** 2026-06-06
**Context:** Written from experience recovering gaming-host-1 (Hetzner AX52, nvme0n1 476.9G Samsung) after a boot failure caused by systemd restart storms and ext2 filesystem corruption.

---

## 1. Getting into a NixOS Installer on a Hetzner Bare-Metal Server

Hetzner's rescue system is a minimal Linux environment — it has no Nix, no nixos-rebuild, and limited tooling. To get a proper NixOS environment for repair or installation, you need to boot a **NixOS kexec installer image**.

### Method: Self-kexec from Hetzner Rescue

This is the standard method for auction/dedicated servers. The reference implementation is:

> **Source:** [onnimonni/hetzner-auction-nixos-example](https://github.com/onnimonni/hetzner-auction-nixos-example)
>
> The key incite is that you can kexec from the rescue system into a nixos-installer image, then either run `nixos-anywhere` targeting `root@::1` (localhost) to do a full install, or use the installer environment for manual repair.

#### Step-by-step

```sh
# 1. Enable rescue mode in Hetzner Robot dashboard
# 2. Reboot the server (CTRL+ALT+DEL in Hetzner console)
# 3. SSH into rescue
ssh root@<PUBLIC_IP>

# 4. Download and extract the kexec installer
curl -L https://gh-v6.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz \
  | tar -xzf- -C /root

# 5. Execute kexec — this replaces the running kernel
/root/kexec/run
```

After `kexec/run` completes:
- The machine drops all SSH connections (the rescue kernel is replaced)
- The NixOS installer kernel boots in-memory (does not touch disk)
- Wait ~60-120 seconds for the new kernel to initialize
- SSH back in with the same `root@<PUBLIC_IP>` — you're now in a NixOS installer environment
- Verify with `uname -a` (kernel version will differ from rescue)

**Important notes:**
- The kexec image URL may change with nixos-unstable releases. If the link is 404, check the [nixos-images releases page](https://github.com/nix-community/nixos-images/releases) for the current `nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz`.
- The `gh-v6.com` mirror is used to avoid GitHub raw content access issues from Hetzner's network. If it's down, use `github.com` directly.
- This method is **non-destructive** — it boots entirely in RAM. The disk is untouched until you explicitly write to it.

### For a Full Fresh Install (from onnimonni's reference)

Once in the NixOS installer environment, you can run `nixos-anywhere` targeting localhost:

```sh
# From your local machine:
scp *.nix "root@<PUBLIC_IP>:/root/"
ssh -A root@<PUBLIC_IP>

# From the remote (now in NixOS installer):
nix --extra-experimental-features "flakes nix-command" \
  run github:nix-community/nixos-anywhere -- \
  --debug --print-build-logs \
  --flake .#myHost root@::1
```

---

## 2. Diagnostic Methods Used During gaming-host-1 Recovery

### 2.1 Filesystem Diagnosis

The rescue system provides basic filesystem tools. Use these to assess damage before attempting repair:

```sh
# Check filesystem type and state
file -sL /dev/nvme0n1p1
# ext2 filesystem — no journal (BAD for a root partition)

# Dry-run fsck to count errors without fixing
e2fsck -n /dev/nvme0n1p1
# Output showed: bitmap differences, inode errors, directory count mismatches

# Check disk usage
df -h /mnt
# 65G used / 455G total — NOT a disk-full situation

# Check what's consuming space
du -sh /mnt/var/lib/* 2>/dev/null | sort -rh | head -20
```

### 2.2 NixOS Boot Chain Verification

When a machine fails to boot, verify each layer of the boot chain from rescue:

```sh
mount /dev/nvme0n1p1 /mnt

# 1. GRUB in MBR
dd if=/dev/nvme0n1 bs=512 count=1 2>/dev/null | file -
# Should show: GRUB ... boot sector

# 2. Partition boot flag
fdisk -l /dev/nvme0n1
# Look for '*' or 'Boot' flag on the EFI/boot partition

# 3. GRUB config references correct UUID
cat /mnt/boot/grub/grub.cfg | grep 'search\|root='
# Compare UUID against actual partition UUID:
blkid /dev/nvme0n1p1

# 4. NixOS system profile exists and is valid
ls -la /mnt/nix/var/nix/profiles/system-12-link
readlink /mnt/nix/var/nix/profiles/system-12-link
# Points to /nix/store/...-nixos-system-gaming-host-1-25.11.20260207.23d72da

# 5. Kernel and initrd present in the profile
ls /mnt/nix/store/...-nixos-system-.../kernel/
ls /mnt/nix/store/...-nixos-system-.../initrd

# 6. init (stage-2-init) exists
ls -la /mnt/nix/store/...-nixos-system-.../init
# Should be a symlink to the NixOS init script

# 7. Hardware config matches actual hardware
cat /mnt/etc/nixos/hardware-configuration.nix
# Verify UUIDs match blkid output
```

### 2.3 Journal Analysis (from rescue)

If the system's journal is on the disk (not tmpfs), you can read it from rescue:

```sh
# Mount the root partition
mount /dev/nvme0n1p1 /mnt

# Read the last journal entries
journalctl -D /mnt/var/log/journal -e -n 50
# Or directly:
ls /mnt/var/log/journal/*/
journalctl --directory=/mnt/var/log/journal/<machine-id>/ -e

# What to look for:
# - Repeated service failures (restart storms)
# - "command not found" in ExecStartPre/ExecStart scripts
# - OOM kills
# - Filesystem errors
# - Last timestamp before silence
```

### 2.4 Checking for Restart Storms

A systemd service with `Restart=on-failure` and no `StartLimitBurst` will restart indefinitely:

```sh
# Count restarts in journal
journalctl -D /mnt/var/log/journal/ | grep -c "Started.*service-name"
# gaming-host-1 had 648 restarts

# Check restart counter
systemctl show service-name | grep NRestarts
# (only works if system is running)

# Look for the failure pattern
journalctl -D /mnt/var/log/journal/ | grep "rsync: command not found"
```

### 2.5 Ext2 → Ext4 Conversion (in-place)

If the root filesystem is ext2 (no journal), convert it to ext4 to prevent corruption on crash:

```sh
# MUST be done while filesystem is unmounted
umount /dev/nvme0n1p1

# Add journaling and ext4 features
tune2fs -O has_journal,extents,dir_index,uninit_bg /dev/nvme0n1p1

# Verify
file -sL /dev/nvme0n1p1
# Should now say: ext4 filesystem

# Run fsck to clean up after conversion
e2fsck -fy /dev/nvme0n1p1
```

### 2.6 NVMe Health and Trim

```sh
# Check NVMe health
nvme smart-log /dev/nvme0n1

# Run TRIM to reclaim unused blocks (important for SSD longevity)
fstrim -v /mnt
# gaming-host-1 reclaimed 390 GB
```

### 2.7 Data Backup from Rescue

When you need to pull data off a broken system:

```sh
# On the rescue system, mount the data partition
mount /dev/nvme0n1p1 /mnt

# Use rsync with resume support and no timeouts
rsync -avP --timeout=0 \
  /mnt/var/lib/private/gameserver/ \
  user@linda:/bulk-storage/recovery/

# Verify byte-for-byte
rsync -avn --delete /mnt/source/ user@linda:/dest/ | tail -5
```

---

## 3. Kexec from Rescue into Existing NixOS (Diagnostic)

When you want to test if the installed NixOS kernel can boot without modifying the MBR/GRUB chain:

```sh
# From rescue, mount the NixOS partition
mount /dev/nvme0n1p1 /mnt

# Find the kernel and initrd from the active profile
PROFILE=$(readlink /mnt/nix/var/nix/profiles/system)
KERNEL=$(find /mnt${PROFILE}/kernel -name bzImage | head -1)
INITRD=$(find /mnt${PROFILE} -name initrd | head -1)

# Extract root= UUID
ROOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p1)

# Kexec into the NixOS kernel
kexec -l "$KERNEL" --initrd="$INITRD" \
  --append="init=${PROFILE}/init root=UUID=${ROOT_UUID} console=ttyS0,115200"

# Replace the running kernel
kexec -e
```

**Interpreting results:**
- If NixOS comes up → boot chain (GRUB/BIOS) is the problem, not the kernel
- If NixOS does NOT come up → kernel, initrd, or init is broken (check `console=ttyS0` output via Hetzner KVM)
- If kexec itself fails → kernel/initrd are corrupt or incompatible with rescue kernel version

**This is a destructive diagnostic** — it kills the rescue session. The machine should come back either as NixOS or as rescue (Hetzner watchdog), but there's a window of unavailability.

---

## 4. Common Pitfalls

| Pitfall | What Happened | Prevention |
|---|---|---|
| Bare `rsync` in ExecStartPre | `rsync: command not found` → exit 127 → restart loop | Always use `${lib.getExe pkgs.rsync}` |
| No `StartLimitBurst` on systemd service | Unlimited restarts → 648 in 2.7 hours → filesystem corruption | Always set `StartLimitBurst = 5` and `StartLimitIntervalSec = 600` |
| ext2 root filesystem | No journal → fsck required on every crash → blocks boot for hours | Use ext4 (or btrfs/zfs) with journaling |
| Single root partition | No separate /var or /home → all data on one fs → full backup requires mounting entire root | Consider separate partitions for data |
| No emergency SSH | WireGuard-only SSH access → if WG is down, only Hetzner console | Keep at least one non-WG SSH access path |
| Hardcoded `start.sh` path | Builder didn't create the file → ExecStart fails | Builder must create the symlink it references |

---

## 5. Hetzner-Specific Notes

### Rescue System
- Accessed via Hetzner Robot dashboard → "Rescue" → enable → reboot
- SSH key is reset on each rescue boot (host key changes)
- Runs a minimal Linux (kernel 6.12.x typically) with basic tools
- Has `kexec`, `e2fsck`, `tune2fs`, `rsync`, `nvme` CLI
- **No** Nix, no `nixos-rebuild`, no `systemctl`

### KVM Console
- Available via Hetzner Robot → "KVM"
- Provides serial/VGA console access for watching boot messages
- Essential for diagnosing kernel panics that happen before SSH starts
- Use `console=ttyS0,115200` in kernel args to get serial output

### Disk Layout (typical auction server)
- `/dev/nvme0n1` — primary NVMe (OS)
- `/dev/nvme1n1` — secondary NVMe (unused until configured)
- Partition table: GPT or MBR depending on installer
- Hetzner's default install uses ext4 — our server had ext2 (likely a migration artifact)

### Network
- Public IP assigned via DHCP or static (check `/etc/network/interfaces` in rescue)
- Hetzner vSwitch / private network available if configured
- WireGuard works fine but should not be the ONLY access path

---

## References

- [onnimonni/hetzner-auction-nixos-example](https://github.com/onnimonni/hetzner-auction-nixos-example) — Method for installing NixOS on Hetzner auction servers via kexec self-install
- [nix-community/nixos-images](https://github.com/nix-community/nixos-images) — Source of the kexec installer tarballs
- [nix-community/nixos-anywhere](https://github.com/nix-community/nixos-anywhere) — Automated NixOS installation tool
- [gaming-host-1 incident report](./incident-report-gaming-host-1-2026-06-05.md) — Full timeline and root cause analysis of the incident that generated these notes
