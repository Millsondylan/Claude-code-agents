# Integration Guide

## Overview

This guide explains how to integrate the Multi-Agent Framework into your workflow and customize it for your needs.

## Directory Structure

```
Claude-code-agents/
├── CLAUDE.md                    # Main orchestrator instructions
├── .ai/
│   └── README.md               # Agent Configuration Manifest (ACM)
├── .claude/
│   ├── settings.json           # Permission settings
│   ├── agents/                 # Agent definitions
│   │   ├── README.md
│   │   ├── task-breakdown.md
│   │   ├── code-discovery.md
│   │   ├── plan-agent.md
│   │   ├── web-syntax-researcher.md
│   │   ├── build-agent.md
│   │   ├── debugger.md
│   │   ├── test-agent.md
│   │   ├── review-agent.md
│   │   └── decide-agent.md
│   ├── commands/               # Slash commands
│   │   ├── pipeline.md
│   │   ├── status.md
│   │   └── restart.md
│   └── skills/                 # Custom skills (empty)
└── docs/
    ├── QUICK_START.md
    └── INTEGRATION_GUIDE.md
```

## Global vs. Project Configuration

### Global Configuration (~/.claude/)

Files in `~/.claude/` apply to ALL projects:

```
~/.claude/
├── settings.json        # Global permissions
├── CLAUDE.md           # Global instructions (can symlink)
├── agents/             # Global agent definitions (can symlink)
└── commands/           # Global slash commands (can symlink)
```

### Project Configuration (./.claude/)

Files in `./.claude/` apply only to the current project:

```
./project/
├── .claude/
│   ├── settings.json   # Project-specific permissions
│   ├── settings.local.json  # Personal settings (gitignored)
│   └── agents/         # Project-specific agents
├── CLAUDE.md           # Project instructions
├── CLAUDE.local.md     # Personal project notes (gitignored)
└── .ai/
    └── README.md       # Project ACM
```

### Precedence (highest to lowest)

1. Enterprise managed policies
2. Command line arguments
3. Local project settings (`.claude/settings.local.json`)
4. Shared project settings (`.claude/settings.json`)
5. User settings (`~/.claude/settings.json`)

## Symlinking for Global Use

To use this framework globally:

```bash
# Backup existing files
mv ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup
mv ~/.claude/agents ~/.claude/agents.backup
mv ~/.claude/commands ~/.claude/commands.backup

# Create symlinks
ln -sf /path/to/Claude-code-agents/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf /path/to/Claude-code-agents/.claude/agents ~/.claude/agents
ln -sf /path/to/Claude-code-agents/.claude/commands ~/.claude/commands
```

## Customizing Agents

### Adding a Custom Agent

1. Create a new file in `.claude/agents/`:

```markdown
# My Custom Agent

**Stage:** [number]
**Role:** [description]
**Re-run Eligible:** YES/NO

---

## Identity

You are the **My Custom Agent**...

## What You Receive
...

## Your Responsibilities
...

## What You Must Output
...

## Tools You Can Use
...

## Session Start Protocol

**MUST:**
1. Read ACM at: `<REPO_ROOT>/.ai/README.md`
2. Apply relevant rules
```

2. Update the pipeline in `CLAUDE.md` if needed
3. Update the agent README

### Modifying Existing Agents

1. Copy the agent file you want to modify
2. Make your changes
3. Keep the standard structure (Identity, Inputs, Outputs, etc.)
4. Update the Session Start Protocol path if needed

## Customizing the ACM

The ACM (`.ai/README.md`) controls:
- Safety protocols
- Quality standards
- Re-run rules

Modify these sections as needed for your organization:

```markdown
## Safety Protocols
[Add organization-specific rules]

## Quality Standards
[Define your code quality requirements]
```

## Adding Custom Slash Commands

Create a new file in `.claude/commands/`:

```markdown
# My Command

Description of what the command does.

## Instructions for Claude

When this command is invoked:
1. [Step 1]
2. [Step 2]
...
```

## Disabling the Framework

To temporarily disable the multi-agent framework:

1. Rename or remove `CLAUDE.md`
2. Or add at the top of `CLAUDE.md`:
   ```markdown
   **FRAMEWORK DISABLED - Operate normally**
   ```

## Troubleshooting

### Agents Not Found

- Check symlinks are correct
- Verify agent files exist in `.claude/agents/`
- Check file permissions

### Pipeline Not Starting

- Ensure CLAUDE.md is being loaded
- Run `/memory` to see loaded files
- Check for syntax errors in CLAUDE.md

### Wrong Agent Behavior

- Verify ACM is readable at the expected path
- Check agent definition for errors
- Ensure Session Start Protocol has correct path

## Best Practices

1. **Use Symlinks for Global Config**: Keeps everything in one place
2. **Version Control Agents**: Track changes to agent definitions
3. **Customize ACM per Project**: Different projects may need different rules
4. **Test Changes Incrementally**: Modify one agent at a time
5. **Keep Backups**: Before making major changes
