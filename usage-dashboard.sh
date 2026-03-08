#!/bin/bash
#
# LIVE Usage Dashboard - Real OpenCode Stats
# Updates every 10 seconds
#

# Cleanup
cleanup() {
    clear
    echo -e "\033[?25h"  # Show cursor
    echo "Dashboard stopped."
    exit 0
}
trap cleanup INT TERM EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'

# Hide cursor
echo -e "\033[?25l"

# Get current framework status
get_framework_status() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    AGENTS_DIR="$SCRIPT_DIR/.opencode/agents"
    
    if [ -d "$AGENTS_DIR" ]; then
        KIMI_AGENTS=$(grep -l "model: kimi-for-coding/k2p5" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        GLM_AGENTS=$(grep -l "model: zai-coding-plan/glm-5" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        OPUS_AGENTS=$(grep -l "model: anthropic/claude-opus-4-6" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        SONNET_AGENTS=$(grep -l "model: anthropic/claude-sonnet-4-6" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    fi
}

# Fetch real stats
fetch_real_stats() {
    opencode stats --models 2>/dev/null > /tmp/live_stats.txt
    
    # Parse each model
    KIMI_LINE=$(grep -A 6 "kimi-for-coding" /tmp/live_stats.txt)
    KIMI_MSGS=$(echo "$KIMI_LINE" | grep "Messages" | awk '{print $2}')
    KIMI_INPUT=$(echo "$KIMI_LINE" | grep "Input Tokens" | awk '{print $2}')
    KIMI_OUTPUT=$(echo "$KIMI_LINE" | grep "Output Tokens" | awk '{print $2}')
    
    OPUS_LINE=$(grep -A 6 "claude-opus" /tmp/live_stats.txt)
    OPUS_MSGS=$(echo "$OPUS_LINE" | grep "Messages" | awk '{print $2}')
    OPUS_INPUT=$(echo "$OPUS_LINE" | grep "Input Tokens" | awk '{print $2}')
    OPUS_OUTPUT=$(echo "$OPUS_LINE" | grep "Output Tokens" | awk '{print $2}')
    
    SONNET_LINE=$(grep -A 6 "claude-sonnet" /tmp/live_stats.txt)
    SONNET_MSGS=$(echo "$SONNET_LINE" | grep "Messages" | awk '{print $2}')
    SONNET_INPUT=$(echo "$SONNET_LINE" | grep "Input Tokens" | awk '{print $2}')
    SONNET_OUTPUT=$(echo "$SONNET_LINE" | grep "Output Tokens" | awk '{print $2}')
    
    GLM_LINE=$(grep -A 6 "zai-coding-plan" /tmp/live_stats.txt)
    GLM_MSGS=$(echo "$GLM_LINE" | grep "Messages" | awk '{print $2}')
    GLM_INPUT=$(echo "$GLM_LINE" | grep "Input Tokens" | awk '{print $2}')
    GLM_OUTPUT=$(echo "$GLM_LINE" | grep "Output Tokens" | awk '{print $2}')
    
    TOTAL_MSGS=$(grep "Messages" /tmp/live_stats.txt | head -1 | awk '{print $2}')
    TOTAL_COST=$(grep "Total Cost" /tmp/live_stats.txt | awk '{print $2}')
}

# Format large numbers
format_number() {
    printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# Draw box
draw_box() {
    local title=$1
    local color=$2
    shift 2
    
    echo -e "${color}┌────────────────────────────────────────────────────────────────┐${NC}"
    printf "${color}│${NC} ${BOLD}%-62s${NC} ${color}│${NC}\n" "$title"
    echo -e "${color}├────────────────────────────────────────────────────────────────┤${NC}"
    
    for line in "$@"; do
        printf "${color}│${NC} %-62s ${color}│${NC}\n" "$line"
    done
    
    echo -e "${color}└────────────────────────────────────────────────────────────────┘${NC}"
}

# Draw dashboard
draw_dashboard() {
    clear
    
    # Header
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}               LIVE OPENCODE USAGE DASHBOARD                   ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Last update
    echo -e "${DIM}  Last update: $(date '+%H:%M:%S') | Auto-refresh: 10 seconds${NC}"
    echo ""
    
    # Framework status
    get_framework_status
    echo -e "${CYAN}Framework Configuration:${NC}"
    echo -e "  Kimi K2.5:   ${GREEN}${KIMI_AGENTS}${NC} agents"
    echo -e "  GLM-5:       ${GREEN}${GLM_AGENTS}${NC} agents"
    echo -e "  Opus:        ${YELLOW}${OPUS_AGENTS}${NC} agents"
    echo -e "  Sonnet:      ${CYAN}${SONNET_AGENTS}${NC} agents"
    echo ""
    
    # Kimi Section
    echo -e "${CYAN}▶ Kimi (Moonshot AI)${NC} ${DIM}- 5 hour weekly limit${NC}"
    echo -e "  ${WHITE}Messages:${NC}    ${KIMI_MSGS:-0}"
    echo -e "  ${WHITE}Input:${NC}       ${KIMI_INPUT:-0} tokens"
    echo -e "  ${WHITE}Output:${NC}      ${KIMI_OUTPUT:-0} tokens"
    echo -e "  ${BLUE}Dashboard:${NC}   https://platform.moonshot.cn/console/usage"
    echo ""
    
    # Claude Opus Section
    echo -e "${MAGENTA}▶ Claude Opus (Anthropic)${NC} ${DIM}- 5 hour limit${NC}"
    echo -e "  ${WHITE}Messages:${NC}    ${OPUS_MSGS:-0}"
    echo -e "  ${WHITE}Input:${NC}       ${OPUS_INPUT:-0} tokens"
    echo -e "  ${WHITE}Output:${NC}      ${OPUS_OUTPUT:-0} tokens"
    echo -e "  ${BLUE}Dashboard:${NC}   https://console.anthropic.com/settings/usage"
    echo ""
    
    # Claude Sonnet Section
    echo -e "${YELLOW}▶ Claude Sonnet (Anthropic)${NC} ${DIM}- 5 hour limit${NC}"
    echo -e "  ${WHITE}Messages:${NC}    ${SONNET_MSGS:-0}"
    echo -e "  ${WHITE}Input:${NC}       ${SONNET_INPUT:-0} tokens"
    echo -e "  ${WHITE}Output:${NC}      ${SONNET_OUTPUT:-0} tokens"
    echo ""
    
    # GLM-5 Section
    if [ "${GLM_AGENTS:-0}" -gt 0 ]; then
        COLOR="$GREEN"
        STATUS="${GREEN}✓ ENABLED${NC}"
    else
        COLOR="$RED"
        STATUS="${RED}✗ DISABLED${NC} (quota exhausted)"
    fi
    
    echo -e "${COLOR}▶ GLM-5 (Zhipu AI)${NC} ${DIM}- Weekly quota${NC}"
    echo -e "  ${WHITE}Messages:${NC}    ${GLM_MSGS:-0}"
    echo -e "  ${WHITE}Input:${NC}       ${GLM_INPUT:-0} tokens"
    echo -e "  ${WHITE}Output:${NC}      ${GLM_OUTPUT:-0} tokens"
    echo -e "  ${WHITE}Status:${NC}      $STATUS"
    if [ "${GLM_AGENTS:-0}" -eq 0 ]; then
        echo -e "  ${YELLOW}Switch back:${NC} ${DIM}./switch_models.sh glm${NC}"
    fi
    echo -e "  ${BLUE}Dashboard:${NC}   https://open.bigmodel.cn/overview"
    echo ""
    
    # Summary box
    draw_box "TOTAL USAGE" "$BLUE" \
        "Messages: ${TOTAL_MSGS:-0}" \
        "Total Cost: ${TOTAL_COST:-\$0.00}" \
        "" \
        "Check provider dashboards for exact limits"
    
    echo ""
    
    # Controls
    echo -e "${DIM}Controls:${NC} ${GREEN}Ctrl+C${NC} to exit"
    echo ""
}

# Main loop
main() {
    clear
    echo -e "${BLUE}Starting Live Dashboard...${NC}"
    sleep 1
    
    while true; do
        fetch_real_stats
        draw_dashboard
        sleep 10
    done
}

# Run
main