#!/bin/bash

# Android Security Audit Script
# Based on comprehensive security audit playbook
# Usage: bash android_security_audit.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="android_security_audit_$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}Android Security Audit Starting...${NC}"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Function to run command and save output
run_check() {
    local check_name=$1
    local command=$2
    local output_file=$3
    
    echo -e "${YELLOW}Running: $check_name${NC}"
    eval "$command" > "$OUTPUT_DIR/$output_file" 2>&1
    
    # Check if output file has content
    if [ -s "$OUTPUT_DIR/$output_file" ]; then
        echo -e "${GREEN}✓ Completed${NC}"
    else
        echo -e "${RED}✗ No output or error${NC}"
    fi
}

# Function to check for suspicious results
check_suspicious() {
    local file=$1
    local pattern=$2
    local message=$3
    
    if grep -q "$pattern" "$OUTPUT_DIR/$file" 2>/dev/null; then
        echo -e "${RED}⚠️  WARNING: $message${NC}" | tee -a "$OUTPUT_DIR/warnings.txt"
    fi
}

echo "=== PHASE 1: BASIC SECURITY STATE ===" | tee "$OUTPUT_DIR/summary.txt"

# Device Information
run_check "Device Information" \
    "adb shell getprop | grep -E 'ro.product|ro.build|ro.bootloader'" \
    "device_info.txt"

# Knox & Security Status
run_check "Knox Warranty Status" \
    "adb shell getprop ro.boot.warranty_bit" \
    "knox_warranty.txt"

run_check "Verified Boot State" \
    "adb shell getprop ro.boot.verifiedbootstate" \
    "verified_boot.txt"

run_check "Bootloader Lock Status" \
    "adb shell getprop ro.boot.flash.locked" \
    "bootloader_lock.txt"

run_check "SELinux Status" \
    "adb shell getenforce" \
    "selinux_status.txt"

run_check "DM-Verity Status" \
    "adb shell getprop ro.boot.veritymode" \
    "dm_verity.txt"

# Check security status results
if grep -q "1" "$OUTPUT_DIR/knox_warranty.txt" 2>/dev/null; then
    echo -e "${RED}⚠️  Knox warranty is tripped!${NC}" | tee -a "$OUTPUT_DIR/warnings.txt"
fi

echo ""
echo "=== PHASE 2: LOCATION & TRACKING ===" | tee -a "$OUTPUT_DIR/summary.txt"

# Location Services
run_check "Location Mode" \
    "adb shell settings get secure location_mode" \
    "location_mode.txt"

run_check "Location Providers" \
    "adb shell settings get secure location_providers_allowed" \
    "location_providers.txt"

# Background Location Access
run_check "Apps with Background Location" \
    "adb shell dumpsys package | awk '/Package \[/{pkg=\$0} /ACCESS_BACKGROUND_LOCATION: granted=true/{print pkg}' | sort -u" \
    "background_location_apps.txt"

# Find My Device Services
run_check "Find My Device Status" \
    "adb shell dumpsys package com.google.android.apps.adm 2>/dev/null | grep -E 'enabled=|ACCESS.*LOCATION' || echo 'Not installed'" \
    "find_my_device.txt"

run_check "Samsung Find My Mobile" \
    "adb shell dumpsys package com.samsung.android.fmm 2>/dev/null | grep -E 'enabled=|ACCESS.*LOCATION' || echo 'Not found'" \
    "samsung_find_my.txt"

echo ""
echo "=== PHASE 3: ADVANCED SECURITY CHECKS ===" | tee -a "$OUTPUT_DIR/summary.txt"

# Check 1: Hidden Apps & Device Admin
echo -e "${BLUE}Check 1: Hidden Apps & Device Admin${NC}"
run_check "Disabled Packages" \
    "adb shell pm list packages -d --user 0 | grep -v 'com.android\|com.google\|com.samsung\|com.sec'" \
    "disabled_packages.txt"

run_check "Device Administrators" \
    "adb shell dumpsys device_policy | grep -A5 'Active admin'" \
    "device_admins.txt"

# Check 2: Keylogger Detection
echo -e "${BLUE}Check 2: Keylogger Detection${NC}"
run_check "Installed Keyboards" \
    "adb shell ime list -a" \
    "keyboards.txt"

run_check "Current Keyboard" \
    "adb shell settings get secure default_input_method" \
    "current_keyboard.txt"

