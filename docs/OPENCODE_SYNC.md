# OpenCode Multi-Agent Framework: Sync Guide

This document explains how to copy the OpenCode multi-agent framework to any
project directory. If you are an AI developer setting up OpenCode for a new
project, read this document in full before touching anything.

---

## What Is This Framework?

This repository contains a multi-agent orchestration framework that works with
two AI coding tools simultaneously:

- **Claude Code** (`.claude/`) - Anthropic's CLI, uses CLAUDE.md + `.claude/agents/`
- **OpenCode** (`.opencode/`) - An alternative AI coding tool, uses AGENTS.md + `.opencode/agent/`

Both tools run the same pipeline of specialized agents that decompose tasks,
discover code, plan implementations, build features, write tests, debug errors,
and make completion decisions. The agent definitions live in `.claude/agents/`
(the source of truth) and are generated into `.opencode/agent/` by a conversion
script.

The `.claude/rules/` directory contains shared orchestration rules that are
loaded by both tools - Claude Code loads them as project instructions and
`opencode.json` references them in its `instructions` array.

---

## Directory Structure

```
Claude-code-agents/                  <- this repo (the framework source)
|
+-- AGENTS.md                        <- OpenCode orchestrator instructions (root)
+-- CLAUDE.md                        <- Claude Code orchestrator instructions (root)
+-- .ai/
|   +-- README.md                    <- ACM: Agent Configuration Manifest
|   +-- schemas/                     <- 15 JSON schema files for agent outputs
|       +-- taskspec-schema.md
|       +-- repoprofile-schema.md
|       +-- pipeline-context-schema.md
|       +-- ... (12 more)
|
+-- .claude/
|   +-- agents/                      <- SOURCE: 84 Claude Code agent definitions
|   +-- rules/                       <- Shared orchestration rules (5 files)
|   +-- commands/                    <- Claude Code slash commands
|   +-- skills/                      <- Claude Code skills
|   +-- hooks/                       <- Claude Code quality/security hooks
|   +-- settings.json                <- Claude Code tool permissions
|
+-- .opencode/
|   +-- opencode.json                <- OpenCode config (model, permissions, MCP)
|   +-- agent/                       <- GENERATED: 83 OpenCode agent definitions
|   +-- command/                     <- 4 OpenCode commands (pipeline, prompt, restart, status)
|   +-- skills/                      <- 2 OpenCode skills (finish, prompt)
|   +-- generate-agents.sh           <- Conversion script: .claude/agents/ -> .opencode/agent/
|
+-- scripts/
|   +-- sync-opencode.sh             <- Helper: copies framework to a target project
+-- sync-to-global.sh                <- Syncs Claude Code framework globally or to a repo
```

---

## File Manifest: What to Copy

### ALWAYS COPY (framework core)

These files must be present in the target project for the OpenCode pipeline to work:

| Source Path | Target Path | Purpose |
|-------------|-------------|---------|
| `AGENTS.md` | `AGENTS.md` | Orchestrator system prompt for OpenCode |
| `.opencode/opencode.json` | `.opencode/opencode.json` | OpenCode config: model, permissions, MCP tools |
| `.opencode/agent/` | `.opencode/agent/` | 83 agent definitions (pipeline workers) |
| `.opencode/command/` | `.opencode/command/` | 4 pipeline commands |
| `.opencode/skills/` | `.opencode/skills/` | 2 OpenCode skills |
| `.opencode/generate-agents.sh` | `.opencode/generate-agents.sh` | Agent regeneration script |
| `.ai/README.md` | `.ai/README.md` | ACM: safety protocols and quality standards |
| `.ai/schemas/` | `.ai/schemas/` | 15 agent output schema files |
| `.claude/rules/` | `.claude/rules/` | 5 shared orchestration rule files |

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
| `.claude/agents/` | Claude Code versions - only needed if using Claude Code in the target |
| `.claude/commands/` | Claude Code commands - only needed if using Claude Code in the target |
| `.claude/skills/` | Claude Code skills - only needed if using Claude Code in the target |
| `.claude/hooks/` | Claude Code quality/security hooks - Claude Code specific |
| `.claude/settings.json` | Claude Code tool permissions - Claude Code specific |
| `model-switch/` | Go router proxy for model switching - this repo only |
| `docs/` | This repo's documentation - does not need to be replicated |
| `sync-to-global.sh` | Utility for syncing this repo globally - not a framework file |

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

# Shared orchestration rules
rsync -av --mkpath .claude/rules/ "$TARGET/.claude/rules/"

