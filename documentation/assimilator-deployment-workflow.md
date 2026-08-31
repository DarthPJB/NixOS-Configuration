# Assimilator Deployment Workflow — Corrected Methodology

> **Last updated:** 2026-08-30
> **Status:** Active — replaces the flawed Stage 3 host-key extraction in `x86-bootstrap-deployment-workflow.md`
> **Scope:** x86_64 machines assimilated via the assimilator-probe workflow

## Purpose

This document codifies the **correct three-step deployment methodology** for machines
assimilated via the assimilator-probe x86-bootstrap workflow. It replaces the flawed
host-key extraction step (Stage 3) in `x86-bootstrap-deployment-workflow.md`, which
incorrectly assumes the probe's transient, auto-generated SSH host key can serve as
the permanent device identity.

**The probe's host key is NOT a valid device identity.** The production probe image
(`machines/x86-bootstrap/default.nix`) does not set `assimilator.hostKey.privateKeyFile`,
so sshd auto-generates a host key on first boot. This key lives in mutable `/etc/ssh/`
(not the Nix store), is unverified, and belongs to a throwaway bootstrap — not the
permanent host. Committing it to `secrets/public_keys/host_keys/` would propagate an
unverified, hallucinated device identity.

---

## The Three-Step Process

```
┌─────────────────────────────────────────────────────────────────────┐
│  Step 1: ASSIMILATOR          (probe boots, HW discovered)         │
│  Step 2: NIXOS-INSTALL        (base system → permanent storage)    │
│  Step 3: NIXINATE DEPLOY      (fleet config deployed to base)      │
└─────────────────────────────────────────────────────────────────────┘
```

**Key principle:** The real device-identity keys (SSH host key, WireGuard keypair) are
generated **during Step 2** — as a deliberate post-install act on the permanent system.
They are NEVER carried over from the transient probe.

---

## Step 1 — Assimilation (Probe Discovery)

**Goal:** Boot the assimilator probe on the target hardware, discover the hardware,
gather diagnostics. The probe is a **throwaway bootstrap** — its keys, hostname, and
identity are irrelevant to the permanent system.

### 1.1 Build the Bootstrap Image

```bash
# Build raw disk image (GPT, GRUB EFI removable)
nix build .#nixosConfigurations.x86-bootstrap.config.system.build.diskoImages \
  --option builders '' --no-link --print-out-paths

# Write to USB flash drive (minimum 4GB)
dd if=main.raw of=/dev/sdX bs=4M status=progress conv=fsync
```

### 1.2 Boot and Discover

1. Insert USB into the target machine, boot from it.
2. **mDNS discovery:** `avahi-resolve -n x86-bootstrap.local` → device IP.
3. **SSH access:** `ssh -p 1108 deploy@<device-ip>` (fleet keys authorized).
4. **Diagnostics:** `cat /run/diagnostics/hardware.json` — CPU, RAM, disks, NICs.

### 1.3 Gather Hardware Details

From the running probe, capture the information needed for Step 2:

| Item | Command | Purpose |
|------|---------|---------|
| Disk layout | `lsblk -f` | Partition UUIDs, sizes, filesystems |
| NIC MAC | `ip link show enp86s0` | DHCP reservation |
| CPU/RAM | `lscpu`, `free -h` | Hardware verification |
| NVMe details | `fdisk -l /dev/nvme0n1` | Target storage layout |
| Host key (probe) | `sudo cat /etc/ssh/ssh_host_ed25519_key.pub` | **Reference only — NOT for committing** |

### 1.4 What NOT to Do

- **DO NOT** commit the probe's SSH host key to `secrets/public_keys/host_keys/`.
  It is auto-generated, unverified, and belongs to a throwaway bootstrap.
- **DO NOT** generate WireGuard keys for the probe. The probe has no WireGuard.
- **DO NOT** register the machine in `flake.nix` yet. No host key exists.

---

## Step 2 — `nixos-install` a Base System

**Goal:** Install a minimal NixOS base system to permanent storage. **This install
generates the real device-identity keys post-install.**

### 2.1 Prepare the Target Storage

The target storage (typically NVMe) must be **wiped and repartitioned fresh**.
The assimilator-probe's DISKO image may have left stale partitions with colliding
UUIDs (e.g., `nvme0n1p1` sharing UUID `12CE-A600` with the USB boot ESP).

**Partition ordering — EFI, Swap, Data (data at the end of the disk):**

| Partition | Size | Type | Purpose |
|-----------|------|------|---------|
| `nvme0n1p1` | ~1G | EFI System (vfat) | ESP — GRUB EFI removable |
| `nvme0n1p2` | ~16G | Linux swap | Swap |
| `nvme0n1p3` | remaining | Linux filesystem (ext4) | Root filesystem |

