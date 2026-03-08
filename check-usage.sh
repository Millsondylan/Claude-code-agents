#!/bin/bash
#
# REAL Usage Monitor for OpenCode Framework
# Shows actual token usage from OpenCode stats
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get real stats from opencode
get_opencode_stats() {
    echo -e "${BLUE}🔍 Fetching real usage data from OpenCode...${NC}"
    echo ""
    
    # Run opencode stats with models flag
    opencode stats --models 2>/dev/null | tee /tmp/opencode_stats.txt
    
    echo ""
}

# Parse and display current model distribution
show_model_distribution() {
    echo -e "${BLUE}📊 Framework Model Distribution:${NC}"
    echo ""
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    AGENTS_DIR="$SCRIPT_DIR/.opencode/agents"
    
    if [ -d "$AGENTS_DIR" ]; then
        KIMI_COUNT=$(grep -l "model: kimi-for-coding/k2p5" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        GLM_COUNT=$(grep -l "model: zai-coding-plan/glm-5" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        OPUS_COUNT=$(grep -l "model: anthropic/claude-opus-4-6" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        SONNET_COUNT=$(grep -l "model: anthropic/claude-sonnet-4-6" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
        
        echo -e "  ${CYAN}Kimi K2.5:${NC}     $KIMI_COUNT agents"
        echo -e "  ${CYAN}GLM-5:${NC}         $GLM_COUNT agents"
        echo -e "  ${CYAN}Claude Opus:${NC}   $OPUS_COUNT agents"
        echo -e "  ${CYAN}Claude Sonnet:${NC} $SONNET_COUNT agents"
        
        if [ "$GLM_COUNT" -eq 0 ]; then
            echo ""
            echo -e "  ${YELLOW}⚠️  GLM-5 temporarily disabled (quota exhausted)${NC}"
        fi
    fi
    
    echo ""
}

# Show usage summary from stats
show_usage_summary() {
    if [ -f /tmp/opencode_stats.txt ]; then
        echo -e "${BLUE}📈 Summary from OpenCode Stats:${NC}"
        echo ""
        
        # Extract key metrics
        local sessions=$(grep "Sessions" /tmp/opencode_stats.txt | awk '{print $2}')
        local messages=$(grep "Messages" /tmp/opencode_stats.txt | head -1 | awk '{print $2}')
        local total_cost=$(grep "Total Cost" /tmp/opencode_stats.txt | awk '{print $2}')
        
        echo -e "  Total Sessions: ${CYAN}$sessions${NC}"
        echo -e "  Total Messages: ${CYAN}$messages${NC}"
        echo -e "  Total Cost: ${CYAN}$total_cost${NC}"
        echo ""
    fi
}

# Show provider dashboard links
show_dashboards() {
    echo -e "${BLUE}🔗 Provider Dashboards (Check Limits):${NC}"
    echo ""
    
    echo -e "${GREEN}Claude (Anthropic):${NC}"
    echo -e "  ${BLUE}https://console.anthropic.com/settings/usage${NC}"
    echo -e "  ${YELLOW}5-hour weekly limit${NC}"
    echo ""
    
    echo -e "${GREEN}Kimi (Moonshot AI):${NC}"
    echo -e "  ${BLUE}https://platform.moonshot.cn/console/usage${NC}"
    echo -e "  ${YELLOW}5-hour weekly limit${NC}"
    echo ""
    
    echo -e "${GREEN}GLM-5 (Zhipu AI):${NC}"
    echo -e "  ${BLUE}https://open.bigmodel.cn/overview${NC}"
    echo -e "  ${YELLOW}Weekly quota${NC}"
    echo ""
}

# Show switch options
show_switch_options() {
    echo -e "${BLUE}🔄 Switch Models:${NC}"
    echo ""
    
    if [ -f "$SCRIPT_DIR/.opencode/agents/switch_models.sh" ]; then
        echo -e "  ${GREEN}cd .opencode/agents${NC}"
        echo -e "  ${GREEN}./switch_models.sh glm${NC}  - Use GLM-5 (cheapest)"
        echo -e "  ${GREEN}./switch_models.sh kimi${NC} - Use Kimi (balanced)"
    else
        echo -e "  ${YELLOW}Switch script not found${NC}"
    fi
    
    echo ""
}

# Main display
main() {
    clear
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         OPENCODE REAL USAGE MONITOR                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get real stats
    get_opencode_stats
    
    # Show summary
    show_usage_summary
    
    # Show model distribution
    show_model_distribution
    
    # Show dashboards
    show_dashboards
    
    # Show switch options
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    show_switch_options
    
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}To refresh:${NC} ./check-usage.sh"
    echo ""
}

# Run
main