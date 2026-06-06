#!/usr/bin/env bash
#
# sysdiag.sh - System Diagnostics Collector
#
# Gathers comprehensive system information and writes to organized log files.
# Designed for root execution, suitable for systemd service deployment.
#
# Usage: sudo ./sysdiag.sh
#
# Output: Creates timestamped directory in /tmp/sysdiag-<hostname>-<timestamp>/
#         Prints the directory path on completion.
#

set -euo pipefail

# ---- Configuration (overrideable via environment variables) ----
# When deployed via NixOS, these are set by the systemd service unit.
# When run standalone, the defaults below apply.
: "${SYSDIAG_OUTPUT_BASE:=/tmp}"
: "${SYSDIAG_HOSTNAME_OVERRIDE:=}"
: "${SYSDIAG_TIMESTAMP_FORMAT:=%Y%m%d-%H%M%S}"

: "${SYSDIAG_COLLECT_SYSTEM:=1}"
: "${SYSDIAG_COLLECT_HARDWARE:=1}"
: "${SYSDIAG_COLLECT_MEMORY:=1}"
: "${SYSDIAG_COLLECT_DISK:=1}"
: "${SYSDIAG_COLLECT_NETWORK:=1}"
: "${SYSDIAG_COLLECT_SYSTEMD:=1}"
: "${SYSDIAG_COLLECT_JOURNAL:=1}"
: "${SYSDIAG_COLLECT_KERNEL:=1}"
: "${SYSDIAG_COLLECT_PROCESSES:=1}"
: "${SYSDIAG_COLLECT_SECURITY:=1}"
: "${SYSDIAG_COLLECT_NIXOS:=1}"
: "${SYSDIAG_COLLECT_LOGS:=1}"

# Journal line limits — reduced for verbose systems (debug logging, no rate limits)
: "${SYSDIAG_JOURNAL_RECENT_LINES:=1000}"
: "${SYSDIAG_JOURNAL_ERROR_LINES:=500}"
: "${SYSDIAG_JOURNAL_WARNING_LINES:=500}"
: "${SYSDIAG_JOURNAL_BOOT_LINES:=2000}"

: "${SYSDIAG_PROCESS_TOP_COUNT:=50}"

# Size safeguards — prevent runaway collection
: "${SYSDIAG_MAX_FILE_SIZE:=10M}"       # Max size per collected file (truncated)
: "${SYSDIAG_MAX_TOTAL_SIZE:=100M}"     # Max total output directory size
: "${SYSDIAG_COLLECT_BOOT_JOURNAL:=0}"  # Skip full boot journal by default (can be huge)

# Configuration
readonly OUTPUT_BASE="${SYSDIAG_OUTPUT_BASE}"
readonly SCRIPT_NAME="$(basename "$0")"
readonly HOSTNAME="${SYSDIAG_HOSTNAME_OVERRIDE:-$(hostname -s)}"
readonly TIMESTAMP="$(date +"${SYSDIAG_TIMESTAMP_FORMAT}")"
readonly OUTPUT_DIR="${OUTPUT_BASE}/sysdiag-${HOSTNAME}-${TIMESTAMP}"

