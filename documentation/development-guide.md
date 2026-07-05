# Development Guide

Extracted from development.html (April 2026). Consolidates prohibited practices and troubleshooting procedures not documented elsewhere.

## Prohibited Practices

These practices are strictly prohibited in this repository:

- **Docker** — Antithetical to Nix purity
- **Cloud provider dependencies** — Self-hosted infrastructure only
- **Imperative configurations** — Everything must be declarative
- **Unpinned flake inputs** — All inputs must be pinned
- **Committing unencrypted secrets** — Use secrix for all secrets
- **Direct nixpkgs_unstable input access** — Use the `unstable` arg passed through `_module.args`

## Pre-Commit Checklist

- [ ] Run `nix fmt` to format code
- [ ] Run `nix flake check` to validate
- [ ] Run `nix flake show` to verify evaluation
- [ ] Test build with `nixos-rebuild build --flake .#hostname`
- [ ] Write descriptive commit message
- [ ] Verify no secrets are committed

## Troubleshooting

### Build Failures

- Check syntax with `nix flake check`
- Verify file paths are correct
- Check for missing imports
- Review build logs: `nix log <derivation>`
- Use `nix repl` for debugging

### Deployment Issues

- Test SSH: `ssh -p 1108 deploy@10.88.127.X`
- Verify VPN connectivity
- Check deploy user permissions
- Verify secrix paths
- Check `buildOn` setting

### Secret Issues

- Check secrix configuration
- Verify public keys exist
- Test secret decryption
- Check file permissions
- Verify secret paths

### Network Issues

- Check WireGuard status
- Verify IP assignments
- Test connectivity between hosts
- Check firewall rules
- Verify DNS resolution
