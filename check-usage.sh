#!/bin/bash
#
# Usage Monitor for OpenCode Framework
# Reads usage from OpenCode saved configuration
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         OPENCODE USAGE MONITOR                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check OpenCode CLI for usage command
echo -e "${BLUE}🔍 Checking OpenCode saved configuration...${NC}"
echo ""

# Check if opencode has usage data
if command -v opencode > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OpenCode CLI detected${NC}"
    
    # Try to get usage from opencode
    if opencode help 2>/dev/null | grep -q usage; then
        echo -e "${GREEN}✓ Running: opencode usage${NC}"
        echo ""
        opencode usage 2>/dev/null || echo -e "${YELLOW}⚠️  Could not fetch usage automatically${NC}"
    else
        echo -e "${YELLOW}⚠️  Usage command not available in OpenCode CLI${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  OpenCode CLI not in PATH${NC}"
fi

echo ""

# Show current model distribution
echo -e "${BLUE}📊 Current Model Distribution:${NC}"
echo ""

# Count agents by model
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/.opencode/agents"

if [ -d "$AGENTS_DIR" ]; then
    KIMI_COUNT=$(grep -l "model: kimi-for-coding/k2p5" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
    GLM_COUNT=$(grep -l "model: zai-coding-plan/glm-5" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
    OPUS_COUNT=$(grep -l "model: anthropic/claude-opus-4-6" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
    SONNET_COUNT=$(grep -l "model: anthropic/claude-sonnet-4-6" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
    
    echo -e "  ${GREEN}Kimi K2.5:${NC}     $KIMI_COUNT agents"
    echo -e "  ${GREEN}GLM-5:${NC}         $GLM_COUNT agents"
    echo -e "  ${GREEN}Claude Opus:${NC}   $OPUS_COUNT agents (critical only)"
    echo -e "  ${GREEN}Claude Sonnet:${NC} $SONNET_COUNT agents (debuggers)"
    echo ""
    
    if [ "$GLM_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  GLM-5 agents temporarily disabled${NC}"
        echo -e "   (Quota exhausted - resets tomorrow)"
        echo ""
    fi
fi

# Manual usage check links
echo -e "${BLUE}🔗 Check Your Usage:${NC}"
echo ""
echo -e "${GREEN}Claude (Anthropic):${NC}"
echo -e "  ${BLUE}https://console.anthropic.com/settings/usage${NC}"
echo -e "  ${YELLOW}5-hour limit / 30-day rolling${NC}"
echo ""

echo -e "${GREEN}Kimi (Moonshot AI):${NC}"
echo -e "  ${BLUE}https://platform.moonshot.cn/console/usage${NC}"
echo -e "  ${YELLOW}5-hour weekly limit${NC}"
echo ""

echo -e "${GREEN}GLM-5 (Zhipu AI):${NC}"
echo -e "  ${BLUE}https://open.bigmodel.cn/overview${NC}"
echo -e "  ${YELLOW}Weekly quota${NC}"
echo ""

# Switch instructions
echo -e "${BLUE}🔄 Switch Models:${NC}"
echo ""
echo -e "  ${BLUE}./switch_models.sh glm${NC}  - Enable GLM-5 (cheapest)"
echo -e "  ${BLUE}./switch_models.sh kimi${NC} - Enable Kimi (balanced)"
echo ""

# Recommendations
echo -e "${BLUE}💡 Recommendations:${NC}"
echo ""

if [ "${GLM_COUNT:-0}" -eq 0 ]; then
    echo -e "Current: ${YELLOW}All agents using Kimi (GLM-5 out of quota)${NC}"
    echo -e "  • Kimi costs: ~\$2-3 per million tokens"
    echo -e "  • GLM-5 costs: ~\$0.50-1 per million tokens"
    echo -e "  • Switch to GLM-5 tomorrow for ${GREEN}60% cost savings${NC}"
else
    echo -e "Current: ${GREEN}Optimal setup with GLM-5 available${NC}"
    echo -e "  • GLM-5: Validation tasks (${GREEN}cheapest${NC})"
    echo -e "  • Kimi: Implementation (${GREEN}balanced${NC})"
    echo -e "  • Opus: Critical decisions only (${YELLOW}expensive${NC})"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Quick status check
echo -e "${BLUE}⚡ Quick Status:${NC}"
echo ""

# Check if any usage files exist
OPENCODE_DB="$HOME/.local/share/opencode/opencode.db"
if [ -f "$OPENCODE_DB" ]; then
    echo -e "${GREEN}✓${NC} OpenCode database found"
    echo -e "  Location: ${BLUE}$OPENCODE_DB${NC}"
    
    # Try to query usage from SQLite if possible
    if command -v sqlite3 > /dev/null 2>&1; then
        echo -e "  ${YELLOW}Usage data stored in SQLite database${NC}"
        echo -e "  ${YELLOW}(Query with: sqlite3 $OPENCODE_DB)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️${NC} OpenCode database not found at expected location"
fi

echo ""
echo -e "${BLUE}For detailed usage, check provider dashboards above${NC}"
echo ""

# Model switcher location
if [ -f "$SCRIPT_DIR/.opencode/agents/switch_models.sh" ]; then
    echo -e "${BLUE}Model switcher:${NC} ${GREEN}$SCRIPT_DIR/.opencode/agents/switch_models.sh${NC}"
fi

echo ""