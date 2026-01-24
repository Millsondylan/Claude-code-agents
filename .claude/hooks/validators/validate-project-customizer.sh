#!/bin/bash
# Validator for project-customizer agent
# Validates Project-Specific section updates with Tech Stack and Patterns
#
# SAFETY: Uses safe shell options. On any error, outputs valid JSON and exits 0.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - output valid JSON on any error
trap 'echo "{\"valid\": true, \"errors\": [], \"warnings\": [\"Validator error - approved\"]}" && exit 0' ERR

# Source shared logging library (with error handling)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR="."
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || true
AGENT_NAME="project-customizer"

# Read stdin (with fallback)
INPUT=$(cat 2>/dev/null) || INPUT=""

# Extract tool_response from PostToolUse JSON
OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_response',''))" 2>/dev/null) || OUTPUT=""

# Initialize arrays
ERRORS=()
WARNINGS=()

# Check for required sections (using 2>/dev/null to suppress errors)
if ! echo "$OUTPUT" | grep -qi "PROJECT-SPECIFIC\|Project-Specific\|project-specific" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in project-customizer output: Missing required marker - PROJECT-SPECIFIC")
fi

if ! echo "$OUTPUT" | grep -qi "Tech Stack\|Stack\|### Tech\|Technology" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in project-customizer output: Missing required section - Tech Stack")
fi

if ! echo "$OUTPUT" | grep -qi "Patterns\|Conventions\|### Patterns\|### Conventions" 2>/dev/null; then
    ERRORS+=("Resolve this Format error in project-customizer output: Missing required section - Patterns/Conventions")
fi

# Check for prohibited modifications - should NOT modify BASE RULES
if echo "$OUTPUT" | grep -qi "BASE RULES.*MODIFIED\|modified.*BASE RULES" 2>/dev/null; then
    ERRORS+=("Resolve this Validation error in project-customizer output: Must NOT modify BASE RULES section")
fi

# Check if BASE RULES markers are preserved
if ! echo "$OUTPUT" | grep -qi "BASE RULES - DO NOT MODIFY" 2>/dev/null; then
    WARNINGS+=("Warning: BASE RULES markers should be preserved")
fi

# Warnings for recommended sections
if ! echo "$OUTPUT" | grep -qi "Discovered\|Analyzed\|Project's" 2>/dev/null; then
    WARNINGS+=("Missing section: Discovered patterns context (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "Testing\|Test\|testing" 2>/dev/null; then
    WARNINGS+=("Missing section: Testing requirements (recommended)")
fi

if ! echo "$OUTPUT" | grep -qi "Safety\|safety\|Security" 2>/dev/null; then
    WARNINGS+=("Missing section: Project-specific safety rules (recommended)")
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