# Check 3: SMS/Call Interceptors
echo -e "${BLUE}Check 3: SMS/Call Interceptors${NC}"
echo "Checking SMS interceptors..." 
{
    for pkg in $(adb shell pm list packages --user 0 2>/dev/null | cut -d: -f2); do
        perms=$(adb shell dumpsys package $pkg 2>/dev/null | grep -E "RECEIVE_SMS.*granted=true|SEND_SMS.*granted=true")
        if [ ! -z "$perms" ]; then
            echo "=== $pkg ==="
            echo "$perms"
        fi
    done
} > "$OUTPUT_DIR/sms_interceptors.txt"

# Check 4: Overlay Attacks
echo -e "${BLUE}Check 4: Overlay Attacks${NC}"
run_check "Apps with Overlay Permission" \
    "adb shell dumpsys package | grep -B20 'SYSTEM_ALERT_WINDOW: granted=true' | grep -E 'Package \[' | grep -v 'com.android\|com.google\|com.samsung'" \
    "overlay_apps.txt"

# Check 5: Persistence Mechanisms
echo -e "${BLUE}Check 5: Persistence Mechanisms${NC}"
run_check "Boot Receivers" \
    "adb shell dumpsys package | grep -B20 'RECEIVE_BOOT_COMPLETED: granted=true' | grep 'Package \[' | grep -v 'com.android\|com.google\|com.samsung' | head -20" \
    "boot_receivers.txt"

run_check "Foreground Services" \
    "adb shell dumpsys activity services | grep -B2 'isForeground=true' | grep -v 'SystemUI\|com.android\|com.google'" \
    "foreground_services.txt"

# Check 6: Network Monitoring
echo -e "${BLUE}Check 6: Network Monitoring${NC}"
run_check "VPN Apps" \
    "adb shell dumpsys package | grep -B20 'android.permission.BIND_VPN_SERVICE' | grep 'Package \['" \
    "vpn_apps.txt"

run_check "Active Network Connections" \
    "adb shell netstat -an | grep 'ESTABLISHED' | grep -v '127.0.0.1\|192.168' | head -30" \
    "network_connections.txt"

run_check "HTTP Proxy Settings" \
    "adb shell settings get global http_proxy" \
    "proxy_settings.txt"

# Check 7: Data Exfiltration Risks
echo -e "${BLUE}Check 7: Data Exfiltration Risks${NC}"
echo "Checking apps with dangerous permission combinations..."
{
    echo "=== Apps with Contacts + Internet ==="
    for pkg in $(adb shell pm list packages -3 --user 0 2>/dev/null | cut -d: -f2); do
        if adb shell dumpsys package $pkg 2>/dev/null | grep -q "READ_CONTACTS: granted=true" && \
           adb shell dumpsys package $pkg 2>/dev/null | grep -q "INTERNET: granted=true"; then
            echo "$pkg"
        fi
    done
    
    echo -e "\n=== Apps with Camera + Mic + Internet ==="
    for pkg in $(adb shell pm list packages -3 --user 0 2>/dev/null | cut -d: -f2); do
        if adb shell dumpsys package $pkg 2>/dev/null | grep -q "CAMERA: granted=true" && \
           adb shell dumpsys package $pkg 2>/dev/null | grep -q "RECORD_AUDIO: granted=true" && \
           adb shell dumpsys package $pkg 2>/dev/null | grep -q "INTERNET: granted=true"; then
            echo "$pkg"
        fi
    done
} > "$OUTPUT_DIR/data_exfiltration_risks.txt"

echo ""
echo "=== PHASE 4: APP INTEGRITY ===" | tee -a "$OUTPUT_DIR/summary.txt"

# App Installation Sources
run_check "Non-Play Store Apps" \
    "adb shell pm list packages -i --user 0 | grep -v 'installer=com.android.vending' | grep -v 'installer=null' | grep -v 'installer=com.sec.android.app.samsungapps' | head -50" \
    "non_playstore_apps.txt"

run_check "Sideloaded Apps" \
    "adb shell pm list packages -i --user 0 | grep -E 'installer=com.android.shell|installer=.*packageinstaller'" \
    "sideloaded_apps.txt"

# Recently Installed Apps
echo "Checking recently installed apps..."
{
    for pkg in $(adb shell pm list packages -3 --user 0 2>/dev/null | cut -d: -f2 | head -20); do
        echo "=== $pkg ==="
        adb shell dumpsys package $pkg 2>/dev/null | grep -E "firstInstallTime|lastUpdateTime"
    done
} > "$OUTPUT_DIR/recent_apps.txt"

echo ""
echo "=== PHASE 5: ADDITIONAL CHECKS ===" | tee -a "$OUTPUT_DIR/summary.txt"

# Notification Access
run_check "Notification Listeners" \
    "adb shell settings get secure enabled_notification_listeners" \
    "notification_listeners.txt"

