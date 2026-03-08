#!/bin/bash
#
# REAL Usage Dashboard with % Remaining
# Attempts to get actual limits from providers
#

# Cleanup
cleanup() {
    echo -e "\033[?25h"  # Show cursor
    clear
    echo "Dashboard stopped."
    exit 0
}
trap cleanup INT TERM EXIT

# Hide cursor
echo -e "\033[?25l"

# Config file for storing limits
CONFIG_DIR="$HOME/.opencode"
CONFIG_FILE="$CONFIG_DIR/usage-limits.conf"

# Provider limits (will be updated with real values)
declare -A TOTAL_LIMITS
declare -A USED_LIMITS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Load saved limits
load_limits() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Save limits
save_limits() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# OpenCode Usage Limits Configuration
# Updated: $(date)

# These are your actual remaining limits from provider dashboards
# Run: ./update-limits.sh to refresh these values

ANTHROPIC_LIMIT_MINUTES=${ANTHROPIC_LIMIT_MINUTES:-300}
KIMI_LIMIT_MINUTES=${KIMI_LIMIT_MINUTES:-300}
GLM_LIMIT_MINUTES=${GLM_LIMIT_MINUTES:-10080}

# Last updated: $(date +%s)
EOF
    chmod 600 "$CONFIG_FILE"
}

# Try to get real usage from Anthropic API
check_anthropic_real() {
    local api_key="${ANTHROPIC_API_KEY:-}"
    
    if [ -z "$api_key" ]; then
        return 1
    fi
    
    # Try to get usage from Anthropic API
    # Note: This requires specific API access that may not be available
    local response=$(curl -s -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        "https://api.anthropic.com/v1/account/usage" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo "$response"
        return 0
    fi
    
    return 1
}

# Get OpenCode stats
get_opencode_stats() {
    opencode stats --models 2>/dev/null > /tmp/opencode_live.txt
    
    # Parse usage
    KIMI_MSGS=$(grep -A 6 "kimi-for-coding" /tmp/opencode_live.txt | grep "Messages" | awk '{print $2}' || echo "0")
    OPUS_MSGS=$(grep -A 6 "claude-opus" /tmp/opencode_live.txt | grep "Messages" | awk '{print $2}' || echo "0")
    SONNET_MSGS=$(grep -A 6 "claude-sonnet" /tmp/opencode_live.txt | grep "Messages" | awk '{print $2}' || echo "0")
    GLM_MSGS=$(grep -A 6 "zai-coding-plan" /tmp/opencode_live.txt | grep "Messages" | awk '{print $2}' || echo "0")
}

# Calculate usage from message count (rough estimate)
# Based on: average conversation is 2-3 minutes of processing
calculate_used_minutes() {
    local msgs=$1
    # Rough estimate: each message takes ~15-30 seconds of model time
    # This is conservative
    echo $((msgs * 20 / 60))
}

# Draw progress bar with percentage
draw_progress() {
    local percent=$1
    local width=40
    local filled=$((width * percent / 100))
    local empty=$((width - filled))
    
    if [ $percent -ge 90 ]; then
        COLOR="$RED"
    elif [ $percent -ge 75 ]; then
        COLOR="$YELLOW"
    else
        COLOR="$GREEN"
    fi
    
    printf "${COLOR}["
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %3d%%${NC}" "$percent"
}

# Format minutes to hours:minutes
format_time() {
    local mins=$1
    local h=$((mins / 60))
    local m=$((mins % 60))
    printf "%dh %02dm" $h $m
}

# Update limits from user input
update_limits_interactive() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}           UPDATE USAGE LIMITS FROM DASHBOARDS                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Please check your provider dashboards and enter remaining limits:${NC}"
    echo ""
    
    echo -e "1. ${CYAN}Claude (Anthropic):${NC} https://console.anthropic.com/settings/usage"
    read -p "   Remaining minutes (5hr = 300): " anthropic_remaining
    
    echo ""
    echo -e "2. ${CYAN}Kimi (Moonshot):${NC} https://platform.moonshot.cn/console/usage"
    read -p "   Remaining minutes (5hr = 300): " kimi_remaining
    
    echo ""
    echo -e "3. ${CYAN}GLM-5 (Zhipu):${NC} https://open.bigmodel.cn/overview"
    read -p "   Remaining minutes (weekly): " glm_remaining
    
    # Save to config
    ANTHROPIC_LIMIT_MINUTES=${anthropic_remaining:-300}
    KIMI_LIMIT_MINUTES=${kimi_remaining:-300}
    GLM_LIMIT_MINUTES=${glm_remaining:-10080}
    
    save_limits
    
    echo ""
    echo -e "${GREEN}✓ Limits saved!${NC}"
    echo -e "${DIM}Config file: $CONFIG_FILE${NC}"
    sleep 2
}

