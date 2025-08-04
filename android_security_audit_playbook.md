# Android Security Audit Playbook

## Prerequisites
- ADB (Android Debug Bridge) installed
- USB Debugging enabled on device
- Device connected via USB-C cable

## Initial Setup
```bash
# Verify connection
adb devices

# Get device info
adb shell getprop | grep -E "ro.product|ro.build|ro.bootloader"
```

## Phase 1: Basic Security State Audit

### 1.1 Knox & Bootloader Status
```bash
# Knox warranty (0=intact, 1=tripped)
adb shell getprop ro.boot.warranty_bit

# Verified boot state (should be "green")
adb shell getprop ro.boot.verifiedbootstate

# Flash lock status (should be "locked")
adb shell getprop ro.boot.flash.locked

# SELinux status (should be "Enforcing")
adb shell getenforce

# DM-Verity status (should be "enforcing")
adb shell getprop ro.boot.veritymode
```

### 1.2 Remote Tracking Services
```bash
# Check Find My Device
adb shell dumpsys package com.google.android.apps.adm | grep -E "enabled=|ACCESS.*LOCATION"

# Check Samsung Find My Mobile
adb shell dumpsys package com.samsung.android.fmm | grep -E "enabled=|ACCESS.*LOCATION"

# Check Google Maps location sharing
adb shell dumpsys package com.google.android.apps.maps | grep -E "enabled=|ACCESS.*LOCATION"
```

### 1.3 Screen Capture/Mirroring Permissions
```bash
# Check media projection permissions
adb shell dumpsys package | grep -B20 "FOREGROUND_SERVICE_MEDIA_PROJECTION: granted=true" | grep "Package \["

# Check capture permissions
adb shell pm list packages --user 0 | while read line; do 
  pkg=$(echo $line | cut -d: -f2)
  perms=$(adb shell dumpsys package $pkg | grep -E "CAPTURE_AUDIO_OUTPUT|CAPTURE_MEDIA_OUTPUT" | grep "granted=true")
  if [ ! -z "$perms" ]; then
    echo "=== $pkg ==="
    echo "$perms"
  fi
done
```

## Phase 2: Advanced Security Checks

### Check 1: Hidden Apps & Device Admin
```bash
# List disabled packages (potential hidden apps)
adb shell pm list packages -d --user 0 | grep -v "com.android\|com.google\|com.samsung\|com.sec"

# Check device administrators
adb shell dumpsys device_policy | grep -A5 "Active admin"

# Apps with overlay permissions
adb shell dumpsys package | grep -B5 "HIDE_NON_SYSTEM_OVERLAY_WINDOWS: granted=true" | grep "Package \["
```

### Check 2: Keylogger Detection
```bash
# Check for apps with keyboard permissions
adb shell dumpsys package | grep -B20 "android.permission.BIND_INPUT_METHOD" | grep "Package \["

# Show current keyboard
adb shell settings get secure default_input_method

# List all available keyboards
adb shell ime list -a

# Check for READ_INPUT_STATE permission
adb shell dumpsys package | grep -B20 "READ_INPUT_STATE: granted=true" | grep "Package \["
```

### Check 3: SMS/Call Interceptors
```bash
# Find apps that can intercept SMS
adb shell pm list packages --user 0 | while read line; do
  pkg=$(echo $line | cut -d: -f2)
  if adb shell dumpsys package $pkg | grep -q "RECEIVE_SMS.*granted=true" && \
     adb shell dumpsys package $pkg | grep -q "SEND_SMS.*granted=true"; then
    echo "⚠️ $pkg can intercept SMS"
  fi
done

# Check call recording apps
adb shell dumpsys package | grep -B20 "RECORD_AUDIO.*granted=true.*PROCESS_OUTGOING_CALLS.*granted=true" | grep "Package \["
```

### Check 4: Overlay Attacks (Tapjacking)
```bash
# Apps with system alert window permission
adb shell dumpsys package | grep -B20 "SYSTEM_ALERT_WINDOW: granted=true" | grep -E "Package \[" | grep -v "com.android\|com.google\|com.samsung"

# Check currently active overlays
adb shell dumpsys window windows | grep -B5 "TYPE_APPLICATION_OVERLAY"

# Check toast overlay abuse
adb shell dumpsys activity services | grep -B2 "isForeground=true" | grep -v "com.android\|com.google"
```

