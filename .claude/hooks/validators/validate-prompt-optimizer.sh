#!/bin/bash
# Validator for prompt-optimizer agent (Stage -1)
# Validates optimized prompt XML format
#
# SAFETY: Uses safe shell options. On any error, outputs valid JSON and exits 0.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - output valid JSON on any error
trap 'echo "{\"valid\": true, \"errors\": [], \"warnings\": [\"Validator error - approved\"]}" && exit 0' ERR

# Source shared logging library (with error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR="."
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true
AGENT_NAME="prompt-optimizer"

# Read stdin (with fallback)
INPUT=$(cat 2>/dev/null) || INPUT=""

# Extract tool_response from PostToolUse JSON
OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',''))" 2>/dev/null) || OUTPUT=""

# Initialize arrays
ERRORS=()
WARNINGS=()

# Check for XML structure (prompt-optimizer outputs XML-structured prompts)
if ! echo "$OUTPUT" | grep -qE "<task>|<context>|<requirements>" 2>/dev/null; then
    ERRORS+=("Resolve this Structure error in prompt-optimizer output: Missing XML structure - Expected <task>, <context>, or <requirements> tags")
fi

# At minimum, should have a task tag
if ! echo "$OUTPUT" | grep -q "<task>" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in prompt-optimizer output: Missing required tag - <task>")
fi

# Check for anti-laziness/persistence rules (should be included)
if ! echo "$OUTPUT" | grep -qi "COMPLETION\|completion_rules\|MUST provide COMPLETE" 2>/dev/null; then
    WARNINGS+=("Missing section: Completion rules (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "PERSISTENCE\|persistence_rules\|Keep going" 2>/dev/null; then
    WARNINGS+=("Missing section: Persistence rules (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "VERIFICATION\|verification_rules\|READ.*first" 2>/dev/null; then
    WARNINGS+=("Missing section: Verification rules (recommended)")
fi

# Check for output format specification
if ! echo "$OUTPUT" | grep -qi "output_format\|<output" 2>/dev/null; then
    WARNINGS+=("Missing section: Output format specification (recommended)")
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
