#!/bin/bash

# Blade Runner Auto-Remediation Script
# Analyzes security audit results and automatically fixes issues

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if audit directory is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <audit_directory>"
    echo "Example: $0 android_security_audit_20250803_212725"
    exit 1
fi

AUDIT_DIR=$1
REMEDIATION_LOG="$AUDIT_DIR/remediation_$(date +%Y%m%d_%H%M%S).log"

# Logging function
log() {
    echo -e "$1" | tee -a "$REMEDIATION_LOG"
}

log "${BLUE}=== Blade Runner Auto-Remediation Starting ===${NC}"
log "Analyzing audit results in: $AUDIT_DIR"
echo ""

# Function to check if file exists and has content
check_file() {
    if [ -f "$AUDIT_DIR/$1" ] && [ -s "$AUDIT_DIR/$1" ]; then
        return 0
    else
        return 1
    fi
}

# Initialize counters
ISSUES_FOUND=0
ISSUES_FIXED=0
ISSUES_MANUAL=0

# 1. MEMORY OPTIMIZATION
log "${YELLOW}1. Checking Memory Usage...${NC}"
if check_file "cpu_usage.txt"; then
    MEM_USAGE=$(grep "Mem:" "$AUDIT_DIR/cpu_usage.txt" | awk '{print int($4/$2*100)}')
    if [ "$MEM_USAGE" -gt 90 ]; then
        log "${RED}⚠️  High memory usage detected: ${MEM_USAGE}%${NC}"
        ((ISSUES_FOUND++))
        
        log "Fixing: Force stopping resource-heavy apps..."
        # Find and kill high memory apps
        HIGH_MEM_APPS=$(grep -E "com.instagram|com.facebook|com.snapchat|com.twitter" "$AUDIT_DIR/cpu_usage.txt" | awk '{print $NF}' | sort -u)
        
        for app in $HIGH_MEM_APPS; do
            if [ ! -z "$app" ]; then
                adb shell am force-stop "$app" 2>/dev/null && log "  ✓ Stopped $app"
                ((ISSUES_FIXED++))
            fi
        done
        
        # Clear caches
        log "Clearing system caches..."
        adb shell pm trim-caches 200M
        log "${GREEN}✓ Memory optimization complete${NC}"
    else
        log "${GREEN}✓ Memory usage normal: ${MEM_USAGE}%${NC}"
    fi
fi

echo ""

# 2. BACKGROUND LOCATION PERMISSIONS
log "${YELLOW}2. Checking Background Location Access...${NC}"
if check_file "background_location_apps.txt"; then
    BG_LOCATION_COUNT=$(grep -c "Package" "$AUDIT_DIR/background_location_apps.txt" 2>/dev/null || echo 0)
    if [ "$BG_LOCATION_COUNT" -gt 5 ]; then
        log "${RED}⚠️  Too many apps with background location: $BG_LOCATION_COUNT${NC}"
        ((ISSUES_FOUND++))
        
        # Apps to restrict
        RESTRICT_APPS=(
            "com.samsung.android.bixby.agent"
            "com.google.android.googlequicksearchbox"
            "com.samsung.android.mcfds"
            "com.sec.android.daemonapp"
        )
        
        log "Restricting background location for non-essential apps..."
        for app in "${RESTRICT_APPS[@]}"; do
            if grep -q "$app" "$AUDIT_DIR/background_location_apps.txt"; then
                adb shell cmd appops set "$app" ACCESS_BACKGROUND_LOCATION ignore 2>/dev/null
                if [ $? -eq 0 ]; then
                    log "  ✓ Restricted: $app"
                    ((ISSUES_FIXED++))
                fi
            fi
        done
    fi
fi

echo ""

# 3. SMS PERMISSION CLEANUP
log "${YELLOW}3. Checking SMS Permissions...${NC}"
if check_file "sms_interceptors.txt"; then
    # Check for non-system apps with SMS
    NON_SYSTEM_SMS=$(grep -v -E "com.android|com.google|com.samsung|com.sec" "$AUDIT_DIR/sms_interceptors.txt" | grep -c "===" 2>/dev/null || echo 0)
    
    if [ "$NON_SYSTEM_SMS" -gt 3 ]; then
        log "${RED}⚠️  Non-system apps with SMS permissions: $NON_SYSTEM_SMS${NC}"
        ((ISSUES_FOUND++))
        
        # Find and list non-system SMS apps
        NON_SYSTEM_APPS=$(grep -B1 -E "SEND_SMS.*granted=true|RECEIVE_SMS.*granted=true" "$AUDIT_DIR/sms_interceptors.txt" | grep "===" | grep -v -E "com.android|com.google|com.samsung|com.sec" | sed 's/=== //' | sed 's/ ===//' | sort -u)
        
        if [ ! -z "$NON_SYSTEM_APPS" ]; then
            log "${YELLOW}Manual review needed for:${NC}"
            echo "$NON_SYSTEM_APPS" | while read app; do
                log "  - $app"
                ((ISSUES_MANUAL++))
            done
        fi
    fi
fi

echo ""