### Check 5: Persistence Mechanisms
```bash
# Apps that start on boot
adb shell dumpsys package | grep -B20 "RECEIVE_BOOT_COMPLETED: granted=true" | grep "Package \[" | grep -v "com.android\|com.google\|com.samsung" | head -20

# Check scheduled jobs
adb shell dumpsys jobscheduler | grep -A5 "JOB #" | grep -v "com.android\|com.google"

# Persistent foreground services
adb shell dumpsys activity services | grep -B2 "isForeground=true" | grep -v "SystemUI\|com.android\|com.google"

# Check alarms
adb shell dumpsys alarm | grep -A2 "WAKEUP" | grep -v "com.android\|com.google" | head -20
```

### Check 6: Network Monitoring & VPN
```bash
# Apps with VPN permissions
adb shell dumpsys package | grep -B20 "android.permission.BIND_VPN_SERVICE" | grep "Package \["

# Check active VPN
adb shell ifconfig | grep tun0
adb shell netstat -rn | grep tun

# Check for proxy settings
adb shell settings get global http_proxy
adb shell settings get global global_http_proxy_host

# Suspicious network connections
adb shell netstat -an | grep "ESTABLISHED" | grep -v "127.0.0.1\|192.168" | head -20

# Apps with network admin permissions
adb shell dumpsys package | grep -B20 "CHANGE_NETWORK_STATE.*granted=true.*WRITE_APN_SETTINGS.*granted=true" | grep "Package \["
```

### Check 7: Data Exfiltration Risks
```bash
# Apps with contacts + internet
for pkg in $(adb shell pm list packages -3 --user 0 | cut -d: -f2); do
  if adb shell dumpsys package $pkg | grep -q "READ_CONTACTS: granted=true" && \
     adb shell dumpsys package $pkg | grep -q "INTERNET: granted=true"; then
    echo "📱 $pkg has contacts+internet"
  fi
done

# Apps with storage + internet
for pkg in $(adb shell pm list packages -3 --user 0 | cut -d: -f2); do
  if adb shell dumpsys package $pkg | grep -q "READ_EXTERNAL_STORAGE: granted=true" && \
     adb shell dumpsys package $pkg | grep -q "INTERNET: granted=true"; then
    echo "💾 $pkg has storage+internet"
  fi
done

# Apps with camera/mic + internet
for pkg in $(adb shell pm list packages -3 --user 0 | cut -d: -f2); do
  if adb shell dumpsys package $pkg | grep -q "CAMERA: granted=true" && \
     adb shell dumpsys package $pkg | grep -q "RECORD_AUDIO: granted=true" && \
     adb shell dumpsys package $pkg | grep -q "INTERNET: granted=true"; then
    echo "📸 $pkg has camera+mic+internet"
  fi
done
```

## Phase 3: Location & Background Tracking

### 3.1 Background Location Access
```bash
# Apps with 24/7 location tracking
adb shell dumpsys package | awk '/Package \[/{pkg=$0} /ACCESS_BACKGROUND_LOCATION: granted=true/{print pkg}' | sort -u

# Current location settings
adb shell settings get secure location_mode
adb shell settings get secure location_providers_allowed

# Apps currently using location
adb shell dumpsys location | grep -A10 "Active Records"
```

### 3.2 Notification Access
```bash
# Apps that can read all notifications
adb shell settings get secure enabled_notification_listeners
```

## Phase 4: App Integrity & Source Verification

### 4.1 Check App Installation Sources
```bash
# Find sideloaded apps (not from Play Store)
adb shell pm list packages -i --user 0 | grep -v "installer=com.android.vending" | grep -v "installer=null" | grep -v "installer=com.sec.android.app.samsungapps"

# Actually sideloaded (via ADB or manual APK)
adb shell pm list packages -i --user 0 | grep -E "installer=com.android.shell|installer=.*packageinstaller"
```

### 4.2 Verify App Signatures
```bash
# Get signature for specific app
adb shell dumpsys package PACKAGE_NAME | grep -A5 "signatures="

# Check for fake system apps
adb shell pm list packages | grep -E "update|system|service|android" | grep -v "com.android\|com.google"
```

## Phase 5: Additional Security Checks

