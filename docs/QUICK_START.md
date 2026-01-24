# Quick Start Guide

## Overview

This is the Claude Code Multi-Agent Framework - a 9-stage pipeline for orchestrated software development with specialized agents.

## Installation

### Global Installation (Recommended)

To use this framework globally across all projects:

```bash
# Clone or copy this repository
git clone <repo-url> ~/Claude-code-agents

# Symlink global configuration
ln -sf ~/Claude-code-agents/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/Claude-code-agents/.claude/agents ~/.claude/agents
ln -sf ~/Claude-code-agents/.claude/commands ~/.claude/commands
```

### Per-Project Installation

To use in a specific project only:

```bash
# Copy the necessary files to your project
cp -r /path/to/Claude-code-agents/.claude /path/to/your/project/
cp /path/to/Claude-code-agents/CLAUDE.md /path/to/your/project/
cp -r /path/to/Claude-code-agents/.ai /path/to/your/project/
```

## Pipeline Stages

| Stage | Agent | Purpose |
|-------|-------|---------|
| 0 | task-breakdown | Analyze request, create TaskSpec |
| 1 | code-discovery | Explore codebase, create RepoProfile |
| 2 | plan-agent | Create implementation plan |
| 3 | web-syntax-researcher | Research APIs/syntax (if needed) |
| 4 | build-agent | Implement features (if code needed) |
| 5 | debugger | Fix errors (if any) |
| 6 | test-agent | Run tests (ALWAYS) |
| 7 | review-agent | Review changes (ALWAYS) |
| 8 | decide-agent | Final decision (ALWAYS) |

## Usage

### Starting the Pipeline

Simply make a request to Claude Code. The orchestrator will:
1. Dispatch to task-breakdown
2. Progress through all required stages
3. Report status at each stage
4. Complete when decide-agent outputs COMPLETE

### Slash Commands

- `/pipeline` - Start the multi-agent pipeline
- `/status` - Show current pipeline status
- `/restart` - Restart from Stage 0

### Example Session

```
User: Add a health check endpoint to the API

Orchestrator:
## Pipeline Status
- [ ] Stage 0: task-breakdown (IN PROGRESS)
...

Dispatching to task-breakdown...

[task-breakdown completes]

## Pipeline Status
- [x] Stage 0: task-breakdown [Run 1]
- [ ] Stage 1: code-discovery (IN PROGRESS)
...

[continues through all stages until decide-agent outputs COMPLETE]
```

## Key Concepts

### Agent Outputs

- **task-breakdown** -> TaskSpec
- **code-discovery** -> RepoProfile
- **plan-agent** -> Implementation Plan
- **build-agent** -> Build Report
- **debugger** -> Debug Report
- **test-agent** -> Test Report
- **review-agent** -> Review Report
- **decide-agent** -> COMPLETE / RESTART / ESCALATE

### Re-run Rules

- All agents except decide-agent can be re-run
- decide-agent is terminal - can only output decisions

## Response Format

Every orchestrator response includes:

```markdown
## Pipeline Status
[Stage checklist]

## Re-run Status
Pipeline Iteration: [N]
Current Stage: [name]
Agent Re-runs: [count]

## Agent Dispatch Chain
[Sequential list of agents]

## Current Action
Dispatching to: [agent]
Objective: [what]

## Previous Stage Results
[Summary]

## Next Steps
[What's next]
```

## Troubleshooting

### Pipeline Stuck

1. Check current stage status
2. Look for agent REQUEST outputs
3. If debugger requested, it will be dispatched

### Tests Failing

Test-agent will automatically request debugger on any failure.
The loop continues until tests pass or escalate.

### Decide-Agent Outputs RESTART

This restarts the entire pipeline from Stage 0 with fresh context.

### Decide-Agent Outputs ESCALATE

User intervention required. Review the escalation reason and provide guidance.
