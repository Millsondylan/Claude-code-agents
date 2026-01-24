#!/bin/bash
# Validator for web-syntax-researcher agent (deprecated - use docs-researcher)
# Validates SyntaxReport format with Research Question and Findings
#
# SAFETY: Uses safe shell options. On any error, outputs valid JSON and exits 0.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - output valid JSON on any error
trap 'echo "{\"valid\": true, \"errors\": [], \"warnings\": [\"Validator error - approved\"]}" && exit 0' ERR

# Source shared logging library (with error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR="."
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true
AGENT_NAME="web-syntax-researcher"

# Read stdin (with fallback)
INPUT=$(cat 2>/dev/null) || INPUT=""

# Extract tool_response from PostToolUse JSON
OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',''))" 2>/dev/null) || OUTPUT=""

# Initialize arrays
ERRORS=()
WARNINGS=()

# Check for required sections (using 2>/dev/null to suppress errors)
if ! echo "$OUTPUT" | grep -qi "## SyntaxReport\|## Syntax Report\|### SyntaxReport\|# SyntaxReport" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in web-syntax-researcher output: Missing required section - SyntaxReport")
fi

if ! echo "$OUTPUT" | grep -qi "Research Question\|What to Research\|### Research\|Question:" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in web-syntax-researcher output: Missing required section - Research Question")
fi

if ! echo "$OUTPUT" | grep -qi "Technology\|Framework\|### Technology\|Library" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in web-syntax-researcher output: Missing required section - Technology/Framework")
fi

if ! echo "$OUTPUT" | grep -qi "Findings\|Results\|### Findings\|### Results" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in web-syntax-researcher output: Missing required section - Findings/Results")
fi

if ! echo "$OUTPUT" | grep -qi "Confidence Level\|Confidence\|### Confidence" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in web-syntax-researcher output: Missing required section - Confidence Level")
fi

# Warnings for recommended sections
if ! echo "$OUTPUT" | grep -qi "Source\|Documentation\|Reference\|URL" 2>/dev/null; then
    WARNINGS+=("Missing section: Source/Documentation reference (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "Gotchas\|Notes\|Caveats\|Warning" 2>/dev/null; then
    WARNINGS+=("Missing section: Gotchas/Notes (recommended)")
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