### 5.1 Accessibility Services (Screen Readers)
```bash
# List all accessibility services
adb shell settings get secure enabled_accessibility_services

# Apps with accessibility permissions
adb shell pm list packages --user 0 | while read line; do
  pkg=$(echo $line | cut -d: -f2)
  if adb shell dumpsys package $pkg | grep -q "android.permission.BIND_ACCESSIBILITY_SERVICE"; then
    echo "$pkg"
  fi
done
```

### 5.2 Active Network Connections
```bash
# External connections
adb shell netstat -an | grep "ESTABLISHED" | grep -v "127.0.0.1" | grep -v "192.168"

# Check specific suspicious IPs
adb shell netstat -an | grep -E "SUSPICIOUS_IP_HERE"
```

### 5.3 Process Monitoring
```bash
# High CPU usage (potential miners)
adb shell top -b -n 1 | head -20

# Check specific suspicious processes
adb shell ps -A | grep -E "suspicious_process_name"
```

### 5.4 Bluetooth Security Audit
```bash
# Check if Bluetooth is enabled
adb shell settings get global bluetooth_on

# List paired devices
adb shell dumpsys bluetooth_manager | grep -A20 "Bonded devices"

# Show currently connected devices
adb shell dumpsys bluetooth_manager | grep -A5 "Connected devices"

# Check Bluetooth connection history
adb shell dumpsys bluetooth_manager | grep -A50 "Connection Events"

# List apps with Bluetooth permissions
adb shell dumpsys package | grep -B20 "BLUETOOTH_ADMIN: granted=true" | grep "Package \[" | grep -v "com.android\|com.google\|com.samsung"

# Check for apps with Bluetooth scanning permission (can track you via Bluetooth)
adb shell dumpsys package | grep -B20 "BLUETOOTH_SCAN: granted=true" | grep "Package \["

# Check for apps that can connect to devices
adb shell dumpsys package | grep -B20 "BLUETOOTH_CONNECT: granted=true" | grep "Package \["

# Check Bluetooth sharing history
adb shell dumpsys bluetooth_manager | grep -A20 "Sharing"

# Verify Bluetooth MAC address (check for spoofing)
adb shell settings get secure bluetooth_address
```

### Bluetooth Red Flags:
- Unknown paired devices
- Devices you don't recognize in connection history
- Apps with Bluetooth admin that shouldn't need it
- Frequent connection/disconnection events
- Unknown devices attempting to pair

## Remediation Commands

### Disable Suspicious Apps
```bash
# Disable app
adb shell pm disable-user --user 0 PACKAGE_NAME

# Force stop app
adb shell am force-stop PACKAGE_NAME

# Clear app data
adb shell pm clear PACKAGE_NAME
```

### Revoke Dangerous Permissions
```bash
# Revoke specific permission
adb shell pm revoke PACKAGE_NAME PERMISSION_NAME

# Revoke notification access
adb shell cmd notification disallow_listener PACKAGE_NAME/SERVICE_NAME
```

### Remove Network Access
```bash
# Block app from using mobile data (requires root)
adb shell cmd netpolicy add restrict-background-whitelist PACKAGE_NAME

# Remove app from data saver whitelist
adb shell cmd netpolicy remove restrict-background-whitelist PACKAGE_NAME
```

## Red Flags to Look For

1. **Apps with these permission combinations:**
   - Camera + Microphone + Internet
   - SMS Read/Send + Internet
   - Contacts + Storage + Internet
   - Accessibility + Internet

2. **Suspicious installers:**
   - `installer=com.android.shell` (ADB install)
   - Unknown package installers

3. **Background activities:**
   - Apps with background location
   - Persistent foreground services
   - Boot receivers from unknown apps

4. **Network indicators:**
   - Connections to non-HTTPS ports
   - VPN apps from unknown sources
   - High data usage from simple apps

5. **System-level access:**
   - Device administrators
   - Accessibility services
   - Input method (keyboard) apps
   - Apps with overlay permissions

## Common Findings & Their Meanings

- **installer=null**: Usually pre-installed apps or restored from backup
- **stopped=false**: App is active and can run
- **enabled=0**: App is enabled (confusingly, 0 means enabled)
- **firstInstallTime**: When app was first installed
- **Knox apps**: Samsung's security framework, usually safe

## Notes

- Run these checks periodically
- Save outputs for comparison
- Focus on third-party apps with powerful permissions
- System apps (com.android.*, com.google.*, com.samsung.*) are generally safe
- Always verify before disabling system apps