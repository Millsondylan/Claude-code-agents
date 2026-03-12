#!/bin/bash
# Run 1 Migration Tests (F1–F5)
#
# Validates migration from Claude/Anthropic to Kimi K2.5:
# - F1: plan-agent.md model → alibaba-coding-plan/kimi-k2.5
# - F2: .ai/README.md Claude→Kimi K2.5
# - F3: rules (03-agent-dispatch.md, 05-operational-policies.md) contain Kimi K2.5 context/token specs
# - F4: generate-agents.sh PROVIDER_PRIMARY, is_primary_agent, map_model
# - F5: opencode.json model and small_model
#
# NO mocks, NO placeholders. Real file content assertions.
#
# Run: bash scripts/tests/test_run1_migration.sh
# Or:  bash scripts/tests/test_run1_migration.sh (from project root)

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OPENCODE_DIR="${PROJECT_ROOT}/.opencode"
AI_DIR="${PROJECT_ROOT}/.ai"
RULES_DIR="${OPENCODE_DIR}/rules"

run_test() {
    local test_name="$1"
    TOTAL=$((TOTAL + 1))
    if eval "$2"; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: $test_name"
        echo "    $3"
        FAILED=$((FAILED + 1))
    fi
}

# ---------------------------------------------------------------------------
# F1: plan-agent.md model → alibaba-coding-plan/kimi-k2.5
# ---------------------------------------------------------------------------

test_f1_plan_agent_contains_kimi_model() {
    local file="${OPENCODE_DIR}/agents/plan-agent.md"
    [[ -f "$file" ]] || return 1
    grep -q 'model: alibaba-coding-plan/kimi-k2.5' "$file"
}

test_f1_plan_agent_no_anthropic_claude() {
    local file="${OPENCODE_DIR}/agents/plan-agent.md"
    [[ -f "$file" ]] || return 1
    ! grep -qE 'anthropic|claude-opus' "$file"
}

# ---------------------------------------------------------------------------
# F2: .ai/README.md contains Kimi K2.5, not Claude Opus 4.6
# ---------------------------------------------------------------------------

test_f2_ai_readme_contains_kimi_k25() {
    local file="${AI_DIR}/README.md"
    [[ -f "$file" ]] || return 1
    grep -q 'Kimi K2.5' "$file"
}

test_f2_ai_readme_no_claude_opus_46() {
    local file="${AI_DIR}/README.md"
    [[ -f "$file" ]] || return 1
    ! grep -q 'Claude Opus 4.6' "$file"
}

# ---------------------------------------------------------------------------
# F3: rules contain Kimi K2.5 context/token specs
# ---------------------------------------------------------------------------

test_f3_agent_dispatch_contains_kimi_reference() {
    local file="${RULES_DIR}/03-agent-dispatch.md"
    [[ -f "$file" ]] || return 1
    grep -qE 'alibaba-coding-plan/kimi-k2.5|Kimi K2.5' "$file"
}

test_f3_operational_policies_contains_kimi_context_specs() {
    local file="${RULES_DIR}/05-operational-policies.md"
    [[ -f "$file" ]] || return 1
    grep -q 'KIMI K2.5' "$file"
}

test_f3_operational_policies_contains_context_window() {
    local file="${RULES_DIR}/05-operational-policies.md"
    [[ -f "$file" ]] || return 1
    grep -qE '256K|256k|context window' "$file"
}

# ---------------------------------------------------------------------------
# F4: generate-agents.sh
# ---------------------------------------------------------------------------

test_f4_generate_agents_bash_syntax() {
    local file="${OPENCODE_DIR}/generate-agents.sh"
    [[ -f "$file" ]] || return 1
    bash -n "$file" 2>/dev/null
}

test_f4_provider_primary_is_kimi() {
    local file="${OPENCODE_DIR}/generate-agents.sh"
    [[ -f "$file" ]] || return 1
    grep -q 'PROVIDER_PRIMARY="alibaba-coding-plan/kimi-k2.5"' "$file"
}

test_f4_has_is_primary_agent() {
    local file="${OPENCODE_DIR}/generate-agents.sh"
    [[ -f "$file" ]] || return 1
    grep -q 'is_primary_agent()' "$file"
}

test_f4_has_map_model() {
    local file="${OPENCODE_DIR}/generate-agents.sh"
    [[ -f "$file" ]] || return 1
    grep -q 'map_model()' "$file"
}

# ---------------------------------------------------------------------------
# F5: opencode.json
# ---------------------------------------------------------------------------

test_f5_opencode_json_valid() {
    local file="${OPENCODE_DIR}/opencode.json"
    [[ -f "$file" ]] || return 1
    python3 -m json.tool "$file" >/dev/null 2>&1
}