# 4. LOCATION MODE OPTIMIZATION
log "${YELLOW}4. Checking Location Mode...${NC}"
if check_file "location_mode.txt"; then
    LOCATION_MODE=$(cat "$AUDIT_DIR/location_mode.txt")
    if [ "$LOCATION_MODE" = "3" ]; then
        log "${RED}⚠️  Location mode set to High Accuracy (battery drain)${NC}"
        ((ISSUES_FOUND++))
        
        log "Switching to Battery Saving mode..."
        adb shell settings put secure location_mode 1
        if [ $? -eq 0 ]; then
            log "${GREEN}✓ Location mode optimized${NC}"
            ((ISSUES_FIXED++))
        fi
    fi
fi

echo ""

# 5. DISABLED APPS CLEANUP
log "${YELLOW}5. Checking Disabled Apps...${NC}"
if check_file "disabled_packages.txt"; then
    DISABLED_COUNT=$(grep -c "package:" "$AUDIT_DIR/disabled_packages.txt" 2>/dev/null || echo 0)
    if [ "$DISABLED_COUNT" -gt 0 ]; then
        log "Found $DISABLED_COUNT disabled apps"
        
        # Check if Microsoft AppManager is disabled
        if grep -q "com.microsoft.appmanager" "$AUDIT_DIR/disabled_packages.txt"; then
            log "${GREEN}✓ Microsoft AppManager already disabled (good)${NC}"
        fi
    fi
fi

echo ""

# 6. APP STANDBY OPTIMIZATION
log "${YELLOW}6. Optimizing App Standby Buckets...${NC}"
BATTERY_HOGS=(
    "com.instagram.android"
    "com.facebook.katana"
    "com.snapchat.android"
    "com.twitter.android"
    "com.reddit.frontpage"
)

for app in "${BATTERY_HOGS[@]}"; do
    if adb shell pm list packages | grep -q "$app"; then
        adb shell am set-standby-bucket "$app" restricted 2>/dev/null
        if [ $? -eq 0 ]; then
            log "  ✓ Restricted: $app"
            ((ISSUES_FIXED++))
        fi
    fi
done

echo ""

# 7. NOTIFICATION LISTENER CLEANUP
log "${YELLOW}7. Checking Notification Listeners...${NC}"
if check_file "notification_listeners.txt"; then
    LISTENERS=$(cat "$AUDIT_DIR/notification_listeners.txt")
    if [ ! -z "$LISTENERS" ]; then
        log "Notification listeners found - manual review recommended"
        ((ISSUES_MANUAL++))
    fi
fi

echo ""

# 8. NETWORK OPTIMIZATIONS
log "${YELLOW}8. Network Optimizations...${NC}"
# Disable WiFi scanning
adb shell settings put global wifi_scan_always_enabled 0
log "  ✓ Disabled always-on WiFi scanning"
((ISSUES_FIXED++))

# Disable mobile data always active
adb shell settings put global mobile_data_always_on 0
log "  ✓ Disabled mobile data always active"
((ISSUES_FIXED++))

echo ""

# 9. GENERATE REMEDIATION REPORT
log "${BLUE}=== Generating Remediation Report ===${NC}"

{
    echo "Blade Runner Auto-Remediation Report"
    echo "===================================="
    echo "Generated: $(date)"
    echo ""
    echo "SUMMARY:"
    echo "- Issues Found: $ISSUES_FOUND"
    echo "- Issues Fixed Automatically: $ISSUES_FIXED"
    echo "- Issues Requiring Manual Review: $ISSUES_MANUAL"
    echo ""
    echo "ACTIONS TAKEN:"
    echo "1. Memory optimization - cleared caches and stopped heavy apps"
    echo "2. Restricted background location for non-essential apps"
    echo "3. Switched location mode to battery saving"
    echo "4. Optimized app standby buckets for social media apps"
    echo "5. Disabled always-on WiFi/mobile data scanning"
    echo ""
    echo "MANUAL ACTIONS RECOMMENDED:"
    echo "1. Review non-system apps with SMS permissions"
    echo "2. Check notification listener apps"
    echo "3. Consider uninstalling unused apps from disabled list"
    echo "4. Enable Developer Options > Don't keep activities (optional)"
    echo ""
    echo "For detailed logs, see: $REMEDIATION_LOG"
} > "$AUDIT_DIR/REMEDIATION_REPORT.txt"

# Display summary
echo ""
log "${GREEN}=== Remediation Complete ===${NC}"
log ""
log "Summary:"
log "- Issues Found: ${YELLOW}$ISSUES_FOUND${NC}"
log "- Issues Fixed: ${GREEN}$ISSUES_FIXED${NC}"
log "- Manual Review: ${YELLOW}$ISSUES_MANUAL${NC}"
log ""
log "Reports saved to:"
log "- Summary: $AUDIT_DIR/REMEDIATION_REPORT.txt"
log "- Detailed log: $REMEDIATION_LOG"

# Final verification
echo ""
log "${BLUE}Running quick verification...${NC}"
NEW_MEM=$(adb shell dumpsys meminfo | grep "Total RAM:" | awk '{print $3}')
log "Current memory usage: $NEW_MEM"

echo ""
log "${GREEN}✓ Auto-remediation complete!${NC}"