# Draw dashboard
draw_dashboard() {
    clear
    
    # Load current limits
    load_limits
    
    # Header
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}          REAL USAGE DASHBOARD - % REMAINING                  ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${DIM}  Last update: $(date '+%H:%M:%S') | Auto-refresh: 30s${NC}"
    echo -e "${DIM}  Press 'u' to update limits, 'q' to quit${NC}"
    echo ""
    
    # Get current stats
    get_opencode_stats
    
    # Calculate used (estimated from messages)
    ANTHROPIC_USED=$(calculate_used_minutes $((OPUS_MSGS + SONNET_MSGS)))
    KIMI_USED=$(calculate_used_minutes $KIMI_MSGS)
    GLM_USED=$(calculate_used_minutes $GLM_MSGS)
    
    # Calculate remaining
    ANTHROPIC_REMAINING=$((ANTHROPIC_LIMIT_MINUTES - ANTHROPIC_USED))
    if [ $ANTHROPIC_REMAINING -lt 0 ]; then ANTHROPIC_REMAINING=0; fi
    
    KIMI_REMAINING=$((KIMI_LIMIT_MINUTES - KIMI_USED))
    if [ $KIMI_REMAINING -lt 0 ]; then KIMI_REMAINING=0; fi
    
    GLM_REMAINING=$((GLM_LIMIT_MINUTES - GLM_USED))
    if [ $GLM_REMAINING -lt 0 ]; then GLM_REMAINING=0; fi
    
    # Calculate percentages (remaining / total)
    ANTHROPIC_PERCENT=$((ANTHROPIC_REMAINING * 100 / ANTHROPIC_LIMIT_MINUTES))
    KIMI_PERCENT=$((KIMI_REMAINING * 100 / KIMI_LIMIT_MINUTES))
    GLM_PERCENT=$((GLM_REMAINING * 100 / GLM_LIMIT_MINUTES))
    
    # Claude Anthropic Section
    echo -e "${MAGENTA}▓▓▓ CLAUDE (ANTHROPIC) ▓▓▓${NC}"
    echo ""
    echo -e "  ${WHITE}Limit:${NC}        5 hours (${ANTHROPIC_LIMIT_MINUTES} min)"
    echo -e "  ${WHITE}Used (est):${NC}   $(format_time $ANTHROPIC_USED)"
    echo -e "  ${WHITE}Remaining:${NC}    $(format_time $ANTHROPIC_REMAINING)"
    echo -n "  ${WHITE}Percent Left:${NC} "
    draw_progress $ANTHROPIC_PERCENT
    echo ""
    
    if [ $ANTHROPIC_PERCENT -le 10 ]; then
        echo -e "  ${RED}⚠️  CRITICAL: Less than 10% remaining!${NC}"
    elif [ $ANTHROPIC_PERCENT -le 25 ]; then
        echo -e "  ${YELLOW}⚠️  WARNING: Less than 25% remaining${NC}"
    fi
    echo ""
    
    # Kimi Section
    echo -e "${CYAN}▓▓▓ KIMI (MOONSHOT AI) ▓▓▓${NC}"
    echo ""
    echo -e "  ${WHITE}Limit:${NC}        5 hours weekly (${KIMI_LIMIT_MINUTES} min)"
    echo -e "  ${WHITE}Used (est):${NC}   $(format_time $KIMI_USED)"
    echo -e "  ${WHITE}Remaining:${NC}    $(format_time $KIMI_REMAINING)"
    echo -n "  ${WHITE}Percent Left:${NC} "
    draw_progress $KIMI_PERCENT
    echo ""
    
    if [ $KIMI_PERCENT -le 10 ]; then
        echo -e "  ${RED}⚠️  CRITICAL: Less than 10% remaining!${NC}"
    elif [ $KIMI_PERCENT -le 25 ]; then
        echo -e "  ${YELLOW}⚠️  WARNING: Less than 25% remaining${NC}"
    fi
    echo ""
    
    # GLM-5 Section
    echo -e "${GREEN}▓▓▓ GLM-5 (ZHIPU AI) ▓▓▓${NC}"
    echo ""
    echo -e "  ${WHITE}Limit:${NC}        Weekly quota (${GLM_LIMIT_MINUTES} min)"
    echo -e "  ${WHITE}Used (est):${NC}   $(format_time $GLM_USED)"
    echo -e "  ${WHITE}Remaining:${NC}    $(format_time $GLM_REMAINING)"
    echo -n "  ${WHITE}Percent Left:${NC} "
    draw_progress $GLM_PERCENT
    echo ""
    
    # Framework status
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    GLM_COUNT=$(grep -l "model: zai-coding-plan/glm-5" "$SCRIPT_DIR/.opencode/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$GLM_COUNT" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠️  GLM-5 agents currently DISABLED${NC}"
        echo -e "      Run: ${DIM}./switch_models.sh glm${NC}"
    fi
    echo ""
    
    # Footer
    echo -e "${BLUE}─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Show current session
    TOTAL=$((OPUS_MSGS + SONNET_MSGS + KIMI_MSGS + GLM_MSGS))
    echo -e "  ${WHITE}Current Session:${NC} ${TOTAL} total messages"
    echo -e "    ${MAGENTA}•${NC} Claude Opus: ${OPUS_MSGS} msgs"
    echo -e "    ${YELLOW}•${NC} Claude Sonnet: ${SONNET_MSGS} msgs"
    echo -e "    ${CYAN}•${NC} Kimi: ${KIMI_MSGS} msgs"
    echo -e "    ${GREEN}•${NC} GLM-5: ${GLM_MSGS} msgs"
    echo ""
    
    # Legend
    echo -e "${DIM}Note: Used time is estimated from message count.${NC}"
    echo -e "${DIM}For exact % remaining, update limits from dashboards (press 'u')${NC}"
    echo ""
}

