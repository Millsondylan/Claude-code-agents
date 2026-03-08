#!/bin/bash
#
# Fetch REAL usage limits from provider dashboards
# Uses browser cookies/session data if available
#

# Config
CONFIG_DIR="$HOME/.opencode"
CONFIG_FILE="$CONFIG_DIR/real-limits.conf"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "Fetching REAL usage limits from providers..."
echo ""

# Method 1: Try to extract from browser cookies/session
# This checks if user is logged into browsers

echo -e "${BLUE}Method 1: Checking browser sessions...${NC}"

# Check Chrome/Chromium cookies for Anthropic
if [ -f "$HOME/Library/Application Support/Google/Chrome/Default/Cookies" ]; then
    echo "  Chrome cookies found - could extract session (requires sqlite3)"
    # Note: This requires decryption which is complex
fi

# Method 2: Check if opencode has stored usage data
echo ""
echo -e "${BLUE}Method 2: Checking OpenCode internal data...${NC}"

OPENCODE_DB="$HOME/.local/share/opencode/opencode.db"
if [ -f "$OPENCODE_DB" ]; then
    echo "  OpenCode database found"
    
    # Try to query for any usage/limit data
    if command -v sqlite3 > /dev/null; then
        echo "  Checking for limit data in database..."
        
        # Look for any tables that might have usage data
        TABLES=$(sqlite3 "$OPENCODE_DB" ".tables" 2>/dev/null)
        echo "  Available tables: $TABLES"
        
        # Check each table for usage-related columns
        for table in $TABLES; do
            SCHEMA=$(sqlite3 "$OPENCODE_DB" "PRAGMA table_info($table);" 2>/dev/null)
            if echo "$SCHEMA" | grep -qi "usage\|limit\|quota\|remaining"; then
                echo "  Found potential usage table: $table"
                sqlite3 "$OPENCODE_DB" "SELECT * FROM $table LIMIT 5;" 2>/dev/null
            fi
        done
    fi
fi

# Method 3: Manual input from user
echo ""
echo -e "${YELLOW}Method 3: Manual input from dashboards${NC}"
echo ""
echo "Since automatic extraction is limited by provider APIs,"
echo "please visit these dashboards and enter your remaining limits:"
echo ""

mkdir -p "$CONFIG_DIR"

# Claude
echo -e "${BLUE}1. Claude (Anthropic)${NC}"
echo "   URL: https://console.anthropic.com/settings/usage"
echo "   Look for: 'Remaining' or usage bar"
read -p "   Remaining hours: " anthropic_hours
read -p "   Remaining minutes: " anthropic_mins
ANTHROPIC_TOTAL=$((anthropic_hours * 60 + anthropic_mins))

# Kimi
echo ""
echo -e "${BLUE}2. Kimi (Moonshot AI)${NC}"
echo "   URL: https://platform.moonshot.cn/console/usage"
echo "   Look for: '剩余时间' (remaining time)"
read -p "   Remaining hours: " kimi_hours
read -p "   Remaining minutes: " kimi_mins
KIMI_TOTAL=$((kimi_hours * 60 + kimi_mins))

# GLM
echo ""
echo -e "${BLUE}3. GLM-5 (Zhipu AI)${NC}"
echo "   URL: https://open.bigmodel.cn/overview"
echo "   Look for: remaining quota"
read -p "   Remaining hours: " glm_hours
read -p "   Remaining minutes: " glm_mins
GLM_TOTAL=$((glm_hours * 60 + glm_mins))

# Save config
cat > "$CONFIG_FILE" << EOF
# Real Usage Limits
# Updated: $(date)
# Source: Manual input from provider dashboards

ANTHROPIC_LIMIT_MINUTES=$ANTHROPIC_TOTAL
KIMI_LIMIT_MINUTES=$KIMI_TOTAL
GLM_LIMIT_MINUTES=$GLM_TOTAL

LAST_UPDATED=$(date +%s)
EOF

chmod 600 "$CONFIG_FILE"

echo ""
echo -e "${GREEN}✓ Real limits saved!${NC}"
echo ""
echo "Saved to: $CONFIG_FILE"
echo ""
echo "You can now run: ./usage-dashboard.sh"
echo "It will show your ACTUAL percentage remaining!"