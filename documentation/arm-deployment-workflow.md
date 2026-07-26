# ARM Deployment Workflow

> **Last updated:** 2026-07-02
> **Status:** Active — validated through arm-builder deployment

## Overview

ARM deployments use a two-stage process:
1. **Bootstrap image** — generic, reusable, gets the device on the network
2. **Actual configuration** — device-specific, deployed over SSH

This separates hardware provisioning from configuration management.

## Stage 1: Bootstrap Image

The bootstrap image (`.#packages.aarch64-linux.arm-bootstrap`) is a generic, one-shot image for ALL ARM devices.

**What it provides:**
- Open SSH on port 22 (all interfaces, 0.0.0.0)
- Users: John88, deploy, inspect
- Avahi/mDNS discovery (`nixos-bootstrap.local`)
- No WireGuard — that's part of the actual config
- Cross-compiled from x86_64, minimal closure
- `nix.settings.trusted-users = [ "deploy" ]` — required for nixos-rebuild to copy closures

**Build and flash:**
```bash
# Build
nix build .#packages.aarch64-linux.arm-bootstrap --no-link --print-out-paths

# Flash to SD card (minimum 4GB, 8GB recommended)
dd if=<path>/sd-image/nixos-*-aarch64-linux.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## Stage 2: Device Discovery

After booting the bootstrap image:

1. **Avahi/mDNS discovery:**
   ```bash
   # From any machine on the same network (cortex-alpha has Avahi configured)
   avahi-resolve -n nixos-bootstrap.local
   # Returns: nixos-bootstrap.local	<device-ip>
   ```

2. **Or check DHCP leases** on your router/DHCP server

3. **Verify SSH access:**
   ```bash
   ssh -p 22 John88@<device-ip>
   ```

## Stage 3: Extract Host Key

The device has a fresh SSH host key generated at boot. We need to capture it for secrix encryption.

1. **Extract the host public key (from your workstation):**
   ```bash
   ssh -p 22 deploy@<device-ip> "sudo cat /etc/ssh/ssh_host_ed25519_key.pub"
   # Returns: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... root@arm-bootstrap
   ```

2. **Extract the host private key (from your workstation):**
   ```bash
   ssh -p 22 deploy@<device-ip> "sudo cat /etc/ssh/ssh_host_ed25519_key"
   # Save to /tmp/arm-host-key
   ```

3. **Store the public key:**
   ```bash
   echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..." > secrets/public_keys/host_keys/<hostname>.pub
   ```

4. **Encrypt the private key with secrix (for backup only, NOT runtime decryption):**
   ```bash
   cat /tmp/arm-host-key | nix run .#secrix encrypt secrets/host_keys/<hostname>_ssh_host_ed25519 -- -u John88
   ```

**IMPORTANT:** The SSH host private key is the root of trust for secrix. It is NOT decrypted at runtime — it stays on the device. The encrypted copy is for operator backup only.

## Stage 4: Generate WireGuard Keys

Each device needs unique WireGuard keys.

1. **Generate key pair:**
   ```bash
   wg genkey | tee /tmp/wg-priv | wg pubkey > /tmp/wg-pub
   ```

2. **Encrypt private key with secrix (ALWAYS include `-u John88`):**
   ```bash
   cat /tmp/wg-priv | nix run .#secrix encrypt secrets/private_keys/wireguard/wg_<hostname> -- -u John88 -s <hostname>
   ```

3. **Store public key:**
   ```bash
   cp /tmp/wg-pub secrets/public_keys/wireguard/wg_<hostname>_pub
   ```

**Important:** See `documentation/operations-runbooks.md#secrix-fast-encryption-workflow` for the
`--all-users` encryption policy. This section covers only the ARM-specific key extraction steps.

## Stage 5: Build Actual Configuration

1. **Create machine config** in `machines/<hostname>/default.nix`
2. **Register in flake.nix** (add to `nixosConfigurations` and SD image list if needed)
3. **Add to topology.nix** with WireGuard IP and hub assignment
4. **Generate golden test:**
   ```bash
   nix run .#dump-config -- <hostname> | jq -S . > goldens/<hostname>.json
   nix run .#check-network -- <hostname>
   ```

## Stage 6: Deploy

**Temporarily point flake.nix at the device's LAN IP:**

1. **Edit flake.nix** — change the host IP from WireGuard to LAN IP:
   ```nix
   # In the machine's mkAarch64 call:
   host = "<device-lan-ip>";  # e.g., "10.88.128.210"
   ```

2. **Deploy with nixos-rebuild:**
   ```bash
   NIX_SSHOPTS="-p 22" nixos-rebuild switch --flake .#<hostname> --target-host deploy@<device-ip> --sudo
   ```

