#!/usr/bin/env bash
set -euo pipefail

# Defaults
TIMEOUT="${1:-120}"
LOGFILE="${2:-/tmp/greeter-boot.log}"

echo "Starting bargman-greeter VM in headless mode with serial capture..."
echo "Timeout: ${TIMEOUT}s"
echo "Log file: ${LOGFILE}"

# Run the VM with serial output, capture both stdout and stderr to the log file.
# Use || true so that timeout's exit code (124) doesn't trigger set -e.
timeout "${TIMEOUT}" nix run .#bargman-greeter-vm-serial > "${LOGFILE}" 2>&1 || true

echo "Serial capture complete. Log saved to: ${LOGFILE}"