# Accessibility Services
run_check "Accessibility Services" \
    "adb shell settings get secure enabled_accessibility_services" \
    "accessibility_services.txt"

# Screen Recording/Capture
echo "Checking screen capture permissions..."
{
    for pkg in $(adb shell pm list packages --user 0 2>/dev/null | cut -d: -f2); do
        perms=$(adb shell dumpsys package $pkg 2>/dev/null | grep -E "CAPTURE_AUDIO_OUTPUT|CAPTURE_MEDIA_OUTPUT|FOREGROUND_SERVICE_MEDIA_PROJECTION" | grep "granted=true")
        if [ ! -z "$perms" ]; then
            echo "=== $pkg ==="
            echo "$perms"
        fi
    done
} > "$OUTPUT_DIR/screen_capture_apps.txt"

# Bluetooth Security
echo -e "${BLUE}Bluetooth Security Check${NC}"
run_check "Bluetooth Status" \
    "adb shell settings get global bluetooth_on" \
    "bluetooth_status.txt"

run_check "Paired Devices" \
    "adb shell dumpsys bluetooth_manager | grep -A20 'Bonded devices'" \
    "bluetooth_paired.txt"

run_check "Connected Devices" \
    "adb shell dumpsys bluetooth_manager | grep -A5 'Connected devices'" \
    "bluetooth_connected.txt"

run_check "Bluetooth History" \
    "adb shell dumpsys bluetooth_manager | grep -A30 'Connection Events' | head -50" \
    "bluetooth_history.txt"

# Process Monitoring
run_check "High CPU Usage" \
    "adb shell top -b -n 1 | head -30" \
    "cpu_usage.txt"

run_check "Microsoft Processes" \
    "adb shell ps -A | grep -E 'microsoft|emmx|appmanager'" \
    "microsoft_processes.txt"

echo ""
echo "=== GENERATING REPORT ===" | tee -a "$OUTPUT_DIR/summary.txt"

# Generate Summary Report
{
    echo "Android Security Audit Report"
    echo "Generated: $(date)"
    echo "================================"
    echo ""
    
    echo "DEVICE INFORMATION:"
    head -5 "$OUTPUT_DIR/device_info.txt" 2>/dev/null
    echo ""
    
    echo "SECURITY STATUS:"
    echo -n "Knox Warranty: "
    cat "$OUTPUT_DIR/knox_warranty.txt" 2>/dev/null || echo "Unknown"
    echo -n "Bootloader: "
    cat "$OUTPUT_DIR/bootloader_lock.txt" 2>/dev/null || echo "Unknown"
    echo -n "SELinux: "
    cat "$OUTPUT_DIR/selinux_status.txt" 2>/dev/null || echo "Unknown"
    echo ""
    
    echo "CRITICAL FINDINGS:"
    if [ -f "$OUTPUT_DIR/warnings.txt" ]; then
        cat "$OUTPUT_DIR/warnings.txt"
    else
        echo "No critical warnings found"
    fi
    echo ""
    
    echo "SUSPICIOUS APPS:"
    echo "- Sideloaded apps: $(wc -l < "$OUTPUT_DIR/sideloaded_apps.txt" 2>/dev/null || echo 0)"
    echo "- Apps with overlay permission: $(grep -c "Package" "$OUTPUT_DIR/overlay_apps.txt" 2>/dev/null || echo 0)"
    echo "- Apps with SMS access: $(grep -c "===" "$OUTPUT_DIR/sms_interceptors.txt" 2>/dev/null || echo 0)"
    echo "- Apps with notification access: $(echo $(cat "$OUTPUT_DIR/notification_listeners.txt" 2>/dev/null | tr ':' '\n' | wc -l) || echo 0)"
    echo ""
    
    echo "NETWORK ACTIVITY:"
    echo "Active external connections:"
    head -10 "$OUTPUT_DIR/network_connections.txt" 2>/dev/null
    echo ""
    
    echo "For detailed results, check individual files in: $OUTPUT_DIR/"
} > "$OUTPUT_DIR/REPORT.txt"

# Display summary
echo ""
echo -e "${GREEN}=== AUDIT COMPLETE ===${NC}"
echo ""
cat "$OUTPUT_DIR/REPORT.txt"

# Check for critical issues
echo ""
if [ -f "$OUTPUT_DIR/warnings.txt" ] && [ -s "$OUTPUT_DIR/warnings.txt" ]; then
    echo -e "${RED}⚠️  CRITICAL WARNINGS FOUND - Check $OUTPUT_DIR/warnings.txt${NC}"
else
    echo -e "${GREEN}✓ No critical security issues detected${NC}"
fi

echo ""
echo "Full results saved to: $OUTPUT_DIR/"