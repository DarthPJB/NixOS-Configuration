#!/usr/bin/env nix-shell
#!nix-shell -i bash -p mcrcon bash coreutils gnugrep gawk openssh
#!nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/nixos-24.11.tar.gz
# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# mc-item-monitor.sh — Passive RCON-based item entity monitor for Minecraft
#
# Monitors ground item entities (EntityType.ITEM) via RCON scoreboard polling.
# When item count exceeds threshold, performs detailed chunk-grid scan to
# identify WHERE items are accumulating and WHAT types they are.
#
# Usage:
#   ./mc-item-monitor.sh [OPTIONS]
#
# Options:
#   -H HOST       RCON host (default: 127.0.0.1)
#   -P PORT       RCON port (default: 25575)
#   -p PASS       RCON password (default: allthemons)
#   -s SSH_HOST   SSH target for remote execution (e.g. deploy@10.88.127.52)
#   -S SSH_PORT   SSH port (default: 1108)
#   -i INTERVAL   Poll interval in seconds (default: 10)
#   -t THRESHOLD  Item count threshold for detailed scan (default: 500)
#   -r RADIUS     Chunk scan radius (default: 8)
#   -l LOGFILE    Log file path (default: /tmp/mc-item-monitor.log)
#   -j            Also monitor systemd journal for clear warnings
#   -h            Show this help
#
# Environment variables (override defaults):
#   MCRCON_HOST, MCRCON_PORT, MCRCON_PASS, MC_SSH_HOST, MC_SSH_PORT
#
# Remote usage (RCON on localhost of remote host):
#   ./mc-item-monitor.sh -s deploy@10.88.127.52 -S 1108
#
# Local usage (RCON accessible directly):
#   ./mc-item-monitor.sh -H 10.88.127.52
#
# Requires: mcrcon, bash, coreutils, grep, awk, openssh (for remote mode)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
HOST="${MCRCON_HOST:-127.0.0.1}"
PORT="${MCRCON_PORT:-25575}"
PASS="${MCRCON_PASS:-allthemons}"
SSH_HOST="${MC_SSH_HOST:-}"
SSH_PORT="${MC_SSH_PORT:-1108}"
INTERVAL=10
THRESHOLD=500
SCAN_RADIUS=8
LOGFILE="/tmp/mc-item-monitor.log"
MONITOR_JOURNAL=false
JOURNAL_UNIT="mc-curseforge-all-the-mons"

# ── Parse args ───────────────────────────────────────────────────────────────
while getopts "H:P:p:s:S:i:t:r:l:jh" opt; do
  case "$opt" in
    H) HOST="$OPTARG" ;;
    P) PORT="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    s) SSH_HOST="$OPTARG" ;;
    S) SSH_PORT="$OPTARG" ;;
    i) INTERVAL="$OPTARG" ;;
    t) THRESHOLD="$OPTARG" ;;
    r) SCAN_RADIUS="$OPTARG" ;;
    l) LOGFILE="$OPTARG" ;;
    j) MONITOR_JOURNAL=true ;;
    h)
      sed -n '2,/^# ──/{ /^# ──/d; s/^# //; p }' "$0"
      exit 0
      ;;
    *) echo "Usage: $0 [-H host] [-P port] [-p pass] [-s ssh_host] [-S ssh_port] [-i interval] [-t threshold] [-r radius] [-l logfile] [-j]" >&2; exit 1 ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────
# Execute RCON command — either locally or via SSH on remote host
rcon() {
  local cmd="$1"
  if [[ -n "$SSH_HOST" ]]; then
    # Execute mcrcon on the remote server via SSH
    ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
      "$SSH_HOST" "mcrcon -H 127.0.0.1 -P $PORT -p '$PASS' '$cmd'" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r'
  else
    # Execute mcrcon locally
    mcrcon -H "$HOST" -P "$PORT" -p "$PASS" "$cmd" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r'
  fi
}

log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $*" | tee -a "$LOGFILE"
}

# ── Setup scoreboards ────────────────────────────────────────────────────────
setup_scoreboards() {
  log "Setting up scoreboards..."
  rcon "scoreboard objectives add itemCount dummy" >/dev/null 2>&1 || true
  rcon "scoreboard objectives add chunkCount dummy" >/dev/null 2>&1 || true
  log "Scoreboards ready."
}

# ── Count items (fast, always fits in RCON packet) ───────────────────────────
count_items() {
  # Reset counter, count items, read result — three separate RCON calls
  rcon "scoreboard players set #global itemCount 0" >/dev/null 2>&1 || true
  rcon "execute store result score #global itemCount run execute if entity @e[type=minecraft:item]" >/dev/null 2>&1 || true
  rcon "scoreboard players get #global itemCount" | grep -oP '#global has \K\d+' || echo "0"
}

