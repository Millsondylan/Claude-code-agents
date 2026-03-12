#!/bin/bash
# Integration tests for sync-opencode-run2.sh
#
# Verifies that sync-opencode-run2.sh:
# - F1: Target .opencode/agents/ has same .md count as source (or 84)
# - F2: Target .opencode/rules/ has 7 rule files
# - F3: Target opencode.json contains alibaba-coding-plan/kimi-k2.5
# - F4: Target .opencode/package.json and bun.lock preserved (unchanged after sync)
# - F5: Script fails when target missing; fails when target equals source
# - Integrity: opencode.json is valid JSON after sync
#
# Uses a temporary directory as target. No mocks. Real file operations.
#
# Run: bash scripts/tests/test_sync_opencode_run2.sh
# Or:  bash scripts/tests/test_sync_opencode_run2.sh (from project root)

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC_SCRIPT="${PROJECT_ROOT}/scripts/sync-opencode-run2.sh"
SOURCE_OPENCODE="${PROJECT_ROOT}/.opencode"

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
# F1: After sync, target .opencode/agents/ has same .md count as source
# ---------------------------------------------------------------------------

test_f1_agents_md_count_matches_source() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        local src_count target_count
        src_count=$(find "$SOURCE_OPENCODE/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        target_count=$(find "$tmpdir/.opencode/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        [[ "$target_count" -eq "$src_count" ]]
    )
}

# ---------------------------------------------------------------------------
# F2: After sync, target .opencode/rules/ has 7 rule files
# ---------------------------------------------------------------------------

test_f2_rules_count_is_seven() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        local count
        count=$(find "$tmpdir/.opencode/rules" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        [[ "$count" -eq 7 ]]
    )
}

# ---------------------------------------------------------------------------
# F3: After sync, target opencode.json contains alibaba-coding-plan/kimi-k2.5
# ---------------------------------------------------------------------------

test_f3_opencode_json_contains_kimi() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        grep -q 'alibaba-coding-plan/kimi-k2.5' "$tmpdir/.opencode/opencode.json"
    )
}

# ---------------------------------------------------------------------------
# F4: Target .opencode/package.json and bun.lock preserved (unchanged after sync)
# ---------------------------------------------------------------------------

test_f4_package_json_and_bun_lock_preserved() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        mkdir -p "$tmpdir/.opencode"
        cp "$SOURCE_OPENCODE/package.json" "$tmpdir/.opencode/package.json"
        cp "$SOURCE_OPENCODE/bun.lock" "$tmpdir/.opencode/bun.lock"
        local before_pkg before_lock
        before_pkg=$(cat "$tmpdir/.opencode/package.json")
        before_lock=$(cat "$tmpdir/.opencode/bun.lock")
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        local after_pkg after_lock
        after_pkg=$(cat "$tmpdir/.opencode/package.json")
        after_lock=$(cat "$tmpdir/.opencode/bun.lock")
        [[ "$before_pkg" == "$after_pkg" ]] && [[ "$before_lock" == "$after_lock" ]]
    )
}

# ---------------------------------------------------------------------------
# F5: Script fails when target missing; fails when target equals source
# ---------------------------------------------------------------------------

test_f5_fails_when_target_missing() {
    local output
    output=$("$SYNC_SCRIPT" /nonexistent/path/xyz 2>&1)
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && [[ "$output" == *"does not exist"* ]]
}

test_f5_fails_when_target_equals_source() {
    local output
    output=$("$SYNC_SCRIPT" "$PROJECT_ROOT" 2>&1)
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && [[ "$output" == *"same as source"* ]]
}

# ---------------------------------------------------------------------------
# Integrity: opencode.json is valid JSON after sync
# ---------------------------------------------------------------------------

test_integrity_opencode_json_valid() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        python3 -m json.tool "$tmpdir/.opencode/opencode.json" >/dev/null 2>&1
    )
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "=========================================="
echo "sync-opencode-run2.sh Integration Tests"
echo "=========================================="
echo ""

run_test "F1: target .opencode/agents/ .md count matches source" \
    test_f1_agents_md_count_matches_source \
    "Expected agent .md count to match source"

run_test "F2: target .opencode/rules/ has 7 rule files" \
    test_f2_rules_count_is_seven \
    "Expected 7 .md files in .opencode/rules/"

run_test "F3: target opencode.json contains alibaba-coding-plan/kimi-k2.5" \
    test_f3_opencode_json_contains_kimi \
    "Expected alibaba-coding-plan/kimi-k2.5 in opencode.json"

run_test "F4: target .opencode/package.json and bun.lock preserved" \
    test_f4_package_json_and_bun_lock_preserved \
    "package.json and bun.lock must be unchanged after sync"

run_test "F5: script fails when target missing" \
    test_f5_fails_when_target_missing \
    "Expected error for nonexistent target"

run_test "F5: script fails when target equals source" \
    test_f5_fails_when_target_equals_source \
    "Expected error when target is same as source"

run_test "Integrity: opencode.json is valid JSON after sync" \
    test_integrity_opencode_json_valid \
    "opencode.json must parse as valid JSON"

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Total:  $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
