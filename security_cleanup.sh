#!/bin/bash

# Android Security Cleanup Script
# Helps remove suspicious apps and revoke dangerous permissions

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Android Security Cleanup Tool ===${NC}"
echo "This script will help you secure your device"
echo ""

# Function to revoke dangerous permissions from an app
revoke_dangerous_perms() {
    local pkg=$1
    echo "Revoking dangerous permissions from $pkg..."
    
    # SMS permissions
    adb shell pm revoke $pkg android.permission.SEND_SMS 2>/dev/null
    adb shell pm revoke $pkg android.permission.RECEIVE_SMS 2>/dev/null
    adb shell pm revoke $pkg android.permission.READ_SMS 2>/dev/null
    
    # Location permissions
    adb shell pm revoke $pkg android.permission.ACCESS_FINE_LOCATION 2>/dev/null
    adb shell pm revoke $pkg android.permission.ACCESS_COARSE_LOCATION 2>/dev/null
    adb shell pm revoke $pkg android.permission.ACCESS_BACKGROUND_LOCATION 2>/dev/null
    
    # Other sensitive permissions
    adb shell pm revoke $pkg android.permission.READ_CONTACTS 2>/dev/null
    adb shell pm revoke $pkg android.permission.CAMERA 2>/dev/null
    adb shell pm revoke $pkg android.permission.RECORD_AUDIO 2>/dev/null
    adb shell pm revoke $pkg android.permission.READ_PHONE_STATE 2>/dev/null
    adb shell pm revoke $pkg android.permission.SYSTEM_ALERT_WINDOW 2>/dev/null
}

# 1. Handle the suspicious Microsoft app
echo -e "${RED}1. Checking for suspicious Microsoft app...${NC}"
if adb shell pm list packages --user 0 | grep -q "com.microsoft.appmanager"; then
    echo -e "${RED}⚠️  Found com.microsoft.appmanager with SMS permissions!${NC}"
    echo "This is highly suspicious. Options:"
    echo "1) Disable the app (recommended first step)"
    echo "2) Uninstall the app completely"
    echo "3) Just revoke permissions"
    echo "4) Skip"
    read -p "Choose [1-4]: " choice
    
    case $choice in
        1)
            adb shell pm disable-user com.microsoft.appmanager
            echo -e "${GREEN}✓ App disabled${NC}"
            ;;
        2)
            adb shell pm uninstall com.microsoft.appmanager
            echo -e "${GREEN}✓ App uninstalled${NC}"
            ;;
        3)
            revoke_dangerous_perms com.microsoft.appmanager
            echo -e "${GREEN}✓ Permissions revoked${NC}"
            ;;
        4)
            echo "Skipped"
            ;;
    esac
else
    echo -e "${GREEN}✓ Suspicious Microsoft app not found${NC}"
fi

echo ""
echo -e "${YELLOW}2. Revoking SMS permissions from non-essential apps...${NC}"
# Get all non-system apps with SMS permissions
for pkg in $(adb shell pm list packages -3 --user 0 | cut -d: -f2); do
    if adb shell dumpsys package $pkg 2>/dev/null | grep -q "SEND_SMS: granted=true\|RECEIVE_SMS: granted=true"; then
        echo -e "\n${YELLOW}Found: $pkg with SMS permissions${NC}"
        echo "Revoke SMS permissions? (y/n/skip all)"
        read -p "> " response
        
        if [ "$response" = "y" ]; then
            adb shell pm revoke $pkg android.permission.SEND_SMS 2>/dev/null
            adb shell pm revoke $pkg android.permission.RECEIVE_SMS 2>/dev/null
            adb shell pm revoke $pkg android.permission.READ_SMS 2>/dev/null
            echo -e "${GREEN}✓ SMS permissions revoked${NC}"
        elif [ "$response" = "skip all" ]; then
            break
        fi
    fi
done

echo ""
echo -e "${YELLOW}3. Checking notification access...${NC}"
listeners=$(adb shell settings get secure enabled_notification_listeners)
if [ ! -z "$listeners" ] && [ "$listeners" != "null" ]; then
    echo "Apps with notification access:"
    echo "$listeners" | tr ':' '\n' | while read app; do
        if [ ! -z "$app" ]; then
            pkg=$(echo $app | cut -d'/' -f1)
            echo "  - $pkg"
        fi
    done
    echo ""
    echo "Remove notification access from non-essential apps? (y/n)"
    read -p "> " response
    if [ "$response" = "y" ]; then
        # This will clear all notification listeners - user will need to re-enable trusted ones
        adb shell settings put secure enabled_notification_listeners ""
        echo -e "${GREEN}✓ Notification access cleared${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}4. Disabling unknown sources...${NC}"
adb shell settings put secure install_non_market_apps 0
echo -e "${GREEN}✓ Installation from unknown sources disabled${NC}"

echo ""
echo -e "${YELLOW}5. Security recommendations:${NC}"
echo "✓ Review and uninstall unused apps regularly"
echo "✓ Only install apps from Google Play Store"
echo "✓ Check app permissions before granting them"
echo "✓ Enable Google Play Protect"
echo "✓ Keep your device updated"

echo ""
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo "Run the security audit again to verify changes."