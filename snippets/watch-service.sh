#!/usr/bin/env bash
# watch-service.sh — Monitor a systemd service for immediate failure after deploy
#
# Usage:
#   ./watch-service.sh <host> <service-name> [ssh-port]
#
# Examples:
#   ./watch-service.sh 10.88.127.52 mc-curseforge-all-the-mons 1108
#   ./watch-service.sh 65.108.141.32 dragonwilds-server
#
# What it does:
#   1. Checks if the service is active/running
#   2. If failed, grabs journal output and exits non-zero
#   3. If running, watches for 60s to catch delayed failures
#   4. Reports final status

set -euo pipefail

HOST="${1:?Usage: $0 <host> <service-name> [ssh-port]}"
SERVICE="${2:?Usage: $0 <host> <service-name> [ssh-port]}"
SSH_PORT="${3:-22}"

SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $SSH_PORT"

check_service() {
  local host="$1" service="$2"
  local status_output journal_output

  # Get service status
  status_output=$(ssh $SSH_OPTS "$host" \
    "systemctl is-active '$service' 2>/dev/null || true")

  case "$status_output" in
    active)
      echo "✅ $service is active and running"
      return 0
      ;;
    activating)
      echo "⏳ $service is still activating..."
      return 2
      ;;
    failed)
      echo "❌ $service has FAILED"
      echo ""
      echo "=== Service Status ==="
      ssh $SSH_OPTS "$host" "systemctl status '$service' --no-pager 2>&1 || true"
      echo ""
      echo "=== Last 30 Journal Lines ==="
      ssh $SSH_OPTS "$host" "journalctl -u '$service' -n 30 --no-pager 2>&1 || true"
      return 1
      ;;
    inactive)
      echo "⏸  $service is inactive (not started or masked)"
      return 3
      ;;
    *)
      echo "❓ $service status unknown: '$status_output'"
      return 4
      ;;
  esac
}

echo "Monitoring $SERVICE on $HOST (port $SSH_PORT)..."
echo "Press Ctrl+C to stop"
echo ""

# Initial check
check_service "$HOST" "$SERVICE"
initial_status=$?

if [ $initial_status -eq 1 ]; then
  echo ""
  echo "Service failed immediately. Aborting."
  exit 1
fi

if [ $initial_status -eq 3 ]; then
  echo ""
  echo "Service is not running. Start it first."
  exit 3
fi

# Watch for 60 seconds
echo ""
echo "Watching for 60s for delayed failures..."
for i in $(seq 1 12); do
  sleep 5
  check_service "$HOST" "$SERVICE"
  watch_status=$?

  if [ $watch_status -eq 1 ]; then
    echo ""
    echo "Service failed after ${i}x5s. Aborting."
    exit 1
  fi
done

echo ""
echo "✅ $SERVICE survived 60s monitoring window. Looks stable."
exit 0
