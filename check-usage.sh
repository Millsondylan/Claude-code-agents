#!/bin/bash
#
# Usage Monitor CLI for OpenCode Framework
# Checks remaining usage from all connected providers
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config file location
CONFIG_FILE="$HOME/.opencode/usage-config.conf"

# Load config if exists
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Check OpenAI Usage
check_openai() {
    local api_key="${OPENAI_API_KEY:-}"
    
    echo -e "${BLUE}🔍 OpenAI (ChatGPT):${NC}"
    
    if [ -z "$api_key" ]; then
        echo -e "  ${YELLOW}⚠️  API key not configured${NC}"
        echo -e "    Run: ${BLUE}./check-usage.sh --setup${NC}"
    else
        echo -e "  ${GREEN}✓ API key configured${NC}"
        echo -e "    ${YELLOW}ℹ️  Check dashboard for usage:${NC}"
        echo -e "    ${BLUE}https://platform.openai.com/usage${NC}"
        
        # Note: OpenAI requires specific billing API access
        # which varies by account type
    fi
    echo ""
}

# Check Anthropic (Claude) Usage
check_anthropic() {
    local api_key="${ANTHROPIC_API_KEY:-}"
    
    echo -e "${BLUE}🔍 Anthropic (Claude):${NC}"
    
    if [ -z "$api_key" ]; then
        echo -e "  ${YELLOW}⚠️  API key not configured${NC}"
        echo -e "    Run: ${BLUE}./check-usage.sh --setup${NC}"
    else
        echo -e "  ${GREEN}✓ API key configured${NC}"
        echo -e "    ${YELLOW}ℹ️  Check console for usage:${NC}"
        echo -e "    ${BLUE}https://console.anthropic.com/${NC}"
        echo -e "    ${YELLOW}ℹ️  Note: Anthropic doesn't have public usage API yet${NC}"
    fi
    echo ""
}

# Check Kimi Usage
check_kimi() {
    local api_key="${KIMI_API_KEY:-}"
    
    echo -e "${BLUE}🔍 Kimi (Moonshot AI):${NC}"
    
    if [ -z "$api_key" ]; then
        echo -e "  ${YELLOW}⚠️  API key not configured${NC}"
        echo -e "    Run: ${BLUE}./check-usage.sh --setup${NC}"
    else
        echo -e "  ${GREEN}✓ API key configured${NC}"
        echo -e "    ${YELLOW}ℹ️  Check platform for usage:${NC}"
        echo -e "    ${BLUE}https://platform.moonshot.cn/${NC}"
        echo -e "    ${YELLOW}ℹ️  5-hour weekly limit applies${NC}"
    fi
    echo ""
}

# Check GLM-5 Usage
check_glm() {
    local api_key="${GLM_API_KEY:-}"
    
    echo -e "${BLUE}🔍 GLM-5 (Zhipu AI):${NC}"
    
    if [ -z "$api_key" ]; then
        echo -e "  ${YELLOW}⚠️  API key not configured${NC}"
        echo -e "    Run: ${BLUE}./check-usage.sh --setup${NC}"
    else
        echo -e "  ${GREEN}✓ API key configured${NC}"
        echo -e "    ${YELLOW}ℹ️  Check platform for usage:${NC}"
        echo -e "    ${BLUE}https://open.bigmodel.cn/${NC}"
        echo -e "    ${YELLOW}ℹ️  Weekly quota applies${NC}"
    fi
    echo ""
}

# Show manual check instructions
show_manual_check() {
    echo -e "${BLUE}📊 Manual Usage Check:${NC}"
    echo ""
    echo "Since most providers don't have public usage APIs,"
    echo "you'll need to check manually:"
    echo ""
    
    echo -e "1. ${GREEN}OpenAI:${NC}      https://platform.openai.com/usage"
    echo -e "2. ${GREEN}Anthropic:${NC}   https://console.anthropic.com/"
    echo -e "3. ${GREEN}Kimi:${NC}         https://platform.moonshot.cn/"
    echo -e "4. ${GREEN}GLM-5:${NC}        https://open.bigmodel.cn/"
    echo ""
}

