# OpenCode Multi-Agent Framework: Sync Guide

This document explains how to copy the OpenCode multi-agent framework to any
project directory. If you are an AI developer setting up OpenCode for a new
project, read this document in full before touching anything.

---

## What Is This Framework?

This repository uses the **OpenCode** setup (`.opencode/`) exclusively. It does
not use Claude Code (`.claude/agents/`) or Codex.

- **OpenCode** (`.opencode/`) - Uses AGENTS.md + `.opencode/agents/` + `.opencode/rules/`
- Agent definitions live in `.opencode/agents/` (source of truth — edit here)
- Orchestration rules live in `.opencode/rules/` and are referenced by `opencode.json`

---

## Directory Structure

```
Claude-code-agents/                  <- this repo (the framework source)
|
+-- AGENTS.md                        <- OpenCode orchestrator instructions (root)
+-- CLAUDE.md                        <- Same content, for Cursor/Claude Code compatibility
+-- .ai/
|   +-- README.md                    <- ACM: Agent Configuration Manifest
|   +-- schemas/                     <- 15 JSON schema files for agent outputs
|
+-- .opencode/                       <- OpenCode setup (source of truth)
|   +-- opencode.json                <- OpenCode config (model, permissions, MCP)
|   +-- agents/                      <- 84 agent definitions (edit here)
|   +-- rules/                       <- 7 orchestration rule files
|   +-- command/                     <- 4 OpenCode commands
|   +-- skills/                      <- 2 OpenCode skills (finish, prompt)
|
+-- .claude/                         <- Hooks/validators only (pipeline infrastructure)
|   +-- hooks/                       <- Validators, observability (used by pipeline)
|   +-- .prompts/                    <- Session prompts (prompt-optimizer output)
|
+-- scripts/
|   +-- sync-opencode.sh             <- Copies framework to a target project
|   +-- sync-framework-run2.sh       <- Full sync with merge (recommended)
```

---

## File Manifest: What to Copy

### ALWAYS COPY (framework core)

These files must be present in the target project for the OpenCode pipeline to work:

| Source Path | Target Path | Purpose |
|-------------|-------------|---------|
| `AGENTS.md` | `AGENTS.md` | Orchestrator system prompt for OpenCode |
| `.opencode/opencode.json` | `.opencode/opencode.json` | OpenCode config: model, permissions, MCP tools |
| `.opencode/agents/` | `.opencode/agents/` | 84 agent definitions (pipeline workers) |
| `.opencode/rules/` | `.opencode/rules/` | 7 orchestration rule files |
| `.opencode/command/` | `.opencode/command/` | 4 pipeline commands |
| `.opencode/skills/` | `.opencode/skills/` | 2 OpenCode skills |
| `.ai/README.md` | `.ai/README.md` | ACM: safety protocols and quality standards |
| `.ai/schemas/` | `.ai/schemas/` | 15 agent output schema files |

### CUSTOMIZE PER PROJECT (edit after copying)

These files are copied but must be updated to reflect the target project:

| File | What to Change |
|------|---------------|
| `AGENTS.md` | Update the `<!-- PROJECT-SPECIFIC -->` section with tech stack and patterns |
| `.opencode/opencode.json` | Update `"model"` or `"provider"` if using a different API key setup |

### DO NOT COPY (source-repo-specific)

These files belong to this repository only and should not be copied to target projects:

| Path | Reason |
|------|--------|
| `.claude/agents/` | Deprecated — not used (opencode-only) |
| `.claude/commands/` | Claude Code specific — not used |
| `.claude/skills/` | Claude Code specific — not used |
| `.claude/settings.json` | Claude Code specific — not used |
| `model-switch/` | Go router proxy for model switching - this repo only |
| `docs/` | This repo's documentation - does not need to be replicated |

---

## Quick Start: Sync to a Target Project

### Option 1: Use the helper script (recommended)

```bash
# From the framework repo root:
./scripts/sync-opencode.sh /path/to/your/project
```

The script copies all required framework files, creates missing directories,
and prints a post-sync checklist.

### Option 2: Manual rsync one-liner

Run this from the framework repo root to copy all OpenCode framework files:

