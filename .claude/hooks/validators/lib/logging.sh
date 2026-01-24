#!/bin/bash
# Shared logging library for validators
# Writes JSONL logs to .claude/hooks/logs/
#
# SAFETY: This library uses safe shell options to prevent failures from
# breaking the validator. Uses || true patterns for potentially failing commands.

# Get the validators directory (parent of lib) - with fallback
VALIDATORS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." 2>/dev/null && pwd)" || VALIDATORS_DIR="."
LOGS_DIR="${VALIDATORS_DIR}/../logs"

# Ensure logs directory exists (silently ignore failures)
mkdir -p "$LOGS_DIR" 2>/dev/null || true

# write_log - Write validation result to JSONL log file
# Arguments:
#   $1 - agent_name: Name of the agent being validated
#   $2 - is_valid: "true" or "false"
#   $3 - errors_json: JSON array of error strings
#   $4 - warnings_json: JSON array of warning strings
#   $5 - output_preview: First ~500 chars of the agent output
#
# This function never fails - silently ignores errors to prevent blocking
write_log() {
    local agent_name="${1:-unknown}"
    local is_valid="${2:-true}"
    local errors_json="${3:-[]}"
    local warnings_json="${4:-[]}"
    local output_preview="${5:-}"

    # Use date with fallback
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || timestamp="unknown"
    local file_timestamp
    file_timestamp=$(date -u +"%Y%m%d_%H%M%S" 2>/dev/null) || file_timestamp="unknown"

    local result="pass"
    [ "$is_valid" != "true" ] && result="fail"

    local log_file="$LOGS_DIR/${file_timestamp}_${agent_name}_${result}.log"

    # Escape preview for JSON (newlines to spaces, escape quotes) - with fallbacks
    local escaped_preview=""
    if [ -n "$output_preview" ]; then
        escaped_preview=$(echo "$output_preview" | head -c 200 2>/dev/null | tr '\n' ' ' 2>/dev/null | sed 's/"/\\"/g' 2>/dev/null | sed "s/'/\\\\'/g" 2>/dev/null) || escaped_preview="(preview unavailable)"
    fi

    # Write JSONL format (silently ignore write failures)
    echo "{\"timestamp\":\"$timestamp\",\"agent\":\"$agent_name\",\"valid\":$is_valid,\"errors\":$errors_json,\"warnings\":$warnings_json,\"preview\":\"$escaped_preview\"}" >> "$log_file" 2>/dev/null || true
}
