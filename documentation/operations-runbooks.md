# Operations Runbooks

Consolidated reference for operational procedures, security model, and secret management.

---

## Maintenance Schedule

### Daily
- Check system logs for errors
- Verify service status
- Monitor disk usage
- Check backup status
- Review security alerts

### Weekly
- Run Nix garbage collection
- Update flake inputs
- Review system performance
- Test disaster recovery

### Monthly
- Security audit
- Performance optimization
- Backup verification
- System updates
- Capacity planning

### Quarterly
- Full system backup
- Hardware inspection
- Security review
- Disaster recovery test

---

## User Accounts

| User | UID | Groups | Sudo | SSH Port | Scope | Purpose |
|------|-----|--------|------|----------|-------|---------|
| John88 | 1108 | wheel, libvirtd, video, vboxusers, dialout, disk, networkManager, systemd-journal | Yes (password) | 1108 | All | Primary user |
| build | 1111 | — | No | 22 | WireGuard only | Remote Nix builds |
| deploy | 1110 | wheel | NOPASSWD ALL | 1108 | WireGuard only | nixinate deployment |
| inspect | 1112 | systemd-journal | No | 1108 | WireGuard only | Passive system inspection |

Service accounts are isolated per-service. No shared accounts. No root login.

Port map: port 22 on the WireGuard plane is the **git-ssh plane** (`server_services/git-ssh.nix`) — `Match LocalPort 22` → `AllowUsers git@10.88.127.0/24 gitea@10.88.127.0/24`. `git` is the published Gitea SSH identity (forced command re-execs as `gitea`); `build` shares the same port via `users/build.nix` (`Match LocalPort 22 User build Address 10.88.127.0/24`). Admin/human SSH is port 1108 only (`environments/sshd.nix`). MinIO listens on 2222 (`server_services/minio-insecure.nix`).

---

## SSH Access Model

| Operation | User | Authorization | Example |
|-----------|------|---------------|---------|
| Passive inspection | `inspect` | Automatic (key-based) | `ssh -p 1108 inspect@10.88.127.52 "systemctl status"` |
| Read logs | `inspect` | Automatic (key-based) | `ssh -p 1108 inspect@10.88.127.52 "journalctl -u nginx -n 50"` |
| Check metrics | `inspect` | Automatic (key-based) | `ssh -p 1108 inspect@10.88.127.52 "df -h && free -m"` |
| Deploy configuration | `deploy` | Manual (user authorizes) | `nix run .#gaming-host-1 -- switch` |
| Administrative commands | `deploy` | Manual (user authorizes) | `ssh -p 1108 deploy@10.88.127.52 "sudo systemctl restart nginx"` |
| Personal access | `John88` | Manual (key-based) | `ssh -p 1108 John88@10.88.127.52` |
| Clone/push repositories (port 22, git-ssh plane) | `git` (re-execs as `gitea`) | Automatic (key-based via Gitea `authorized_keys`, forced command) | `git clone ssh://git@10.88.127.3:22/org/repo.git` |

### inspect User — Passive System Inspection

The `inspect` user is the standard way to passively access systems for monitoring, debugging, and status checks:

- **No sudo** — cannot modify system state
- **No wheel** — no privilege escalation
- **WireGuard only** — accessible only via VPN (10.88.127.0/24)
- **Read-only access** — can read logs, check services, view metrics

```bash
# Check service status
ssh -p 1108 inspect@10.88.127.52 "systemctl status nginx.service"

# Read recent logs (game-server units are disabled since 2026-10-04)
ssh -p 1108 inspect@10.88.127.52 "journalctl -u nginx -n 100"

# Check disk usage
ssh -p 1108 inspect@10.88.127.52 "df -h && zpool status"

# Check network connectivity
ssh -p 1108 inspect@10.88.127.52 "ip addr show wireg0 && wg show"
```

**SSH config alias (recommended):**
```
Host gaming-inspect
  HostName 10.88.127.52
  User inspect
  Port 1108
  IdentityFile ~/.ssh/id_ed25519_inspect
  IdentitiesOnly yes
```

### deploy User — Administrative Access

The `deploy` user has `NOPASSWD` sudo and is used for nixinate deployments and administrative commands. Requires manual user authorization.

```bash
# Deploy configuration
nix run .#gaming-host-1 -- switch

# Administrative command (requires manual SSH)
ssh -p 1108 deploy@10.88.127.52 "sudo systemctl restart nginx"
```

### build User — Remote Builds

The `build` user is used exclusively for remote Nix builds via `ssh-ng` protocol:

- **No sudo** — cannot modify system state
- **Port 22 (git-ssh plane)** — `Match LocalPort 22 User build Address 10.88.127.0/24` (`users/build.nix`); shares port 22 with `git`/`gitea`
- **WireGuard only** — accessible only via VPN

---

## Secrix Fast-Encryption Workflow