# Main loop with keyboard input
main() {
    # Check if limits are set
    load_limits
    
    if [ ! -f "$CONFIG_FILE" ]; then
        update_limits_interactive
    fi
    
    clear
    
    while true; do
        draw_dashboard
        
        # Wait for 30 seconds or keypress
        read -t 30 -n 1 key
        
        if [ "$key" = "u" ] || [ "$key" = "U" ]; then
            update_limits_interactive
        elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            cleanup
        fi
        
        # Clear key for next iteration
        key=""
    done
}

# Create update script
create_update_script() {
    cat > "$(dirname "$0")/update-limits.sh" << 'EOF'
#!/bin/bash
# Update usage limits from provider dashboards

echo "Usage Limit Updater"
echo "==================="
echo ""
echo "Please check your remaining limits from these dashboards:"
echo ""
echo "1. Claude (Anthropic): https://console.anthropic.com/settings/usage"
echo "   - Look for remaining time/quota"
echo ""
echo "2. Kimi (Moonshot): https://platform.moonshot.cn/console/usage"
echo "   - Look for remaining weekly time"
echo ""
echo "3. GLM-5 (Zhipu): https://open.bigmodel.cn/overview"
echo "   - Look for remaining weekly quota"
echo ""
read -p "Press Enter to input values..."

./usage-dashboard.sh
EOF
    chmod +x "$(dirname "$0")/update-limits.sh"
}

# Run
create_update_script
main