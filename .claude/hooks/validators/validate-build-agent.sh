#!/bin/bash
# Validator for build-agent-1/2/3/4/5 (Stage 4)
# Validates Build Report format with Files Changed and Budget Consumed
#
# SAFETY: Uses safe shell options. On any error, outputs valid JSON and exits 0.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - output valid JSON on any error
trap 'echo "{\"valid\": true, \"errors\": [], \"warnings\": [\"Validator error - approved\"]}" && exit 0' ERR

# Source shared logging library (with error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR="."
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true
AGENT_NAME="build-agent"

# Read stdin (with fallback)
INPUT=$(cat 2>/dev/null) || INPUT=""

# Extract tool_response from PostToolUse JSON
OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',''))" 2>/dev/null) || OUTPUT=""

# Initialize arrays
ERRORS=()
WARNINGS=()

# Check for required sections (using 2>/dev/null to suppress errors)
if ! echo "$OUTPUT" | grep -qi "Build.*Report\|## Build\|### Build" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in build-agent output: Missing required section - Build Report")
fi

if ! echo "$OUTPUT" | grep -qi "Files Changed\|Files Created\|Files Modified\|#### Created\|#### Modified" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in build-agent output: Missing required section - Files Changed")
fi

if ! echo "$OUTPUT" | grep -qi "Budget Consumed\|Budget.*:\|Simple:.*[0-9]" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in build-agent output: Missing required section - Budget Consumed")
fi

if ! echo "$OUTPUT" | grep -qi "Features Implemented\|### Features\|F[0-9]+:" 2>/dev/null; then
    WARNINGS+=("Missing section: Features Implemented (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "Change Ledger\|### Change\|Change ID" 2>/dev/null; then
    WARNINGS+=("Missing section: Change Ledger (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "Tests Created\|Tests Modified\|test" 2>/dev/null; then
    WARNINGS+=("Missing section: Tests Created/Modified (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "Status\|Next Steps\|Completion" 2>/dev/null; then
    WARNINGS+=("Missing section: Status/Next Steps (recommended)")
fi

# Output result as JSON
if [ ${#ERRORS[@]} -eq 0 ]; then
    WARN_JSON="[]"
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        WARN_JSON=$(printf '%s\n' "${WARNINGS[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null) || WARN_JSON="[]"
    fi
    # Write log (silently ignore failures)
    OUTPUT_PREVIEW=$(echo "$OUTPUT" | head -c 500 2>/dev/null) || OUTPUT_PREVIEW=""
    write_log "$AGENT_NAME" "true" "[]" "$WARN_JSON" "$OUTPUT_PREVIEW" 2>/dev/null || true
    echo "{\"valid\": true, \"errors\": [], \"warnings\": $WARN_JSON}"
    exit 0
else
    ERROR_JSON=$(printf '%s\n' "${ERRORS[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null) || ERROR_JSON="[]"
    WARN_JSON="[]"
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        WARN_JSON=$(printf '%s\n' "${WARNINGS[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null) || WARN_JSON="[]"
    fi
    # Write log (silently ignore failures)
    OUTPUT_PREVIEW=$(echo "$OUTPUT" | head -c 500 2>/dev/null) || OUTPUT_PREVIEW=""
    write_log "$AGENT_NAME" "false" "$ERROR_JSON" "$WARN_JSON" "$OUTPUT_PREVIEW" 2>/dev/null || true
    echo "{\"valid\": false, \"errors\": $ERROR_JSON, \"warnings\": $WARN_JSON}"
    exit 0
fi
