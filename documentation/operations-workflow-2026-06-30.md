# Operations Workflow — 2026-06-30

Session summary: backup system audit, passive inspection user deployment, and minecraft backup verification.

## What We Did

### 1. Stale Worktree Cleanup

Removed 3 stale worktrees that were fully merged or superseded:
- `/tmp/arm-build-26` — fully merged
- `/tmp/fuck-police` — fully merged
- `/tmp/nixinate-image-test` — superseded (subset of overlord-I)

**Lesson:** Always check `git worktree list` and verify merge status before removing.

### 2. Documentation Cleanup

Extracted unique content from 7 AI-generated HTML files into Markdown, then deleted the HTML:
- `security-reference.md` — user UIDs, security layers, incident response
- `operations-runbooks.md` — maintenance schedules, deployment runbooks
- `development-guide.md` — prohibited practices, troubleshooting
- `roadmap-snapshot.md` — technical debt, success metrics, timeline

Removed dead `cloud_and_backup.nix` stub (rsync already provided by `code.nix`).

### 3. Inspect User — Passive System Inspection

Created a fleet-wide low-privilege user for passive system inspection:

| Property | Value |
|----------|-------|
| User | `inspect` |
| UID | 1112 |
| Groups | none (no sudo, no wheel) |
| SSH | port 1108, WireGuard only |
| Key | `secrets/inspect_private_key` (age-encrypted, John88 only) |

**Files created:**
- `users/inspect.nix` — user module
- `secrets/inspect_private_key` — encrypted private key
- `secrets/public_keys/INSPECT_ED_25519.pub` — public key

**Usage:**
```bash
# Check service status
ssh -p 1108 inspect@10.88.127.52 "systemctl status nginx.service"

# Read logs (limited — not in adm group)
ssh -p 1108 inspect@10.88.127.52 "journalctl -u minecraft -n 50"

# Check filesystem
ssh -p 1108 inspect@10.88.127.52 "df -h && free -m"
```

**Key generation:**
```bash
ssh-keygen -t ed25519 -f /home/pokej/.ssh/id_ed25519_inspect -C "inspect@fleet" -N ""
cp /home/pokej/.ssh/id_ed25519_inspect.pub secrets/public_keys/INSPECT_ED_25519.pub
cat /home/pokej/.ssh/id_ed25519_inspect | nix run .#secrix encrypt secrets/inspect_private_key -- -u John88
```

### 4. Minecraft Backup to local-nas

Added rclone backup for gaming-host-1's minecraft world archives:

**Configuration (`services/minecraft-backup.nix`):**
- Source: `/bulk-storage/minecraft/all-the-mons/backups/`
- Destination: `minio:minecraft-backups` (S3 on local-nas)
- Mode: copy (one-way backup)
- Schedule: daily at 06:00 UTC
- Bandwidth: 10MB/s limit
- Rotation: 14 days (preExec)

**Prerequisites:**
- rclone config with `minio` remote (S3 on local-nas at `10.88.127.3:2222`)
- `lib/rclone-target.nix` imported by machine config

**Verification:**
```bash
# Check service status
ssh -p 1108 inspect@10.88.127.52 "systemctl status rclone-sync-mc-backups.service"

# Check timer
ssh -p 1108 inspect@10.88.127.52 "systemctl status rclone-sync-mc-backups.timer"

# Trigger manually (requires deploy user)
ssh -p 1108 deploy@10.88.127.52 "sudo systemctl start rclone-sync-mc-backups.service"

# Verify on local-nas
ssh -p 1108 deploy@10.88.127.3 "sudo ls -la /bulk-storage/minio/minecraft-backups/"
```

### 5. LINDA Backup Audit

Found and fixed:
- **Leading space bug:** `" /bulk-storage/88-DB-v3/"` → `"/bulk-storage/88-DB-v3/"`
- **Dead code:** Moved `syncthing_server.nix` to `snippets/` (not imported by any machine)

**Active backup on LINDA:**
- Target: `obsidian-v3`
- Source: `/bulk-storage/88-DB-v3/` (800MB Obsidian vault)
- Destination: `minio:obsidian-v3` (S3 on local-nas)
- Mode: bisync (bidirectional)
- Interval: 60 seconds

### 6. Backup Architecture

All backups use the same pattern:

```
Machine → rclone → minio (S3) → local-nas
```

**Active backups:**

| Machine | Target | Source | Destination | Mode | Schedule |
|---------|--------|--------|-------------|------|----------|
| LINDA | `obsidian-v3` | `/bulk-storage/88-DB-v3/` | `minio:obsidian-v3` | bisync | 60s |
| terminal-zero | `obsidian-v3` | `/home/pokej/88-DB-v3/` | `minio:obsidian-v3` | bisync | 60s |
| gaming-host-1 | `mc-backups` | `/bulk-storage/minecraft/all-the-mons/backups/` | `minio:minecraft-backups` | copy | daily 06:00 |

**Minio on local-nas:**
- Endpoint: `http://10.88.127.3:2222`
- Config: `secrets/rclone-config-file` (encrypted with secrix)
- Buckets: `obsidian-v3` (806M), `minecraft-backups` (33.6G)

## User Hierarchy (Now Standard)

| User | Purpose | Authorization |
|------|---------|---------------|
| `inspect` | Passive inspection | Automatic (key-based) |
| `deploy` | Deployment + admin | Manual (user authorizes) |
| `John88` | Personal access | Manual (key-based) |
| `build` | Remote builds | Automatic (key-based) |

**Rule:** Passive inspection always uses `inspect` user. Administrative commands require `deploy` user with manual authorization.

## Future Plans

### Backup Transformer (overlord-II)

Topology-driven backup configuration:
```nix
# topology/gaming-host-1.nix
{
  backup = {
    targets = {
      mc-backups = {
        source = "/bulk-storage/minecraft/all-the-mons/backups/";
        bucket = "minecraft-backups";
        mode = "copy";
        calendar = "*-*-* 06:00:00";
      };
    };
  };
}
```

Part of topology rectification (`jb/overlord-II`). See `documentation/plans/topology-rectification-2026-06-23.md`.

## Lessons Learned

1. **Always verify paths exist** — the leading space in LINDA's filePath was a bug
2. **Use inspect for passive access** — don't use deploy user for read-only operations
3. **Minio S3 is the standard** — all backups go to local-nas via S3
4. **Check dead code** — `syncthing_server.nix` was never imported
5. **Verify backup completion** — monitor service status and verify on destination
