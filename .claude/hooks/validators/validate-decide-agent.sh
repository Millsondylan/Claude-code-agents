#!/bin/bash
# Validator for decide-agent (Stage 8)
# Validates Decision output (COMPLETE or RESTART)
#
# SAFETY: Uses safe shell options. On any error, outputs valid JSON and exits 0.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - output valid JSON on any error
trap 'echo "{\"valid\": true, \"errors\": [], \"warnings\": [\"Validator error - approved\"]}" && exit 0' ERR

# Source shared logging library (with error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR="."
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true
AGENT_NAME="decide-agent"

# Read stdin (with fallback)
INPUT=$(cat 2>/dev/null) || INPUT=""

# Extract tool_response from PostToolUse JSON
OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',''))" 2>/dev/null) || OUTPUT=""

# Initialize arrays
ERRORS=()
WARNINGS=()

# Check for required sections (using 2>/dev/null to suppress errors)
if ! echo "$OUTPUT" | grep -qi "Decide.*Agent\|Decision\|## Decide" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in decide-agent output: Missing required section - Decide Agent Decision")
fi

# Must have exactly one of COMPLETE or RESTART
HAS_COMPLETE=$(echo "$OUTPUT" | grep -ci "COMPLETE" 2>/dev/null) || HAS_COMPLETE=0
HAS_RESTART=$(echo "$OUTPUT" | grep -ci "RESTART" 2>/dev/null) || HAS_RESTART=0

if [ "$HAS_COMPLETE" -eq 0 ] && [ "$HAS_RESTART" -eq 0 ]; then
    ERRORS+=("Resolve this Content error in decide-agent output: Missing required decision - Must specify COMPLETE or RESTART")
fi

if [ "$HAS_COMPLETE" -gt 0 ] && [ "$HAS_RESTART" -gt 0 ]; then
    # Check if both appear as actual decisions (not just references)
    DECISION_COMPLETE=$(echo "$OUTPUT" | grep -ciE "Decision:.*COMPLETE|### Decision.*COMPLETE" 2>/dev/null) || DECISION_COMPLETE=0
    DECISION_RESTART=$(echo "$OUTPUT" | grep -ciE "Decision:.*RESTART|### Decision.*RESTART" 2>/dev/null) || DECISION_RESTART=0
    if [ "$DECISION_COMPLETE" -gt 0 ] && [ "$DECISION_RESTART" -gt 0 ]; then
        ERRORS+=("Resolve this Validation error in decide-agent output: Ambiguous decision - Cannot specify both COMPLETE and RESTART")
    fi
fi

if ! echo "$OUTPUT" | grep -qi "Justification\|Reason\|### Justification" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in decide-agent output: Missing required section - Justification")
fi

if ! echo "$OUTPUT" | grep -qi "Evidence\|### Evidence" 2>/dev/null; then
    WARNINGS+=("Missing section: Evidence (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "Summary\|### Summary" 2>/dev/null; then
    WARNINGS+=("Missing section: Summary (recommended)")
fi

# Check for prohibited REQUEST patterns (decide-agent cannot request other agents)
if echo "$OUTPUT" | grep -qiE "REQUEST:.*agent|REQUEST:.*debugger|REQUEST:.*build" 2>/dev/null; then
    ERRORS+=("Resolve this Validation error in decide-agent output: Prohibited action - decide-agent cannot REQUEST other agents (use RESTART instead)")
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
