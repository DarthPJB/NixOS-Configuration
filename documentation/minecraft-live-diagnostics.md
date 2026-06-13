# Minecraft Live Diagnostics — mcrcon Workflow

**Date:** 2026-06-13
**Machine:** gaming-host-1 (`mc-curseforge-all-the-mons`)
**Tool:** `mcrcon` (installed via `environment.systemPackages`)

## Prerequisites

- WireGuard VPN connectivity to `10.88.127.0/24`
- SSH key authorized for the `deploy` user (ED25519 from `secrets/public_keys/JOHN_BARGMAN_ED_25519.pub`)
- `deploy` user has `NOPASSWD: ALL` sudo (required for localhost RCON access)

## SSH Access

```bash
ssh -p 1108 deploy@10.88.127.52
```

The `deploy` user home is `/tmp/deploy` (ephemeral, cleaned on boot). RCON requires `sudo` because the MC process runs as `mc-curseforge-all-the-mons` and binds localhost only.

## mcrcon One-Liner (from your local machine)

```bash
ssh -o ConnectTimeout=10 -p 1108 deploy@10.88.127.52 \
  "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' <command>"
```

## Service Status Check

```bash
# Is the MC service running?
ssh -p 1108 deploy@10.88.127.52 "systemctl is-active mc-curseforge-all-the-mons"

# Full service status
ssh -p 1108 deploy@10.88.127.52 "systemctl status mc-curseforge-all-the-mons --no-pager"

# Recent journal
ssh -p 1108 deploy@10.88.127.52 "journalctl -u mc-curseforge-all-the-mons -n 50 --no-pager"

# Watch for failures after deploy (see snippets/watch-service.sh)
./snippets/watch-service.sh 10.88.127.52 mc-curseforge-all-the-mons 1108
```

## Essential mcrcon Commands

All commands use: `mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' <command>`

### Player Management

| Command | Description |
|---------|-------------|
| `list` | Show online players (uuids + names) |
| `whitelist list` | Show whitelist |
| `whitelist add <player>` | Add player to whitelist |
| `whitelist remove <player>` | Remove player from whitelist |
| `ban <player>` | Ban a player |
| `pardon <player>` | Unban a player |
| `op <player>` | Grant operator |
| `deop <player>` | Remove operator |
| `kick <player> [reason]` | Kick a player |

### World State

| Command | Description |
|---------|-------------|
| `save-all` | Force immediate world save |
| `time query daytime` | Show current game time (ticks) |
| `time set <value>` | Set time (day=1000, noon=6000, night=13000, midnight=18000) |
| `difficulty` | Show current difficulty |
| `gamerule <rule>` | Query a gamerule value |
| `gamerule <rule> <value>` | Set a gamerule |

### Weather & Environment

| Command | Description |
|---------|-------------|
| `weather clear [duration]` | Clear weather |
| `weather rain [duration]` | Start rain |
| `weather thunder [duration]` | Start thunderstorm |

### Chat & Announcements

| Command | Description |
|---------|-------------|
| `say <message>` | Broadcast to all players |
| `tell <player> <message>` | Private whisper to a player |
| `msg <player> <message>` | Alias for tell |
| `tellraw @a {"text":"...","color":"gold"}` | Rich text broadcast |

### Item Management

| Command | Description |
|---------|-------------|
| `give <player> <item>` | Give an item (e.g. `minecraft:poppy`, `minecraft:diamond`) |
| `give <player> <item> <count>` | Give multiple items |
| `clear <player>` | Clear entire inventory (**destructive**) |
| `clear <player> <item>` | Clear only a specific item |
| `clear <player> <item> <count>` | Clear up to `<count>` of an item |

**Example — timed batch delivery:**
```bash
# Give a poppy + whisper every second for 5 seconds
ssh -p 1108 deploy@10.88.127.52 '
for i in $(seq 1 5); do
  sudo mcrcon -H 127.0.0.1 -P 25575 -p "allthemons" "give MahouShojoKaida minecraft:poppy"
  sudo mcrcon -H 127.0.0.1 -P 25575 -p "allthemons" "tell MahouShojoKaida from Gobi via LLM"
  sleep 1
done'
```

**Example — replace bugged items with fresh copies:**
```bash
# Clear bugged cardboard boxes, then give fresh empty ones
ssh -p 1108 deploy@10.88.127.52 \
  "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'clear darthpjb mekanism:cardboard_box' && \
   sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'give darthpjb mekanism:cardboard_box 15'"
```

### Inventory Inspection

The full inventory data exceeds RCON's 4096-byte packet limit. Query slot-by-slot instead:

```bash
ssh -p 1108 deploy@10.88.127.52 '
for slot in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 \
            18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 \
            100 101 102 103 -106; do
  result=$(sudo mcrcon -H 127.0.0.1 -P 25575 -p "allthemons" \
    "data get entity <player> Inventory[{Slot:${slot}b}]" 2>&1)
  if echo "$result" | grep -q "found no elements"; then
    continue
  fi
  echo "$result" | grep -v "^$"
done'
```

