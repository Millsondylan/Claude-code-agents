#!/bin/bash
# use-local-opencode.sh
# Force OpenCode to use ONLY this repo's .opencode/ setup.
# Ignores ~/.config/opencode/, other projects' .opencode/, etc.
#
# Usage: source scripts/use-local-opencode.sh
#    or: . scripts/use-local-opencode.sh
#
# Run this before launching OpenCode when working in this repo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OPENCODE_DIR="${REPO_ROOT}/.opencode"
CONFIG_FILE="${OPENCODE_DIR}/opencode.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: opencode.json not found at ${CONFIG_FILE}" >&2
    return 1 2>/dev/null || exit 1
fi

export OPENCODE_CONFIG="$CONFIG_FILE"
export OPENCODE_CONFIG_DIR="$OPENCODE_DIR"

echo "OpenCode locked to this repo's setup:"
echo "  OPENCODE_CONFIG=$OPENCODE_CONFIG"
echo "  OPENCODE_CONFIG_DIR=$OPENCODE_CONFIG_DIR"
echo ""
echo "Launch OpenCode from this directory. Other configs are ignored."
