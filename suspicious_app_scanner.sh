#!/bin/bash

# Quick Suspicious App Checker
# Focuses on non-system apps with dangerous permissions

echo "=== SUSPICIOUS APP SCANNER ==="
echo "Checking for non-system apps with dangerous permissions..."
echo ""

# Check for non-system apps with SMS permissions
echo "1. Non-system apps with SMS permissions:"
adb shell pm list packages -3 --user 0 | cut -d: -f2 | while read pkg; do
    if adb shell dumpsys package $pkg 2>/dev/null | grep -q "SEND_SMS: granted=true\|RECEIVE_SMS: granted=true"; then
        echo "  ⚠️  $pkg"
        adb shell dumpsys package $pkg | grep -E "firstInstallTime|versionName" | sed 's/^/     /'
    fi
done

echo ""
echo "2. Apps with overlay + other dangerous permissions:"
adb shell pm list packages -3 --user 0 | cut -d: -f2 | while read pkg; do
    perms=$(adb shell dumpsys package $pkg 2>/dev/null)
    if echo "$perms" | grep -q "SYSTEM_ALERT_WINDOW: granted=true"; then
        if echo "$perms" | grep -qE "READ_SMS|RECEIVE_SMS|READ_CONTACTS|CAMERA|RECORD_AUDIO"; then
            echo "  ⚠️  $pkg (Overlay + sensitive permissions)"
        fi
    fi
done

echo ""
echo "3. Recently installed apps (last 30 days):"
current_time=$(date +%s)
thirty_days_ago=$((current_time - 2592000))

adb shell pm list packages -3 --user 0 | cut -d: -f2 | while read pkg; do
    install_time=$(adb shell dumpsys package $pkg 2>/dev/null | grep firstInstallTime | head -1 | cut -d= -f2 | cut -d' ' -f1)
    if [ ! -z "$install_time" ]; then
        install_epoch=$(date -d "$install_time" +%s 2>/dev/null || echo 0)
        if [ $install_epoch -gt $thirty_days_ago ]; then
            echo "  📅 $pkg (installed: $install_time)"
        fi
    fi
done

echo ""
echo "4. Apps from unknown sources:"
adb shell pm list packages -i -3 --user 0 | grep -vE "installer=com.android.vending|installer=com.sec.android.app.samsungapps"

echo ""
echo "5. Checking specific suspicious app: com.microsoft.appmanager"
if adb shell pm list packages --user 0 | grep -q "com.microsoft.appmanager"; then
    echo "  ⚠️  FOUND: com.microsoft.appmanager"
    echo "  Details:"
    adb shell dumpsys package com.microsoft.appmanager | grep -E "versionName|firstInstallTime|lastUpdateTime|installer" | sed 's/^/    /'
    echo "  Permissions:"
    adb shell dumpsys package com.microsoft.appmanager | grep -E "permission.*granted=true" | grep -E "SMS|CONTACTS|CAMERA|LOCATION|PHONE" | sed 's/^/    /'
else
    echo "  ✓ Not found (may have been uninstalled)"
fi

echo ""
echo "=== SCAN COMPLETE ==="