#!/bin/bash

# Android Security Audit Script - Fixed Version
# Addresses permission and parsing issues
# Usage: sudo ./android_security_audit_fixed.sh

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

echo -e "${BLUE}Android Security Audit Starting (Fixed Version)...${NC}"
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
        # Try alternative command if available
        if [ ! -z "$4" ]; then
            echo -e "${YELLOW}  Trying alternative command...${NC}"
            eval "$4" > "$OUTPUT_DIR/$output_file" 2>&1
            if [ -s "$OUTPUT_DIR/$output_file" ]; then
                echo -e "${GREEN}  ✓ Alternative succeeded${NC}"
            fi
        fi
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

echo ""
echo "=== PHASE 2: LOCATION & TRACKING ===" | tee -a "$OUTPUT_DIR/summary.txt"

# Location Services
run_check "Location Mode" \
    "adb shell settings get secure location_mode" \
    "location_mode.txt"

run_check "Location Providers" \
    "adb shell settings get secure location_providers_allowed" \
    "location_providers.txt"

# Background Location Access - Fixed parsing
echo "Checking background location apps..."
{
    adb shell dumpsys package | grep -B50 "ACCESS_BACKGROUND_LOCATION: granted=true" | grep "Package \[" | sed 's/.*Package \[\(.*\)\].*/\1/' | sort -u
} > "$OUTPUT_DIR/background_location_apps.txt"

echo ""
echo "=== PHASE 3: ADVANCED SECURITY CHECKS ===" | tee -a "$OUTPUT_DIR/summary.txt"

# Check 1: Hidden Apps & Device Admin
echo -e "${BLUE}Check 1: Hidden Apps & Device Admin${NC}"
run_check "Disabled Packages" \
    "adb shell pm list packages -d" \
    "disabled_packages.txt"

# Fixed Device Administrators check
echo "Checking device administrators..."
{
    echo "=== From device_policy ==="
    adb shell dumpsys device_policy | grep -A10 "Active admin" 2>/dev/null
    echo -e "\n=== From dpm ==="
    adb shell dpm list-admins 2>/dev/null
    echo -e "\n=== Apps with BIND_DEVICE_ADMIN permission ==="
    for pkg in $(adb shell pm list packages | cut -d: -f2); do
        if adb shell dumpsys package $pkg 2>/dev/null | grep -q "android.permission.BIND_DEVICE_ADMIN"; then
            echo "$pkg"
        fi
    done
} > "$OUTPUT_DIR/device_admins.txt"

# Check 2: Keylogger Detection
echo -e "${BLUE}Check 2: Keylogger Detection${NC}"
run_check "Installed Keyboards" \
    "adb shell ime list -a" \
    "keyboards.txt"

run_check "Current Keyboard" \
    "adb shell settings get secure default_input_method" \
    "current_keyboard.txt"

# Check 3: SMS/Call Interceptors - Already working, keep as is
echo -e "${BLUE}Check 3: SMS/Call Interceptors${NC}"
echo "Checking SMS interceptors..." 
{
    for pkg in $(adb shell pm list packages | cut -d: -f2); do
        perms=$(adb shell dumpsys package $pkg 2>/dev/null | grep -E "RECEIVE_SMS.*granted=true|SEND_SMS.*granted=true")
        if [ ! -z "$perms" ]; then
            echo "=== $pkg ==="
            echo "$perms"
        fi
    done
} > "$OUTPUT_DIR/sms_interceptors.txt"

# Check 4: Overlay Attacks - Fixed
echo -e "${BLUE}Check 4: Overlay Attacks${NC}"
echo "Checking overlay permission apps..."
{
    for pkg in $(adb shell pm list packages | cut -d: -f2); do
        if adb shell dumpsys package $pkg 2>/dev/null | grep -q "SYSTEM_ALERT_WINDOW: granted=true"; then
            # Skip system apps optionally
            if ! echo "$pkg" | grep -qE "^com.android\.|^com.google\.|^com.samsung\.|^com.sec\."; then
                echo "$pkg"
            fi
        fi
    done
} > "$OUTPUT_DIR/overlay_apps.txt"

# Check 5: Persistence Mechanisms - Fixed
echo -e "${BLUE}Check 5: Persistence Mechanisms${NC}"
echo "Checking boot receivers..."
{
    for pkg in $(adb shell pm list packages | cut -d: -f2); do
        if adb shell dumpsys package $pkg 2>/dev/null | grep -q "RECEIVE_BOOT_COMPLETED: granted=true"; then
            if ! echo "$pkg" | grep -qE "^com.android\.|^com.google\.|^com.samsung\."; then
                echo "$pkg"
            fi
        fi
    done | head -50
} > "$OUTPUT_DIR/boot_receivers.txt"

echo "Checking foreground services..."
{
    adb shell dumpsys activity services | grep -B3 "isForeground=true" | grep -E "ServiceRecord|isForeground" | grep -v "SystemUI"
} > "$OUTPUT_DIR/foreground_services.txt"

