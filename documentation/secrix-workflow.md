# Secrix Fast-Encryption Workflow

## Overview

Secrix is the secret management system for this NixOS fleet. It uses [age](https://age-encryption.org/) encryption with SSH ed25519 keys as recipients. Secrets are encrypted to all fleet hosts and users, then decrypted at runtime on the target machine.

## Quick Reference

### Encrypt a Secret (stdin → file)

```bash
echo -n 'SECRET_VALUE' | nix run .#secrix encrypt secrets/output_file -- --all-users --all-systems
```

### Encrypt a Secret (file → file)

```bash
cat /path/to/plaintext | nix run .#secrix encrypt secrets/output_file -- --all-users --all-systems
```

### Encrypt for Specific User Only

```bash
echo -n 'SECRET_VALUE' | nix run .#secrix encrypt secrets/output_file -- -u John88
```

### Encrypt for Specific System Only

```bash
echo -n 'SECRET_VALUE' | nix run .#secrix encrypt secrets/output_file -- -s cortex-alpha
```

### Re-encrypt with New Recipients

```bash
nix run .#secrix rekey secrets/existing_file -- -i ~/.ssh/id_ed25519 --all-users --all-systems
```

### Edit an Encrypted Secret

```bash
nix run .#secrix edit secrets/existing_file -- -i ~/.ssh/id_ed25519
```

## Flags Reference

| Flag | Description |
|------|-------------|
| `--all-users` | Encrypt to all users defined in `secrix.defaultEncryptKeys` |
| `--all-systems` | Encrypt to all host public keys in `secrets/public_keys/host_keys/` |
| `-u USER` | Encrypt to a specific user's keys |
| `-s SYSTEM` | Encrypt to a specific system's host key |
| `-r RECIPIENT` | Encrypt to an ad-hoc public key |
| `-i IDENTITY` | Private key for decryption (rekey/edit only) |

## Usage in NixOS Modules

### System Secrets

```nix
{
  secrix.system.secrets.my-secret = {
    encrypted.file = ../secrets/my_secret_file;
  };
  
  # Access the decrypted path
  some-service.passwordFile = config.secrix.system.secrets.my-secret.decrypted.path;
}
```

### Service Secrets

```nix
{
  secrix.services.my-service.secrets.my-secret.encrypted.file = 
    ../secrets/my_secret_file;
  
  # Access the decrypted path
  some-service.passwordFile = 
    config.secrix.services.my-service.secrets.my-secret.decrypted.path;
}
```

## How It Works

1. **Encryption time** (developer workstation):
   - `secrix` reads the flake's `secrix.defaultEncryptKeys` and host public keys
   - Encrypts the secret to all specified recipients using age
   - Outputs an age-encrypted file

2. **Build time** (NixOS evaluation):
   - The encrypted file path is stored in the Nix store
   - The module system knows where the decrypted file will be at runtime

3. **Runtime** (target machine):
   - A systemd service (`secrix-system-secrets.service` or per-service) decrypts using the host's SSH private key
   - Decrypted files are placed in `/run/system-keys/` (system secrets) or service-specific runtime directories
   - Files are accessible only to the specified user/group

## Example: GitHub Runner Token

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

## Example: WireGuard Private Key

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

## Troubleshooting

### Check if secret exists
```bash
ls -la secrets/my_secret_file
```

### Verify decryption on target
```bash
ssh -p 1108 deploy@10.88.127.50 "sudo ls -la /run/system-keys/"
```

### Check secrix service status
```bash
ssh -p 1108 deploy@10.88.127.50 "sudo systemctl status secrix-system-secrets.service"
```

### View secrix service logs
```bash
ssh -p 1108 deploy@10.88.127.50 "sudo journalctl -u secrix* -n 50"
```

## Security Notes

- Secrets are encrypted to **all fleet hosts** by default (`--all-systems`)
- Each host can only decrypt using its own SSH private key
- Decrypted secrets exist only in tmpfs (`/run/`) and are lost on reboot
- Never commit plaintext secrets to the repository
- Use `--all-users` when multiple developers need access

## CRITICAL: Always Encrypt with `--all-users`

**Every secret MUST be encrypted with `--all-users` (or `-u John88` at minimum).**

Failure to do this means the operator cannot decrypt keys for management,
backup, or re-keying. This is a hard requirement, not optional.

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

**Applies to ALL secrets:**
- WireGuard private keys
- SSH host private keys
- API tokens
- Any other encrypted asset
