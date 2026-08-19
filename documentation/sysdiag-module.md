# System Diagnostics Module

A NixOS module for collecting system diagnostics on a schedule. Deploys `sysdiag.sh` as a systemd oneshot service with optional periodic timer.

## Features

- **Comprehensive collection**: System info, hardware, memory, disk, network, systemd units, journal logs, kernel messages, processes, security, NixOS-specific data
- **Size safeguards**: Per-file and total output size limits prevent runaway collection
- **Configurable**: All settings controlled via NixOS options
- **Retention management**: Automatic cleanup of old diagnostic reports
- **Security hardened**: systemd sandboxing options

## Quick Start

```nix
# In your NixOS configuration:
services.sysdiag = {
  enable = true;
  enableTimer = true;
};
```

## Options

### `services.sysdiag`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the diagnostics service |
| `enableTimer` | bool | `false` | Enable periodic collection via systemd timer |
| `outputBase` | str | `"/tmp"` | Base directory for output |
| `collection` | attrsOf bool | all `true` | Enable/disable individual categories |
| `journalRecentLines` | positive int | `1000` | Recent journal lines to collect |
| `journalErrorLines` | positive int | `500` | Error-level journal lines |
| `journalWarningLines` | positive int | `500` | Warning-level journal lines |
| `processTopCount` | positive int | `50` | Top processes by CPU/memory |
| `maxFileSize` | str | `"10M"` | Max size per collected file |
| `maxTotalSize` | str | `"100M"` | Max total output directory size |
| `collectBootJournal` | bool | `false` | Collect full boot journal (can be 100MB+ with debug logging) |
| `timerConfig` | attrsOf str | `{ OnBootSec = "5min"; OnUnitActiveSec = "1h"; ... }` | Timer configuration |
| `securitySettings` | submodule | `{ protectSystem = "strict"; protectHome = "read-only"; noNewPrivileges = false; }` | Security hardening |

### `services.sysdiag-cleanup`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable cleanup service |
| `retentionDays` | unsigned int | `30` | Remove reports older than N days (0 to disable) |
| `retentionCount` | unsigned int | `10` | Keep only N most recent reports (0 to disable) |
| `timerConfig` | attrsOf str | `{ OnCalendar = "daily"; ... }` | Cleanup timer configuration |

## Collection Categories

| Category | Description |
|----------|-------------|
| `system` | Kernel, hostname, uptime, OS release |
| `hardware` | lshw, lscpu, lspci, lsusb, dmidecode |
| `memory` | free, meminfo, swapon, vmstat |
| `disk` | df, lsblk, blkid, mount, fdisk |
| `network` | ip, ss, nftables, resolv.conf, wireguard |
| `systemd` | units, failed units, timers, sockets |
| `journal` | Recent entries, errors, warnings |
| `kernel` | dmesg, lsmod, sysctl, cmdline |
| `processes` | ps, top, resource consumers |
| `security` | passwd, shadow, ssh config, logins |
| `nixos` | configuration.nix, nix-store, generations |
| `logs` | auth.log, syslog, messages |

## Size Safeguards

The module includes protection against runaway collection:

- **Per-file limit** (`maxFileSize`): Each collected file is truncated at this size
- **Total limit** (`maxTotalSize`): Collection stops if output directory exceeds this
- **Command timeout**: Each command has a 30-second timeout
- **Boot journal**: Disabled by default (can be 100MB+ with debug logging)

## Examples

### Minimal (errors only)

```nix
services.sysdiag = {
  enable = true;
  collection = {
    system = true;
    journal = true;
    kernel = true;
    # Disable everything else
    hardware = false;
    memory = false;
    disk = false;
    network = false;
    systemd = false;
    processes = false;
    security = false;
    nixos = false;
    logs = false;
  };
};
```

### Debug mode (full collection)

```nix
services.sysdiag = {
  enable = true;
  enableTimer = true;
  collectBootJournal = true;
  journalRecentLines = 5000;
  maxFileSize = "50M";
  maxTotalSize = "500M";
  timerConfig = {
    OnBootSec = "5min";
    OnUnitActiveSec = "1h";
  };
};
```

### Custom output location

```nix
services.sysdiag = {
  enable = true;
  outputBase = "/var/log/sysdiag";
};
```

## Ad-hoc Usage

```bash
# Run immediately
sudo sysdiag

# Run with custom settings
SYSDIAG_COLLECT_HARDWARE=0 SYSDIAG_MAX_TOTAL_SIZE=50M sudo sysdiag
```

## Output Structure

```
<outputBase>/sysdiag-<hostname>-<timestamp>/
├── summary.txt
├── system/
│   ├── uname.txt
│   ├── hostname.txt
│   └── ...
├── hardware/
├── memory/
├── disk/
├── network/
├── systemd/
├── journal/
├── kernel/
├── processes/
├── security/
├── nixos/
└── logs/
```

## Troubleshooting

### Collection is slow

- Disable hardware collection: `collection.hardware = false`
- Reduce journal lines: `journalRecentLines = 500`
- Reduce process count: `processTopCount = 20`

### Output is too large

- Reduce `maxFileSize` and `maxTotalSize`
- Disable boot journal: `collectBootJournal = false`
- Reduce journal line counts

### Permission errors

The module uses `systemd.tmpfiles.rules` to ensure the output directory exists with correct permissions. For `/tmp`, mode is `1777`; for other paths, mode is `0755`.

## Architecture

```
sysdiag.nix (NixOS module)
    ├── options.services.sysdiag.*
    ├── options.services.sysdiag-cleanup.*
    └── config
        ├── systemd.services.sysdiag (oneshot)
        ├── systemd.timers.sysdiag (optional)
        ├── systemd.services.sysdiag-cleanup (oneshot)
        ├── systemd.timers.sysdiag-cleanup
        └── environment.systemPackages (sysdiag wrapper)
```

The wrapper script exports Nix-managed configuration as environment variables, then execs the canonical `sysdiag.sh` script. This keeps the script usable standalone while the module controls configuration.
