#!/bin/bash
# Quality Gate Hook: Post-Write File Quality Checks (PostToolUse)
# Purpose: Run language-appropriate syntax/format checks on files written by the Write tool
# Location: .claude/hooks/quality-gate.sh
# Event: PostToolUse (Write)
#
# SAFETY: Uses safe shell options. Always exits 0 (never blocks). Uses additionalContext
# to communicate results back to the agent.

set -u  # Only -u (undefined vars), not -e or pipefail

# Graceful degradation trap - on any unexpected error, exit 0 with safe context
trap 'echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PostToolUse\", \"additionalContext\": \"Quality gate encountered an error - skipping checks\"}}" && exit 0' ERR

# ---------------------------------------------------------------------------
# JSON parsing helpers: prefer jq, fall back to python3
# ---------------------------------------------------------------------------
parse_json_string() {
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
# Output helper - always exit 0 with additionalContext
# ---------------------------------------------------------------------------
output_result() {
    local message="$1"
    # Escape double quotes in message for safe JSON embedding
    local safe_msg
    safe_msg=$(printf '%s' "$message" | sed 's/"/\\"/g' 2>/dev/null) || safe_msg="$message"
    printf '{"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "%s"}}\n' "$safe_msg"
    exit 0
}

# ---------------------------------------------------------------------------
# Read stdin
# ---------------------------------------------------------------------------
INPUT=$(cat 2>/dev/null) || INPUT=""

if [ -z "$INPUT" ]; then
    output_result "Quality gate: No input received - skipping"
fi

# ---------------------------------------------------------------------------
# Extract file path from tool_input
# ---------------------------------------------------------------------------
FILE_PATH=$(parse_json_string "$INPUT" ".tool_input.file_path" "")

if [ -z "$FILE_PATH" ]; then
    output_result "Quality gate: No file path in input - skipping"
fi

if [ ! -f "$FILE_PATH" ]; then
    output_result "Quality gate: File not found on disk (${FILE_PATH}) - skipping"
fi

# ---------------------------------------------------------------------------
# Determine file extension
# ---------------------------------------------------------------------------
EXTENSION="${FILE_PATH##*.}"
BASENAME="$(basename "$FILE_PATH")"

# ---------------------------------------------------------------------------
# Run quality checks by extension
# ---------------------------------------------------------------------------

case "$EXTENSION" in

    # -----------------------------------------------------------------------
    # Shell scripts: bash syntax check
    # NOTE: Use 'if' statement to run commands that may fail without triggering
    # the ERR trap. Capturing $() exit codes separately fires the ERR trap.
    # -----------------------------------------------------------------------
    sh|bash)
        if command -v bash >/dev/null 2>&1; then
            SH_ERR=""
            if bash -n "$FILE_PATH" 2>/tmp/_qg_sh_err_$$ ; then
                output_result "Quality check: .sh file syntax OK (${BASENAME})"
            else
                SH_ERR=$(head -c 300 /tmp/_qg_sh_err_$$ 2>/dev/null | sed 's/"/\\"/g' | tr '\n' ' ' 2>/dev/null) || SH_ERR="syntax error"
                rm -f /tmp/_qg_sh_err_$$ 2>/dev/null || true
                output_result "Quality check: .sh file has syntax errors (${BASENAME}): ${SH_ERR}"
            fi
            rm -f /tmp/_qg_sh_err_$$ 2>/dev/null || true
        else
            output_result "Quality check: bash not available - skipping .sh check (${BASENAME})"
        fi
        ;;

    # -----------------------------------------------------------------------
    # Python: compile syntax check
    # NOTE: Use 'if' statement to run commands that may fail without triggering
    # the ERR trap.
    # -----------------------------------------------------------------------
    py)
        if command -v python3 >/dev/null 2>&1; then
            PY_ERR=""
            if python3 -m py_compile "$FILE_PATH" 2>/tmp/_qg_py_err_$$ ; then
                output_result "Quality check: .py file syntax OK (${BASENAME})"
            else
                PY_ERR=$(head -c 300 /tmp/_qg_py_err_$$ 2>/dev/null | sed 's/"/\\"/g' | tr '\n' ' ' 2>/dev/null) || PY_ERR="syntax error"
                rm -f /tmp/_qg_py_err_$$ 2>/dev/null || true
                output_result "Quality check: .py file has syntax errors (${BASENAME}): ${PY_ERR}"
            fi
            rm -f /tmp/_qg_py_err_$$ 2>/dev/null || true
        else
            output_result "Quality check: python3 not available - skipping .py check (${BASENAME})"
        fi
        ;;

    # -----------------------------------------------------------------------
    # Go: format check (warn only - gofmt exit code is 0 even with diffs)
    # -----------------------------------------------------------------------
    go)
        if command -v gofmt >/dev/null 2>&1; then
            DIFF_OUTPUT=$(gofmt -l "$FILE_PATH" 2>/dev/null) || DIFF_OUTPUT=""
            if [ -z "$DIFF_OUTPUT" ]; then
                output_result "Quality check: .go file format OK (${BASENAME})"
            else
                output_result "Quality check: .go file has formatting issues (${BASENAME}) - consider running gofmt [warn only]"
            fi
        else
            output_result "Quality check: gofmt not available - skipping .go format check (${BASENAME})"
        fi
        ;;

    # -----------------------------------------------------------------------
    # JSON: validity check via python3
    # -----------------------------------------------------------------------
    json)
        if command -v python3 >/dev/null 2>&1; then
            CHECK_OUTPUT=$(python3 -m json.tool "$FILE_PATH" > /dev/null 2>&1; echo $?)
            CHECK_EXIT="${CHECK_OUTPUT}"
            # Re-run to capture error message if needed
            if [ "$CHECK_EXIT" = "0" ]; then
                output_result "Quality check: .json file is valid JSON (${BASENAME})"
            else
                ERROR_MSG=$(python3 -m json.tool "$FILE_PATH" 2>&1 | head -c 200 | sed 's/"/\\"/g; s/\n/ /g' 2>/dev/null) || ERROR_MSG="invalid JSON"
                output_result "Quality check: .json file has JSON errors (${BASENAME}): ${ERROR_MSG}"
            fi
        elif command -v jq >/dev/null 2>&1; then
            if jq empty "$FILE_PATH" >/dev/null 2>&1; then
                output_result "Quality check: .json file is valid JSON (${BASENAME})"
            else
                JQ_ERR=$(jq empty "$FILE_PATH" 2>&1 | head -c 200 | sed 's/"/\\"/g' 2>/dev/null) || JQ_ERR="invalid JSON"
                output_result "Quality check: .json file has JSON errors (${BASENAME}): ${JQ_ERR}"
            fi
        else
            output_result "Quality check: No JSON validator available - skipping .json check (${BASENAME})"
        fi
        ;;

    # -----------------------------------------------------------------------
    # All other extensions: skip
    # -----------------------------------------------------------------------
    *)
        output_result "Quality check: No quality check defined for .${EXTENSION} files (${BASENAME}) - skipping"
        ;;

esac
