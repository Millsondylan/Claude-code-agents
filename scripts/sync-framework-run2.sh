#!/bin/bash
# sync-framework-run2.sh
# Sync framework from Claude-code-agents to a target project (e.g. AIWebOptimizer).
#
# Usage: ./scripts/sync-framework-run2.sh [TARGET_DIR] [--with-claude]
#
# Default target: /Users/dyl/WORK/AIWebOptimizer
#
# Order:
#   F1: rsync .opencode/ → target (excl. node_modules)
#   F2: rsync .ai/ → target (excl. node_modules, dist, *.bak), then merge .ai/README.md
#   F3: merge CLAUDE.md and AGENTS.md via merge-project-specific.sh
#   F4: If --with-claude: rsync .claude/ (excl. logs, observability, session prompts)
#
# Exclusions: node_modules, dist, *.bak, hooks/logs, hooks/observability,
#             .prompts/202*.md, .repo-profile-run*.md
#
# Preserves target app code - only overwrites framework files.

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve source directory (repo root containing this script's parent).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MERGE_SCRIPT="${SCRIPT_DIR}/merge-project-specific.sh"

# ---------------------------------------------------------------------------
# Default target and parse args.
# ---------------------------------------------------------------------------
DEFAULT_TARGET="/Users/dyl/WORK/AIWebOptimizer"
WITH_CLAUDE=false
TARGET_DIR=""

for arg in "$@"; do
    if [[ "$arg" == "--with-claude" ]]; then
        WITH_CLAUDE=true
    elif [[ -z "$TARGET_DIR" && "$arg" != --* ]]; then
        TARGET_DIR="$arg"
    fi
done

[[ -z "$TARGET_DIR" ]] && TARGET_DIR="$DEFAULT_TARGET"

# ---------------------------------------------------------------------------
# Validate.
# ---------------------------------------------------------------------------
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: target directory does not exist: ${TARGET_DIR}" >&2
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if [[ "$TARGET_DIR" == "$SOURCE_DIR" ]]; then
    echo "Error: target and source are the same directory." >&2
    exit 1
fi

if [[ ! -f "$MERGE_SCRIPT" ]]; then
    echo "Error: merge helper not found: ${MERGE_SCRIPT}" >&2
    exit 1
fi

echo "=== Framework Sync (Run 2) ==="
echo "Source : ${SOURCE_DIR}"
echo "Target : ${TARGET_DIR}"
echo "With .claude: ${WITH_CLAUDE}"
echo ""

# ---------------------------------------------------------------------------
# F1: rsync .opencode/ → target (excl. node_modules)
# ---------------------------------------------------------------------------
echo "[F1] Syncing .opencode/..."
rsync -a --delete \
    --exclude='node_modules' \
    "${SOURCE_DIR}/.opencode/" "${TARGET_DIR}/.opencode/"

# ---------------------------------------------------------------------------
# F2: rsync .ai/ → target (excl. node_modules, dist, *.bak, README.md), then merge README
# ---------------------------------------------------------------------------
echo "[F2] Syncing .ai/..."
rsync -a --delete \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='*.bak' \
    --exclude='README.md' \
    "${SOURCE_DIR}/.ai/" "${TARGET_DIR}/.ai/"

echo "[F2] Merging .ai/README.md (preserving project-specific block)..."
"$MERGE_SCRIPT" "${SOURCE_DIR}/.ai/README.md" "${TARGET_DIR}/.ai/README.md"

# ---------------------------------------------------------------------------
# F3: merge CLAUDE.md and AGENTS.md (preserving project-specific blocks)
# ---------------------------------------------------------------------------
echo "[F3] Merging CLAUDE.md (preserving project-specific block)..."
"$MERGE_SCRIPT" "${SOURCE_DIR}/CLAUDE.md" "${TARGET_DIR}/CLAUDE.md"

echo "[F3] Merging AGENTS.md (preserving project-specific block)..."
"$MERGE_SCRIPT" "${SOURCE_DIR}/AGENTS.md" "${TARGET_DIR}/AGENTS.md"

# ---------------------------------------------------------------------------
# F4: If --with-claude, rsync .claude/ (excl. logs, observability, session prompts)
# ---------------------------------------------------------------------------
if [[ "$WITH_CLAUDE" == true ]]; then
    echo "[F4] Syncing .claude/..."
    rsync -a --delete \
        --exclude='hooks/logs' \
        --exclude='hooks/observability' \
        --exclude='.prompts/202*.md' \
        --exclude='.repo-profile-run*.md' \
        "${SOURCE_DIR}/.claude/" "${TARGET_DIR}/.claude/"
else
    echo "[F4] Skipped (use --with-claude to sync .claude/)"
fi

echo ""
echo "Sync complete."
