#!/bin/bash

# Blade Runner Master Script
# Runs audit, analysis, and remediation in sequence

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║        BLADE RUNNER SECURITY SUITE v2.0              ║"
echo "║        Automated Android Security System             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to display menu
show_menu() {
    echo "1) Run Full Security Audit"
    echo "2) Analyze Existing Audit"
    echo "3) Auto-Remediate Issues"
    echo "4) Run Everything (Audit + Analyze + Remediate)"
    echo "5) Quick Security Check"
    echo "6) Generate Security Report"
    echo "7) Exit"
    echo ""
    read -p "Select option [1-7]: " choice
}

# Function to select audit directory
select_audit_dir() {
    echo -e "\n${YELLOW}Available audit directories:${NC}"
    ls -dt android_security_audit_*/ 2>/dev/null | head -10 | nl
    echo ""
    read -p "Enter number or full path: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        AUDIT_DIR=$(ls -dt android_security_audit_*/ 2>/dev/null | sed -n "${selection}p" | sed 's/\/$//')
    else
        AUDIT_DIR="$selection"
    fi
    
    if [ ! -d "$AUDIT_DIR" ]; then
        echo -e "${RED}Error: Directory not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Selected: $AUDIT_DIR${NC}"
    return 0
}

# Function to run quick security check
quick_check() {
    echo -e "\n${YELLOW}Running Quick Security Check...${NC}"
    
    echo -e "\n${BLUE}Device Status:${NC}"
    echo -n "Knox Warranty: "
    adb shell getprop ro.boot.warranty_bit
    echo -n "SELinux: "
    adb shell getenforce
    echo -n "Bootloader: "
    adb shell getprop ro.boot.flash.locked
    
    echo -e "\n${BLUE}Suspicious Apps:${NC}"
    echo "Checking for non-system apps with dangerous permissions..."
    
    # Quick SMS check
    SMS_COUNT=$(adb shell pm list packages -3 --user 0 | cut -d: -f2 | while read pkg; do
        if adb shell dumpsys package $pkg 2>/dev/null | grep -q "SEND_SMS: granted=true"; then
            echo $pkg
        fi
    done | wc -l)
    
    echo "Non-system apps with SMS: $SMS_COUNT"
    
    # Memory check
    MEM_PERCENT=$(adb shell dumpsys meminfo | grep "Total RAM:" | awk '{gsub(/,/,""); print int($7/$3*100)}')
    echo -e "\n${BLUE}Performance:${NC}"
    echo "Memory Usage: ${MEM_PERCENT}%"
    
    if [ "$MEM_PERCENT" -gt 90 ]; then
        echo -e "${RED}⚠️  High memory usage detected!${NC}"
    else
        echo -e "${GREEN}✓ Memory usage normal${NC}"
    fi
}