# Show recommendations
show_recommendations() {
    echo -e "${BLUE}🎯 Current Model Strategy:${NC}"
    echo ""
    
    # Check current model assignment
    local kimi_count=$(grep -r "model: kimi-for-coding/k2p5" .opencode/agents/*.md 2>/dev/null | wc -l)
    local glm_count=$(grep -r "model: zai-coding-plan/glm-5" .opencode/agents/*.md 2>/dev/null | wc -l)
    
    echo -e "Active model distribution:"
    echo -e "  ${GREEN}• Kimi K2.5:${NC} ${kimi_count} agents"
    echo -e "  ${GREEN}• GLM-5:${NC}     ${glm_count} agents"
    echo -e "  ${GREEN}• Opus:${NC}      3 agents (critical only)"
    echo ""
    
    if [ "$glm_count" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  GLM-5 temporarily disabled (quota exhausted)${NC}"
        echo ""
        echo -e "To switch back to GLM-5 tomorrow:"
        echo -e "  ${BLUE}./switch_models.sh glm${NC}"
    else
        echo -e "${GREEN}✓ GLM-5 active (cheap option)${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}💡 Recommendations:${NC}"
    echo ""
    
    if [ "$glm_count" -eq 0 ]; then
        echo -e "Current setup (GLM-5 out of quota):"
        echo -e "  • All agents using Kimi K2.5 (moderate cost)"
        echo -e "  • Switch to GLM-5 tomorrow for cost savings"
    else
        echo -e "Optimal setup (all providers available):"
        echo -e "  • GLM-5: Validation, simple tasks (${GREEN}cheapest${NC})"
        echo -e "  • Kimi: Most coding tasks (${GREEN}balanced${NC})"
        echo -e "  • Opus: plan-agent, review-agent, debugger-11 only"
    fi
    
    echo ""
    echo -e "To change models:"
    echo -e "  ${BLUE}./switch_models.sh glm${NC}  - Use GLM-5 agents"
    echo -e "  ${BLUE}./switch_models.sh kimi${NC} - Use Kimi agents"
}

# Show quick status
show_quick_status() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         USAGE MONITOR - QUICK STATUS          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Setup wizard
setup_wizard() {
    echo "🔧 Usage Monitor Setup"
    echo ""
    echo "This will create a config file at:"
    echo "  $CONFIG_FILE"
    echo ""
    echo "Note: API keys are stored locally and never transmitted."
    echo ""
    
    mkdir -p "$HOME/.opencode"
    
    read -p "OpenAI API Key (sk-...): " openai_key
    read -p "Anthropic API Key (sk-ant-...): " anthropic_key
    read -p "Kimi API Key: " kimi_key
    read -p "GLM-5 API Key: " glm_key
    
    cat > "$CONFIG_FILE" << EOF
# OpenCode Usage Monitor Config
# Generated: $(date)

# OpenAI (ChatGPT) - Used for some agents
OPENAI_API_KEY="${openai_key}"

# Anthropic (Claude) - Used for critical decisions
ANTHROPIC_API_KEY="${anthropic_key}"

# Kimi (Moonshot AI) - 5hr weekly limit
KIMI_API_KEY="${kimi_key}"

# GLM-5 (Zhipu AI) - Weekly quota
GLM_API_KEY="${glm_key}"
EOF
    
    chmod 600 "$CONFIG_FILE"
    echo ""
    echo -e "${GREEN}✅ Config saved!${NC}"
    echo ""
    echo -e "File location: ${BLUE}$CONFIG_FILE${NC}"
    echo -e "Permissions: ${BLUE}600 (owner only)${NC}"
    echo ""
    echo "You can now run: ./check-usage.sh"
}

# Main function
main() {
    case "${1:-}" in
        --setup|-s)
            setup_wizard
            exit 0
            ;;
        --help|-h)
            echo "Usage Monitor for OpenCode Framework"
            echo ""
            echo "Usage: ./check-usage.sh [options]"
            echo ""
            echo "Options:"
            echo "  --setup, -s     Configure API keys"
            echo "  --help, -h      Show this help"
            echo ""
            echo "Checks configured AI providers and shows usage status."
            echo ""
            echo "Examples:"
            echo "  ./check-usage.sh --setup    # First time setup"
            echo "  ./check-usage.sh            # Check all providers"
            echo ""
            exit 0
            ;;
    esac
    
    # Load config
    load_config
    
    # Show header
    show_quick_status
    
    # Check each provider
    check_openai
    check_anthropic
    check_kimi
    check_glm
    
    # Show manual check info
    show_manual_check
    
    # Show current setup and recommendations
    show_recommendations
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
}

# Run main
main "$@"