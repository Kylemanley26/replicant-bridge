#!/bin/bash

# Blade Runner Advanced Pattern Analyzer
# Analyzes patterns in security audit data for custom remediation

AUDIT_DIR=$1
OUTPUT_DIR="$AUDIT_DIR/analysis"
mkdir -p "$OUTPUT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Blade Runner Pattern Analysis ===${NC}"

# Function to analyze SMS patterns
analyze_sms_patterns() {
    echo -e "\n${YELLOW}Analyzing SMS Permission Patterns...${NC}"
    
    if [ -f "$AUDIT_DIR/sms_interceptors.txt" ]; then
        # Extract unique permission patterns
        grep -E "SEND_SMS|RECEIVE_SMS" "$AUDIT_DIR/sms_interceptors.txt" | \
            sed 's/.*flags=\[//' | sed 's/\]//' | \
            sort | uniq -c | sort -rn > "$OUTPUT_DIR/sms_permission_patterns.txt"
        
        # Find apps with both SEND and RECEIVE
        awk '/===/{app=$2} /SEND_SMS.*granted=true/{send[app]=1} /RECEIVE_SMS.*granted=true/{recv[app]=1} END{for(a in send) if(recv[a]) print a}' \
            "$AUDIT_DIR/sms_interceptors.txt" > "$OUTPUT_DIR/apps_with_full_sms.txt"
        
        echo "Found $(wc -l < "$OUTPUT_DIR/apps_with_full_sms.txt") apps with full SMS access"
    fi
}

# Function to analyze background activity patterns
analyze_background_patterns() {
    echo -e "\n${YELLOW}Analyzing Background Activity Patterns...${NC}"
    
    # Combine data from multiple sources
    > "$OUTPUT_DIR/background_activity_summary.txt"
    
    # Background location apps
    if [ -f "$AUDIT_DIR/background_location_apps.txt" ]; then
        echo "=== BACKGROUND LOCATION ===" >> "$OUTPUT_DIR/background_activity_summary.txt"
        grep "Package" "$AUDIT_DIR/background_location_apps.txt" | \
            sed 's/.*Package \[\(.*\)\].*/\1/' >> "$OUTPUT_DIR/background_activity_summary.txt"
    fi
    
    # High CPU usage apps
    if [ -f "$AUDIT_DIR/cpu_usage.txt" ]; then
        echo -e "\n=== HIGH CPU USAGE ===" >> "$OUTPUT_DIR/background_activity_summary.txt"
        grep -E "com\.[a-z]+\.[a-z]+" "$AUDIT_DIR/cpu_usage.txt" | \
            awk '$8>5 {print $NF, "CPU:"$8"%", "MEM:"$9"%"}' >> "$OUTPUT_DIR/background_activity_summary.txt"
    fi
}

# Function to create remediation rules
create_remediation_rules() {
    echo -e "\n${YELLOW}Creating Custom Remediation Rules...${NC}"
    
    cat > "$OUTPUT_DIR/custom_remediation_rules.sh" << 'EOF'
#!/bin/bash
# Auto-generated remediation rules based on pattern analysis

# Rule 1: Revoke SMS from apps not in messaging category
MESSAGING_APPS=("com.google.android.apps.messaging" "com.samsung.android.messaging" "com.whatsapp")
while read app; do
    if [[ ! " ${MESSAGING_APPS[@]} " =~ " ${app} " ]]; then
        echo "Revoking SMS from non-messaging app: $app"
        adb shell pm revoke "$app" android.permission.SEND_SMS 2>/dev/null
        adb shell pm revoke "$app" android.permission.RECEIVE_SMS 2>/dev/null
    fi
done < apps_with_full_sms.txt

# Rule 2: Restrict apps with high battery usage patterns
while read line; do
    app=$(echo "$line" | awk '{print $1}')
    cpu=$(echo "$line" | grep -o 'CPU:[0-9.]*' | cut -d: -f2 | cut -d% -f1)
    if (( $(echo "$cpu > 10" | bc -l) )); then
        echo "Restricting high CPU app: $app (${cpu}%)"
        adb shell cmd appops set "$app" RUN_IN_BACKGROUND ignore
        adb shell am set-standby-bucket "$app" restricted
    fi
done < background_activity_summary.txt

# Rule 3: Optimize location access based on app category
ALWAYS_LOCATION_APPS=("com.google.android.apps.maps" "com.samsung.android.weather")
while read app; do
    if [[ ! " ${ALWAYS_LOCATION_APPS[@]} " =~ " ${app} " ]]; then
        echo "Restricting background location for: $app"
        adb shell cmd appops set "$app" ACCESS_BACKGROUND_LOCATION ignore
    fi
done < <(grep "Package" background_location_apps.txt | sed 's/.*Package \[\(.*\)\].*/\1/')
EOF
    
    chmod +x "$OUTPUT_DIR/custom_remediation_rules.sh"
}

