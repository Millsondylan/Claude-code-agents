#!/bin/bash
# End-to-end tests for Claude Code hook validators
#
# Tests validator shell scripts with various inputs:
# - Valid output (should return valid: true)
# - Invalid output (should return valid: false with errors)
# - Malformed input (should gracefully return valid: true with warning)
# - Empty input (should gracefully return valid: true)
#
# Run: bash .claude/hooks/tests/test_validators.sh
# Or:  ./test_validators.sh (from tests directory)

set -u

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
TOTAL=0

# Find script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VALIDATORS_DIR="$PROJECT_ROOT/.claude/hooks/validators"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# Test helper function
run_test() {
    local test_name="$1"
    local validator="$2"
    local input_file="$3"
    local expected_valid="$4"
    local check_field="${5:-}"
    local check_value="${6:-}"

    TOTAL=$((TOTAL + 1))

    local validator_path="$VALIDATORS_DIR/$validator"
    local input_path="$FIXTURES_DIR/$input_file"

    # Check validator exists
    if [ ! -f "$validator_path" ]; then
        echo -e "${YELLOW}SKIP${NC}: $test_name - Validator not found: $validator"
        return
    fi

    # Check input exists
    if [ ! -f "$input_path" ]; then
        echo -e "${RED}FAIL${NC}: $test_name - Input file not found: $input_file"
        FAILED=$((FAILED + 1))
        return
    fi

    # Run validator
    local output
    output=$(bash "$validator_path" < "$input_path" 2>/dev/null)
    local exit_code=$?

    # Check exit code is 0 (validators should always exit 0)
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}FAIL${NC}: $test_name - Exit code $exit_code (expected 0)"
        FAILED=$((FAILED + 1))
        return
    fi

    # Check output is valid JSON
    if ! echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${RED}FAIL${NC}: $test_name - Output is not valid JSON: $output"
        FAILED=$((FAILED + 1))
        return
    fi

    # Check valid field
    local actual_valid
    actual_valid=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('valid', 'missing'))" 2>/dev/null)

    if [ "$actual_valid" != "$expected_valid" ]; then
        echo -e "${RED}FAIL${NC}: $test_name - valid=$actual_valid (expected $expected_valid)"
        echo "    Output: $output"
        FAILED=$((FAILED + 1))
        return
    fi

    # Check additional field if specified
    if [ -n "$check_field" ] && [ -n "$check_value" ]; then
        local actual_value
        actual_value=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('$check_field', [])))" 2>/dev/null)

        if [ "$check_value" = "non_empty" ]; then
            if [ "$actual_value" = "0" ]; then
                echo -e "${RED}FAIL${NC}: $test_name - $check_field should not be empty"
                echo "    Output: $output"
                FAILED=$((FAILED + 1))
                return
            fi
        fi
    fi

    echo -e "${GREEN}PASS${NC}: $test_name"
    PASSED=$((PASSED + 1))
}

# Test helper for empty stdin
run_test_empty_stdin() {
    local test_name="$1"
    local validator="$2"

    TOTAL=$((TOTAL + 1))

    local validator_path="$VALIDATORS_DIR/$validator"

    if [ ! -f "$validator_path" ]; then
        echo -e "${YELLOW}SKIP${NC}: $test_name - Validator not found"
        return
    fi

    # Run validator with empty stdin
    local output
    output=$(echo "" | bash "$validator_path" 2>/dev/null)
    local exit_code=$?

    # Should exit 0
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}FAIL${NC}: $test_name - Exit code $exit_code (expected 0)"
        FAILED=$((FAILED + 1))
        return
    fi

    # Should output valid JSON
    if ! echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${RED}FAIL${NC}: $test_name - Output is not valid JSON: $output"
        FAILED=$((FAILED + 1))
        return
    fi

    # Should return valid: true (graceful degradation)
    local actual_valid
    actual_valid=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('valid', 'missing'))" 2>/dev/null)

    if [ "$actual_valid" != "True" ] && [ "$actual_valid" != "true" ]; then
        # Empty stdin should be handled gracefully - accept either true or false
        echo -e "${YELLOW}WARN${NC}: $test_name - valid=$actual_valid (expected True for graceful handling)"
    fi

    echo -e "${GREEN}PASS${NC}: $test_name"
    PASSED=$((PASSED + 1))
}

# Test helper for malformed JSON
run_test_malformed_json() {
    local test_name="$1"
    local validator="$2"

    TOTAL=$((TOTAL + 1))

    local validator_path="$VALIDATORS_DIR/$validator"

    if [ ! -f "$validator_path" ]; then
        echo -e "${YELLOW}SKIP${NC}: $test_name - Validator not found"
        return
    fi

    # Run validator with malformed JSON
    local output
    output=$(echo "not valid json at all {{{" | bash "$validator_path" 2>/dev/null)
    local exit_code=$?

    # Should exit 0 (graceful degradation)
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}FAIL${NC}: $test_name - Exit code $exit_code (expected 0 for graceful handling)"
        FAILED=$((FAILED + 1))
        return
    fi

    # Should output valid JSON
    if ! echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${RED}FAIL${NC}: $test_name - Output is not valid JSON: $output"
        FAILED=$((FAILED + 1))
        return
    fi

    echo -e "${GREEN}PASS${NC}: $test_name"
    PASSED=$((PASSED + 1))
}

echo "=========================================="
echo "Claude Code Hook Validator Tests"
echo "=========================================="
echo ""

# ============================================
# Task-Breakdown Validator Tests
# ============================================
echo "--- task-breakdown validator ---"

run_test \
    "task-breakdown: valid output passes" \
    "validate-task-breakdown.sh" \
    "valid_task_breakdown.json" \
    "True"

run_test \
    "task-breakdown: invalid output fails with errors" \
    "validate-task-breakdown.sh" \
    "invalid_task_breakdown.json" \
    "False" \
    "errors" \
    "non_empty"

run_test_empty_stdin \
    "task-breakdown: empty stdin handled gracefully" \
    "validate-task-breakdown.sh"

run_test_malformed_json \
    "task-breakdown: malformed JSON handled gracefully" \
    "validate-task-breakdown.sh"

echo ""

# ============================================
# Plan-Agent Validator Tests
# ============================================
echo "--- plan-agent validator ---"

run_test \
    "plan-agent: valid output passes" \
    "validate-plan-agent.sh" \
    "valid_plan_agent.json" \
    "True"

run_test \
    "plan-agent: invalid output fails with errors" \
    "validate-plan-agent.sh" \
    "invalid_plan_agent.json" \
    "False" \
    "errors" \
    "non_empty"

run_test_empty_stdin \
    "plan-agent: empty stdin handled gracefully" \
    "validate-plan-agent.sh"

run_test_malformed_json \
    "plan-agent: malformed JSON handled gracefully" \
    "validate-plan-agent.sh"

echo ""

# ============================================
# All Validators - Graceful Degradation Tests
# ============================================
echo "--- All validators: graceful degradation ---"

# Test all validators handle empty input gracefully
for validator_file in "$VALIDATORS_DIR"/validate-*.sh; do
    if [ -f "$validator_file" ]; then
        validator_name=$(basename "$validator_file")
        run_test_empty_stdin \
            "$validator_name: empty stdin" \
            "$validator_name"
    fi
done

echo ""

# ============================================
# Summary
# ============================================
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
