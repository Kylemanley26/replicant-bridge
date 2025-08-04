#!/bin/bash

# Android Memory Optimization Script
# Frees up memory and identifies resource hogs

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Android Memory Optimizer ===${NC}"
echo ""

# 1. Show current memory status
echo -e "${BLUE}Current Memory Status:${NC}"
adb shell dumpsys meminfo | grep -E "Total RAM:|Free RAM:|Used RAM:|Lost RAM:" | head -4

echo ""
echo -e "${YELLOW}Top 10 Memory Consuming Apps:${NC}"
adb shell dumpsys meminfo | grep -E "^[[:space:]]*[0-9]+," | head -10

echo ""
echo -e "${YELLOW}Force stopping resource-heavy background apps...${NC}"

# Apps to potentially force stop (customize this list)
APPS_TO_CHECK=(
    "com.instagram.android"
    "com.facebook.katana"
    "com.snapchat.android"
    "com.zhiliaoapp.musically"  # TikTok
    "com.twitter.android"
)

for app in "${APPS_TO_CHECK[@]}"; do
    if adb shell pm list packages | grep -q "$app"; then
        # Check if app is in foreground
        if ! adb shell dumpsys activity activities | grep -q "mResumedActivity.*$app"; then
            echo -e "Stopping $app..."
            adb shell am force-stop "$app"
        else
            echo -e "${YELLOW}$app is in foreground, skipping${NC}"
        fi
    fi
done

echo ""
echo -e "${YELLOW}Clearing cache...${NC}"
adb shell pm trim-caches 200M

echo ""
echo -e "${YELLOW}Optimizing background apps...${NC}"
# Restrict background activity for heavy apps
for app in "${APPS_TO_CHECK[@]}"; do
    if adb shell pm list packages | grep -q "$app"; then
        # Put app in restricted standby bucket
        adb shell am set-standby-bucket "$app" restricted 2>/dev/null
        echo "Restricted: $app"
    fi
done

echo ""
echo -e "${GREEN}Memory optimization complete!${NC}"
echo ""
echo -e "${BLUE}New Memory Status:${NC}"
adb shell dumpsys meminfo | grep -E "Total RAM:|Free RAM:|Used RAM:|Lost RAM:" | head -4

echo ""
echo -e "${YELLOW}Tips to maintain performance:${NC}"
echo "1. Restart your device weekly"
echo "2. Uninstall unused apps"
echo "3. Use 'Lite' versions of social media apps"
echo "4. Enable Developer Options > Don't keep activities"
echo "5. Limit background processes in Developer Options"
