#!/bin/bash
# Unit tests for merge-project-specific.sh
#
# Verifies that merge_project_specific preserves the target's PROJECT-SPECIFIC
# block between <!-- PROJECT-SPECIFIC - AUTO-UPDATED - START/END --> markers.
#
# Run: bash scripts/tests/test_merge_project_specific.sh
# Or:  bash scripts/tests/test_merge_project_specific.sh (from project root)

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MERGE_SCRIPT="${PROJECT_ROOT}/scripts/merge-project-specific.sh"

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

# Test 1: Source file missing returns error
test_source_missing_returns_error() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        local dst="$tmpdir/target.md"
        echo "content" > "$dst"
        local output
        output=$("$MERGE_SCRIPT" /nonexistent/path/source.md "$dst" 2>&1)
        local exit_code=$?
        [[ $exit_code -ne 0 ]] && [[ "$output" == *"source file does not exist"* ]] || exit 1
        exit 0
    )
}

# Test 2: Target missing copies source as-is
test_target_missing_copies_source_as_is() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        local src="$tmpdir/source.md"
        local dst="$tmpdir/target.md"
        printf 'before\n%s\ncontent here\n%s\nafter\n' "$START_MARKER" "$END_MARKER" > "$src"
        "$MERGE_SCRIPT" "$src" "$dst" 2>/dev/null
        [[ $? -eq 0 ]] && [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1 || exit 1
        exit 0
    )
}

# Test 3: Target has PROJECT-SPECIFIC block - merge preserves it
test_merge_preserves_target_project_specific_block() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        local src="$tmpdir/source.md"
        local dst="$tmpdir/target.md"
        printf 'header\n%s\n*Source project block*\n%s\nfooter\n' "$START_MARKER" "$END_MARKER" > "$src"
        printf 'old_header\n%s\n*Target custom block - MUST STAY*\n%s\nold_footer\n' "$START_MARKER" "$END_MARKER" > "$dst"
        "$MERGE_SCRIPT" "$src" "$dst" 2>/dev/null
        [[ $? -ne 0 ]] && exit 1
        grep -q "Target custom block - MUST STAY" "$dst" || exit 1
        grep -q "Source project block" "$dst" && exit 1
        grep -q "header" "$dst" || exit 1
        grep -q "footer" "$dst" || exit 1
        exit 0
    )
}

# Test 4: Markers missing in target - use source block (copy source as-is)
test_markers_missing_in_target_uses_source_block() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        local src="$tmpdir/source.md"
        local dst="$tmpdir/target.md"
        printf 'header\n%s\n*Source block*\n%s\nfooter\n' "$START_MARKER" "$END_MARKER" > "$src"
        echo "target has no markers at all" > "$dst"
        "$MERGE_SCRIPT" "$src" "$dst" 2>/dev/null
        [[ $? -ne 0 ]] && exit 1
        grep -q "Source block" "$dst" || exit 1
        grep -q "target has no markers" "$dst" && exit 1
        exit 0
    )
}

# Test 5: src == dst (same file) - handles correctly
test_src_equals_dst_handles_correctly() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        local f="$tmpdir/same.md"
        printf 'header\n%s\n*Preserved block*\n%s\nfooter\n' "$START_MARKER" "$END_MARKER" > "$f"
        "$MERGE_SCRIPT" "$f" "$f" 2>/dev/null
        [[ $? -ne 0 ]] && exit 1
        grep -q "Preserved block" "$f" || exit 1
        grep -q "header" "$f" || exit 1
        exit 0
    )
}

# Test 6: Multiline project-specific block preserved exactly
test_multiline_project_specific_block_preserved() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        local src="$tmpdir/source.md"
        local dst="$tmpdir/target.md"
        printf 'framework\n%s\nSource line 1\nSource line 2\n%s\nend\n' "$START_MARKER" "$END_MARKER" > "$src"
        printf 'framework\n%s\nCustom line A\nCustom line B\nCustom line C\n%s\nend\n' "$START_MARKER" "$END_MARKER" > "$dst"
        "$MERGE_SCRIPT" "$src" "$dst" 2>/dev/null
        [[ $? -ne 0 ]] && exit 1
        grep -q "Custom line A" "$dst" || exit 1
        grep -q "Custom line B" "$dst" || exit 1
        grep -q "Custom line C" "$dst" || exit 1
        grep -q "Source line" "$dst" && exit 1
        exit 0
    )
}

# Test 7: Usage shown when wrong args
test_wrong_args_shows_usage() {
    local output
    output=$("$MERGE_SCRIPT" 2>&1)
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && [[ "$output" == *"Usage"* ]]
}

# Test 8: Empty project-specific block in target preserved
test_empty_project_specific_block_preserved() {
    (
        local tmpdir
        tmpdir=$(mktemp -d)
        trap 'rm -rf "'"$tmpdir"'"' EXIT
        local src="$tmpdir/source.md"
        local dst="$tmpdir/target.md"
        printf 'header\n%s\n*Source content*\n%s\nfooter\n' "$START_MARKER" "$END_MARKER" > "$src"
        printf 'header\n%s\n%s\nfooter\n' "$START_MARKER" "$END_MARKER" > "$dst"
        "$MERGE_SCRIPT" "$src" "$dst" 2>/dev/null
        [[ $? -ne 0 ]] && exit 1
        grep -q "Source content" "$dst" && exit 1
        exit 0
    )
}

echo "=========================================="
echo "merge-project-specific.sh Unit Tests"
echo "=========================================="
echo ""

run_test "source file missing returns error" test_source_missing_returns_error "Expected non-zero exit and error message"
run_test "target missing copies source as-is" test_target_missing_copies_source_as_is "Expected dst to equal src"
run_test "merge preserves target PROJECT-SPECIFIC block" test_merge_preserves_target_project_specific_block "Target custom block should remain, source block should not appear"
run_test "markers missing in target uses source block" test_markers_missing_in_target_uses_source_block "Source content should replace target when target has no markers"
run_test "src equals dst handles correctly" test_src_equals_dst_handles_correctly "Same file merge should preserve block"
run_test "multiline project-specific block preserved" test_multiline_project_specific_block_preserved "All custom lines should remain"
run_test "wrong args shows usage" test_wrong_args_shows_usage "Expected usage message on wrong args"
run_test "empty project-specific block preserved" test_empty_project_specific_block_preserved "Empty target block should replace source block"

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