```bash
TARGET=/path/to/your/project

# Core config and instruction files
rsync -av AGENTS.md "$TARGET/AGENTS.md"
rsync -av .ai/README.md "$TARGET/.ai/README.md"

# Schema files
rsync -av --mkpath .ai/schemas/ "$TARGET/.ai/schemas/"

# OpenCode config, agents, and rules
rsync -av --mkpath .opencode/opencode.json "$TARGET/.opencode/opencode.json"
rsync -av --mkpath .opencode/agents/ "$TARGET/.opencode/agents/"
rsync -av --mkpath .opencode/rules/ "$TARGET/.opencode/rules/"
rsync -av --mkpath .opencode/command/ "$TARGET/.opencode/command/"
rsync -av --mkpath .opencode/skills/ "$TARGET/.opencode/skills/"
```

---

## Post-Sync Checklist

After running the sync, verify the setup is correct:

1. **Verify agent count**
   ```bash
   ls /path/to/your/project/.opencode/agents/ | wc -l
   # Should print 83
   ```

2. **Verify rules are present**
   ```bash
   ls /path/to/your/project/.opencode/rules/
   # Should list 7 files: 01- through 07-
   ```

3. **Verify ACM is present**
   ```bash
   test -f /path/to/your/project/.ai/README.md && echo "OK"
   ```

4. **Verify opencode.json is valid JSON**
   ```bash
   python3 -m json.tool /path/to/your/project/.opencode/opencode.json > /dev/null && echo "OK"
   ```

5. **Customize AGENTS.md for the target project**

   Open `AGENTS.md` in the target project and update the `PROJECT-SPECIFIC` section:

   ```markdown
   <!-- PROJECT-SPECIFIC - AUTO-UPDATED - START -->

   ## Project Context

   ### Tech Stack
   - Language: TypeScript / Node.js 20
   - Framework: Next.js 14
   - Database: PostgreSQL via Prisma
   - Testing: Vitest

   ### Patterns
   - All components in src/components/
   - API routes under src/app/api/
   - Services follow repository pattern
   <!-- PROJECT-SPECIFIC - AUTO-UPDATED - END -->
   ```

6. **Verify OpenCode loads agents**

   Launch OpenCode in the target project directory and type `@` to open the agent
   autocomplete. You should see `pipeline-scaler` and `task-breakdown` listed
   (the two non-hidden entry-point agents).

---

## Use Only This Repo's OpenCode Setup

If you have multiple OpenCode configs (e.g. `~/.config/opencode/`, other projects), force this repo to use only its local `.opencode/`:

**Option A: Source the script (each terminal session)**
```bash
source scripts/use-local-opencode.sh
# or: . scripts/use-local-opencode.sh
```

**Option B: direnv (auto-load when you `cd` into the repo)**
```bash
direnv allow   # one-time, after installing direnv
```

This sets `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` so OpenCode ignores global and other project configs.

---

## OpenCode-Only Setup

This repo uses `.opencode/` as the single source of truth:

- **Edit agents** in `.opencode/agents/` — they are not generated from elsewhere
- **Edit rules** in `.opencode/rules/` — referenced by `opencode.json`
- `AGENTS.md` and `CLAUDE.md` contain the same pipeline instructions (for Cursor/Claude Code compatibility)
- `.claude/agents/` and `generate-agents.sh` are deprecated — do not use

---

## Troubleshooting

**OpenCode does not show agents in @ autocomplete**

Verify that `AGENTS.md` is present in the project root (not just `.opencode/`).
OpenCode reads this file as the system prompt and discovers agents from the
`.opencode/agents/` directory.

**Pipeline fails with "agent not found" errors**

The `opencode.json` instructions array references `rules/` (relative to `.opencode/`).
Ensure `.opencode/rules/` was copied to the target.

**Agents run with the wrong model**

Check `.opencode/opencode.json` - the `"model"` field sets the default for all
agents. Individual agents can override this in their frontmatter. Ensure your
Anthropic API key has access to the configured model.

**ACM safety rules not enforced**

The `.ai/README.md` (Agent Configuration Manifest) must be present. All agents
read it at session start for anti-destruction rules, safety protocols, and quality
standards. If it is missing, regenerate from source or copy it manually.