# OpenCode config and agents
rsync -av --mkpath .opencode/opencode.json "$TARGET/.opencode/opencode.json"
rsync -av --mkpath .opencode/agent/ "$TARGET/.opencode/agent/"
rsync -av --mkpath .opencode/command/ "$TARGET/.opencode/command/"
rsync -av --mkpath .opencode/skills/ "$TARGET/.opencode/skills/"
rsync -av .opencode/generate-agents.sh "$TARGET/.opencode/generate-agents.sh"
chmod +x "$TARGET/.opencode/generate-agents.sh"
```

---

## Post-Sync Checklist

After running the sync, verify the setup is correct:

1. **Verify agent count**
   ```bash
   ls /path/to/your/project/.opencode/agent/ | wc -l
   # Should print 83
   ```

2. **Verify rules are present**
   ```bash
   ls /path/to/your/project/.claude/rules/
   # Should list 5 files: 01- through 05-
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

## How to Regenerate Agents

The `.opencode/agent/` files are generated from `.claude/agents/`. If you ever
update the source agent definitions in `.claude/agents/` (e.g., to add new agents
or change prompts), run the generation script to rebuild the OpenCode versions:

```bash
# From within this framework repo:
./.opencode/generate-agents.sh
```

The script:
- Reads each `.md` file from `.claude/agents/`
- Converts Claude Code frontmatter fields (model aliases, tool names, colors) to
  OpenCode equivalents
- Writes transformed files to `.opencode/agent/`
- Is idempotent: safe to re-run at any time

After regenerating, re-run the sync to push the updated agents to target projects:

```bash
./scripts/sync-opencode.sh /path/to/your/project
```

### What the Generator Converts

| Claude Code | OpenCode |
|-------------|----------|
| `model: opus` | `model: anthropic/claude-opus-4-6` |
| `model: sonnet` | `model: anthropic/claude-sonnet-4-6` |
| `model: haiku` | `model: anthropic/claude-haiku-4-5-20251001` |
| `model: inherit` | (field omitted) |
| `color: purple` | `color: "#800080"` |
| `tools: Write, Read, Edit` | `tools:\n  write: true\n  read: true\n  edit: true` |
| `pipeline-scaler.md` | `hidden: false, mode: primary` |
| all other agents | `hidden: true, mode: subagent` |

---

## Relationship Between .claude/ and .opencode/

Understanding how these two directories relate is important for maintenance:

```
.claude/agents/          <- EDIT HERE (source of truth for agent prompts)
       |
       | generate-agents.sh
       v
.opencode/agent/         <- DO NOT EDIT (auto-generated, will be overwritten)


.claude/rules/           <- SHARED (referenced by both tools)
       |                    Claude Code: loaded as project instructions
       +----------------------> .opencode/opencode.json "instructions" array
                               OpenCode: loaded via opencode.json


CLAUDE.md                <- Claude Code orchestrator instructions
AGENTS.md                <- OpenCode orchestrator instructions
       |
       | Both reference .claude/rules/ for detailed pipeline rules
       | Both reference .ai/README.md (ACM) for safety protocols
```

### Key Principle: Single Source of Truth

- All agent logic lives in `.claude/agents/` - edit there, then regenerate
- The `.opencode/agent/` directory is a build artifact - never edit it directly
- The `.claude/rules/` files are shared between both tools - changes there affect both
- `AGENTS.md` and `CLAUDE.md` contain the same pipeline table but are formatted
  for their respective tools (OpenCode uses lowercase tool names, Claude Code uses
  Title Case)

---

## Troubleshooting

**OpenCode does not show agents in @ autocomplete**

Verify that `AGENTS.md` is present in the project root (not just `.opencode/`).
OpenCode reads this file as the system prompt and discovers agents from the
`.opencode/agent/` directory.

**Pipeline fails with "agent not found" errors**

The `opencode.json` instructions array references `.claude/rules/` with relative
paths. Ensure the `.claude/rules/` directory was copied to the target. The
`opencode.json` uses `../` paths (e.g., `"../.claude/rules/01-pipeline-orchestration.md"`),
so it expects the rules to be one directory above `.opencode/`.

**Agents run with the wrong model**

Check `.opencode/opencode.json` - the `"model"` field sets the default for all
agents. Individual agents can override this in their frontmatter. Ensure your
Anthropic API key has access to the configured model.

**ACM safety rules not enforced**

The `.ai/README.md` (Agent Configuration Manifest) must be present. All agents
read it at session start for anti-destruction rules, safety protocols, and quality
standards. If it is missing, regenerate from source or copy it manually.