**Slot map:**
| Slots | Area |
|-------|------|
| 0–8 | Hotbar |
| 9–35 | Main inventory (27 slots) |
| 100 | Boots |
| 101 | Leggings |
| 102 | Chestplate |
| 103 | Helmet |
| -106 | Offhand |

### squaremap Web Viewer (plugin)

squaremap provides a live web map at `https://gaming-host-1.johnbargman.net/` (served via nginx reverse proxy on port 443, backed by squaremap on port 8080). All commands use the `/squaremap` prefix:

| Command | Description |
|---------|-------------|
| `squaremap help` | List all squaremap commands (3 pages) |
| `squaremap cancelrender <world>` | Cancel an active render (e.g. `minecraft:overworld`) |
| `squaremap radiusrender <world> <radius> [center]` | Render a focused area (e.g. `minecraft:overworld 5 0 0`) |
| `squaremap fullrender <world>` | Full world render |
| `squaremap pauserender <world>` | Pause a running render |
| `squaremap resetmap <world>` | Wipe and re-render the entire map |
| `squaremap progresslogging` | Check progress logging status |
| `squaremap progresslogging toggle` | Toggle render progress logging |
| `squaremap progresslogging rate <seconds>` | Set progress log interval |
| `squaremap reload` | Reload squaremap config |
| `squaremap show [player]` | Show/hide player on map |

**Render management workflow:**
```bash
# Check if renders are running
ssh -p 1108 deploy@10.88.127.52 \
  "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'squaremap progresslogging'"

# Cancel a stuck/broken render
ssh -p 1108 deploy@10.88.127.52 \
  "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'squaremap cancelrender minecraft:overworld'"

# Focused re-render around a specific area (e.g. factory)
ssh -p 1108 deploy@10.88.127.52 \
  "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'squaremap radiusrender minecraft:overworld 5 548 -2480'"
```

## Safe Shutdown via RCON

Never `kill -9` the Minecraft process — it corrupts world data. Use the graceful shutdown path (the same one systemd's `ExecStop` uses):

```bash
# Warn players, save, then stop
ssh -p 1108 deploy@10.88.127.52 "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' \
  'say §cServer shutting down in 30 seconds§r' \
  && sleep 25 \
  && sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'save-all' \
  && sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' stop"
```

Or use systemd (which runs the same graceful ExecStop):
```bash
ssh -p 1108 deploy@10.88.127.52 "sudo systemctl stop mc-curseforge-all-the-mons"
```

## Service Lifecycle

```bash
# Restart the MC service (graceful stop + start)
ssh -p 1108 deploy@10.88.127.52 "sudo systemctl restart mc-curseforge-all-the-mons"

# Check restart limit status (prevents restart storms — StartLimitBurst=5, Interval=600s)
ssh -p 1108 deploy@10.88.127.52 "systemctl show mc-curseforge-all-the-mons | grep -i limit"
```

## Common Diagnostic Scenarios

### Players Report Lag / Server Unresponsive
```bash
# Check online count
ssh -p 1108 deploy@10.88.127.52 "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' list"

# Check memory usage
ssh -p 1108 deploy@10.88.127.52 "ps aux | grep -i forge | grep -v grep"

# Broadcast an apology/ETA
ssh -p 1108 deploy@10.88.127.52 "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'say §6Server diagnostics in progress - brief lag possible'"
```

### Squaremap Not Rendering / Shows Holes
```bash
# Cancel any stuck render
ssh -p 1108 deploy@10.88.127.52 "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'squaremap cancelrender minecraft:overworld'"

# Trigger fresh render
ssh -p 1108 deploy@10.88.127.52 "sudo mcrcon -H 127.0.0.1 -P 25575 -p 'allthemons' 'squaremap radiusrender minecraft:overworld 10'"
```

### Server Crashed / Restart Storm
```bash
# Check restart history
ssh -p 1108 deploy@10.88.127.52 "journalctl -u mc-curseforge-all-the-mons --since '1 hour ago' --no-pager"

# Reset restart counter if needed
ssh -p 1108 deploy@10.88.127.52 "sudo systemctl reset-failed mc-curseforge-all-the-mons"
```

## Configuration Reference

All RCON settings are in the machine config at `machines/gaming-host-1/default.nix:81-111`:

```nix
services.minecraft-curseforge.all-the-mons = {
  enable = true;
  gamePort = 25565;       # client connection port
  rconPort = 25575;       # RCON (localhost only)
  rconPassword = "allthemons";  # TODO: move to secrets
  maxMemory = "8G";
  minMemory = "4G";
  enableSquaremap = true;
  squaremapPort = 8080;   # map web viewer
  ...
};
```

The mcrcon executable path is baked into the systemd unit at deployment via `${lib.getExe pkgs.mcrcon}` (see `server_services/game_servers/minecraft-curseforge.nix:385-388`). It is always installed at `/run/current-system/sw/bin/mcrcon` on the target machine.
