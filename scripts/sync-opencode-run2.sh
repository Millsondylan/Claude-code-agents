#!/usr/bin/env bash
# sync-opencode-run2.sh
# Sync .opencode/agents/, .opencode/rules/, opencode.json, and .claude/agents/ from Claude-code-agents to target.
# PRESERVES: .opencode/package.json, .opencode/bun.lock in target (script does not touch them).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-/Users/dyl/WORK/AIWebOptimizer}"

# Validate: target exists
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

# Validate: target != source (canonical paths)
SOURCE_CANON="$(cd "$SOURCE_DIR" && pwd)"
TARGET_CANON="$(cd "$TARGET_DIR" && pwd)"
if [[ "$SOURCE_CANON" == "$TARGET_CANON" ]]; then
  echo "Error: Target must not be the same as source." >&2
  exit 1
fi

echo "Syncing OpenCode from $SOURCE_DIR to $TARGET_DIR"
echo "  - .opencode/agents/"
echo "  - .opencode/rules/"
echo "  - .opencode/opencode.json"
echo "  - .claude/agents/"
echo "  (Preserving .opencode/package.json and .opencode/bun.lock in target)"
echo ""

# rsync -a --delete for agents and rules (trailing slash on source)
rsync -a --delete "$SOURCE_DIR/.opencode/agents/" "$TARGET_DIR/.opencode/agents/"
rsync -a --delete "$SOURCE_DIR/.opencode/rules/" "$TARGET_DIR/.opencode/rules/"

# cp for opencode.json
cp "$SOURCE_DIR/.opencode/opencode.json" "$TARGET_DIR/.opencode/opencode.json"

# .claude/agents/ (Cursor/Codex may read from here; keep in sync with .opencode/agents/)
if [[ -d "$SOURCE_DIR/.claude/agents" ]]; then
  mkdir -p "$TARGET_DIR/.claude/agents"
  rsync -a --delete "$SOURCE_DIR/.claude/agents/" "$TARGET_DIR/.claude/agents/"
fi

echo "Sync complete."
