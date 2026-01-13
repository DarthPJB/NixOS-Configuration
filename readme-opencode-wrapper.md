# OpenCode Wrapper Readme

## Expected User Desire Summary

**Core Goal:** Minimal, isolated sandbox for opencode execution with direct project edits and clean config branching, preserving host git history and single source of truth.

### Work-Folder (Project):
- Direct rw bind from host PWD to sandbox `/home/opencode-sandbox/work`.
- No copy/strip; .git/history preserved on host.
- chdir to `/home/opencode-sandbox/work` before exec.
- Edits live on host; no script mods to host git.

### Agent-Config (/speed-storage/opencode):
- Single source of truth: Host `/speed-storage/opencode`.
- Clean copy (rm .git) to temp_full → mount to sandbox `/speed-storage/opencode`.
- Sub: temp_full/.opencode → bind to sandbox `/var/lib/opencode`.
- Exit: Branch temp_full to host `/speed-storage/opencode` (stash-safe, main → new branch → commit → main; discard sub).

### Sandbox User:
- UID/GID 4000; home `/home/opencode-sandbox`.
- Config at `/home/opencode-sandbox/.config/opencode` (if needed, bind from temp_full/.opencode).

### Execution:
- chdir /home/opencode-sandbox/work; exec opencode (args forwarded).
- No host work git ops; config branch only.

### Minimal Impl: 
- 2 binds (work direct, config full copy); stash-branch config; no work copy.

**Matches Conversation:** Yes (direct work, clean config copy/branch, sub bind, no host work mods).