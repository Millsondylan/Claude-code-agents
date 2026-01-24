#!/bin/bash
# Observability Hook: Trace Tool Calls (PreToolUse)
# Purpose: Log all tool calls for debugging and observability
# Location: .claude/hooks/observability/trace-tool-call.sh
#
# SAFETY: Uses safe shell options. On any error, outputs valid JSON and exits 0.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - output valid JSON on any error
trap 'echo "{\"decision\": \"approve\", \"reason\": \"Observability hook error - approved\"}" && exit 0' ERR

# Get script directory for relative path resolution (with fallback)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR="."
LOG_DIR="$SCRIPT_DIR/../logs/observability"
mkdir -p "$LOG_DIR" 2>/dev/null || true

TIMESTAMP=$(date +%Y%m%d_%H%M%S 2>/dev/null) || TIMESTAMP="unknown"

# Parse input from stdin - Claude provides JSON via stdin, not env vars
INPUT=$(cat 2>/dev/null) || INPUT=""

# Extract tool name and session from stdin JSON (with fallbacks)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null) || TOOL_NAME="unknown"
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || SESSION_ID="$(date +%s 2>/dev/null)" || SESSION_ID="unknown"

# Create trace log entry
LOG_FILE="$LOG_DIR/${TIMESTAMP}_trace.jsonl"

# Extract tool input for logging (truncate if too long)
TOOL_INPUT=$(echo "$INPUT" | head -c 500 2>/dev/null) || TOOL_INPUT=""

# Log the trace entry (append to JSONL file) - silently ignore failures
# NOTE: Using printf instead of echo to preserve escaped characters in JSON (echo interprets \n)
{
    INPUT_JSON=$(printf '%s' "$TOOL_INPUT" | jq -Rs . 2>/dev/null) || INPUT_JSON='""'
    printf '%s\n' "{\"timestamp\": \"$TIMESTAMP\", \"event\": \"PreToolUse\", \"tool\": \"$TOOL_NAME\", \"session\": \"$SESSION_ID\", \"input_preview\": $INPUT_JSON}" >> "$LOG_FILE"
} 2>/dev/null || true

# Always approve - this is just for observability
echo '{"decision": "approve", "reason": "Tool call traced for observability"}'
