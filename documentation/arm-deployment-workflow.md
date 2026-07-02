# ARM Deployment Workflow

> **Last updated:** 2026-07-02
> **Status:** Active — evolving rapidly

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
   # From any machine on the same network
   avahi-resolve -n nixos-bootstrap.local
   # or
   ping nixos-bootstrap.local
   ```

2. **Or check DHCP leases** on your router/DHCP server

3. **Verify SSH access:**
   ```bash
   ssh -p 22 John88@<device-ip>
   ```

## Stage 3: Extract Host Key

The device has a fresh SSH host key generated at boot. We need to capture it for secrix.

1. **SSH into the device:**
   ```bash
   ssh -p 22 John88@<device-ip>
   ```

2. **Extract the host key pair:**
   ```bash
   # On the device
   sudo cat /etc/ssh/ssh_host_ed25519_key > /tmp/host_key
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub > /tmp/host_key.pub
   ```

3. **Copy the keys to your workstation:**
   ```bash
   # From your workstation
   scp -P 22 John88@<device-ip>:/tmp/host_key /tmp/arm-host-key
   scp -P 22 John88@<device-ip>:/tmp/host_key.pub /tmp/arm-host-key.pub
   ```

4. **Encrypt the private key with secrix:**
   ```bash
   cd /path/to/NixOS-Configuration
   cat /tmp/arm-host-key | nix run .#secrix encrypt secrets/host_keys/<hostname>_ssh_host_ed25519 -- -s <hostname>
   ```

5. **Store the public key:**
   ```bash
   cp /tmp/arm-host-key.pub secrets/public_keys/host_keys/<hostname>.pub
   ```

## Stage 4: Generate WireGuard Keys

Each device needs unique WireGuard keys.

1. **Generate key pair:**
   ```bash
   wg genkey | tee /tmp/wg-priv | wg pubkey > /tmp/wg-pub
   ```

2. **Encrypt private key with secrix:**
   ```bash
   cat /tmp/wg-priv | nix run .#secrix encrypt secrets/private_keys/wireguard/wg_<hostname> -- -s <hostname>
   ```

3. **Store public key:**
   ```bash
   cp /tmp/wg-pub secrets/public_keys/wireguard/wg_<hostname>_pub
   ```

## Stage 5: Build Actual Configuration

1. **Create machine config** in `machines/<hostname>/default.nix`
2. **Register in flake.nix** (add to `nixosConfigurations` and SD image list if needed)
3. **Add to topology.nix** with WireGuard IP and hub assignment
4. **Generate golden test:**
   ```bash
   nix run .#dump-config -- <hostname> | jq -S . > real-topology/golden/<hostname>.json
   nix run .#check-network -- <hostname>
   ```

## Stage 6: Deploy

**Temporarily point flake.nix at the device's LAN IP:**

1. **Edit flake.nix** — change the host IP from WireGuard to LAN IP:
   ```nix
   # In the machine's mkAarch64 call:
   host = "<device-lan-ip>";  # e.g., "192.168.1.100"
   sshPort = 22;              # bootstrap listens on 22
   ```

2. **Deploy with --switch:**
   ```bash
   nix run .#deploy.<hostname> -- --switch
   ```

3. **Reset flake.nix** to WireGuard IP and port:
   ```nix
   host = topoIp "<hostname>";  # back to WG IP
   sshPort = 1108;              # back to WG port
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
ping nixos-bootstrap.local  # or check DHCP

# 3. Extract host key
ssh -p 22 John88@<device-ip>
sudo cat /etc/ssh/ssh_host_ed25519_key > /tmp/host_key
# Copy to workstation and encrypt with secrix

# 4. Generate WG keys
wg genkey | tee /tmp/wg-priv | wg pubkey > /tmp/wg-pub
# Encrypt private key with secrix

# 5. Build arm-builder config
nix build .#packages.aarch64-linux.arm-builder --no-link --print-out-paths

# 6. Deploy
# Temporarily set host = "<device-lan-ip>" and sshPort = 22 in flake.nix
nix run .#deploy.arm-builder -- --switch
# Reset to WG IP and port 1108

# 7. Verify
ping 10.88.127.42
ssh -p 1108 deploy@10.88.127.42
```

## Key Points

- **Bootstrap image is generic** — one image for ALL ARM devices
- **No WireGuard in bootstrap** — WG is part of the actual config
- **Host key extraction is critical** — secrix needs the actual host key for encryption
- **Deploy over LAN first** — then switch to WireGuard for future deployments
- **Each device needs unique keys** — never reuse WireGuard or SSH host keys

## Future Improvements

- [ ] Automate host key extraction and secrix encryption
- [ ] Automate WireGuard key generation and encryption
- [ ] Consider using `nixos-rebuild-ng` for deployment
- [ ] Add device discovery via mDNS/Avahi (in progress)
