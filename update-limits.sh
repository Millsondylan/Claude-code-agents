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
