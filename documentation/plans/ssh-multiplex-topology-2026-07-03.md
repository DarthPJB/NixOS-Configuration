# Fleet SSH Multiplexing via Topology

> **Created:** 2026-07-03
> **Status:** Planned — target overlord-II
> **Parent directive:** Simplicity over cleverness; topology as single source of truth

## Context

Every `nixos-rebuild`, `nixinate deploy`, `rsync`, or operator SSH session to a fleet
machine performs a full TCP handshake, key exchange, and authentication. On a local
network this is ~150-500ms. On a WAN link it can exceed a second. A deployment
script that opens 3-5 SSH connections to the same host wastes seconds per deploy
in handshakes alone.

OpenSSH has had connection multiplexing since 2004: the first connection becomes a
**master** (creating a Unix socket), and every subsequent connection to the same
target reuses that socket — no re-handshake, no re-auth. The speedup is dramatic:
follow-up commands drop from hundreds of milliseconds to tens of milliseconds.

This capability should be generated from the topology — the same source of truth
that already feeds `knownHosts`, WireGuard peers, nginx proxies, firewall rules,
and DNS/DHCP config.

## `matchBlocks` vs `extraConfig`

The `knownHosts` generation in `flake.nix` uses the declarative
`programs.ssh.knownHosts` attrset, not a raw string. SSH multiplexing config
should follow the same pattern.

| Approach | Type | Merges? | Validated? | Buildable from data? |
|---|---|---|---|---|
| `programs.ssh.extraConfig` | Raw string | No (blind concatenation) | No | No |
| `programs.ssh.matchBlocks` | Nix attrset | Yes (per-host merge) | Yes (attr names checked) | Yes |

The LINDA `extraConfig` block for `hyperhyper` is a prototype — it works but
is scoped to one host and can't be distributed fleet-wide without copy-paste.

## Design

### `mkMultiplexConfig` — mirror of `mkKnownHosts`

A new function in `flake.nix`, structurally identical to `mkKnownHosts` (lines
149-202), that produces `programs.ssh.matchBlocks` from the topology:

```nix
mkMultiplexConfig = nixosConfigs:
  let
    allMachines = lib.unique (
      builtins.attrNames topo
      ++ builtins.attrNames nixosConfigs
      ++ builtins.attrNames (self.dormantConfigurations or { })
    );
  in
    builtins.listToAttrs (map (name:
      let entry = topo.${name} or null;
      in lib.nameValuePair name (
        if entry ? wireguard then {
          hostname = entry.wireguard;
          user = "deploy";
          port = 1108;
          controlMaster = "auto";
          controlPath = "/run/user/%i/ssh-mux/%C";
          controlPersist = "15m";
          identitiesOnly = true;
          identityFile = "~/.ssh/id_ed25519_master";
        } else null
      )
    ) allMachines);
```

Applied in `commonModules`:

```nix
programs.ssh.matchBlocks = mkMultiplexConfig self.nixosConfigurations;
```

### Socket directory

The `%C` token expands to a SHA1 hash of `%r@%h:%p` — it avoids leaking
hostnames in directory listings. The socket directory must be per-user with
strict permissions:

```nix
systemd.tmpfiles.rules = [
  "d /run/user/%i/ssh-mux 0700 %u users -"
];
```

For the `deploy` user specifically, ensure `linger` is enabled so
`/run/user/<UID>` persists:

```nix
users.users.deploy.linger = true;
```

### Server-side tuning

Increase `MaxSessions` to accommodate multiplexed channels:

```nix
services.openssh.settings.MaxSessions = 20;  # default is 10
```

## Security

- The Unix socket IS the auth boundary — anyone who can read/write it gains
  access as the authenticated user without a credential check
- Socket directory MUST be 0700 and owned by the user
- Never use `/tmp` — use `/run/user/%i/` (tmpfs, per-user, auto-cleaned)
- `ControlPersist` should be modest (5-30 min); longer windows increase
  exposure from a compromised client process
- `%C` (hash) avoids revealing `user@host:port` in `ls` output

## Operations

Runtime control commands for operators:

```bash
# Check if a master is active
ssh -O check deploy@10.88.127.88

# Gracefully tear down master + all children
ssh -O exit deploy@10.88.127.88

# List open channels
ssh -O conninfo deploy@10.88.127.88
```

## Phases

| Phase | Description | Dependencies |
|---|---|---|
| 1 | Implement `mkMultiplexConfig` in `flake.nix` | None |
| 2 | Add `systemd.tmpfiles.rules` for socket dir to `commonModules` | Phase 1 |
| 3 | Add `MaxSessions = 20` to `environments/sshd.nix` or `configuration.nix` | None |
| 4 | Enable `deploy` user `linger` | Phase 1 |
| 5 | Local smoke test on cortex-alpha | Phases 1-4 |
| 6 | Fleet-wide deployment | Phase 5 passes |
| 7 | Benchmark: `time ssh deploy@<host> true` before/after | Phase 6 |
