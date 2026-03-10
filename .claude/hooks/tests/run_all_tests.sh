#!/bin/bash
# Master test runner for Claude Code hooks
#
# Runs all test suites:
# 1. Shell validator tests (test_validators.sh)
# 2. Python dispatcher tests (test_validate_task_output.py)
#
# Run from project root: bash .claude/hooks/tests/run_all_tests.sh
# Or with pytest:        python3 -m pytest .claude/hooks/ -v

set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Find directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"

echo "=========================================="
echo "Claude Code Hooks - Full Test Suite"
echo "=========================================="
echo "Project root: $PROJECT_ROOT"
echo "Hooks dir:    $HOOKS_DIR"
echo ""

# Track overall results
SHELL_RESULT=0
PYTHON_RESULT=0
STRUCTURE_RESULT=0
SCRIPTS_RESULT=0

# ============================================
# Run Agent Structure Verification
# ============================================
echo -e "${BLUE}[1/4] Running Agent Structure Verification${NC}"
echo "------------------------------------------"

if [ -f "$SCRIPT_DIR/test_agent_structure.sh" ]; then
    bash "$SCRIPT_DIR/test_agent_structure.sh"
    STRUCTURE_RESULT=$?
else
    echo -e "${RED}Agent structure test not found: $SCRIPT_DIR/test_agent_structure.sh${NC}"
    STRUCTURE_RESULT=1
fi

echo ""

# ============================================
# Run Shell Validator Tests
# ============================================
echo -e "${BLUE}[2/4] Running Shell Validator Tests${NC}"
echo "------------------------------------------"

if [ -f "$SCRIPT_DIR/test_validators.sh" ]; then
    bash "$SCRIPT_DIR/test_validators.sh"
    SHELL_RESULT=$?
else
    echo -e "${RED}Shell test file not found: $SCRIPT_DIR/test_validators.sh${NC}"
    SHELL_RESULT=1
fi

echo ""

# ============================================
# Run Python Dispatcher Tests
# ============================================
echo -e "${BLUE}[3/4] Running Python Dispatcher Tests${NC}"
echo "------------------------------------------"

if [ -f "$HOOKS_DIR/test_validate_task_output.py" ]; then
    # Try pytest first, fall back to direct execution
    if command -v pytest &> /dev/null; then
        cd "$PROJECT_ROOT" && python3 -m pytest "$HOOKS_DIR/test_validate_task_output.py" -v
        PYTHON_RESULT=$?
    else
        cd "$PROJECT_ROOT" && python3 "$HOOKS_DIR/test_validate_task_output.py"
        PYTHON_RESULT=$?
    fi
else
    echo -e "${RED}Python test file not found: $HOOKS_DIR/test_validate_task_output.py${NC}"
    PYTHON_RESULT=1
fi

echo ""

# ============================================
# Run Scripts Tests (merge-project-specific, sync-framework-run2)
# ============================================
echo -e "${BLUE}[4/4] Running Scripts Tests${NC}"
echo "------------------------------------------"

SCRIPTS_TESTS_DIR="$PROJECT_ROOT/scripts/tests"
if [ -f "$SCRIPTS_TESTS_DIR/test_merge_project_specific.sh" ]; then
    bash "$SCRIPTS_TESTS_DIR/test_merge_project_specific.sh"
    MERGE_RESULT=$?
else
    MERGE_RESULT=1
fi
if [ -f "$SCRIPTS_TESTS_DIR/test_sync_framework_run2.sh" ]; then
    bash "$SCRIPTS_TESTS_DIR/test_sync_framework_run2.sh"
    SYNC_RESULT=$?
else
    SYNC_RESULT=1
fi
if [ $MERGE_RESULT -eq 0 ] && [ $SYNC_RESULT -eq 0 ]; then
    SCRIPTS_RESULT=0
else
    SCRIPTS_RESULT=1
fi

echo ""

# ============================================
# Summary
# ============================================
echo "=========================================="
echo "Overall Test Summary"
echo "=========================================="

if [ $STRUCTURE_RESULT -eq 0 ]; then
    echo -e "Agent Structure: ${GREEN}PASSED${NC}"
else
    echo -e "Agent Structure: ${RED}FAILED${NC}"
fi

if [ $SHELL_RESULT -eq 0 ]; then
    echo -e "Shell Tests:     ${GREEN}PASSED${NC}"
else
    echo -e "Shell Tests:     ${RED}FAILED${NC}"
fi

if [ $PYTHON_RESULT -eq 0 ]; then
    echo -e "Python Tests:    ${GREEN}PASSED${NC}"
else
    echo -e "Python Tests:    ${RED}FAILED${NC}"
fi

if [ $SCRIPTS_RESULT -eq 0 ]; then
    echo -e "Scripts Tests:   ${GREEN}PASSED${NC}"
else
    echo -e "Scripts Tests:   ${RED}FAILED${NC}"
fi

echo ""

# Overall exit code
if [ $STRUCTURE_RESULT -eq 0 ] && [ $SHELL_RESULT -eq 0 ] && [ $PYTHON_RESULT -eq 0 ] && [ $SCRIPTS_RESULT -eq 0 ]; then
    echo -e "${GREEN}All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}Some test suites failed.${NC}"
    exit 1
fi
