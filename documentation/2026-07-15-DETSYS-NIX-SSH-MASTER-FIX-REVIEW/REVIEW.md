# Review: Determinate Nix SSH Master Protocol Leak — Solution Vectors

**Date:** 2026-07-15  
**Type:** Architectural / Upstream Fix Analysis  
**Objective:** Identify fix vectors for the `SSHMaster::startCommand()` protocol leak that work WITH Determinate Nix's `maxConnections=64` default, without limiting existing functionality.

---

## Problem Statement

Determinate Nix changed `RemoteStoreConfig::maxConnections` default from **1** (upstream) to **64**. This enables SSH master mode (`-M -N`) for `ssh-ng` remote builders. The SSH masters have `ControlPersist=no` (OpenSSH default), causing them to die when the last command disconnects. When a command SSH falls back to a direct connection through a stale master socket, `LocalCommand=echo started` fires on the command SSH, and `startCommand()` does not consume it (because `useMaster=true`). The `"started"` string leaks into the nix protocol stream, causing `protocol mismatch, got 'started'`.

## Key Source Files

- `/speed-storage/bargman-tech/determinate/src/libstore/ssh.cc` — `SSHMaster::startCommand()`, `SSHMaster::startMaster()`
- `/speed-storage/bargman-tech/determinate/src/libstore/include/nix/store/remote-store.hh` — `maxConnections` default (64)
- `/speed-storage/bargman-tech/determinate/src/libstore/machines.cc` — `max-connections=1` only for `ssh`, not `ssh-ng`
- `/speed-storage/bargman-tech/determinate/src/libstore/ssh-store.cc` — `SSHStore` constructor, `useMaster` logic

## The Bug (Exact Location)

In `ssh.cc`, `SSHMaster::startCommand()`:

```cpp
if (!fakeSSH && !useMaster && !isMasterRunning()) {
    reply = readLine(out.readSide.get());
    if (reply != "started") { throw Error("failed to start SSH connection..."); }
}
conn->out = std::move(out.readSide);
```

When `useMaster=true`, the code skips reading `"started"`. This is correct for live master connections (where `LocalCommand` doesn't run on command SSHs). But when the master is dead and the command SSH falls back to a direct connection, `LocalCommand` fires and `"started"` leaks.

## Constraints

- Must NOT reduce `maxConnections` default (64 is intentional for Determinate daemon performance)
- Must NOT break the existing master mode for live connections
- Must NOT require changes to fleet SSH configuration
- Must handle the stale-socket-fallback case gracefully
- Should be upstreamable to both NixOS/nix and DeterminateSystems/nix-src

## Solution Vectors to Evaluate

### Vector 1: Always consume "started" in `startCommand()`

Remove the `!useMaster` guard. Always read "started" from the command SSH's stdout.

**Risk:** When `useMaster=true` and the master is alive, the command SSH through a live master does NOT produce "started". `readLine()` would block waiting for data, then read WORKER_MAGIC_2 as the first bytes. `reply != "started"` would throw "failed to start SSH connection".

**Verdict:** Broken as-is. Needs modification.

### Vector 2: Detect dead master before consuming "started"

After spawning the command SSH, check if the master socket is still alive. If dead, consume "started". If alive, skip.

**Implementation:** Call `isMasterRunning()` after `startProcess()` but before the `readLine()` conditional. If the master died between `startMaster()` and `startCommand()`, the fallback has occurred.

**Risk:** Race condition — the master might die between the check and the read. Also, `isMasterRunning()` runs `ssh -O check` which has overhead.

### Vector 3: Set `ControlPersist=15m` on the master SSH

Add `-oControlPersist=15m` to the master SSH args in `startMaster()`. This keeps the master alive for 15 minutes after the last command disconnects.

**Implementation:** In `startMaster()`, after building the args list, add:
```cpp
args.push_back(OS_STR("-oControlPersist=15m"));
```

**Risk:** Doesn't fix the underlying bug — just makes it much less likely to trigger. If the master dies for other reasons (network interruption, OOM kill), the issue persists.

### Vector 4: Use `-oLocalCommand=true` on command SSHs (no-op)

Override `LocalCommand` on command SSHs to a no-op command. This prevents `"started"` from appearing on the command SSH's stdout even if it falls back to a direct connection.

**Implementation:** In `startCommand()`, when `useMaster=true`, add `-oLocalCommand=true` to the command SSH args (after `addCommonSSHOpts` which adds `-oLocalCommand=echo started`). The later `-oLocalCommand=true` overrides the earlier one.

**Risk:** If the command SSH falls back to a direct connection, the no-op `LocalCommand` means `startCommand()` doesn't need to consume anything. But `startCommand()` still skips the read (because `useMaster=true`), so the protocol handler reads the nix-daemon protocol directly. This should work.

### Vector 5: Use a separate file descriptor for "started" signal

Replace `LocalCommand=echo started` with a mechanism that writes to a file descriptor or named pipe, not stdout. `startCommand()` reads from the file descriptor instead of stdout.

**Implementation:** Use `-oLocalCommand="echo started >&3"` and pass fd 3 through the SSH process. `startCommand()` reads from fd 3 instead of stdout.

**Risk:** Complex. SSH might not pass arbitrary file descriptors. Requires changes to both `startMaster()` and `startCommand()`.

### Vector 6: Use `-F /dev/null` on all Nix SSH invocations

Force SSH to ignore the system config by passing `-F /dev/null`. This prevents any OS-level `ControlMaster` or `LocalCommand` settings from interfering.

**Implementation:** In `addCommonSSHOpts()`, add:
```cpp
args.push_back(OS_STR("-F"));
args.push_back(OS_STR("/dev/null"));
```

**Risk:** This prevents Nix from using any SSH config settings (like `UserKnownHostsFile`, `IdentityFile`, etc.). Nix already passes these via command-line options, so it should work. But it's a heavy-handed approach.

### Vector 7: Set `max-connections=1` for `ssh-ng` in `machines.cc`

Match the `ssh` protocol behavior:
```cpp
if (generic && (generic->scheme == "ssh" || generic->scheme == "ssh-ng")) {
    storeUri.params["max-connections"] = "1";
}
```

**Risk:** Limits `ssh-ng` to a single connection. This defeats the purpose of Determinate's `maxConnections=64` change. Not acceptable per constraints.

---

## Review Questions for Agents

1. Which vectors are technically sound and upstreamable?
2. Which vectors have the lowest risk of regression?
3. Are there hybrid approaches that combine multiple vectors?
4. What are the edge cases for each vector?
5. Is there a vector we haven't considered?
6. What would the Nix upstream maintainers likely accept?