3. **Reset flake.nix** to WireGuard IP:
   ```nix
   host = topoIp "<hostname>";  # back to WG IP
   ```

4. **Commit and push:**
   ```bash
   git add flake.nix && git commit -m "deploy: reset <hostname> to WG IP"
   git push origin jb/overlord-I
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

3. **Run golden test:**
   ```bash
   nix run .#check-network -- <hostname>
   ```

## Example: Deploying arm-builder

```bash
# 1. Build and flash bootstrap image
nix build .#packages.aarch64-linux.arm-bootstrap --no-link --print-out-paths
dd if=<path>/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync

# 2. Boot and discover
avahi-resolve -n nixos-bootstrap.local
# Returns: nixos-bootstrap.local	10.88.128.210

# 3. Extract host key
ssh -p 22 deploy@10.88.128.210 "sudo cat /etc/ssh/ssh_host_ed25519_key.pub"
# Store in secrets/public_keys/host_keys/arm-builder.pub

# 4. Generate WG keys
wg genkey | tee /tmp/wg-priv | wg pubkey > /tmp/wg-pub
cat /tmp/wg-priv | nix run .#secrix encrypt secrets/private_keys/wireguard/wg_arm-builder -- -u John88 -s arm-builder
cp /tmp/wg-pub secrets/public_keys/wireguard/wg_arm-builder_pub

# 5. Build arm-builder config
nix build .#packages.aarch64-linux.arm-builder --no-link --print-out-paths

# 6. Deploy
# Temporarily set host = "10.88.128.210" in flake.nix
NIX_SSHOPTS="-p 22" nixos-rebuild switch --flake .#arm-builder --target-host deploy@10.88.128.210 --sudo
# Reset to WG IP in flake.nix

# 7. Verify
ping 10.88.127.42
ssh -p 1108 deploy@10.88.127.42
```

## Determinate Nix and Cross-Compilation

**Critical:** The bootstrap image (`arm-bootstrap`) must NOT include Determinate Nix. It is cross-compiled from x86_64 and the Determinate Nix daemon (`determinate-nixd`) cannot be cross-compiled — it must be built natively on aarch64.

**Bootstrap → Actual config transition:**
1. `arm-bootstrap` is built with `dt = false` (no Determinate Nix) — cross-compiled, minimal, just gets the device on the network
2. `arm-builder` (and other aarch64 machines) use `dt = true` (Determinate Nix) — the daemon is built natively on the remote builder during the first deployment
3. The local x86_64 host runs Determinate Nix — all remote builders MUST also run Determinate Nix to avoid protocol mismatches

**Why this matters:**
- The local host's `nix` client speaks the Determinate protocol
- Remote builders running standard `nix-daemon` cause `error: protocol mismatch` failures
- The Determinate Nix daemon must be built natively (not cross-compiled) — so the bootstrap image can't include it
- After the first deployment with `dt = true`, the remote builder will have `determinate-nixd` and can serve as a builder for subsequent cross-compiled deployments

**Configuration:**
- `mkAarch64` default is `dt ? true` — all aarch64 machines get Determinate Nix by default
- `arm-bootstrap` is built separately (not via `mkAarch64`) with no Determinate Nix
- `arm-builder` has explicit `dt = true` in `flake.nix` for safety (it IS the remote builder)

## Key Points

- **Bootstrap image is generic** — one image for ALL ARM devices
- **No WireGuard in bootstrap** — WG is part of the actual config
- **No Determinate Nix in bootstrap** — daemon must be built natively, not cross-compiled
- **Host key extraction is critical** — secrix needs the actual host key for encryption
- **Deploy over LAN first** — then switch to WireGuard for future deployments
- **Each device needs unique keys** — never reuse WireGuard or SSH host keys
- **Deploy user must be trusted** — bootstrap image needs `nix.settings.trusted-users = [ "deploy" ]`
- **Always encrypt with `-u John88`** — never encrypt with `-s hostname` only
- **Use `NIX_SSHOPTS="-p 22"`** — for deployment to bootstrap image (port 22)
- **Use `nixos-rebuild`** — not `nix run .#deploy.<hostname>` (that syntax is wrong)
- **Remote builders must run Determinate Nix** — protocol mismatch with standard nix-daemon

## Lessons Learned

1. **Circular dependency**: SSH host private key cannot be a secrix secret (secrix needs it to decrypt)
2. **Trusted users**: Bootstrap image must have deploy user as trusted nix user
3. **SSH port**: Use `NIX_SSHOPTS` environment variable for port specification
4. **Encryption**: Always encrypt with `-u John88` — never with `-s hostname` only
5. **Deployment command**: `nixos-rebuild switch --flake .#<hostname> --target-host deploy@<ip> --sudo`
