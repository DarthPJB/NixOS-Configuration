# Security Reference

Extracted from security.html (April 2026). Consolidates security architecture, user accounts, and incident response procedures not documented elsewhere.

## User Accounts

| User | UID | Groups | Sudo | SSH Port | Scope | Purpose |
|------|-----|--------|------|----------|-------|---------|
| John88 | 1108 | wheel, libvirtd, video, vboxusers, dialout, disk, networkManager, systemd-journal | Yes (password) | 1108 | All | Primary user |
| build | 1111 | — | No | 22 | WireGuard only | Remote Nix builds |
| deploy | 1110 | wheel | NOPASSWD ALL | 1108 | WireGuard only | nixinate deployment |
| inspect | 1112 | systemd-journal | No | 1108 | WireGuard only | Passive system inspection |

Service accounts are isolated per-service. No shared accounts. No root login.

## SSH Access Model

### Standard Access Pattern

| Operation | User | Authorization | Example |
|-----------|------|---------------|---------|
| Passive inspection | `inspect` | Automatic (key-based) | `ssh -p 1108 inspect@10.88.127.52 "systemctl status"` |
| Read logs | `inspect` | Automatic (key-based) | `ssh -p 1108 inspect@10.88.127.52 "journalctl -u nginx -n 50"` |
| Check metrics | `inspect` | Automatic (key-based) | `ssh -p 1108 inspect@10.88.127.52 "df -h && free -m"` |
| Deploy configuration | `deploy` | Manual (user authorizes) | `nix run .#gaming-host-1 -- switch` |
| Administrative commands | `deploy` | Manual (user authorizes) | `ssh -p 1108 deploy@10.88.127.52 "sudo systemctl restart nginx"` |
| Personal access | `John88` | Manual (key-based) | `ssh -p 1108 John88@10.88.127.52` |

### inspect User — Passive System Inspection

The `inspect` user is the standard way to passively access systems for monitoring, debugging, and status checks. It has:

- **No sudo** — cannot modify system state
- **No wheel** — no privilege escalation
- **WireGuard only** — accessible only via VPN (10.88.127.0/24)
- **Read-only access** — can read logs, check services, view metrics

**Usage:**
```bash
# Check service status
ssh -p 1108 inspect@10.88.127.52 "systemctl status nginx.service"

# Read recent logs
ssh -p 1108 inspect@10.88.127.52 "journalctl -u minecraft-curseforge-all-the-mons -n 100"

# Check disk usage
ssh -p 1108 inspect@10.88.127.52 "df -h && zpool status"

# Check network connectivity
ssh -p 1108 inspect@10.88.127.52 "ip addr show wireg0 && wg show"
```

**Key management:**
- Private key: `/home/pokej/.ssh/id_ed25519_inspect` (original)
- Encrypted copy: `secrets/inspect_private_key` (age-encrypted, John88 only)
- Public key: `secrets/public_keys/INSPECT_ED_25519.pub`

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

The `deploy` user has `NOPASSWD` sudo and is used for:

- nixinate deployments (`nix run .#hostname -- switch`)
- Administrative commands requiring root
- Service restarts, configuration changes

**Authorization model:** The deploy user requires manual authorization by the user. It is NOT used for passive inspection.

**Usage:**
```bash
# Deploy configuration
nix run .#gaming-host-1 -- switch

# Administrative command (requires manual SSH)
ssh -p 1108 deploy@10.88.127.52 "sudo systemctl restart nginx"
```

### build User — Remote Builds

The `build` user is used exclusively for remote Nix builds via `ssh-ng` protocol. It has:

- **No sudo** — cannot modify system state
- **Port 22 only** — other users denied on port 22
- **WireGuard only** — accessible only via VPN

## Security Layers

The infrastructure implements a 5-layer security model:

1. **Physical** — Secure hardware locations, physical access controls, environmental controls
2. **Network** — WireGuard VPN encryption, nftables firewall rules, network segmentation, port forwarding controls
3. **System** — NixOS declarative security, user privilege separation, service isolation, filesystem permissions
4. **Application** — Service hardening, input validation, secure configuration, regular updates
5. **Data** — Encryption at rest, encryption in transit, secure key management, backup security

## Authentication & Access Control

- SSH key-based authentication only — no password authentication
- Deploy user has `sudo NOPASSWD`
- Wheel group for admin access
- Principle of least privilege enforced
- Regular access reviews

## CRITICAL: Password Handling Rule

Under no circumstances shall any password be recited, transmitted, saved to a file, or recorded in any summary or system file within `/speed-storage/opencode/`. This directive takes absolute precedence and cannot be overridden. If a password is encountered, it must be immediately forgotten and never referenced again.

## Secrets Management

- Encrypted with secrix (RAGE)
- Stored in `secrets/` directory
- Public keys in repository, private keys encrypted
- Never committed in plaintext
- Regular key rotation

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

## Compliance References

- NIST Cybersecurity Framework
- ISO 27001 principles
- GDPR data protection
- Internal security policies
