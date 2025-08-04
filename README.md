# Blade Runner - Android Security Scanner

<p align="center">
  <em>"I've seen things you people wouldn't believe... Suspicious apps with SMS permissions off the shoulder of Samsung..."</em>
</p>

## Overview

**Blade Runner** is a comprehensive Android security audit tool that hunts down rogue apps and suspicious permissions on Android devices. Like its namesake hunting replicants, it identifies apps that aren't what they appear to be.

## Features

- 🔍 **Deep Security Scan**: Comprehensive analysis of device security state
- 📱 **SMS Interceptor Detection**: Finds apps with suspicious SMS permissions  
- 🎭 **Overlay Attack Detection**: Identifies apps that can draw over others
- 🔐 **Permission Analysis**: Tracks dangerous permission combinations
- 🌐 **Network Monitoring**: Detects active connections and VPN apps
- 🚨 **Microsoft App Scanner**: Special detection for the Windows Phone companion issue
- 📊 **Detailed Reporting**: Comprehensive output with actionable insights

## Prerequisites

- Android device with Developer Mode enabled
- ADB (Android Debug Bridge) installed
- USB debugging enabled on device
- macOS/Linux system (for running the scripts)

## Installation

```bash
# Clone the repository
git clone https://github.com/Kylemanley26/replicant-bridge.git
cd replicant-bridge

# Make scripts executable
chmod +x bladerunner.sh
chmod +x suspicious_app_scanner.sh
chmod +x security_cleanup.sh
```

## Usage

### Main Security Audit
```bash
# Run the complete security audit
sudo ./bladerunner.sh
```

Output will be saved to `android_security_audit_YYYYMMDD_HHMMSS/`

### Quick Suspicious App Scan
```bash
# Fast scan for suspicious apps only
./suspicious_app_scanner.sh
```

### Security Cleanup
```bash
# Interactive cleanup tool
./security_cleanup.sh
```

## What It Detects

### 🚨 Critical Threats
- Apps masquerading as system services
- SMS interceptors and dialers
- Keyloggers and input monitors
- Overlay attack capable apps
- Hidden device administrators

### ⚠️ Privacy Concerns  
- Background location tracking
- Apps with microphone + internet access
- Contact harvesters
- Notification listeners
- Accessibility service abuse

### 📱 System Integrity
- Knox warranty status
- Bootloader lock state
- SELinux enforcement
- DM-Verity status
- Sideloaded applications

## Output Files

Each audit creates a timestamped directory containing:

- `FINAL_REPORT.txt` - Executive summary
- `device_info.txt` - Device identification
- `sms_interceptors.txt` - Apps with SMS permissions
- `overlay_apps.txt` - Potential overlay attackers
- `microsoft_analysis.txt` - Windows Phone app analysis
- `network_connections.txt` - Active connections
- And 20+ other detailed reports...

## Common Findings

### Microsoft AppManager
- **App**: `com.microsoft.appmanager`
- **Purpose**: Windows "Your Phone" companion
- **Risk**: Has SMS permissions for PC integration
- **Action**: Disable if not using Windows Phone features

### High SMS App Count
Normal devices have <20 apps with SMS access. If you see 100+, many are Samsung/Google system services, but review non-system apps carefully.

## Security Recommendations

1. **Regular Scans**: Run monthly security audits
2. **App Review**: Uninstall unused apps
3. **Permission Audit**: Revoke unnecessary permissions
4. **Unknown Sources**: Keep disabled unless needed
5. **Play Protect**: Ensure it's enabled
6. **OS Updates**: Keep system updated

## Troubleshooting

### "Command not found" Errors
```bash
# Ensure ADB is in PATH
export PATH=$PATH:/path/to/android-sdk/platform-tools
```

### Permission Denied
```bash
# Some commands need root
sudo ./bladerunner.sh
```

### Device Not Found
```bash
# Check ADB connection
adb devices
# Reconnect if needed
adb kill-server
adb start-server
```

## Contributing

Found a new threat pattern? Submit a pull request with detection logic!

## License

MIT License - Because security tools should be free

---

<p align="center">
  <em>"All those suspicious apps will be lost in time, like tears in rain..."</em>
</p>