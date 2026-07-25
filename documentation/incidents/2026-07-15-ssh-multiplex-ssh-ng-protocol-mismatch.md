# Incident: Determinate Nix maxConnections Default Breaks ssh-ng Remote Builders

**Date:** 2026-07-15  
**Severity:** High (blocks all ARM builds from x86_64 host)  
**Status:** Resolved (store URI param fix applied 2026-07-16), upstream fix pending  
**Supersedes:** `2026-07-14-nix-protocol-mismatch-arm-builder.md` (incorrect root cause)

---

## Summary

Building `display-1` (aarch64) from LINDA (x86_64) failed with `protocol mismatch, got 'started'` when the nix-daemon's ssh-ng connection to `arm-builder` (10.88.127.43) was corrupted by Nix's own SSH master mode. The root cause: **Determinate Nix changed the `maxConnections` default from 1 (upstream) to 64**, which enables SSH master mode (`-M -N`) for ssh-ng remote builders. The SSH masters have `ControlPersist=no`, causing them to die and leave stale sockets. When a command SSH falls back to a direct connection through a stale socket, Nix's `LocalCommand=echo started` leaks into the protocol stream.

## Environment

| Property | Local (LINDA) | Remote (arm-builder) |
|----------|--------------|---------------------|
| **Hostname** | LINDA | arm-builder |
| **WireGuard IP** | 10.88.127.88 | 10.88.127.43 |
| **Architecture** | x86_64-linux | aarch64-linux |
| **Nix Distribution** | Determinate Nix 3.21.5 | Determinate Nix 3.21.5 |
| **Nix Base Version** | 2.34.8 | 2.34.8 |
| **Nix Daemon** | `determinate-nixd` | `determinate-nixd` |
| **SSH Protocol** | `ssh-ng` | `ssh-ng` |
| **SSH User** | — | `build` (port 22, WireGuard only) |

## Error

```
error: cannot open connection to remote store 'ssh-ng://build@10.88.127.43': protocol mismatch, got 'started'
error: Cannot build '/nix/store/8pcxdrymg4hl191c0jr8xxdj7c4h0y7p-linux-rpi-6.18.34-stable_20260609.drv'.
```

## Root Cause

### The Smoking Gun: Determinate Nix Changed a Default

**Upstream Nix** (`remote-store.hh`):
```cpp
Setting<int> maxConnections{
    this, 1, "max-connections", "Maximum number of concurrent connections to the Nix daemon."};
```

**Determinate Nix** (`remote-store.hh`):
```cpp
Setting<int> maxConnections{
    this, 64, "max-connections", "Maximum number of concurrent connections to the Nix daemon."};
```

One integer. 1 → 64. This is the entire chain of causation.

### The Mechanism

With `maxConnections = 64`:
1. `connections->capacity() = max(1, 64) = 64`
2. `useMaster = (64 > 1) = true`
3. `SSHMaster::startMaster()` spawns `ssh -M -N -oControlPersist=no -S /tmp/nix-.../ssh.sock`
4. Master runs `LocalCommand=echo started`, `startMaster()` reads `"started"`
5. Command SSHs connect through master socket — `LocalCommand` does NOT run on live masters
6. `startCommand()` correctly skips reading `"started"` (because `useMaster = true`)
7. Protocol handler reads nix-daemon protocol from command SSH stdout — everything works

**Until the master dies:**

8. Master has `ControlPersist=no` (OpenSSH default with `-M`) — dies when last command disconnects
9. Socket lingers after master death
10. Next command SSH through stale socket → SSH falls back to direct connection
11. Direct connection runs `LocalCommand=echo started`
12. `"started"` appears on command SSH's stdout
13. `startCommand()` does NOT read it (because `useMaster = true`)
14. Protocol handler reads `"started"` instead of `WORKER_MAGIC_2`
15. `protocol mismatch, got 'started'`

### Why Upstream Nix Never Triggers This

With `maxConnections = 1` (upstream default):
- `connections->capacity() = 1`
- `useMaster = (1 > 1) = false`
- No SSH masters are ever created
- `startCommand()` always reads `"started"` — no stale socket fallback path exists

The bug in `SSHMaster::startCommand()` (not consuming `"started"` when `useMaster = true`) is a **latent bug** that exists in both upstream and Determinate Nix. But upstream's `maxConnections=1` means `useMaster` is always false, so the bug is never reachable.

### Why `machines.cc` Doesn't Save Us

In `machines.cc`, the store URI is constructed with explicit `max-connections` for the `ssh` protocol:

```cpp
if (generic && generic->scheme == "ssh") {
    storeUri.params["max-connections"] = "1";
}
```

For `ssh-ng`: this line is **skipped**. The `ssh-ng` store inherits the `RemoteStoreConfig` default — which Determinate changed to 64.

### Verification

`strace` on the nix-daemon during a build confirmed SSH master creation:

```
104403 ssh build@10.88.127.43 -M -N -oControlPersist=no -i ... -S /tmp/nix-104377-.../ssh.sock
104410 ssh build@10.88.127.43 -x -i ... -S /tmp/nix-104377-.../ssh.sock -- nix-daemon --stdio
104532 ssh build@10.88.127.43 -M -N -oControlPersist=no -i ... -S /tmp/nix-104506-.../ssh.sock
```

Multiple SSH masters with different socket paths, confirming `useMaster = true`.

Empirical stale socket test confirmed `LocalCommand` fires on fallback:

