#!/bin/bash
# Syncs agent framework to global ~/.claude/ and optionally to a repo
# Copies ALL components: agents, commands, skills, settings, ACM, CLAUDE.md, .mcp.json

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

sync_to_global() {
    TARGET_DIR="$HOME/.claude"
    echo "Syncing to ~/.claude/..."

    # Ensure target exists
    mkdir -p "$TARGET_DIR"

    # Copy CLAUDE.md to user home (global instructions)
    cp "$SOURCE_DIR/CLAUDE.md" "$HOME/CLAUDE.md"

    # Copy all .claude subdirectories
    rm -rf "$TARGET_DIR/agents" && cp -r "$SOURCE_DIR/.claude/agents" "$TARGET_DIR/agents"
    rm -rf "$TARGET_DIR/commands" && cp -r "$SOURCE_DIR/.claude/commands" "$TARGET_DIR/commands"
    rm -rf "$TARGET_DIR/skills" && cp -r "$SOURCE_DIR/.claude/skills" "$TARGET_DIR/skills" 2>/dev/null || true

    # Copy settings
    cp "$SOURCE_DIR/.claude/settings.json" "$TARGET_DIR/settings.json"

    # Copy MCP config
    cp "$SOURCE_DIR/.mcp.json" "$HOME/.mcp.json"

    echo "✓ Global sync complete"
    echo "  - ~/CLAUDE.md"
    echo "  - ~/.claude/agents/ ($(ls -1 "$TARGET_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ') agents)"
    echo "  - ~/.claude/commands/"
    echo "  - ~/.claude/skills/"
    echo "  - ~/.claude/settings.json"
    echo "  - ~/.mcp.json"
}

sync_to_repo() {
    REPO="$1"
    if [ -z "$REPO" ]; then echo "Usage: $0 repo /path/to/repo"; exit 1; fi
    if [ ! -d "$REPO" ]; then echo "Error: $REPO is not a directory"; exit 1; fi

    echo "Syncing to $REPO..."

    # Create directories
    mkdir -p "$REPO/.claude" "$REPO/.ai"

    # Copy CLAUDE.md (orchestrator instructions)
    cp "$SOURCE_DIR/CLAUDE.md" "$REPO/CLAUDE.md"

    # Copy all .claude subdirectories
    rm -rf "$REPO/.claude/agents" && cp -r "$SOURCE_DIR/.claude/agents" "$REPO/.claude/"
    rm -rf "$REPO/.claude/commands" && cp -r "$SOURCE_DIR/.claude/commands" "$REPO/.claude/"
    rm -rf "$REPO/.claude/skills" && cp -r "$SOURCE_DIR/.claude/skills" "$REPO/.claude/" 2>/dev/null || true

    # Copy settings
    cp "$SOURCE_DIR/.claude/settings.json" "$REPO/.claude/"

    # Copy ACM (Agent Configuration Manifest)
    cp "$SOURCE_DIR/.ai/README.md" "$REPO/.ai/"

    # Copy MCP config
    cp "$SOURCE_DIR/.mcp.json" "$REPO/"

    echo "✓ Repo sync complete: $REPO"
    echo "  - CLAUDE.md"
    echo "  - .claude/agents/ ($(ls -1 "$REPO/.claude/agents"/*.md 2>/dev/null | wc -l | tr -d ' ') agents)"
    echo "  - .claude/commands/"
    echo "  - .claude/skills/"
    echo "  - .claude/settings.json"
    echo "  - .ai/README.md (ACM)"
    echo "  - .mcp.json"
}

list_contents() {
    echo "=== Source Framework Contents ==="
    echo ""
    echo "CLAUDE.md (orchestrator instructions)"
    echo ""
    echo "Agents (.claude/agents/):"
    for f in "$SOURCE_DIR/.claude/agents"/*.md; do
        name=$(basename "$f" .md)
        model=$(grep "^model:" "$f" | cut -d' ' -f2)
        echo "  - $name ($model)"
    done
    echo ""
    echo "Commands: $(ls -1 "$SOURCE_DIR/.claude/commands" 2>/dev/null | wc -l | tr -d ' ') files"
    echo "Skills: $(ls -1 "$SOURCE_DIR/.claude/skills" 2>/dev/null | wc -l | tr -d ' ') files"
    echo "ACM: .ai/README.md"
    echo "MCP: .mcp.json"
}

case "$1" in
    global) sync_to_global ;;
    repo) sync_to_repo "$2" ;;
    list) list_contents ;;
    *)
        echo "Multi-Agent Framework Sync Tool"
        echo ""
        echo "Usage: $0 {global|repo|list}"
        echo ""
        echo "  global          - Sync to ~/.claude/ (user-level)"
        echo "  repo /path      - Sync to specific repo (project-level)"
        echo "  list            - Show framework contents"
        ;;
esac