Secrix is the secret management system for this NixOS fleet. It uses [age](https://age-encryption.org/) encryption with SSH ed25519 keys as recipients. Secrets are encrypted to all fleet hosts and users, then decrypted at runtime on the target machine.

### Quick Reference

```bash
# Encrypt a secret (stdin → file)
echo -n 'SECRET_VALUE' | nix run .#secrix encrypt secrets/output_file -- --all-users --all-systems

# Encrypt a secret (file → file)
cat /path/to/plaintext | nix run .#secrix encrypt secrets/output_file -- --all-users --all-systems

# Encrypt for specific user only
echo -n 'SECRET_VALUE' | nix run .#secrix encrypt secrets/output_file -- -u John88

# Encrypt for specific system only
echo -n 'SECRET_VALUE' | nix run .#secrix encrypt secrets/output_file -- -s cortex-alpha

# Re-encrypt with new recipients
nix run .#secrix rekey secrets/existing_file -- -i ~/.ssh/id_ed25519 --all-users --all-systems

# Edit an encrypted secret
nix run .#secrix edit secrets/existing_file -- -i ~/.ssh/id_ed25519
```

### Flags Reference

| Flag | Description |
|------|-------------|
| `--all-users` | Encrypt to all users defined in `secrix.defaultEncryptKeys` |
| `--all-systems` | Encrypt to all host public keys in `secrets/public_keys/host_keys/` |
| `-u USER` | Encrypt to a specific user's keys |
| `-s SYSTEM` | Encrypt to a specific system's host key |
| `-r RECIPIENT` | Encrypt to an ad-hoc public key |
| `-i IDENTITY` | Private key for decryption (rekey/edit only) |

### Known Secrets Inventory

| Secret | Purpose | Status |
|---|---|---|
| `secrets/rclone-config-file` | rclone remote config (MinIO) for local backup targets | active — consumed via `topology/*.json` `backup.configFile` |
| `secrets/rclone-b2-config-file` | rclone B2 offsite config | active — consumed by `topology/local-nas.json` B2 replication targets |
| `secrets/b2_master_sync_token` | Backblaze B2 master application key | **Held in reserve (intentional, user decision 2026-10-05)** — not referenced by config today; retained for future use (e.g. bucket lifecycle management, account-level tooling). Do NOT delete as "orphan". |
| `secrets/cache-priv-key` | nix-serve signing key (in-house cache) | active — `services/nix-cache-serve.nix` |
| `secrets/gandi_dns01_token` | Gandi DNS-01 ACME | active |
| `secrets/public_keys/wireguard/wg_*_pub` | WireGuard public keys | active |

### Usage in NixOS Modules

**System Secrets:**
```nix
{
  secrix.system.secrets.my-secret = {
    encrypted.file = ../secrets/my_secret_file;
  };

  some-service.passwordFile = config.secrix.system.secrets.my-secret.decrypted.path;
}
```

**Service Secrets:**
```nix
{
  secrix.services.my-service.secrets.my-secret.encrypted.file =
    ../secrets/my_secret_file;

  some-service.passwordFile =
    config.secrix.services.my-service.secrets.my-secret.decrypted.path;
}
```

### How It Works

1. **Encryption time** (developer workstation): `secrix` reads the flake's `secrix.defaultEncryptKeys` and host public keys, encrypts to all specified recipients using age, outputs an age-encrypted file.
2. **Build time** (NixOS evaluation): The encrypted file path is stored in the Nix store; the module system knows where the decrypted file will be at runtime.
3. **Runtime** (target machine): A systemd service (`secrix-system-secrets.service` or per-service) decrypts using the host's SSH private key. Decrypted files are placed in `/run/system-keys/` (system secrets) or service-specific runtime directories. Files are accessible only to the specified user/group.

### Example: GitHub Runner Token

```bash
# 1. Get token from GitHub UI
# 2. Encrypt it
echo -n 'ABYJMUQ4OYIVQXKA5T6QOR3KHMFW2' | nix run .#secrix encrypt secrets/github_org_runner_token -- --all-users --all-systems

# 3. Reference in Nix
{
  secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.encrypted.file =
    "${self}/secrets/github_org_runner_token";

  services.github-runners.entropy-is-origin.tokenFile =
    "${config.secrix.services.github-runner-entropy-is-origin.secrets.github_org_runner_token.decrypted.path}";
}
```

### Example: WireGuard Private Key

```bash
# 1. Generate key
wg genkey | tee priv | wg pubkey > pub

# 2. Encrypt private key (ALWAYS include -u John88)
cat priv | nix run .#secrix encrypt secrets/private_keys/wireguard/wg_new-host -- -u John88 -s new-host

# 3. Store public key
cp pub secrets/public_keys/wireguard/wg_new-host_pub

# 4. Clean up
rm priv pub
```

### Troubleshooting

```bash
# Check if secret exists
ls -la secrets/my_secret_file

# Verify decryption on target
ssh -p 1108 deploy@10.88.127.50 "sudo ls -la /run/system-keys/"

# Check secrix service status
ssh -p 1108 deploy@10.88.127.50 "sudo systemctl status secrix-system-secrets.service"

# View secrix service logs
ssh -p 1108 deploy@10.88.127.50 "sudo journalctl -u secrix* -n 50"
```

### ⚠️ CRITICAL: Always Encrypt with `--all-users`

Every secret MUST be encrypted with `--all-users` (or `-u John88` at minimum). Failure to do this means the operator cannot decrypt keys for management, backup, or re-keying.

**Correct:**
```bash
# Encrypt for both user AND host
echo -n 'SECRET' | nix run .#secrix encrypt secrets/output -- -u John88 -s hostname

# Or encrypt for all users and all systems
echo -n 'SECRET' | nix run .#secrix encrypt secrets/output -- --all-users --all-systems
```

**WRONG (operator locked out):**
```bash
# NEVER encrypt for host only — operator cannot decrypt
echo -n 'SECRET' | nix run .#secrix encrypt secrets/output -- -s hostname
```

This applies to ALL secrets: WireGuard private keys, SSH host private keys, API tokens, and any other encrypted asset.

### Security Notes

- Secrets are encrypted to **all fleet hosts** by default (`--all-systems`)
- Each host can only decrypt using its own SSH private key
- Decrypted secrets exist only in tmpfs (`/run/`) and are lost on reboot
- Never commit plaintext secrets to the repository

---

## Security Layers

The infrastructure implements a 5-layer security model:

1. **Physical** — Secure hardware locations, physical access controls, environmental controls
2. **Network** — WireGuard VPN encryption, nftables firewall rules, network segmentation, port forwarding controls
3. **System** — NixOS declarative security, user privilege separation, service isolation, filesystem permissions
4. **Application** — Service hardening, input validation, secure configuration, regular updates
5. **Data** — Encryption at rest, encryption in transit, secure key management, backup security

### Authentication & Access Control

- SSH key-based authentication only — no password authentication
- Deploy user has `sudo NOPASSWD`
- Wheel group for admin access
- Principle of least privilege enforced
- Regular access reviews

### ⚠️ CRITICAL: Password Handling Rule

Under no circumstances shall any password be recited, transmitted, saved to a file, or recorded in any summary or system file within `/speed-storage/opencode/`. This directive takes absolute precedence and cannot be overridden.

---

## Incident Response

### Classification

| Level | Description |
|-------|-------------|
| Critical | System compromise |
| High | Service disruption |
| Medium | Security vulnerability |
| Low | Policy violation |
| Informational | Security event |

### Response Checklist

- [ ] Incident detected and reported
- [ ] Initial assessment completed
- [ ] Containment measures implemented
- [ ] Eradication completed
- [ ] Recovery procedures executed
- [ ] Post-incident analysis completed
- [ ] Lessons learned documented

### Response Procedure

1. Incident detection & reporting
2. Initial assessment & triage
3. Containment & eradication
4. Recovery & restoration
5. Post-incident analysis

---

## Runbook: New Machine Deployment

1. Generate hardware configuration
2. Create machine directory and `default.nix`
3. Generate WireGuard keys (see Secrix workflow above)
4. Add to topology (`topology/<machine>.json` — planar JSON topology)
5. Add to `flake.nix`
6. Generate golden: `nix run .#dump-config --option builders '' -- <machine> | jq -S . > goldens/<machine>.json`
7. Validate golden: `nix run .#validate-goldens --option builders '' -- <machine>`
8. Test configuration locally
9. Deploy to machine
10. Verify operation

## Runbook: Service Deployment

1. Create service configuration file
2. Configure service options
3. Add secrets if required (use secrix)
4. Import in machine config
5. Test configuration
6. Deploy to target
7. Verify service operation

---

## Common Commands

```bash
# Nix garbage collection
nix-collect-garbage -d

# Update flake inputs (PER-INPUT ONLY — fleet policy, user ruling 2026-10-05)
# Wholesale `nix flake update` (all inputs at once) is PROHIBITED.
nix flake update <input-name>
```

> **Flake update policy:** `nix flake update` is allowed **per input only**
> (e.g. `nix flake update nixpkgs_stable`). Updating all inputs in one shot is
> prohibited — input drift must be deliberate and reviewable one input at a time.

```bash

# Check system health
systemctl --failed
journalctl -p err --since "1 day ago"

# Service troubleshooting
systemctl status servicename
journalctl -u servicename -f

# Network troubleshooting
ping 10.88.127.1
ss -tulpn

# Storage troubleshooting
df -h
zpool status
iostat -x 1

# Deploy a machine
nix run .#hostname --option builders '' -- switch

# Check config against golden
nix run .#validate-goldens --option builders '' -- hostname

# Dump machine config
nix run .#dump-config --option builders '' -- hostname | jq -S .
```