# Function to generate comprehensive report
generate_report() {
    if ! select_audit_dir; then
        return
    fi
    
    REPORT_FILE="$AUDIT_DIR/COMPREHENSIVE_SECURITY_REPORT_$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Blade Runner Security Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #0a0a0a; color: #00ff00; margin: 20px; }
        h1 { color: #00ffff; text-align: center; text-shadow: 0 0 10px #00ffff; }
        h2 { color: #ffff00; border-bottom: 2px solid #ffff00; }
        .section { background: #1a1a1a; padding: 15px; margin: 10px 0; border: 1px solid #00ff00; }
        .good { color: #00ff00; }
        .warning { color: #ffff00; }
        .critical { color: #ff0000; }
        .score { font-size: 48px; text-align: center; margin: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 8px; text-align: left; border: 1px solid #00ff00; }
        th { background: #003300; }
        .timestamp { text-align: center; color: #888; }
    </style>
</head>
<body>
    <h1>BLADE RUNNER SECURITY REPORT</h1>
    <p class="timestamp">Generated: $(date)</p>
EOF
    
    # Add device info
    if [ -f "$AUDIT_DIR/device_info.txt" ]; then
        echo "<div class='section'><h2>Device Information</h2><pre>" >> "$REPORT_FILE"
        head -10 "$AUDIT_DIR/device_info.txt" >> "$REPORT_FILE"
        echo "</pre></div>" >> "$REPORT_FILE"
    fi
    
    # Add security status
    echo "<div class='section'><h2>Security Status</h2><table>" >> "$REPORT_FILE"
    echo "<tr><th>Check</th><th>Status</th></tr>" >> "$REPORT_FILE"
    
    # Knox
    KNOX=$(cat "$AUDIT_DIR/knox_warranty.txt" 2>/dev/null)
    if [ "$KNOX" = "0" ]; then
        echo "<tr><td>Knox Warranty</td><td class='good'>✓ Not Tripped</td></tr>" >> "$REPORT_FILE"
    else
        echo "<tr><td>Knox Warranty</td><td class='critical'>✗ Tripped</td></tr>" >> "$REPORT_FILE"
    fi
    
    # SELinux
    SELINUX=$(cat "$AUDIT_DIR/selinux_status.txt" 2>/dev/null)
    if [ "$SELINUX" = "Enforcing" ]; then
        echo "<tr><td>SELinux</td><td class='good'>✓ Enforcing</td></tr>" >> "$REPORT_FILE"
    else
        echo "<tr><td>SELinux</td><td class='critical'>✗ $SELINUX</td></tr>" >> "$REPORT_FILE"
    fi
    
    echo "</table></div>" >> "$REPORT_FILE"
    
    # Add summary statistics
    echo "<div class='section'><h2>Summary Statistics</h2><ul>" >> "$REPORT_FILE"
    echo "<li>SMS Apps: $(grep -c "===" "$AUDIT_DIR/sms_interceptors.txt" 2>/dev/null || echo 0)</li>" >> "$REPORT_FILE"
    echo "<li>Background Location: $(grep -c "Package" "$AUDIT_DIR/background_location_apps.txt" 2>/dev/null || echo 0)</li>" >> "$REPORT_FILE"
    echo "<li>Sideloaded Apps: $(wc -l < "$AUDIT_DIR/sideloaded_apps.txt" 2>/dev/null || echo 0)</li>" >> "$REPORT_FILE"
    echo "</ul></div>" >> "$REPORT_FILE"
    
    # Calculate and add score
    if [ -f "$AUDIT_DIR/analysis/security_score.txt" ]; then
        SCORE=$(grep "Overall Score:" "$AUDIT_DIR/analysis/security_score.txt" | awk '{print $3}')
        echo "<div class='section'><h2>Security Score</h2><div class='score'>$SCORE</div></div>" >> "$REPORT_FILE"
    fi
    
    echo "</body></html>" >> "$REPORT_FILE"
    
    echo -e "${GREEN}Report generated: $REPORT_FILE${NC}"
    echo "Opening in browser..."
    
    # Try to open in browser
    if command -v open &> /dev/null; then
        open "$REPORT_FILE"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$REPORT_FILE"
    fi
}

# Main loop
while true; do
    show_menu
    
    case $choice in
        1)
            echo -e "\n${BLUE}Starting Security Audit...${NC}"
            if [ -f "$SCRIPT_DIR/bladerunner.sh" ]; then
                sudo "$SCRIPT_DIR/bladerunner.sh"
            else
                echo -e "${RED}Error: bladerunner.sh not found${NC}"
            fi
            ;;
        2)
            if select_audit_dir; then
                echo -e "\n${BLUE}Analyzing Audit Data...${NC}"
                if [ -f "$SCRIPT_DIR/blade_runner_analyze.sh" ]; then
                    "$SCRIPT_DIR/blade_runner_analyze.sh" "$AUDIT_DIR"
                else
                    echo -e "${RED}Error: blade_runner_analyze.sh not found${NC}"
                fi
            fi
            ;;
        3)
            if select_audit_dir; then
                echo -e "\n${BLUE}Starting Auto-Remediation...${NC}"
                if [ -f "$SCRIPT_DIR/blade_runner_remediate.sh" ]; then
                    "$SCRIPT_DIR/blade_runner_remediate.sh" "$AUDIT_DIR"
                else
                    echo -e "${RED}Error: blade_runner_remediate.sh not found${NC}"
                fi
            fi
            ;;
        4)
            echo -e "\n${BLUE}Running Complete Security Suite...${NC}"
            
            # Run audit
            echo -e "\n${YELLOW}Step 1/3: Security Audit${NC}"
            sudo "$SCRIPT_DIR/bladerunner.sh"
            
            # Get latest audit directory
            LATEST_AUDIT=$(ls -dt android_security_audit_*/ 2>/dev/null | head -1 | sed 's/\/$//')
            
            if [ -d "$LATEST_AUDIT" ]; then
                # Run analysis
                echo -e "\n${YELLOW}Step 2/3: Pattern Analysis${NC}"
                "$SCRIPT_DIR/blade_runner_analyze.sh" "$LATEST_AUDIT"
                
                # Run remediation
                echo -e "\n${YELLOW}Step 3/3: Auto-Remediation${NC}"
                "$SCRIPT_DIR/blade_runner_remediate.sh" "$LATEST_AUDIT"
                
                echo -e "\n${GREEN}Complete Security Suite Finished!${NC}"
                echo "Results in: $LATEST_AUDIT"
            else
                echo -e "${RED}Error: Could not find audit results${NC}"
            fi
            ;;
        5)
            quick_check
            ;;
        6)
            generate_report
            ;;
        7)
            echo -e "\n${BLUE}Exiting Blade Runner...${NC}"
            echo "\"All those moments will be lost in time, like tears in rain.\""
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done