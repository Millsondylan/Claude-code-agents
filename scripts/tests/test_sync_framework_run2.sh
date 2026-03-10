#!/bin/bash
# Integration tests for sync-framework-run2.sh
#
# Verifies that sync-framework-run2.sh:
# - Creates .opencode/, .ai/, CLAUDE.md, AGENTS.md in target
# - Preserves PROJECT-SPECIFIC block in merged files (AGENTS.md, .ai/README.md)
#
# Uses a temporary directory as target. No mocks.
#
# Run: bash scripts/tests/test_sync_framework_run2.sh
# Or:  bash scripts/tests/test_sync_framework_run2.sh (from project root)

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC_SCRIPT="${PROJECT_ROOT}/scripts/sync-framework-run2.sh"

START_MARKER='<!-- PROJECT-SPECIFIC - AUTO-UPDATED - START -->'
END_MARKER='<!-- PROJECT-SPECIFIC - AUTO-UPDATED - END -->'

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

# Test 1: .opencode/ present in target after sync
test_opencode_present_after_sync() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        [[ -d "$tmpdir/.opencode" ]]
    )
}

# Test 2: .ai/ present in target after sync
test_ai_present_after_sync() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        [[ -d "$tmpdir/.ai" ]]
    )
}

# Test 3: CLAUDE.md present in target after sync
test_claude_md_present_after_sync() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        [[ -f "$tmpdir/CLAUDE.md" ]]
    )
}

# Test 4: AGENTS.md present in target after sync
test_agents_md_present_after_sync() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        [[ -f "$tmpdir/AGENTS.md" ]]
    )
}

# Test 5: PROJECT-SPECIFIC block preserved in AGENTS.md after sync (target had custom block)
test_agents_md_preserves_project_specific() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        # Pre-create AGENTS.md with custom block
        mkdir -p "$tmpdir"
        printf 'base\n%s\n*CUSTOM_AGENTS_BLOCK*\n%s\nend\n' "$START_MARKER" "$END_MARKER" > "$tmpdir/AGENTS.md"
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        grep -q "CUSTOM_AGENTS_BLOCK" "$tmpdir/AGENTS.md" || exit 1
        grep -q "PROJECT-SPECIFIC" "$tmpdir/AGENTS.md" || exit 1
        exit 0
    )
}

# Test 6: .ai/README.md has PROJECT-SPECIFIC markers after sync
# (merge runs after rsync; structure is correct)
test_ai_readme_has_project_specific_markers() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        grep -q "PROJECT-SPECIFIC - AUTO-UPDATED - START" "$tmpdir/.ai/README.md" || exit 1
        grep -q "PROJECT-SPECIFIC - AUTO-UPDATED - END" "$tmpdir/.ai/README.md" || exit 1
        exit 0
    )
}

# Test 7: Sync fails when target does not exist
test_sync_fails_when_target_missing() {
    local output
    output=$("$SYNC_SCRIPT" /nonexistent/path/xyz 2>&1)
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && [[ "$output" == *"does not exist"* ]]
}

# Test 8: Sync fails when target equals source
test_sync_fails_when_target_equals_source() {
    local output
    output=$("$SYNC_SCRIPT" "$PROJECT_ROOT" 2>&1)
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && [[ "$output" == *"same directory"* ]]
}

# Test 9: .opencode/ contains agents (at least one agent file)
test_opencode_contains_agents() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        "$SYNC_SCRIPT" "$tmpdir" 2>/dev/null
        [[ -d "$tmpdir/.opencode/agents" ]]
        local count
        count=$(find "$tmpdir/.opencode/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
        [[ "$count" -ge 1 ]]
    )
}

echo "=========================================="
echo "sync-framework-run2.sh Integration Tests"
echo "=========================================="
echo ""

run_test ".opencode/ present in target" test_opencode_present_after_sync "Expected .opencode/ directory"
run_test ".ai/ present in target" test_ai_present_after_sync "Expected .ai/ directory"
run_test "CLAUDE.md present in target" test_claude_md_present_after_sync "Expected CLAUDE.md file"
run_test "AGENTS.md present in target" test_agents_md_present_after_sync "Expected AGENTS.md file"
run_test "AGENTS.md preserves PROJECT-SPECIFIC block" test_agents_md_preserves_project_specific "Target custom block should remain"
run_test ".ai/README.md has PROJECT-SPECIFIC markers" test_ai_readme_has_project_specific_markers "Expected PROJECT-SPECIFIC markers in .ai/README.md"
run_test "sync fails when target missing" test_sync_fails_when_target_missing "Expected error for missing target"
run_test "sync fails when target equals source" test_sync_fails_when_target_equals_source "Expected error for same dir"
run_test ".opencode/ contains agents" test_opencode_contains_agents "Expected agents in .opencode/agents/"

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
