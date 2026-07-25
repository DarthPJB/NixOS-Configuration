# Incident: Nix Protocol Mismatch — Remote ARM Build Failure

**Date:** 2026-07-14  
**Severity:** Medium (blocks ARM builds from x86_64 host)  
**Status:** Mitigated (daemon reset), root cause unresolved  

---

## Summary

Building `arm-builder` (aarch64) from the x86_64 host failed with a protocol mismatch error when the Determinate Nix client on the local machine attempted to communicate with the standard Nix daemon on the remote builder at `10.88.127.43`.

## Environment

| Property | Local (x86_64 build host) | Remote (aarch64 builder) |
|----------|--------------------------|--------------------------|
| **Hostname** | bargman-tech workstation | arm-builder |
| **IP** | (local) | `10.88.127.43` |
| **Architecture** | x86_64-linux | aarch64-linux |
| **Nix Distribution** | Determinate Nix 3.21.1 | Standard Nix (NixOS) |
| **Nix Base Version** | 2.34.7 | 2.34.7 |
| **Nix Daemon** | `determinate-nixd` | `nix-daemon` (standard) |
| **Protocol** | Determinate protocol | Standard nix-daemon protocol |
| **SSH Port** | — | 1108 |
| **SSH User** | — | `build` (trusted) |

## Error

```
error: cannot open connection to remote store 'ssh-ng://build@10.88.127.43':
  error: protocol mismatch, got 'started
         oixd
```

The partial string `oixd` is likely truncated output from `determinate-nixd` or the standard daemon handshake being misinterpreted as protocol data.

## Root Cause

**Determinate Nix** (installed on the local x86_64 host) uses a different wire protocol than **standard Nix** (installed on arm-builder). Despite both reporting base version `2.34.7`, the Determinate Nix client cannot reliably communicate with a standard `nix-daemon` over `ssh-ng`.

The `dt ? true` default in `mkAarch64` (flake.nix) was introduced in the `overlord-ii-phase-B` merge to enable Determinate Nix on all aarch64 systems. However, arm-builder currently runs standard Nix, creating this mismatch.

## Impact

- ARM cross-compilation from x86_64 hosts fails intermittently
- Some derivations build successfully (e.g., `determinate-nixd` itself), others fail (e.g., `boehm-gc`)
- The failure is non-deterministic — it depends on connection state and daemon handshake timing

## Mitigation (Short-Term)

SSH into the remote builder and restart the nix daemon:

```bash
ssh -p 1108 deploy@10.88.127.43 'sudo systemctl restart nix-daemon'
```

This clears stale connection state and allows the next build attempt to proceed. The build may need to be retried multiple times if the protocol mismatch recurs on subsequent derivations.

## Resolution (Long-Term Options)

1. **Align Nix distributions:** Either install Determinate Nix on arm-builder, or use standard Nix on the local host
2. **Override `dt` for arm-builder:** Set `dt = false` in the arm-builder flake config to prevent Determinate Nix from being deployed
3. **Use `nix.settings.builders-use-substitutes`:** Ensure the remote builder fetches from cache rather than building native aarch64 derivations locally

## Cross-Compilation Note

`arm-builder` has `nixpkgs.buildPlatform = "x86_64-linux"` set, meaning it cross-compiles from x86_64. This should minimize native aarch64 builds. However, Determinate Nix (`determinate-nixd`) is an aarch64-native binary that cannot be cross-compiled — it must be built on the remote builder, triggering the protocol issue.

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 09:07 | Build started, remote builder at `10.88.127.43` engaged |
| 09:09 | `boehm-gc` build failed with protocol mismatch |
| 09:16 | Remote nix-daemon reset via SSH |
| 09:16 | Build retry pending |