# ── Chunk grid scan ──────────────────────────────────────────────────────────
# Scans a grid of chunks around a center point, reporting item counts per chunk.
# Uses bounding box selectors [x,z,dx=15,dz=15] which are chunk-aligned and
# leverage the server's spatial index for fast lookups.
#
# Args: $1=center_chunk_x $2=center_chunk_z $3=radius
scan_chunk_grid() {
  local ccx="$1" ccz="$2" radius="$3"
  local total_scanned=0 total_found=0

  log "Scanning ${radius}x${radius} chunk grid centered on chunk ($ccx, $ccz)..."

  for ((dx=-radius; dx<=radius; dx++)); do
    for ((dz=-radius; dz<=radius; dz++)); do
      local cx=$((ccx + dx))
      local cz=$((ccz + dz))
      local x=$((cx * 16))
      local z=$((cz * 16))

      # Count items in this chunk
      local result
      rcon "scoreboard players set #c chunkCount 0" >/dev/null 2>&1 || true
      rcon "execute as @e[type=minecraft:item,x=$x,z=$z,dx=15,dz=15] run scoreboard players add #c chunkCount 1" >/dev/null 2>&1 || true
      result=$(rcon "scoreboard players get #c chunkCount" | grep -oP '#c has \K\d+' || echo "0")

      total_scanned=$((total_scanned + 1))

      if [[ "$result" -gt 0 ]]; then
        total_found=$((total_found + result))
        log "  Chunk ($cx, $cz) [x=$x, z=$z]: $result items"

        # If few enough items, get their types
        if [[ "$result" -le 20 ]]; then
          local types
          types=$(rcon "execute as @e[type=minecraft:item,x=$x,z=$z,dx=15,dz=15] run data get entity @s Item.id" 2>/dev/null)
          if [[ -n "$types" ]] && ! echo "$types" | grep -q "Warning:"; then
            echo "$types" | grep -oP '"[^"]*"' | sort | uniq -c | sort -rn | while read -r count type; do
              log "    $count × $type"
            done
          fi
        fi
      fi
    done
  done

  log "Grid scan complete: $total_found items across $total_scanned chunks scanned."
}

# ── Full position dump (when count is small enough) ──────────────────────────
dump_item_details() {
  local count="$1"
  log "Dumping details for $count items..."

  # Get positions
  local positions
  positions=$(rcon "execute as @e[type=minecraft:item] run data get entity @s Pos" 2>/dev/null)

  if echo "$positions" | grep -q "Warning:"; then
    log "  Position dump too large for RCON packet. Falling back to chunk scan."
    return 1
  fi

  # Parse positions into chunk coordinates and cluster
  echo "$positions" | grep -oP '\[-?\d+\.?\d*d?,\s*-?\d+\.?\d*d?,\s*-?\d+\.?\d*d?\]' \
    | sed 's/\[//;s/\]//;s/d//g' \
    | awk -F',' '{
        x = int($1 / 16);
        z = int($3 / 16);
        printf "Chunk (%d, %d) [x=%.0f, y=%.0f, z=%.0f]\n", x, z, $1, $2, $3
      }' \
    | sort | uniq -c | sort -rn | head -20 | while read -r cnt loc; do
      log "  $cnt × $loc"
    done

  # Get item types
  local types
  types=$(rcon "execute as @e[type=minecraft:item] run data get entity @s Item.id" 2>/dev/null)

  if echo "$types" | grep -q "Warning:"; then
    log "  Type dump too large for RCON packet."
    return 1
  fi

  log "  Item types:"
  echo "$types" | grep -oP '"[^"]*"' | sort | uniq -c | sort -rn | head -20 | while read -r cnt type; do
    log "    $cnt × $type"
  done
}

# ── Journal monitor (background) ─────────────────────────────────────────────
monitor_journal() {
  if ! command -v journalctl &>/dev/null; then
    log "WARNING: journalctl not available, skipping journal monitor."
    return
  fi

  log "Starting journal monitor for unit: $JOURNAL_UNIT"
  journalctl -u "$JOURNAL_UNIT" -f --no-pager 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | grep -qiE "ITEMCLEAR|items cleared|clear.*item"; then
      log "JOURNAL: $line"
    fi
  done &
  JOURNAL_PID=$!
  log "Journal monitor started (PID: $JOURNAL_PID)"
}

# ── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
  log "Shutting down..."
  if [[ -n "${JOURNAL_PID:-}" ]]; then
    kill "$JOURNAL_PID" 2>/dev/null || true
  fi
  exit 0
}
trap cleanup INT TERM EXIT

# ── Main loop ────────────────────────────────────────────────────────────────
main() {
  log "════════════════════════════════════════════════════════════════"
  log "MC Item Monitor — $HOST:$PORT"
  if [[ -n "$SSH_HOST" ]]; then
    log "Remote mode via SSH: $SSH_HOST:$SSH_PORT"
  fi
  log "Poll interval: ${INTERVAL}s | Threshold: $THRESHOLD | Scan radius: $SCAN_RADIUS"
  log "Log file: $LOGFILE"
  log "════════════════════════════════════════════════════════════════"

  setup_scoreboards

  if [[ "$MONITOR_JOURNAL" == true ]]; then
    monitor_journal
  fi

  local prev_count=0
  local scan_count=0

  while true; do
    local count
    count=$(count_items)

    # Detect changes
    if [[ "$count" != "$prev_count" ]]; then
      log "Items: $count (was: $prev_count)"
    fi

    # Trigger detailed scan when threshold exceeded
    if [[ "$count" -ge "$THRESHOLD" && "$count" -ne "$prev_count" ]]; then
      log "⚠ THRESHOLD EXCEEDED: $count items (threshold: $THRESHOLD)"

      # Try full dump first (works if count is small enough for RCON packet)
      if [[ "$count" -le 100 ]]; then
        dump_item_details "$count" || true
      fi

      # Always do chunk grid scan for spatial clustering
      # Default center: chunk (84, 176) based on initial survey
      # TODO: make this configurable or auto-detect from player positions
      scan_chunk_grid 84 176 "$SCAN_RADIUS"
      scan_count=$((scan_count + 1))
    fi

    prev_count="$count"
    sleep "$INTERVAL"
  done
}

main "$@"

log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $*" | tee -a "$LOGFILE"
}

# ── Setup scoreboards ────────────────────────────────────────────────────────
setup_scoreboards() {
  log "Setting up scoreboards..."
  rcon "scoreboard objectives add itemCount dummy" >/dev/null 2>&1 || true
  rcon "scoreboard objectives add chunkCount dummy" >/dev/null 2>&1 || true
  log "Scoreboards ready."
}

# ── Count items (fast, always fits in RCON packet) ───────────────────────────
count_items() {
  # Reset counter, count items, read result — three separate RCON calls
  rcon "scoreboard players set #global itemCount 0" >/dev/null 2>&1 || true
  rcon "execute store result score #global itemCount run execute if entity @e[type=minecraft:item]" >/dev/null 2>&1 || true
  rcon "scoreboard players get #global itemCount" | grep -oP '#global has \K\d+' || echo "0"
}

# ── Chunk grid scan ──────────────────────────────────────────────────────────
# Scans a grid of chunks around a center point, reporting item counts per chunk.
# Uses bounding box selectors [x,z,dx=15,dz=15] which are chunk-aligned and
# leverage the server's spatial index for fast lookups.
#
# Args: $1=center_chunk_x $2=center_chunk_z $3=radius
scan_chunk_grid() {
  local ccx="$1" ccz="$2" radius="$3"
  local total_scanned=0 total_found=0

  log "Scanning ${radius}x${radius} chunk grid centered on chunk ($ccx, $ccz)..."

  for ((dx=-radius; dx<=radius; dx++)); do
    for ((dz=-radius; dz<=radius; dz++)); do
      local cx=$((ccx + dx))
      local cz=$((ccz + dz))
      local x=$((cx * 16))
      local z=$((cz * 16))

      # Count items in this chunk
      local result
      rcon "scoreboard players set #c chunkCount 0" >/dev/null 2>&1 || true
      rcon "execute as @e[type=minecraft:item,x=$x,z=$z,dx=15,dz=15] run scoreboard players add #c chunkCount 1" >/dev/null 2>&1 || true
      result=$(rcon "scoreboard players get #c chunkCount" | grep -oP '#c has \K\d+' || echo "0")

      total_scanned=$((total_scanned + 1))

      if [[ "$result" -gt 0 ]]; then
        total_found=$((total_found + result))
        log "  Chunk ($cx, $cz) [x=$x, z=$z]: $result items"

        # If few enough items, get their types
        if [[ "$result" -le 20 ]]; then
          local types
          types=$(rcon "execute as @e[type=minecraft:item,x=$x,z=$z,dx=15,dz=15] run data get entity @s Item.id" 2>/dev/null)
          if [[ -n "$types" ]] && ! echo "$types" | grep -q "Warning:"; then
            echo "$types" | grep -oP '"[^"]*"' | sort | uniq -c | sort -rn | while read -r count type; do
              log "    $count × $type"
            done
          fi
        fi
      fi
    done
  done

  log "Grid scan complete: $total_found items across $total_scanned chunks scanned."
}