# Logging functions
log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_section() {
    local section="$1"
    echo ""
    echo "=========================================="
    echo "  $section"
    echo "=========================================="
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Create output directory structure
create_output_dir() {
    mkdir -p "${OUTPUT_DIR}"
    log_info "Created output directory: ${OUTPUT_DIR}"
}

# Helper function to run command and save output with size limit
collect_data() {
    local category="$1"
    local filename="$2"
    local command="$3"
    local description="$4"
    
    local filepath="${OUTPUT_DIR}/${category}/${filename}"
    mkdir -p "$(dirname "$filepath")"
    
    # Check total size limit before collecting
    local current_size
    current_size=$(du -sb "${OUTPUT_DIR}" 2>/dev/null | cut -f1)
    local max_bytes
    max_bytes=$(numfmt --from=iec "${SYSDIAG_MAX_TOTAL_SIZE}" 2>/dev/null || echo "104857600")
    
    if [[ "${current_size:-0}" -gt "${max_bytes}" ]]; then
        log_error "Total size limit reached (${SYSDIAG_MAX_TOTAL_SIZE}), skipping: ${description}"
        echo "SKIPPED: Total size limit reached" > "$filepath"
        return 0
    fi
    
    log_info "Collecting: ${description}"
    
    # Run command with timeout and capture exit code
    # Using bash -c instead of eval for better isolation
    local exit_code=0
    timeout 30 bash -c "$command" 2>&1 | head -c "${SYSDIAG_MAX_FILE_SIZE}" > "$filepath" || exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        local file_size
        file_size=$(stat -c%s "$filepath" 2>/dev/null || echo "0")
        log_info "  -> Saved to ${category}/${filename} ($(numfmt --to=iec "$file_size"))"
        
        # Add truncation notice if file was cut
        local max_bytes_file
        max_bytes_file=$(numfmt --from=iec "${SYSDIAG_MAX_FILE_SIZE}" 2>/dev/null || echo "10485760")
        if [[ "${file_size}" -ge "${max_bytes_file}" ]]; then
            echo -e "\n\n[TRUNCATED: Output exceeded ${SYSDIAG_MAX_FILE_SIZE} limit]" >> "$filepath"
        fi
    elif [[ $exit_code -eq 124 ]]; then
        log_error "  -> Timed out (30s): ${description}"
        echo "TIMEOUT: Command exceeded 30 second limit" > "$filepath"
    else
        log_error "  -> Failed to collect: ${description} (exit code: ${exit_code})"
        echo "COMMAND FAILED (exit code: ${exit_code}): $command" > "$filepath"
    fi
}

# System Information
collect_system_info() {
    log_section "System Information"
    
    collect_data "system" "uname.txt" "uname -a" "Kernel information"
    collect_data "system" "hostname.txt" "hostname -f" "Fully qualified hostname"
    collect_data "system" "uptime.txt" "uptime" "System uptime"
    collect_data "system" "date.txt" "date" "Current date and time"
    collect_data "system" "timezone.txt" "timedatectl" "Timezone information"
    collect_data "system" "os-release.txt" "cat /etc/os-release" "OS release information"
    collect_data "system" "nixos-version.txt" "nixos-version 2>/dev/null || echo 'N/A'" "NixOS version"
}

# Hardware Information
collect_hardware_info() {
    log_section "Hardware Information"
    
    collect_data "hardware" "lshw.txt" "lshw -short" "Hardware list (short)"
    collect_data "hardware" "lshw-full.txt" "lshw" "Hardware list (full)"
    collect_data "hardware" "lscpu.txt" "lscpu" "CPU information"
    collect_data "hardware" "lspci.txt" "lspci -v" "PCI devices"
    collect_data "hardware" "lsusb.txt" "lsusb -v" "USB devices"
    collect_data "hardware" "lsmem.txt" "lsmem" "Memory block information"
    collect_data "hardware" "dmidecode.txt" "dmidecode" "DMI/SMBIOS information"
    collect_data "hardware" "bios.txt" "dmidecode -t bios" "BIOS information"
}

# Memory and Swap
collect_memory_info() {
    log_section "Memory Information"
    
    collect_data "memory" "free.txt" "free -h" "Memory usage"
    collect_data "memory" "meminfo.txt" "cat /proc/meminfo" "Detailed memory info"
    collect_data "memory" "swapon.txt" "swapon --show" "Swap devices"
    collect_data "memory" "vmstat.txt" "vmstat 1 5" "Virtual memory statistics"
}

# Disk and Filesystem
collect_disk_info() {
    log_section "Disk and Filesystem Information"
    
    collect_data "disk" "df.txt" "df -h" "Disk space usage"
    collect_data "disk" "df-inodes.txt" "df -i" "Inode usage"
    collect_data "disk" "lsblk.txt" "lsblk -f" "Block devices"
    collect_data "disk" "blkid.txt" "blkid" "Block device attributes"
    collect_data "disk" "mount.txt" "mount" "Mounted filesystems"
    collect_data "disk" "fdisk.txt" "fdisk -l" "Partition tables"
    collect_data "disk" "iostat.txt" "iostat -x 1 3 2>/dev/null || echo 'iostat not available'" "IO statistics"
}

# Network Information
collect_network_info() {
    log_section "Network Information"
    
    collect_data "network" "ip-addr.txt" "ip addr show" "Network interfaces"
    collect_data "network" "ip-route.txt" "ip route show" "Routing table"
    collect_data "network" "ip-link.txt" "ip link show" "Link status"
    collect_data "network" "ip-neigh.txt" "ip neigh show" "ARP table"
    collect_data "network" "ss.txt" "ss -tuln" "Listening sockets"
    collect_data "network" "ss-all.txt" "ss -tuna" "All sockets"
    collect_data "network" "iptables.txt" "iptables -L -n -v 2>/dev/null || echo 'iptables not available'" "Firewall rules (iptables)"
    collect_data "network" "nftables.txt" "nft list ruleset 2>/dev/null || echo 'nftables not available'" "Firewall rules (nftables)"
    collect_data "network" "resolv.conf.txt" "cat /etc/resolv.conf" "DNS configuration"
    collect_data "network" "hosts.txt" "cat /etc/hosts" "Hosts file"
    collect_data "network" "wireguard.txt" "wg show 2>/dev/null || echo 'WireGuard not available'" "WireGuard status"
    collect_data "network" "networkctl.txt" "networkctl status 2>/dev/null || echo 'networkctl not available'" "systemd-networkd status"
}

# Systemd Services
collect_systemd_info() {
    log_section "Systemd Information"
    
    collect_data "systemd" "units.txt" "systemctl list-units --type=service" "Service units"
    collect_data "systemd" "units-failed.txt" "systemctl list-units --state=failed" "Failed units"
    collect_data "systemd" "timers.txt" "systemctl list-timers --all" "Timer units"
    collect_data "systemd" "sockets.txt" "systemctl list-sockets" "Socket units"
    collect_data "systemd" "journald.txt" "journalctl --disk-usage" "Journal disk usage"
}

# Journal Logs
collect_journal_logs() {
    log_section "Journal Logs"
    
    collect_data "journal" "journal-recent.txt" "journalctl -n ${SYSDIAG_JOURNAL_RECENT_LINES} --no-pager" "Recent journal entries (last ${SYSDIAG_JOURNAL_RECENT_LINES})"
    collect_data "journal" "journal-errors.txt" "journalctl -p err -n ${SYSDIAG_JOURNAL_ERROR_LINES} --no-pager" "Recent errors"
    collect_data "journal" "journal-warnings.txt" "journalctl -p warning -n ${SYSDIAG_JOURNAL_WARNING_LINES} --no-pager" "Recent warnings"
    
    # Boot journals can be enormous with debug logging — skip by default
    if [[ "${SYSDIAG_COLLECT_BOOT_JOURNAL}" = "1" ]]; then
        collect_data "journal" "journal-boot.txt" "journalctl -b -n ${SYSDIAG_JOURNAL_BOOT_LINES} --no-pager" "Current boot journal (limited to ${SYSDIAG_JOURNAL_BOOT_LINES} lines)"
        collect_data "journal" "journal-boot-previous.txt" "journalctl -b -1 -n ${SYSDIAG_JOURNAL_BOOT_LINES} --no-pager 2>/dev/null || echo 'No previous boot available'" "Previous boot journal (limited)"
    else
        log_info "Skipping boot journal (enable with SYSDIAG_COLLECT_BOOT_JOURNAL=1)"
    fi
    
    collect_data "journal" "journal-dmesg.txt" "journalctl -k -n 1000 --no-pager" "Kernel messages from journal (last 1000)"
}

# Kernel Messages
collect_kernel_info() {
    log_section "Kernel Information"
    
    collect_data "kernel" "dmesg.txt" "dmesg | tail -2000" "Kernel ring buffer (last 2000 lines)"
    collect_data "kernel" "dmesg-errors.txt" "dmesg --level=err,crit,alert,emerg | tail -500" "Kernel errors (last 500)"
    collect_data "kernel" "modules.txt" "lsmod" "Loaded kernel modules"
    collect_data "kernel" "modinfo.txt" "cat /proc/modules" "Kernel modules info"
    collect_data "kernel" "sysctl.txt" "sysctl -a" "Kernel parameters"
    collect_data "kernel" "cmdline.txt" "cat /proc/cmdline" "Kernel command line"
}

# Process Information
collect_process_info() {
    log_section "Process Information"
    
    collect_data "processes" "ps.txt" "ps auxf" "Process tree"
    collect_data "processes" "top.txt" "top -b -n 1" "Top processes"
    collect_data "processes" "top-memory.txt" "ps aux --sort=-%mem | head -${SYSDIAG_PROCESS_TOP_COUNT}" "Top memory consumers (top ${SYSDIAG_PROCESS_TOP_COUNT})"
    collect_data "processes" "top-cpu.txt" "ps aux --sort=-%cpu | head -${SYSDIAG_PROCESS_TOP_COUNT}" "Top CPU consumers (top ${SYSDIAG_PROCESS_TOP_COUNT})"
    collect_data "processes" "limits.txt" "cat /proc/*/limits 2>/dev/null | head -200 || echo 'N/A'" "Process limits"
}

# Security Information
collect_security_info() {
    log_section "Security Information"
    
    collect_data "security" "passwd.txt" "cat /etc/passwd" "User accounts"
    collect_data "security" "shadow.txt" "cat /etc/shadow 2>/dev/null || echo 'Permission denied'" "Password hashes"
    collect_data "security" "group.txt" "cat /etc/group" "Group information"
    collect_data "security" "sudoers.txt" "cat /etc/sudoers 2>/dev/null || echo 'Permission denied'" "Sudo configuration"
    collect_data "security" "ssh-config.txt" "cat /etc/ssh/sshd_config 2>/dev/null || echo 'N/A'" "SSH server config"
    collect_data "security" "last-logins.txt" "last -n 50" "Recent logins"
    collect_data "security" "lastb.txt" "lastb -n 50 2>/dev/null || echo 'N/A'" "Failed login attempts"
    collect_data "security" "audit.txt" "auditctl -l 2>/dev/null || echo 'auditctl not available'" "Audit rules"
}

# NixOS Specific
collect_nixos_info() {
    log_section "NixOS Specific Information"
    
    collect_data "nixos" "configuration.txt" "cat /etc/nixos/configuration.nix 2>/dev/null || echo 'N/A'" "NixOS configuration"
    collect_data "nixos" "nix-store.txt" "nix-store -q --references /run/current-system 2>/dev/null | head -100 || echo 'N/A'" "Nix store references"
    collect_data "nixos" "nix-channel.txt" "nix-channel --list 2>/dev/null || echo 'N/A'" "Nix channels"
    collect_data "nixos" "generations.txt" "nix-env --list-generations -p /nix/var/nix/profiles/system 2>/dev/null || echo 'N/A'" "System generations"
    collect_data "nixos" "flake-lock.txt" "cat /etc/nixos/flake.lock 2>/dev/null || echo 'N/A'" "Flake lock file"
}

# System Logs
collect_logs() {
    log_section "System Logs"
    
    collect_data "logs" "auth.log.txt" "cat /var/log/auth.log 2>/dev/null || echo 'N/A'" "Authentication log"
    collect_data "logs" "syslog.txt" "cat /var/log/syslog 2>/dev/null || echo 'N/A'" "System log"
    collect_data "logs" "messages.txt" "cat /var/log/messages 2>/dev/null || echo 'N/A'" "Messages log"
    collect_data "logs" "dmesg.log.txt" "cat /var/log/dmesg 2>/dev/null || echo 'N/A'" "dmesg log file"
}

# Generate summary
generate_summary() {
    log_section "Generating Summary"
    
    local summary_file="${OUTPUT_DIR}/summary.txt"
    
    cat > "$summary_file" << EOF
System Diagnostics Summary
==========================

Generated: $(date)
Hostname: $(hostname -f)
Kernel: $(uname -r)
OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')

Output Directory: ${OUTPUT_DIR}

Contents:
EOF
    
    # List all collected files
    find "${OUTPUT_DIR}" -type f -name "*.txt" | sort | while read -r file; do
        local rel_path="${file#${OUTPUT_DIR}/}"
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown")
        echo "  - ${rel_path} (${size} bytes)" >> "$summary_file"
    done
    
    log_info "Summary written to summary.txt"
}

# Main execution
main() {
    log_info "Starting system diagnostics collection"
    log_info "Script: ${SCRIPT_NAME}"
    log_info "Timestamp: ${TIMESTAMP}"
    
    check_root
    create_output_dir
    
    # Collect all information (category toggles read from env vars)
    collect_system_info
    [ "${SYSDIAG_COLLECT_HARDWARE}" = "1" ] && collect_hardware_info
    [ "${SYSDIAG_COLLECT_MEMORY}" = "1" ]   && collect_memory_info
    [ "${SYSDIAG_COLLECT_DISK}" = "1" ]     && collect_disk_info
    [ "${SYSDIAG_COLLECT_NETWORK}" = "1" ]  && collect_network_info
    [ "${SYSDIAG_COLLECT_SYSTEMD}" = "1" ]  && collect_systemd_info
    [ "${SYSDIAG_COLLECT_JOURNAL}" = "1" ]  && collect_journal_logs
    [ "${SYSDIAG_COLLECT_KERNEL}" = "1" ]   && collect_kernel_info
    [ "${SYSDIAG_COLLECT_PROCESSES}" = "1" ] && collect_process_info
    [ "${SYSDIAG_COLLECT_SECURITY}" = "1" ] && collect_security_info
    [ "${SYSDIAG_COLLECT_NIXOS}" = "1" ]    && collect_nixos_info
    [ "${SYSDIAG_COLLECT_LOGS}" = "1" ]     && collect_logs
    
    # Generate summary
    generate_summary
    
    # Output the directory path
    echo ""
    echo "=========================================="
    echo "  Diagnostics Collection Complete"
    echo "=========================================="
    echo ""
    echo "Output directory: ${OUTPUT_DIR}"
    echo ""
    echo "Files collected:"
    find "${OUTPUT_DIR}" -type f -name "*.txt" | wc -l
    echo ""
    echo "Total size:"
    du -sh "${OUTPUT_DIR}" | cut -f1
    echo ""
}

# Run main function
main "$@"
