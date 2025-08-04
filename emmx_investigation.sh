#!/bin/bash

# Microsoft EMMX Investigation Script
# Investigates the suspicious com.microsoft.emmx app

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}=== MICROSOFT EMMX INVESTIGATION ===${NC}"
echo -e "${YELLOW}Investigating com.microsoft.emmx...${NC}"
echo ""

# Check if app exists
if ! adb shell pm list packages | grep -q "com.microsoft.emmx"; then
    echo -e "${GREEN}✓ App not found on device${NC}"
    exit 0
fi

echo -e "${RED}⚠️  APP FOUND! Gathering information...${NC}"
echo ""

# Basic info
echo -e "${BLUE}Basic Information:${NC}"
adb shell dumpsys package com.microsoft.emmx | grep -E "versionName|versionCode|firstInstallTime|lastUpdateTime|installerPackageName" | sed 's/^/  /'

echo ""
echo -e "${BLUE}Installation Source:${NC}"
adb shell pm list packages -i | grep emmx | sed 's/^/  /'

echo ""
echo -e "${BLUE}Is System App:${NC}"
if adb shell pm list packages -s | grep -q emmx; then
    echo -e "  ${RED}YES - This is a system app${NC}"
else
    echo -e "  ${GREEN}NO - User installed app${NC}"
fi

echo ""
echo -e "${BLUE}Dangerous Permissions:${NC}"
adb shell dumpsys package com.microsoft.emmx | grep -E "CAMERA|RECORD_AUDIO|ACCESS_FINE_LOCATION|READ_SMS|RECEIVE_SMS|READ_CONTACTS|READ_PHONE_STATE" | grep "granted=true" | sed 's/^/  /'

echo ""
echo -e "${BLUE}Running Processes:${NC}"
if adb shell ps -A | grep -q emmx; then
    echo -e "  ${RED}RUNNING:${NC}"
    adb shell ps -A | grep emmx | sed 's/^/    /'
else
    echo -e "  ${GREEN}Not currently running${NC}"
fi

echo ""
echo -e "${BLUE}Recent Activity (last 24h):${NC}"
adb shell dumpsys usagestats | grep -A5 "com.microsoft.emmx" | head -10 | sed 's/^/  /'

echo ""
echo -e "${YELLOW}=== SECURITY RECOMMENDATIONS ===${NC}"
echo ""
echo -e "${RED}This app has suspicious permissions!${NC}"
echo ""
echo "Options:"
echo "1. ${YELLOW}Disable the app:${NC}"
echo "   adb shell pm disable-user com.microsoft.emmx"
echo ""
echo "2. ${YELLOW}Revoke permissions:${NC}"
echo "   adb shell pm revoke com.microsoft.emmx android.permission.CAMERA"
echo "   adb shell pm revoke com.microsoft.emmx android.permission.RECORD_AUDIO"
echo ""
echo "3. ${YELLOW}Uninstall (if possible):${NC}"
echo "   adb shell pm uninstall com.microsoft.emmx"
echo ""
echo -e "${RED}⚠️  Consider this app HIGH RISK due to camera/mic/internet combo${NC}"