# Check 6: Network Monitoring - Fixed
echo -e "${BLUE}Check 6: Network Monitoring${NC}"
echo "Checking VPN apps..."
{
    for pkg in $(adb shell pm list packages | cut -d: -f2); do
        if adb shell dumpsys package $pkg 2>/dev/null | grep -q "android.permission.BIND_VPN_SERVICE"; then
            echo "$pkg"
        fi
    done
} > "$OUTPUT_DIR/vpn_apps.txt"

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
    for pkg in $(adb shell pm list packages -3 | cut -d: -f2); do
        perms=$(adb shell dumpsys package $pkg 2>/dev/null)
        if echo "$perms" | grep -q "READ_CONTACTS: granted=true" && \
           echo "$perms" | grep -q "INTERNET: granted=true"; then
            echo "$pkg"
        fi
    done
    
    echo -e "\n=== Apps with Camera + Mic + Internet ==="
    for pkg in $(adb shell pm list packages -3 | cut -d: -f2); do
        perms=$(adb shell dumpsys package $pkg 2>/dev/null)
        if echo "$perms" | grep -q "CAMERA: granted=true" && \
           echo "$perms" | grep -q "RECORD_AUDIO: granted=true" && \
           echo "$perms" | grep -q "INTERNET: granted=true"; then
            echo "$pkg"
        fi
    done
} > "$OUTPUT_DIR/data_exfiltration_risks.txt"

echo ""
echo "=== PHASE 4: APP INTEGRITY ===" | tee -a "$OUTPUT_DIR/summary.txt"

# App Installation Sources
run_check "Non-Play Store Apps" \
    "adb shell pm list packages -i | grep -v 'installer=com.android.vending' | grep -v 'installer=null' | head -50" \
    "non_playstore_apps.txt"

# Fixed sideloaded apps check
echo "Checking sideloaded apps..."
{
    adb shell pm list packages -i | grep -E "installer=com.android.shell|installer=.*packageinstaller|installer=com.android.packageinstaller"
} > "$OUTPUT_DIR/sideloaded_apps.txt"

echo ""
echo "=== PHASE 5: ADDITIONAL CHECKS ===" | tee -a "$OUTPUT_DIR/summary.txt"

# Microsoft-specific checks
echo -e "${BLUE}Microsoft App Analysis${NC}"
echo "Checking Microsoft apps and services..."
{
    echo "=== Installed Microsoft Apps ==="
    adb shell pm list packages | grep -i microsoft
    
    echo -e "\n=== Microsoft App Permissions ==="
    for pkg in $(adb shell pm list packages | grep -i microsoft | cut -d: -f2); do
        echo -e "\n--- $pkg ---"
        adb shell dumpsys package $pkg | grep -E "granted=true|permission:" | grep -E "CAMERA|RECORD_AUDIO|READ_CONTACTS|ACCESS_FINE_LOCATION|READ_SMS|RECEIVE_SMS|READ_PHONE_STATE|SYSTEM_ALERT_WINDOW"
    done
    
    echo -e "\n=== Microsoft Processes ==="
    adb shell ps -A | grep -i microsoft
} > "$OUTPUT_DIR/microsoft_analysis.txt"

# Notification Access
run_check "Notification Listeners" \
    "adb shell settings get secure enabled_notification_listeners" \
    "notification_listeners.txt"

# Accessibility Services
run_check "Accessibility Services" \
    "adb shell settings get secure enabled_accessibility_services" \
    "accessibility_services.txt"

# Generate final report
echo ""
echo "=== GENERATING COMPREHENSIVE REPORT ===" | tee -a "$OUTPUT_DIR/summary.txt"

{
    echo "Android Security Audit Report (Fixed Version)"
    echo "Generated: $(date)"
    echo "================================"
    echo ""
    
    echo "SECURITY ANALYSIS:"
    echo ""
    
    # Check for Microsoft app with concerning permissions
    if grep -qi "microsoft" "$OUTPUT_DIR/microsoft_analysis.txt" && grep -q "SEND_SMS: granted=true" "$OUTPUT_DIR/microsoft_analysis.txt"; then
        echo -e "${RED}⚠️  CRITICAL: Microsoft app has SMS sending permission!${NC}"
        echo "This is highly unusual and potentially malicious."
    fi
    
    # Count suspicious apps
    echo "APP STATISTICS:"
    echo "- Total SMS-capable apps: $(grep -c "===" "$OUTPUT_DIR/sms_interceptors.txt" 2>/dev/null || echo 0)"
    echo "- Non-system SMS apps: $(grep -v -E "com.android|com.google|com.samsung|com.sec" "$OUTPUT_DIR/sms_interceptors.txt" | grep -c "===" 2>/dev/null || echo 0)"
    echo "- Overlay permission apps: $(wc -l < "$OUTPUT_DIR/overlay_apps.txt" 2>/dev/null || echo 0)"
    echo "- Device admin apps: $(grep -c "^[a-z]" "$OUTPUT_DIR/device_admins.txt" 2>/dev/null || echo 0)"
    echo "- VPN-capable apps: $(wc -l < "$OUTPUT_DIR/vpn_apps.txt" 2>/dev/null || echo 0)"
    echo "- Sideloaded apps: $(wc -l < "$OUTPUT_DIR/sideloaded_apps.txt" 2>/dev/null || echo 0)"
    
    echo ""
    echo "For detailed results, check individual files in: $OUTPUT_DIR/"
} > "$OUTPUT_DIR/FINAL_REPORT.txt"

# Display final report
cat "$OUTPUT_DIR/FINAL_REPORT.txt"

echo ""
echo -e "${GREEN}Audit complete. All results saved to: $OUTPUT_DIR/${NC}"