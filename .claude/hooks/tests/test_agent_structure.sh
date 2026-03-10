#!/bin/bash
# Verification script for agent structure and rules
#
# Confirms:
# (a) All agent .md files in .opencode/agents/ contain "Anti-Orchestration" or "NEVER use the Task tool"
# (b) 03-agent-dispatch.md contains "Anti-Orchestration Rules"
# (c) 04-evaluation-and-context.md contains "Anti-Orchestration Rules"
#
# Run: bash .claude/hooks/tests/test_agent_structure.sh
# Or via: bash .claude/hooks/tests/run_all_tests.sh

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/.opencode/agents"
RULES_DIR="$PROJECT_ROOT/.opencode/rules"

FAILED=0
PASSED=0

# (a) All agent files contain Anti-Orchestration or NEVER use the Task tool
echo "--- Agent files: Anti-Orchestration / NEVER use the Task tool ---"
MISSING=()
for f in "$AGENTS_DIR"/*.md; do
    [ -f "$f" ] || continue
    if grep -qE 'Anti-Orchestration|NEVER use the Task tool' "$f" 2>/dev/null; then
        PASSED=$((PASSED + 1))
    else
        MISSING+=("$(basename "$f")")
        echo -e "${RED}FAIL${NC}: $(basename "$f") - missing required content"
        FAILED=$((FAILED + 1))
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    AGENT_COUNT=$(find "$AGENTS_DIR" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
    echo -e "${GREEN}PASS${NC}: All $AGENT_COUNT agent files contain required content"
fi

echo ""

# (b) 03-agent-dispatch.md contains "Anti-Orchestration Rules"
echo "--- 03-agent-dispatch.md: Anti-Orchestration Rules ---"
DISPATCH_FILE="$RULES_DIR/03-agent-dispatch.md"
if [ -f "$DISPATCH_FILE" ]; then
    if grep -q "Anti-Orchestration Rules" "$DISPATCH_FILE" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: 03-agent-dispatch.md contains 'Anti-Orchestration Rules'"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: 03-agent-dispatch.md missing 'Anti-Orchestration Rules'"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC}: 03-agent-dispatch.md not found"
    FAILED=$((FAILED + 1))
fi

echo ""

# (c) 04-evaluation-and-context.md contains "Anti-Orchestration Rules"
echo "--- 04-evaluation-and-context.md: Anti-Orchestration Rules ---"
EVAL_FILE="$RULES_DIR/04-evaluation-and-context.md"
if [ -f "$EVAL_FILE" ]; then
    if grep -q "Anti-Orchestration Rules" "$EVAL_FILE" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}: 04-evaluation-and-context.md contains 'Anti-Orchestration Rules'"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: 04-evaluation-and-context.md missing 'Anti-Orchestration Rules'"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "${RED}FAIL${NC}: 04-evaluation-and-context.md not found"
    FAILED=$((FAILED + 1))
fi

echo ""
echo "=========================================="
echo "Agent Structure Verification Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    exit 1
fi
exit 0