**Why this ordering:** EFI at the start for bootloader compatibility. Swap second
(fixed size, predictable). Data at the end (takes all remaining space, can be
resized later if needed). This matches the standard GPT layout convention.

**All UUIDs must be freshly generated.** Do not reuse any UUIDs from the USB image.

```bash
# From the running probe via SSH (deploy user, then sudo -i)
# parted is not in the probe's PATH — use nix-shell to get it
sudo nix-shell -p parted --run "parted /dev/nvme0n1"

# Inside parted:
mklabel gpt
mkpart esp 1MB 1024MB
mkpart linux-swap 1024MB 16GB
mkpart ext4 16GB 100%
quit

# Set the ESP flag
sudo nix-shell -p parted --run "parted /dev/nvme0n1 -- set 1 esp on"

# Format (requires root — sudo -i)
sudo -i
mkfs.fat -F 32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
mkfs.ext4 /dev/nvme0n1p3

# Mount
mkdir -p /mnt/boot
mount /dev/nvme0n1p3 /mnt
mount /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p2
```

### 2.2 Define a Minimal Base Config

The base config is **minimal** — CLI + OpenSSH + fleet public-key auth. It does NOT
contain the full pillar-of-autum fleet config (that comes in Step 3).

**Minimal base config requirements:**

- `boot.loader.grub` — GRUB EFI removable (matches the USB bootstrap bootloader)
- `networking.hostName` — the permanent hostname (e.g., `pillar-of-autum`)
- `networking.useDHCP = true` — DHCP on all interfaces
- `services.openssh.enable = true` — SSH daemon
- `services.openssh.ports = [ 1108 ]` — match fleet SSH port
- `services.openssh.settings.PasswordAuthentication = false` — key-only
- `users.users.deploy` — deployment user with fleet SSH keys authorized
- `users.users.John88` — operator user with fleet SSH keys authorized
- `security.sudo.extraRules` — passwordless sudo for deploy
- `nix.settings.trusted-users = [ "deploy" ]` — nixinate requirement
- `nix.settings.experimental-features = [ "nix-command flakes" ]`
- `hardware.enableRedistributableFirmware = true`

**Public keys to authorize** (from `secrets/public_keys/`):
- `JOHN_BARGMAN_ED_25519.pub` — operator key
- `INSPECT_ED_25519.pub` — inspect key (if needed)

### 2.3 Generate Hardware Config and Install

```bash
# Generate hardware config (captures NVMe UUIDs, not USB)
nixos-generate-config --root /mnt

# Replace /mnt/etc/nixos/configuration.nix with the minimal base config
# The generated config has wrong defaults (systemd-boot, NetworkManager).
# Overwrite it entirely with the minimal base config (see §2.2).

# Install (set root password when prompted at the end)
nixos-install
```

**Notes:**
- Do NOT use `--option builders ''` for `nixos-install` — it is a local build,
  not a remote one. The `--option builders ''` flag is only for `nix run`/`nix eval`
  commands that may try to connect to remote builders.
- Do NOT use `--no-root-passwd` — set the root password manually at the end of
  the install. This is the only password on the system and the operator must know it.
- The `nixos-install` command will build the system closure and install it to `/mnt`.
  On first boot, the fresh system generates its own SSH host key.

### 2.4 Post-Install: Generate Real Keys

After `nixos-install` completes, **boot the NVMe system** (set EFI boot variable
or remove the USB). The fresh system generates its own SSH host key on first boot.

**Then, on the running NVMe system:**

1. **Retrieve the real SSH host key:**
   ```bash
   ssh -p 1108 deploy@<host-ip> "cat /etc/ssh/ssh_host_ed25519_key.pub"
   ```

2. **Generate a WireGuard keypair (single command — validated 2026-08-31):**
   ```bash
   wg genkey | tee >(wg pubkey > secrets/public_keys/wireguard/wg_pillar-of-autum_pub) | nix run .#secrix -- encrypt secrets/private_keys/wireguard/wg_pillar-of-autum -- --all-users --all-systems
   ```
   This single command:
   - `wg genkey` — generates the private key, outputs to stdout (never touches disk)
   - `tee >(wg pubkey > ...)` — duplicates the stream: one copy derives the public
     key → `secrets/public_keys/wireguard/wg_pillar-of-autum_pub`; the other continues
   - `nix run .#secrix -- encrypt ... -- --all-users --all-systems` — reads the
     private key from stdin, age-encrypts it → `secrets/private_keys/wireguard/wg_pillar-of-autum`

   **Recipients:**
   - `--all-users` — John88's key (manual decryption possible)
   - `--all-systems` — all host keys incl. pillar-of-autum (machine decrypts at runtime
     via `secrix.services.wireguard-wireg0`)

   **The private key never touches disk as plaintext.**

   **Verify:**
   ```bash
   # Public key: 45 bytes, valid WireGuard format
   ls -la secrets/public_keys/wireguard/wg_pillar-of-autum_pub
   # Encrypted private key: age-encrypted (header: age-encryption.org/v1)
   ls -la secrets/private_keys/wireguard/wg_pillar-of-autum
   ```

