# Security Reference

Extracted from security.html (April 2026). Consolidates security architecture, user accounts, and incident response procedures not documented elsewhere.

## User Accounts

| User | UID | Purpose |
|------|-----|---------|
| John88 | 1108 | Primary user |
| build | 1109 | Build user |
| deploy | 1110 | Deployment user |

Service accounts are isolated per-service. No shared accounts. No root login.

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