# Function to generate security score
calculate_security_score() {
    echo -e "\n${YELLOW}Calculating Security Score...${NC}"
    
    SCORE=100
    DEDUCTIONS=""
    
    # Check various security aspects
    if [ -f "$AUDIT_DIR/knox_warranty.txt" ] && [ "$(cat "$AUDIT_DIR/knox_warranty.txt")" != "0" ]; then
        SCORE=$((SCORE - 20))
        DEDUCTIONS+="\n  -20: Knox warranty tripped"
    fi
    
    if [ -f "$AUDIT_DIR/selinux_status.txt" ] && [ "$(cat "$AUDIT_DIR/selinux_status.txt")" != "Enforcing" ]; then
        SCORE=$((SCORE - 15))
        DEDUCTIONS+="\n  -15: SELinux not enforcing"
    fi
    
    if [ -f "$AUDIT_DIR/sideloaded_apps.txt" ] && [ -s "$AUDIT_DIR/sideloaded_apps.txt" ]; then
        COUNT=$(wc -l < "$AUDIT_DIR/sideloaded_apps.txt")
        SCORE=$((SCORE - COUNT * 5))
        DEDUCTIONS+="\n  -$((COUNT * 5)): $COUNT sideloaded apps"
    fi
    
    if [ -f "$AUDIT_DIR/background_location_apps.txt" ]; then
        COUNT=$(grep -c "Package" "$AUDIT_DIR/background_location_apps.txt" 2>/dev/null || echo 0)
        if [ "$COUNT" -gt 10 ]; then
            SCORE=$((SCORE - 5))
            DEDUCTIONS+="\n  -5: Too many background location apps ($COUNT)"
        fi
    fi
    
    # Generate score report
    cat > "$OUTPUT_DIR/security_score.txt" << EOF
Blade Runner Security Score
===========================
Date: $(date)
Device: $(grep "ro.product.model" "$AUDIT_DIR/device_info.txt" 2>/dev/null | cut -d: -f2 | tr -d '[]' || echo "Unknown")

Overall Score: $SCORE/100

Deductions:$DEDUCTIONS

Rating:
EOF
    
    if [ "$SCORE" -ge 90 ]; then
        echo "★★★★★ EXCELLENT" >> "$OUTPUT_DIR/security_score.txt"
    elif [ "$SCORE" -ge 80 ]; then
        echo "★★★★☆ GOOD" >> "$OUTPUT_DIR/security_score.txt"
    elif [ "$SCORE" -ge 70 ]; then
        echo "★★★☆☆ FAIR" >> "$OUTPUT_DIR/security_score.txt"
    elif [ "$SCORE" -ge 60 ]; then
        echo "★★☆☆☆ POOR" >> "$OUTPUT_DIR/security_score.txt"
    else
        echo "★☆☆☆☆ CRITICAL" >> "$OUTPUT_DIR/security_score.txt"
    fi
    
    echo -e "${GREEN}Security Score: $SCORE/100${NC}"
}

# Run all analyses
analyze_sms_patterns
analyze_background_patterns
create_remediation_rules
calculate_security_score

echo -e "\n${GREEN}Analysis complete! Check $OUTPUT_DIR for results.${NC}"
echo -e "\nTo apply custom rules, run:"
echo -e "${YELLOW}cd $OUTPUT_DIR && ./custom_remediation_rules.sh${NC}"