### 2.5 Manual Verification (MANDATORY)

**Before committing any key, manually verify the host's identity:**

- **SSH host key:** Compare the fingerprint retrieved via SSH against the fingerprint
  displayed on the **physical console** (or via another trusted out-of-band channel).
  ```bash
  # Via SSH
  ssh -p 1108 deploy@<host-ip> "ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub"
  # On physical console
  ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
  # Fingerprints MUST match
  ```

- **WireGuard public key:** Verify the public key corresponds to the private key
  that was encrypted (secrix decrypt + `wg pubkey` comparison).

**DO NOT commit any key that has not been manually verified.**

---

## Step 3 — `nixinate` Deploy

**Goal:** Deploy the full fleet configuration to the base system via nixinate.

### 3.1 Register the Machine

**Only after Step 2 yields verified keys.** Register in `flake.nix`:

```nix
pillar-of-autum = mkX86_64 "pillar-of-autum" {
  host = topoIp "pillar-of-autum";
  extraModules = [
    xlibre-overlay.nixosModules.overlay-xlibre-xserver
    xlibre-overlay.nixosModules.overlay-all-xlibre-drivers
  ];
};
```

The `hostPubKey` default (`builtins.readFile ./secrets/public_keys/host_keys/pillar-of-autum.pub`)
now resolves because the verified key exists from Step 2.

### 3.2 Add Topology

Create `topology/pillar-of-autum.json` with WG peer ID and LAN coordinate.
The `public_key_file` must point to the real WG public key from Step 2.

### 3.3 Deploy

```bash
# Temporarily point at LAN IP (the base system is on the LAN, not yet WG)
# Edit flake.nix: host = "10.88.128.150"

# Deploy
nix run .#pillar-of-autum --option builders '' -- switch

# Reset to WG IP
# Edit flake.nix: host = topoIp "pillar-of-autum"
```

### 3.4 Verify

1. **WireGuard connectivity:** `ping 10.88.127.110`
2. **SSH on WG:** `ssh -p 1108 deploy@10.88.127.110`
3. **Headed session:** lightdm + i3 (XLibre) on the attached display
4. **Golden:** `nix run .#validate-goldens -- pillar-of-autum --option builders ''`

---

## Why the Existing Workflow Is Wrong

The documented workflow in `x86-bootstrap-deployment-workflow.md` Stage 3 says:

> **Stage 3: Extract Host Key**
> The device has a fresh SSH host key generated at boot. Capture it for fleet known_hosts.

This is **architecturally wrong** for three reasons:

1. **The probe's host key is transient.** The production probe image
   (`machines/x86-bootstrap/default.nix`) does not set `assimilator.hostKey.privateKeyFile`.
   sshd auto-generates a key on first boot. This key lives in mutable `/etc/ssh/`
   (not the Nix store) and belongs to a throwaway bootstrap.

2. **The probe's host key is unverified.** No manual out-of-band verification was
   performed. Committing it would propagate an unverified device identity — the same
   class of error as committing agent-generated WireGuard keys.

3. **The probe's host key does not survive `nixos-install`.** When the base system
   is installed to permanent storage, it generates its own fresh host key. The probe's
   key is discarded with the bootstrap image.

**The correct flow:** keys are generated **during Step 2** (post-install), manually
verified, then committed. The probe is discarded.

---

## Checklist Summary

| Phase | Action | Who | Blocks |
|-------|--------|-----|--------|
| **A** | Assimilation — probe boots, HW discovered | Agent | — |
| **B** | DHCP reservation in `topology/cortex-alpha.json` | Agent | — |
| **C** | `nixos-install` base system to NVMe | **User** | D |
| **D** | Capture + manually verify real SSH host key + WG keys | **User** | E |
| **E** | Register in `flake.nix` + topology + golden + fleet goldens | Agent | F |
| **F** | `nixinate` deploy + verify | Agent+User | — |

**No secret assets are created without manual user verification.**
**No machine is registered in `flake.nix` until a verified host key exists.**
**The probe's transient keys are NEVER committed.**
