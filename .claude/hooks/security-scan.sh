#!/bin/bash
# Security Scanner Hook: Detect Secrets/Credentials (PreToolUse)
# Purpose: Block Write and Edit tool calls that contain potential secrets
# Location: .claude/hooks/security-scan.sh
# Event: PreToolUse (Write, Edit)
#
# SAFETY: Uses safe shell options. On any error, exits 0 (approve) gracefully.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - on any unexpected error, approve (never crash)
trap 'echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"approve\", \"permissionDecisionReason\": \"Security scanner error - approved by default\"}}" && exit 0' ERR

# ---------------------------------------------------------------------------
# JSON parsing helpers: prefer jq, fall back to python3
# ---------------------------------------------------------------------------
parse_json_field() {
    local json="$1"
    local field="$2"
    local default="${3:-}"

    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r "${field} // \"${default}\"" 2>/dev/null || echo "$default"
    else
        echo "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Support simple dotted paths like '.tool_input.content'
    parts = '${field}'.lstrip('.').split('.')
    val = d
    for p in parts:
        if isinstance(val, dict):
            val = val.get(p)
        else:
            val = None
            break
    print(val if val is not None else '${default}')
except Exception:
    print('${default}')
" 2>/dev/null || echo "$default"
    fi
}

# ---------------------------------------------------------------------------
# Read stdin
# ---------------------------------------------------------------------------
INPUT=$(cat 2>/dev/null) || INPUT=""

if [ -z "$INPUT" ]; then
    # Nothing to scan - approve
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "approve", "permissionDecisionReason": "No input received"}}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Extract relevant fields
# ---------------------------------------------------------------------------
TOOL_NAME=$(parse_json_field "$INPUT" ".tool_name" "unknown")
FILE_PATH=$(parse_json_field "$INPUT" ".tool_input.file_path" "")

# Determine content to scan based on tool:
# - Write tool: content is in tool_input.content
# - Edit tool:  content is in tool_input.new_string
if [ "$TOOL_NAME" = "Write" ]; then
    CONTENT=$(parse_json_field "$INPUT" ".tool_input.content" "")
elif [ "$TOOL_NAME" = "Edit" ]; then
    CONTENT=$(parse_json_field "$INPUT" ".tool_input.new_string" "")
else
    # Not a tool we scan - approve immediately
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "approve", "permissionDecisionReason": "Tool not subject to secret scanning"}}'
    exit 0
fi

if [ -z "$CONTENT" ]; then
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "approve", "permissionDecisionReason": "No content to scan"}}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Secret detection patterns
# Each check sets DETECTED_REASON if a secret is found.
# ---------------------------------------------------------------------------
DETECTED_REASON=""

# Helper: grep the content for a pattern (case-sensitive unless flag passed)
# IMPORTANT: Use -e to pass the pattern explicitly - prevents patterns starting with
# dashes (e.g., -----BEGIN PRIVATE KEY) from being misinterpreted as grep flags.
content_matches() {
    local pattern="$1"
    echo "$CONTENT" | grep -qE -e "$pattern" 2>/dev/null
}

# 1. Anthropic API key (sk-ant-)
if content_matches 'sk-ant-[a-zA-Z0-9_-]{10,}'; then
    DETECTED_REASON="Anthropic API key pattern (sk-ant-...)"
fi

# 2. OpenAI / generic sk-proj- keys
if [ -z "$DETECTED_REASON" ] && content_matches 'sk-proj-[a-zA-Z0-9_-]{10,}'; then
    DETECTED_REASON="Project API key pattern (sk-proj-...)"
fi

# 3. Generic sk- prefixed keys (broad catch)
if [ -z "$DETECTED_REASON" ] && content_matches "sk-[a-zA-Z0-9]{20,}"; then
    DETECTED_REASON="Generic secret key pattern (sk-...)"
fi

# 4. AWS Access Key ID
if [ -z "$DETECTED_REASON" ] && content_matches 'AKIA[0-9A-Z]{16}'; then
    DETECTED_REASON="AWS Access Key ID (AKIA...)"
fi

# 5. AWS Secret Access Key (common variable assignments)
if [ -z "$DETECTED_REASON" ] && content_matches 'AWS_SECRET_ACCESS_KEY\s*=\s*['\''"][a-zA-Z0-9/+]{20,}'; then
    DETECTED_REASON="AWS Secret Access Key assignment"
fi

# 6. PEM/Private Key headers
if [ -z "$DETECTED_REASON" ] && content_matches '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'; then
    DETECTED_REASON="Private key block (-----BEGIN ... PRIVATE KEY-----)"
fi

# 7. API_KEY or API_SECRET hardcoded assignments
#    Matches: API_KEY = 'abc123', API_KEY="abc123xyz"
if [ -z "$DETECTED_REASON" ] && content_matches "API_KEY\s*=\s*['\"][a-zA-Z0-9_\-]{8,}['\"]"; then
    DETECTED_REASON="Hardcoded API_KEY assignment"
fi

if [ -z "$DETECTED_REASON" ] && content_matches "API_SECRET\s*=\s*['\"][a-zA-Z0-9_\-]{8,}['\"]"; then
    DETECTED_REASON="Hardcoded API_SECRET assignment"
fi

# 8. Hardcoded password assignments
#    Matches: password = 'abc123', PASSWORD="abc123", passwd='...'
if [ -z "$DETECTED_REASON" ] && content_matches "[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]\s*=\s*['\"][^'\"]{4,}['\"]"; then
    DETECTED_REASON="Hardcoded password assignment"
fi

if [ -z "$DETECTED_REASON" ] && content_matches "[Pp][Aa][Ss][Ss][Ww][Dd]\s*=\s*['\"][^'\"]{4,}['\"]"; then
    DETECTED_REASON="Hardcoded passwd assignment"
fi

# 9. GitHub / GitLab personal access tokens
if [ -z "$DETECTED_REASON" ] && content_matches 'gh[ps]_[a-zA-Z0-9]{36,}'; then
    DETECTED_REASON="GitHub personal access token (ghp_/ghs_...)"
fi

if [ -z "$DETECTED_REASON" ] && content_matches 'glpat-[a-zA-Z0-9_-]{20,}'; then
    DETECTED_REASON="GitLab personal access token (glpat-...)"
fi

# 10. Generic bearer token assignments
if [ -z "$DETECTED_REASON" ] && content_matches 'Bearer [a-zA-Z0-9_\-\.]{20,}'; then
    DETECTED_REASON="Hardcoded Bearer token"
fi

# ---------------------------------------------------------------------------
# Output decision
# ---------------------------------------------------------------------------
if [ -n "$DETECTED_REASON" ]; then
    # Escape file path and reason for safe JSON embedding
    SAFE_REASON=$(echo "$DETECTED_REASON" | sed 's/"/\\"/g' 2>/dev/null) || SAFE_REASON="Potential secret detected"
    SAFE_FILE=$(echo "$FILE_PATH" | sed 's/"/\\"/g' 2>/dev/null) || SAFE_FILE="unknown"

    printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "BLOCKED: Potential secret detected in %s - %s. Remove secrets before writing. Use environment variables or a secrets manager instead."}}\n' \
        "$SAFE_FILE" "$SAFE_REASON"
    exit 0
fi

# No secrets found - approve
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "approve", "permissionDecisionReason": "Security scan passed: no secrets detected"}}'
exit 0
