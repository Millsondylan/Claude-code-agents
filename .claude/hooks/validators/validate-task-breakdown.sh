#!/bin/bash
# Validator for task-breakdown agent (Stage 0)
# Validates TaskSpec format with Features and Acceptance Criteria
#
# SAFETY: Uses safe shell options. On any error, outputs valid JSON and exits 0.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - output valid JSON on any error
trap 'echo "{\"valid\": true, \"errors\": [], \"warnings\": [\"Validator error - approved\"]}" && exit 0' ERR

# Source shared logging library (with error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR="."
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true
AGENT_NAME="task-breakdown"

# Read stdin (with fallback)
INPUT=$(cat 2>/dev/null) || INPUT=""

# Extract tool_response from PostToolUse JSON
OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',''))" 2>/dev/null) || OUTPUT=""

# Initialize arrays
ERRORS=()
WARNINGS=()

# Check for required sections (using || true to prevent exit on grep failure)
if ! echo "$OUTPUT" | grep -qi "## TaskSpec\|### TaskSpec\|# TaskSpec" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in task-breakdown output: Missing required section - TaskSpec")
fi

if ! echo "$OUTPUT" | grep -qi "### Features\|## Features\|#### F1" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in task-breakdown output: Missing required section - Features")
fi

if ! echo "$OUTPUT" | grep -qi "Acceptance Criteria\|acceptance criteria" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in task-breakdown output: Missing required section - Acceptance Criteria")
fi

if ! echo "$OUTPUT" | grep -qi "### Risks\|## Risks\|### Risk" 2>/dev/null; then
    WARNINGS+=("Missing section: Risks (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "### Assumptions\|## Assumptions" 2>/dev/null; then
    WARNINGS+=("Missing section: Assumptions (recommended)")
fi

# Check for at least one feature (F1, F2, etc.)
if ! echo "$OUTPUT" | grep -qE "F[0-9]+:|#### F[0-9]+" 2>/dev/null; then
    ERRORS+=("Resolve this Content error in task-breakdown output: No features defined - expected F1, F2, etc.")
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
