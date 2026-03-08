#!/bin/bash
# Script to switch between GLM-5 and Kimi models
# Usage: ./switch_models.sh [glm|kimi]

if [ "$1" = "glm" ]; then
    echo "Switching to GLM-5..."
    find . -name "*.md" -type f -exec sed -i '' 's/model: kimi-for-coding\/k2p5$/model: zai-coding-plan\/glm-5/g' {} \;
    echo "✅ Switched to GLM-5"
elif [ "$1" = "kimi" ]; then
    echo "Switching to Kimi K2.5..."
    find . -name "*.md" -type f -exec sed -i '' 's/model: zai-coding-plan\/glm-5$/model: kimi-for-coding\/k2p5/g' {} \;
    echo "✅ Switched to Kimi K2.5"
else
    echo "Usage: ./switch_models.sh [glm|kimi]"
    echo "  glm  - Switch to GLM-5 (tomorrow)"
    echo "  kimi - Switch to Kimi K2.5 (today)"
    exit 1
fi