# ── Full position dump (when count is small enough) ──────────────────────────
dump_item_details() {
  local count="$1"
  log "Dumping details for $count items..."

  # Get positions
  local positions
  positions=$(rcon "execute as @e[type=minecraft:item] run data get entity @s Pos" 2>/dev/null)

  if echo "$positions" | grep -q "Warning:"; then
    log "  Position dump too large for RCON packet. Falling back to chunk scan."
    return 1
  fi

  # Parse positions into chunk coordinates and cluster
  echo "$positions" | grep -oP '\[-?\d+\.?\d*d?,\s*-?\d+\.?\d*d?,\s*-?\d+\.?\d*d?\]' \
    | sed 's/\[//;s/\]//;s/d//g' \
    | awk -F',' '{
        x = int($1 / 16);
        z = int($3 / 16);
        printf "Chunk (%d, %d) [x=%.0f, y=%.0f, z=%.0f]\n", x, z, $1, $2, $3
      }' \
    | sort | uniq -c | sort -rn | head -20 | while read -r cnt loc; do
      log "  $cnt × $loc"
    done

  # Get item types
  local types
  types=$(rcon "execute as @e[type=minecraft:item] run data get entity @s Item.id" 2>/dev/null)

  if echo "$types" | grep -q "Warning:"; then
    log "  Type dump too large for RCON packet."
    return 1
  fi

  log "  Item types:"
  echo "$types" | grep -oP '"[^"]*"' | sort | uniq -c | sort -rn | head -20 | while read -r cnt type; do
    log "    $cnt × $type"
  done
}

# ── Journal monitor (background) ─────────────────────────────────────────────
monitor_journal() {
  if ! command -v journalctl &>/dev/null; then
    log "WARNING: journalctl not available, skipping journal monitor."
    return
  fi

  log "Starting journal monitor for unit: $JOURNAL_UNIT"
  journalctl -u "$JOURNAL_UNIT" -f --no-pager 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | grep -qiE "ITEMCLEAR|items cleared|clear.*item"; then
      log "JOURNAL: $line"
    fi
  done &
  JOURNAL_PID=$!
  log "Journal monitor started (PID: $JOURNAL_PID)"
}

# ── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
  log "Shutting down..."
  if [[ -n "${JOURNAL_PID:-}" ]]; then
    kill "$JOURNAL_PID" 2>/dev/null || true
  fi
  exit 0
}
trap cleanup INT TERM EXIT

# ── Main loop ────────────────────────────────────────────────────────────────
main() {
  # Set up SSH tunnel if needed
  setup_ssh_tunnel

  log "════════════════════════════════════════════════════════════════"
  log "MC Item Monitor — $HOST:$PORT"
  if [[ -n "$SSH_HOST" ]]; then
    log "SSH tunnel via: $SSH_HOST:$SSH_PORT"
  fi
  log "Poll interval: ${INTERVAL}s | Threshold: $THRESHOLD | Scan radius: $SCAN_RADIUS"
  log "Log file: $LOGFILE"
  log "════════════════════════════════════════════════════════════════"

  setup_scoreboards

  if [[ "$MONITOR_JOURNAL" == true ]]; then
    monitor_journal
  fi

  local prev_count=0
  local scan_count=0

  while true; do
    local count
    count=$(count_items)

    # Detect changes
    if [[ "$count" != "$prev_count" ]]; then
      log "Items: $count (was: $prev_count)"
    fi

    # Trigger detailed scan when threshold exceeded
    if [[ "$count" -ge "$THRESHOLD" && "$count" -ne "$prev_count" ]]; then
      log "⚠ THRESHOLD EXCEEDED: $count items (threshold: $THRESHOLD)"

      # Try full dump first (works if count is small enough for RCON packet)
      if [[ "$count" -le 100 ]]; then
        dump_item_details "$count" || true
      fi

      # Always do chunk grid scan for spatial clustering
      # Default center: chunk (84, 176) based on initial survey
      # TODO: make this configurable or auto-detect from player positions
      scan_chunk_grid 84 176 "$SCAN_RADIUS"
      scan_count=$((scan_count + 1))
    fi

    prev_count="$count"
    sleep "$INTERVAL"
  done
}

main "$@"
