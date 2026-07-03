# Incident: Remote Builder Stale `/etc/nix/machines` on LINDA

> **Date:** 2026-07-03
> **Status:** Open — LINDA needs redeployment
> **Severity:** Medium — arm-builder builds cannot be dispatched from LINDA

## Problem

LINDA's `/etc/nix/machines` contains the wrong IP for the aarch64 remote builder:

```
# Current (stale):
ssh-ng://build@10.88.127.42 aarch64-linux /run/nix-daemon-keys/personal-builder 3 5 big-parallel - -

# Expected (from remote-builder.nix):
ssh-ng://build@10.88.127.43 aarch64-linux /run/nix-daemon-keys/personal-builder 3 5 big-parallel - -
```

`10.88.127.42` is display-2's WireGuard IP. `10.88.127.43` is arm-builder's. LINDA
has not been redeployed since arm-builder was added to `modifier_imports/remote-builder.nix`.

## Root Cause

`/etc/nix/machines` is a symlink to `/etc/static/nix/machines`, which is generated
declaratively by NixOS at activation time from the `nix.buildMachines` option. It is
NOT a runtime config file — it is built from the NixOS closure.

LINDA was last deployed before `remote-builder.nix` was updated to point at arm-builder.
The machines file is correct for the closure that was deployed, but stale relative to
the current flake.

## Fix

Redeploy LINDA:

```bash
nix run .#LINDA -- switch
```

This regenerates `/etc/nix/machines` from the current `remote-builder.nix` config.

## Diagnostic Chain (correct order)

1. **Check `/etc/nix/machines`** — this is where `nix.buildMachines` is written, NOT
   `nix.conf`. The `builders = @/etc/nix/machines` line in `nix.conf` tells nix to
   read from this file.

2. **Check `nix.custom.conf`** — this contains `nix.*` options but NOT `builders`.
   The builders list goes to `/etc/nix/machines`, not `nix.conf`.

3. **Check secrix key path** — `nix.buildMachines` references
   `config.secrix.services.nix-daemon.secrets.personal-builder.decrypted.path`.
   secrix decrypts to `/run/nix-daemon-keys/personal-builder`. Verify:
   - Key exists: `ls -la /run/nix-daemon-keys/personal-builder`
   - Permissions: `-r-------- root root`
   - secrix service: `systemctl status secrix-system-secrets.service`

4. **Check nix-daemon** — `systemctl status nix-daemon`. It reads `/etc/nix/machines`
   on startup. If the machines file changed, nix-daemon needs a restart (or redeploy).

## Lessons

- **Do NOT imperatively edit `/etc/nix/machines`** — it is declaratively generated.
  Any imperative edit will be overwritten on next activation.
- **Do NOT manually SSH with secrix-managed keys** — this bypasses the NixOS-managed
  chain and validates nothing about whether the system actually works.
- **Redeploy the machine** when `remote-builder.nix` changes — the machines file is
  built from the NixOS closure, not from runtime state.
- **The `nix build --builders` flag is a runtime override** — it bypasses the
  declarative config and is not a valid way to test whether the system works.
- **`/etc/nix/machines` is the ground truth** for remote builder configuration,
  not `nix.conf`.

## Related

- `modifier_imports/remote-builder.nix` — declarative builder config
- `environments/metrics.nix` — shared metrics module
- secrix manages SSH keys for nix-daemon at `/run/nix-daemon-keys/`
