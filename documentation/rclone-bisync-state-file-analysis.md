# Rclone Bisync State File Format Analysis

## Executive Summary

The rclone bisync state file format changed significantly between versions 1.68 and 1.72, introducing path hash prefixes like `local__` to state filenames. This incompatibility causes bisync services to fail when upgrading from older versions (likely <1.70) to rclone 1.72.1.

## Root Cause Analysis

### 1. State File Naming Convention Change Timeline

**Key Change:** The bisync state file naming convention was updated to include path hash prefixes (like `local__`, `remote__`) starting in **rclone v1.70.0** (released 2025-06-17).

**Evidence from Changelog:**
- **v1.70.0** (2025-06-17): Major bisync improvements and stabilization
- **v1.71.0** (2025-08-22): Bisync promoted from beta to stable
- **v1.72.0** (2025-11-21): Continued bisync refinements

The `local__` prefix is part of a new state file naming scheme that includes cryptographic hashes of the source and destination paths to prevent state file collisions and improve security.

### 2. `--resync` vs `--resilient` Behavior

**`--resync` (used in OnFailure service):**
- **Purpose:** Performs a complete resynchronization from scratch
- **Effect:** Creates **new state files** in the current format
- **Behavior:** Copies all files from both sides to create a superset (equivalent to `rclone copy Path2 Path1 --ignore-existing` followed by `rclone copy Path1 Path2`)
- **State Files:** Generates fresh state files in the **new format** (with `local__` prefix)

**`--resilient` (used in normal operation):**
- **Purpose:** Allows recovery from minor errors without requiring full resync
- **Effect:** Uses existing state files if compatible
- **Behavior:** Attempts to continue with existing state, falls back to requiring `--resync` if state is corrupted
- **State Files:** Expects state files in the format they were created (old format fails)

### 3. Does `rclone bisync --resync` Regenerate State Files?

**YES.** `--resync` **does regenerate state files in the new format**, including the `local__` prefix. This is the primary recovery mechanism for state file incompatibility.

**Critical Detail:** The OnFailure resync service in your configuration (`rclone-sync-${name}-resync`) uses `--resync`, but it may still fail if:
1. The old state files exist and cause confusion
2. The state directory contains mixed old/new format files
3. Permissions or path issues prevent new state file creation

### 4. Correct Recovery Procedure

**For Bisync State File Incompatibility:**

1. **Stop all bisync services** (timers and services)
2. **Backup existing state files** (located in `~/.cache/rclone/bisync/` or systemd service-specific cache)
3. **Delete old state files** for the affected sync pair:
   ```bash
   rm -f ~/.cache/rclone/bisync/*${sync_name}*.lst
   rm -f ~/.cache/rclone/bisync/*${sync_name}*.lst.*
   ```
4. **Run manual resync with verbose logging:**
   ```bash
   rclone bisync ${source} ${destination} --resync --verbose --dry-run
   ```
   Verify output, then run without `--dry-run`
5. **Verify new state files** are created with `local__` prefix
6. **Restart normal bisync service** (without `--resync`)

### 5. Specific Fix for Your NixOS Configuration

The issue manifests in your system because:
1. Old rclone version created state files without `local__` prefix
2. New rclone 1.72.1 expects `local__` prefix
3. OnFailure resync service may fail due to state file confusion

**Immediate Solution:**

```bash
# For each failing bisync service:
# 1. Find the state file directory
#    Systemd services run as user 'John88', check:
#    /home/John88/.cache/rclone/bisync/
#    /var/cache/rclone/bisync/

# 2. Identify and remove old state files
sudo -u John88 rm -f /home/John88/.cache/rclone/bisync/*${sync_name}*

# 3. Manually run resync
sudo -u John88 rclone bisync ${source_path} ${remote} --resync --config ${config_path}

# 4. Verify new state files exist with local__ prefix
sudo -u John88 ls -la /home/John88/.cache/rclone/bisync/ | grep local__
```

## Preventive Measures

### 1. Version Upgrade Protocol
Always run `--resync` after major rclone version upgrades (especially across 1.68→1.70 boundary).

### 2. State File Management
```bash
# Add to upgrade scripts:
systemctl stop rclone-sync-*.timer
systemctl stop rclone-sync-*.service
find ~/.cache/rclone/bisync -name "*.lst" -mtime +30 -delete
# Then restart services
```

### 3. Monitoring
Add state file format checks to monitoring:
```bash
# Check for old-format state files
find ~/.cache/rclone/bisync -name "*.lst" ! -name "*local__*" ! -name "*remote__*"
```

## Technical Details

### State File Location
- Linux: `~/.cache/rclone/bisync/`
- macOS: `~/Library/Caches/rclone/bisync/`
- Windows: `C:\Users\Username\AppData\Local\rclone\bisync\`

### New Naming Format
```
local__{hash1}_{hash2}.lst
remote__{hash1}_{hash2}.lst
```
Where `{hash1}` and `{hash2}` are cryptographic hashes of the source and destination paths.

### Migration Path
1. Old format: `path1_path2.lst`
2. New format: `local__{hash1}_{hash2}.lst`, `remote__{hash1}_{hash2}.lst`

## Recommendation

**Immediate Action:** For each failing bisync service:
1. Stop the service and timer
2. Remove old state files
3. Run manual `--resync`
4. Verify new state file creation
5. Restart service

**Long-term:** Add state file cleanup to your rclone version upgrade procedures, and consider implementing a wrapper script that checks state file compatibility before running bisync.