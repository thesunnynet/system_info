#!/bin/bash
# ==============================================================================
# Comprehensive Linux System Information Gathering Script
# Outputs a detailed report to stdout and a file.
# ==============================================================================

OUTPUT_FILE="system_full_report.txt"
# Clear the file at the start (or create it)
> "$OUTPUT_FILE"

# Helper function: print to screen and append to file
report_section() {
    local title="$1"
    echo -e "\n================================================================================" | tee -a "$OUTPUT_FILE"
    echo "  $title" | tee -a "$OUTPUT_FILE"
    echo "================================================================================" | tee -a "$OUTPUT_FILE"
}

report_command() {
    local desc="$1"
    local cmd="$2"
    echo -e "\n--- $desc ---" | tee -a "$OUTPUT_FILE"
    if eval "$cmd" >> "$OUTPUT_FILE" 2>&1; then
        # Also show on screen (optional, but helpful)
        eval "$cmd" | head -20 # show first 20 lines on screen to avoid flooding
    else
        echo "[Command failed: $cmd]" | tee -a "$OUTPUT_FILE"
    fi
}

# ==============================================================================
# 1. OPERATING SYSTEM & KERNEL INFORMATION
# ==============================================================================
report_section "1. OPERATING SYSTEM & KERNEL"

report_command "OS Release Details" "cat /etc/os-release"
report_command "Kernel Version" "uname -a"
report_command "Hostname" "hostnamectl 2>/dev/null || hostname"
report_command "Uptime & Load" "uptime"
report_command "System Date/Time" "date"

# ==============================================================================
# 2. HARDWARE INFORMATION (CPU, MEMORY)
# ==============================================================================
report_section "2. HARDWARE INFORMATION"

report_command "CPU Details" "lscpu 2>/dev/null || cat /proc/cpuinfo | head -20"
report_command "Memory Usage" "free -h"
report_command "PCI Devices (Summary)" "lspci 2>/dev/null | head -20"
report_command "USB Devices (Summary)" "lsusb 2>/dev/null | head -10"

# ==============================================================================
# 3. DISK PARTITIONS, FILESYSTEMS & USAGE
# ==============================================================================
report_section "3. DISK & FILESYSTEM INFORMATION"

report_command "Block Devices & Partitions (lsblk)" "lsblk -f 2>/dev/null"
report_command "Filesystem Disk Usage (df -hT)" "df -hT"
report_command "Inode Usage" "df -i"
report_command "Mount Points" "mount | column -t 2>/dev/null || mount"

# ==============================================================================
# 4. NETWORK CONFIGURATION
# ==============================================================================
report_section "4. NETWORK CONFIGURATION"

report_command "Network Interfaces (IP Addresses)" "ip -br addr 2>/dev/null || ifconfig -a"
report_command "Routing Table" "ip route 2>/dev/null || route -n"
report_command "DNS Configuration" "cat /etc/resolv.conf 2>/dev/null; resolvectl status 2>/dev/null | head -20"
report_command "Listening Ports & Connections" "ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null"
report_command "Active Network Connections (Established)" "ss -tun state established 2>/dev/null || netstat -tun 2>/dev/null | grep ESTABLISHED"

# ==============================================================================
# 5. INSTALLED APPLICATIONS & PACKAGE MANAGEMENT
# ==============================================================================
report_section "5. INSTALLED APPLICATIONS"

if command -v dpkg &>/dev/null; then
    report_command "Debian/Ubuntu Installed Packages (dpkg)" "dpkg-query -W -f='\${Package} \${Version}\n' | sort"
elif command -v rpm &>/dev/null; then
    report_command "RHEL/CentOS/Fedora Installed Packages (rpm)" "rpm -qa | sort"
else
    echo "No supported package manager (dpkg/rpm) found." | tee -a "$OUTPUT_FILE"
fi

# ==============================================================================
# 6. SYSTEM CONFIGURATION & SERVICES
# ==============================================================================
report_section "6. SYSTEM CONFIGURATION & SERVICES"

report_command "Systemd Unit Files (Enabled)" "systemctl list-unit-files --type=service --state=enabled 2>/dev/null | head -30"
report_command "Running Services" "systemctl list-units --type=service --state=running 2>/dev/null | head -30"
report_command "Kernel Parameters (sysctl)" "sysctl -a 2>/dev/null | head -30"
report_command "Scheduled Cron Jobs (Root)" "crontab -l 2>/dev/null || echo 'No crontab for root.'"
report_command "Users with Shell Access" "grep -E '/bin/(ba)?sh' /etc/passwd | cut -d: -f1"
report_command "Environment Variables (Key Paths)" "env | grep -E 'PATH|HOME|SHELL'"

# ==============================================================================
# 7. LOGS & SECURITY (QUICK SNAPSHOT)
# ==============================================================================
report_section "7. LOGS & SECURITY SNAPSHOT"

report_command "Recent System Logs (last 10 lines)" "journalctl -n 10 --no-pager 2>/dev/null || tail -n 10 /var/log/syslog 2>/dev/null"
report_command "SELinux/AppArmor Status" "getenforce 2>/dev/null; aa-status 2>/dev/null | head -5"
report_command "Firewall Rules (Summary)" "iptables -L -n 2>/dev/null | head -20; nft list ruleset 2>/dev/null | head -20"

# ==============================================================================
# SCRIPT COMPLETE
# ==============================================================================
echo -e "\n\n================================================================================" | tee -a "$OUTPUT_FILE"
echo "  REPORT COMPLETE. Full details saved to: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
echo "================================================================================" | tee -a "$OUTPUT_FILE"