```bash
ssh -M -N -S /tmp/test.sock -o ControlPersist=1s deploy@10.88.127.43 &
kill $!; sleep 3
ssh -S /tmp/test.sock -o LocalCommand="echo LEAKED" deploy@10.88.127.43 "echo REMOTE"
# Output: LEAKED \n REMOTE
```

## Resolution

### ~~Workaround: `nix.settings.max-connections = 1`~~ (INCORRECT — see below)

~~In `machines/LINDA/default.nix`:~~

```nix
nix.settings = {
  max-connections = 1;  # ← WRONG: not a valid nix.conf setting
  # ...
};
```

~~This overrides the Determinate default of 64, restoring upstream behavior. `useMaster = false`, no SSH masters, no stale sockets, no protocol leak. The `ssh-ng` protocol and fleet SSH multiplexing both work correctly.~~

### Correct Fix: Store URI Parameter in `/etc/nix/machines`

**`max-connections` is a per-store `RemoteStoreConfig` parameter, NOT a global `nix.conf` setting.** The `nix.settings` NixOS option writes to `/etc/nix/nix.conf`, which only accepts global daemon settings. The nix.conf validator rejects `max-connections` as `unknown setting`.

**Evidence from Determinate Nix source:**
- `remote-store.hh:29-30`: `Setting<int> maxConnections{this, 64, "max-connections", ...}` — defined on `RemoteStoreConfig`, a store-level config class
- `machines.cc:66-68`: Only injects `max-connections=1` for `ssh` scheme, NOT `ssh-ng`
- `StoreReference::parse` (`store-reference.cc:76-77`): Parses `?key=value` query params from store URIs

**The fix:** Embed `?max-connections=1` as a store URI query parameter in `/etc/nix/machines`:

```nix
# modifier_imports/remote-builder.nix
environment.etc."nix/machines".text = lib.mkForce ''
  ssh-ng://build@100.107.101.14?max-connections=1 x86_64-linux /run/nix-daemon-keys/hyperhyper 10 10 big-parallel,kvm - -
  ssh-ng://build@10.88.127.43?max-connections=1 aarch64-linux /run/nix-daemon-keys/personal-builder 3 5 big-parallel - -
'';
```

`StoreReference::parse` extracts `max-connections=1` from the URI query string and passes it as a store parameter, overriding the `RemoteStoreConfig` default of 64. `useMaster = false`, no SSH masters, no stale sockets, no protocol leak.

**Why `mkForce`:** The NixOS `nix.buildMachines` module generates its own `/etc/nix/machines` via `environment.etc`. Without `mkForce`, the `types.lines` merge concatenates both texts, producing a broken double-entry file.

### Upstream Fix (Pending)

The bug in `SSHMaster::startCommand()` should be fixed regardless:

```cpp
// Current: skips reading "started" when useMaster=true
if (!useMaster && !isMasterRunning()) {
    reply = readLine(out.readSide.get());
}

// Proposed: always consume "started"
reply = readLine(out.readSide.get());
```

Or: set `max-connections=1` for `ssh-ng` in `machines.cc`, matching the `ssh` protocol.

## Files Changed

- `machines/LINDA/default.nix` — removed `max-connections = 1` from `nix.settings` (was invalid nix.conf setting)
- `modifier_imports/remote-builder.nix` — override `/etc/nix/machines` with `?max-connections=1` store URI param; builder exclusion wiring, explicit `Host build@*` block (defense in depth)
- `modules/ssh-multiplex.nix` — topology-only scoping, exclusion list option (defense in depth)

## References

- Determinate Nix `remote-store.hh` line 30: `maxConnections` default = 64
- Upstream Nix `remote-store.hh` line 29: `maxConnections` default = 1
- NixOS/nix#14132: SSH ControlMaster breaks ssh-ng remote store
- DeterminateSystems/nix-src#441: Remote store fails with SSH multiplexing
- Blog: `personal-website-blog/draft-blogs/2026-07-15-nix-ssh-multiplex-protocol-mismatch.md`
- Prior incident: `2026-07-14-nix-protocol-mismatch-arm-builder.md` (superseded)

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 2026-07-14 09:07 | First incident — protocol mismatch on `boehm-gc` build |
| 2026-07-14 09:16 | Mitigated by daemon reset; root cause misidentified as Determinate vs standard Nix |
| 2026-07-15 ~09:00 | Recurrence — `nixos-rebuild build --flake .#display-1` fails with same error |
| 2026-07-15 ~10:00 | SSH multiplexing identified as contributing factor |
| 2026-07-15 ~10:15 | SSH multiplexing scoped to topology subnets; exclusion list added |
| 2026-07-15 ~10:25 | Build test: 12+ derivations succeed, then intermittent failures resume |
| 2026-07-15 ~10:30 | Stale `/etc/nix/nix.conf` removed from arm-builder |
| 2026-07-15 ~11:00 | `strace` reveals daemon creates SSH masters (`-M -N`) — `maxConnections > 1` |
| 2026-07-15 ~11:30 | Stale socket fallback test confirms `LocalCommand` leaks on dead master |
| 2026-07-15 ~12:00 | Switched to `protocol = "ssh"` as workaround |
| 2026-07-15 ~13:00 | Determinate source found: `maxConnections` default changed from 1 to 64 |
| 2026-07-15 ~13:30 | Root cause confirmed. Applied `max-connections = 1` fix, reverted to `ssh-ng` |
| 2026-07-16 ~14:00 | Discovered `nix.settings.max-connections` is invalid (per-store param, not nix.conf). Corrected: embed `?max-connections=1` as store URI param in `/etc/nix/machines` |
