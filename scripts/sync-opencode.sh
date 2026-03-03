#!/bin/bash
# sync-opencode.sh
# Copies the OpenCode multi-agent framework to a target project directory.
#
# Usage: ./scripts/sync-opencode.sh /path/to/target/project
#
# What gets copied:
#   AGENTS.md                     <- OpenCode orchestrator instructions
#   .ai/README.md                 <- ACM: safety protocols and quality standards
#   .ai/schemas/                  <- 15 agent output schema files
#   .claude/rules/                <- 5 shared orchestration rule files
#   .opencode/opencode.json       <- OpenCode config (model, permissions, MCP)
#   .opencode/agent/              <- 83 generated agent definitions
#   .opencode/command/            <- 4 pipeline commands
#   .opencode/skills/             <- 2 OpenCode skills
#   .opencode/generate-agents.sh  <- Agent regeneration script
#
# What does NOT get copied:
#   .claude/agents/   (Claude Code versions - source of truth for generation)
#   .claude/commands/ (Claude Code commands)
#   .claude/skills/   (Claude Code skills)
#   .claude/hooks/    (Claude Code hooks)
#   .claude/settings.json (Claude Code tool permissions)
#   model-switch/     (Go router proxy - this repo only)
#   docs/             (this repo's docs)

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve source directory (the repo root containing this script's parent).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Validate arguments.
# ---------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") /path/to/target/project" >&2
    echo "" >&2
    echo "Copies the OpenCode multi-agent framework files to the target directory." >&2
    echo "See docs/OPENCODE_SYNC.md for the full file manifest and post-sync steps." >&2
    exit 1
fi

TARGET_DIR="$1"

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "Error: target directory does not exist: ${TARGET_DIR}" >&2
    echo "Create it first, then re-run this script." >&2
    exit 1
fi

# Resolve to absolute path.
TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"

# Refuse to sync to the source repo itself.
if [[ "${TARGET_DIR}" == "${SOURCE_DIR}" ]]; then
    echo "Error: target and source are the same directory." >&2
    exit 1
fi

echo "=== OpenCode Framework Sync ==="
echo "Source : ${SOURCE_DIR}"
echo "Target : ${TARGET_DIR}"
echo ""

# ---------------------------------------------------------------------------
# Helper: rsync a single file, creating parent directories as needed.
# ---------------------------------------------------------------------------
sync_file() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "${dest}")"
    rsync -a "${src}" "${dest}"
}

# ---------------------------------------------------------------------------
# Helper: rsync a directory (trailing slash = contents, not dir itself).
# ---------------------------------------------------------------------------
sync_dir() {
    local src="$1"   # path without trailing slash
    local dest="$2"  # path without trailing slash
    mkdir -p "${dest}"
    rsync -a "${src}/" "${dest}/"
}

# ---------------------------------------------------------------------------
# Copy framework files.
# ---------------------------------------------------------------------------

echo "Copying orchestrator instructions..."
sync_file "${SOURCE_DIR}/AGENTS.md" "${TARGET_DIR}/AGENTS.md"

echo "Copying ACM (Agent Configuration Manifest)..."
sync_file "${SOURCE_DIR}/.ai/README.md" "${TARGET_DIR}/.ai/README.md"

echo "Copying agent output schemas..."
sync_dir "${SOURCE_DIR}/.ai/schemas" "${TARGET_DIR}/.ai/schemas"

echo "Copying shared orchestration rules..."
sync_dir "${SOURCE_DIR}/.claude/rules" "${TARGET_DIR}/.claude/rules"

echo "Copying OpenCode config..."
sync_file "${SOURCE_DIR}/.opencode/opencode.json" "${TARGET_DIR}/.opencode/opencode.json"

echo "Copying OpenCode agents ($(ls -1 "${SOURCE_DIR}/.opencode/agent/"*.md 2>/dev/null | wc -l | tr -d ' ') files)..."
sync_dir "${SOURCE_DIR}/.opencode/agent" "${TARGET_DIR}/.opencode/agent"

echo "Copying OpenCode commands..."
sync_dir "${SOURCE_DIR}/.opencode/command" "${TARGET_DIR}/.opencode/command"

echo "Copying OpenCode skills..."
sync_dir "${SOURCE_DIR}/.opencode/skills" "${TARGET_DIR}/.opencode/skills"

echo "Copying agent generator script..."
sync_file "${SOURCE_DIR}/.opencode/generate-agents.sh" "${TARGET_DIR}/.opencode/generate-agents.sh"
chmod +x "${TARGET_DIR}/.opencode/generate-agents.sh"

# ---------------------------------------------------------------------------
# Summary.
# ---------------------------------------------------------------------------
echo ""
echo "Sync complete. Files written:"
echo "  ${TARGET_DIR}/AGENTS.md"
echo "  ${TARGET_DIR}/.ai/README.md"
echo "  ${TARGET_DIR}/.ai/schemas/  ($(ls -1 "${TARGET_DIR}/.ai/schemas/" 2>/dev/null | wc -l | tr -d ' ') files)"
echo "  ${TARGET_DIR}/.claude/rules/  ($(ls -1 "${TARGET_DIR}/.claude/rules/" 2>/dev/null | wc -l | tr -d ' ') files)"
echo "  ${TARGET_DIR}/.opencode/opencode.json"
echo "  ${TARGET_DIR}/.opencode/agent/  ($(ls -1 "${TARGET_DIR}/.opencode/agent/"*.md 2>/dev/null | wc -l | tr -d ' ') agents)"
echo "  ${TARGET_DIR}/.opencode/command/  ($(ls -1 "${TARGET_DIR}/.opencode/command/" 2>/dev/null | wc -l | tr -d ' ') files)"
echo "  ${TARGET_DIR}/.opencode/skills/  ($(ls -1 "${TARGET_DIR}/.opencode/skills/" 2>/dev/null | wc -l | tr -d ' ') files)"
echo "  ${TARGET_DIR}/.opencode/generate-agents.sh"
echo ""

# ---------------------------------------------------------------------------
# Post-sync instructions.
# ---------------------------------------------------------------------------
cat <<'POST_SYNC'
Next steps:

1. Customize AGENTS.md for this project.
   Open TARGET/AGENTS.md and update the PROJECT-SPECIFIC section:

     <!-- PROJECT-SPECIFIC - AUTO-UPDATED - START -->
     ## Project Context

     ### Tech Stack
     - Language: <fill in>
     - Framework: <fill in>
     - Testing: <fill in>

     ### Patterns
     - <fill in>
     <!-- PROJECT-SPECIFIC - AUTO-UPDATED - END -->

2. Verify agent count.
     ls .opencode/agent/ | wc -l
   Should print 83.

3. Verify rules are present.
     ls .claude/rules/
   Should list 5 files: 01- through 05-.

4. Verify opencode.json is valid.
     python3 -m json.tool .opencode/opencode.json > /dev/null && echo OK

5. Launch OpenCode and type @ to confirm agents load.
   You should see pipeline-scaler and task-breakdown in autocomplete.

6. If you update .claude/agents/ in the source repo later, regenerate:
     ./.opencode/generate-agents.sh
   Then re-run this sync script.

See docs/OPENCODE_SYNC.md in the framework repo for the full reference.
POST_SYNC
