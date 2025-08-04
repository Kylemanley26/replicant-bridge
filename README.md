## Example Workflow

```bash
# 1. Run the master script
./blade_runner_master.sh

# 2. Select option 4 (Run Everything)
# This will:
#   - Run full security audit
#   - Analyze patterns
#   - Auto-remediate issues
#   - Generate reports

# 3. Review the HTML report
# Auto-opens in browser

# 4. Check remediation log
cat android_security_audit_*/REMEDIATION_REPORT.txt
```## Auto-Remediation Actions

The remediation system automatically:

### Memory Optimization
- Force stops high-memory apps (Instagram, Facebook, etc.)
- Clears system caches
- Optimizes app standby buckets

### Privacy Enhancement
- Restricts background location for non-essential apps
- Switches location mode to battery saving
- Disables always-on WiFi/mobile scanning

### Battery Optimization
- Sets social media apps to "restricted" standby
- Limits background activity for battery hogs
- Optimizes network scanning settings

### Security Hardening
- Identifies apps with dangerous permission combinations
- Creates custom rules based on findings
- Provides manual review recommendations

## Security Scoring

Blade Runner calculates a security score (0-100):
- **90-100**: ★★★★★ EXCELLENT
- **80-89**: ★★★★☆ GOOD
- **70-79**: ★★★☆☆ FAIR
- **60-69**: ★★☆☆☆ POOR
- **Below 60**: ★☆☆☆☆ CRITICAL

Deductions for:
- Knox warranty tripped (-20)
- SELinux not enforcing (-15)
- Sideloaded apps (-5 each)
- Excessive background apps (-5)# Blade Runner - Android Security Scanner & Auto-Remediation Suite

<p align="center">
  <em>"I've seen things you people wouldn't believe... Suspicious apps with SMS permissions off the shoulder of Samsung..."</em>
</p>

## Overview

**Blade Runner** is a comprehensive Android security audit and auto-remediation tool that hunts down rogue apps and automatically fixes security issues. Like its namesake hunting replicants, it identifies apps that aren't what they appear to be and neutralizes threats.

## 🚀 New: Auto-Remediation Features

### Master Control Script
```bash
./blade_runner_master.sh
```

Provides a menu-driven interface for:
- Full security audits
- Pattern analysis
- Automatic remediation
- Quick security checks
- HTML report generation

### Auto-Remediation
```bash
./blade_runner_remediate.sh <audit_directory>
```

Automatically fixes:
- High memory usage (kills resource hogs, clears caches)
- Excessive background location permissions
- Battery-draining location settings
- App standby optimization
- Network scanning settings

### Pattern Analysis
```bash
./blade_runner_analyze.sh <audit_directory>
```

Analyzes:
- SMS permission patterns
- Background activity patterns
- Creates custom remediation rules
- Calculates security score (0-100)

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

### Quick Start - Master Script (Recommended)
```bash
# Make all scripts executable
chmod +x blade_runner_*.sh

# Run the master control script
./blade_runner_master.sh
```

### Individual Components

#### Main Security Audit
```bash
# Run the complete security audit
sudo ./bladerunner.sh
```

#### Auto-Remediation
```bash
# Automatically fix issues found in audit
./blade_runner_remediate.sh android_security_audit_YYYYMMDD_HHMMSS
```

#### Pattern Analysis
```bash
# Analyze patterns and create custom rules
./blade_runner_analyze.sh android_security_audit_YYYYMMDD_HHMMSS
```

#### Quick Scan
```bash
# Run from master script menu option 5
./blade_runner_master.sh
# Select option 5
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

### Core Reports
- `FINAL_REPORT.txt` - Executive summary
- `REMEDIATION_REPORT.txt` - Auto-fix summary (after remediation)
- `COMPREHENSIVE_SECURITY_REPORT.html` - Visual HTML report
- `analysis/security_score.txt` - Security rating (0-100)
- `analysis/custom_remediation_rules.sh` - Generated fix scripts

### Detailed Scans
- `device_info.txt` - Device identification
- `sms_interceptors.txt` - Apps with SMS permissions
- `overlay_apps.txt` - Potential overlay attackers
- `background_location_apps.txt` - Battery drainers
- `microsoft_analysis.txt` - Windows Phone app analysis
- `network_connections.txt` - Active connections
- And 30+ other detailed reports...

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