test_f5_opencode_json_model_is_kimi() {
    local file="${OPENCODE_DIR}/opencode.json"
    [[ -f "$file" ]] || return 1
    grep -q '"model": "alibaba-coding-plan/kimi-k2.5"' "$file"
}

test_f5_opencode_json_small_model_is_kimi() {
    local file="${OPENCODE_DIR}/opencode.json"
    [[ -f "$file" ]] || return 1
    grep -q '"small_model": "alibaba-coding-plan/kimi-k2.5"' "$file"
}

# ---------------------------------------------------------------------------
# Migration integrity: migrated files have minimal/no anthropic/claude-opus
# ---------------------------------------------------------------------------

test_migrated_files_no_anthropic() {
    local count=0
    for f in "${OPENCODE_DIR}/agents/plan-agent.md" "${AI_DIR}/README.md" \
             "${RULES_DIR}/03-agent-dispatch.md" "${RULES_DIR}/05-operational-policies.md" \
             "${OPENCODE_DIR}/opencode.json"; do
        [[ -f "$f" ]] || continue
        if grep -q 'anthropic' "$f" 2>/dev/null; then
            count=$((count + 1))
        fi
    done
    [[ $count -eq 0 ]]
}

test_migrated_files_no_claude_opus() {
    local count=0
    for f in "${OPENCODE_DIR}/agents/plan-agent.md" "${AI_DIR}/README.md" \
             "${RULES_DIR}/03-agent-dispatch.md" "${RULES_DIR}/05-operational-policies.md" \
             "${OPENCODE_DIR}/opencode.json"; do
        [[ -f "$f" ]] || continue
        if grep -q 'claude-opus' "$f" 2>/dev/null; then
            count=$((count + 1))
        fi
    done
    [[ $count -eq 0 ]]
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=========================================="
echo "Run 1 Migration Tests (F1–F5)"
echo "=========================================="
echo ""

run_test "F1: plan-agent.md contains alibaba-coding-plan/kimi-k2.5" \
    test_f1_plan_agent_contains_kimi_model \
    "Expected model: alibaba-coding-plan/kimi-k2.5 in plan-agent.md"

run_test "F1: plan-agent.md has no anthropic/claude-opus" \
    test_f1_plan_agent_no_anthropic_claude \
    "Migrated plan-agent.md should not reference anthropic or claude-opus"

run_test "F2: .ai/README.md contains Kimi K2.5" \
    test_f2_ai_readme_contains_kimi_k25 \
    "Expected 'Kimi K2.5' in .ai/README.md"

run_test "F2: .ai/README.md does not contain Claude Opus 4.6" \
    test_f2_ai_readme_no_claude_opus_46 \
    "Migrated ACM should not reference Claude Opus 4.6"

run_test "F3: 03-agent-dispatch.md contains Kimi K2.5 reference" \
    test_f3_agent_dispatch_contains_kimi_reference \
    "Rules should document Kimi K2.5 model"

run_test "F3: 05-operational-policies.md contains KIMI K2.5 section" \
    test_f3_operational_policies_contains_kimi_context_specs \
    "Rules should have KIMI K2.5 context/token section"

run_test "F3: 05-operational-policies.md contains context window spec" \
    test_f3_operational_policies_contains_context_window \
    "Rules should document 256K context window"

run_test "F4: generate-agents.sh passes bash -n" \
    test_f4_generate_agents_bash_syntax \
    "generate-agents.sh must have valid bash syntax"

run_test "F4: PROVIDER_PRIMARY is alibaba-coding-plan/kimi-k2.5" \
    test_f4_provider_primary_is_kimi \
    "PROVIDER_PRIMARY must be alibaba-coding-plan/kimi-k2.5"

run_test "F4: generate-agents.sh has is_primary_agent function" \
    test_f4_has_is_primary_agent \
    "Script must define is_primary_agent()"

run_test "F4: generate-agents.sh has map_model function" \
    test_f4_has_map_model \
    "Script must define map_model()"

run_test "F5: opencode.json is valid JSON" \
    test_f5_opencode_json_valid \
    "opencode.json must parse as valid JSON"

run_test "F5: opencode.json model is alibaba-coding-plan/kimi-k2.5" \
    test_f5_opencode_json_model_is_kimi \
    "model field must be alibaba-coding-plan/kimi-k2.5"

run_test "F5: opencode.json small_model is alibaba-coding-plan/kimi-k2.5" \
    test_f5_opencode_json_small_model_is_kimi \
    "small_model field must be alibaba-coding-plan/kimi-k2.5"

run_test "Migration: migrated files have no anthropic references" \
    test_migrated_files_no_anthropic \
    "Migrated files should not contain 'anthropic'"

run_test "Migration: migrated files have no claude-opus references" \
    test_migrated_files_no_claude_opus \
    "Migrated files should not contain 'claude-opus'"

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Total:  $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All migration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
