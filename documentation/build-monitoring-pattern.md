# Long-Running Build Monitoring Pattern

> **Recommended practice for all agents and users running builds that may take minutes to hours.**

## The Pattern

Use **tmux + log files + passive polling** for any long-running NixOS build, kernel compilation, or remote builder operation.

### Launch (detached in tmux)

```bash
tmux new-session -d -s <session-name> \
  "<command> 2>&1 | tee /tmp/<name>.log; echo BUILD_DONE | tee -a /tmp/<name>.log"
```

**Example:**
```bash
tmux new-session -d -s build-display-1 \
  "cd /path/to/flake && nix build .#nixosConfigurations.display-1.config.system.build.toplevel \
  --no-link --print-out-paths 2>&1 | tee /tmp/build-display-1.log; \
  echo BUILD_DONE | tee -a /tmp/build-display-1.log"
```

### Monitor (passive, non-blocking)

```bash
# Check last N lines of output
tail -5 /tmp/build-display-1.log

# Check for errors
grep -i "error:" /tmp/build-display-1.log

# Check if complete
grep BUILD_DONE /tmp/build-display-*.log

# Verify process is alive
ps aux | grep "nix build" | grep -v grep

# Check remote builder activity
ssh deploy@<builder-ip> "uptime; free -h; ps aux | grep gcc | grep -v grep"
```

### Attach (if interactive view needed)

```bash
tmux attach -t build-display-1
```

### Cleanup

```bash
tmux kill-session -t build-display-1
```

## Why This Works

| Benefit | Explanation |
|---------|-------------|
| **Persistence** | tmux sessions survive SSH disconnects, terminal closes, network drops |
| **Non-blocking** | Poll logs without interrupting the build |
| **Auditable** | Full output preserved in log file for debugging |
| **Parallel** | Run multiple builds simultaneously in separate sessions |
| **Safe** | No timeout issues — builds continue independently |
| **Observable** | Can monitor both client and server sides |

## Use Cases

- NixOS system builds (`nix build`)
- Remote builder dispatch (aarch64 builds via SSH)
- Kernel compilation
- Large package builds
- Any operation expected to take > 30 seconds

## Anti-Patterns to Avoid

- ❌ Running builds directly in SSH sessions (will timeout/kill on disconnect)
- ❌ Using `nohup` without log redirection (no progress visibility)
- ❌ Polling with `watch` (blocks terminal, can't compose with other checks)
- ❌ Ignoring error output (always check `grep error:`)

## Related

- [ARM Build Limitations](arm-build-limitations.md) — Uses this pattern for remote builder operations
- tmux man page: `man tmux`
