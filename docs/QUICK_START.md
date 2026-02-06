# Quick Start Guide

## Overview

This is the Claude Code Multi-Agent Framework - a 15-stage pipeline for orchestrated software development with specialized agents.

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
| -1 | prompt-optimizer | Optimize prompts before dispatch |
| 0 | task-breakdown | Analyze request, create TaskSpec |
| 1 | code-discovery | Explore codebase, create RepoProfile |
| 2 | plan-agent | Create implementation plan |
| 3 | docs-researcher | Research library documentation (Context7 MCP) |
| 3.5 | pre-flight-checker | Pre-implementation sanity checks |
| 4 | build-agent-1 to 55 | Implement features (55 agents) |
| 5 | debugger to debugger-11 | Fix errors (11 agents) |
| 5.5 | logical-agent | Verify code logic correctness |
| 6 | test-agent | Run tests (ALWAYS) |
| 6.5 | integration-agent | Integration testing |
| 7 | review-agent | Review changes (ALWAYS) |
| 8 | decide-agent | Final decision (ALWAYS) |

## Usage

### Starting the Pipeline

Simply make a request to Claude Code. The orchestrator will:
1. Dispatch to prompt-optimizer first
2. Then dispatch to task-breakdown
3. Progress through all required stages
4. Report status at each stage
5. Complete when decide-agent outputs COMPLETE

### Slash Commands

- `/pipeline` - Start the multi-agent pipeline
- `/status` - Show current pipeline status
- `/restart` - Restart from Stage 0

### Example Session

```
User: Add a health check endpoint to the API

Orchestrator:
## Pipeline Status
- [ ] Stage -1: prompt-optimizer (IN PROGRESS)
...

Dispatching to prompt-optimizer...

[prompt-optimizer completes]

## Pipeline Status
- [x] Stage -1: prompt-optimizer
- [ ] Stage 0: task-breakdown (IN PROGRESS)
...

Dispatching to task-breakdown...

[task-breakdown completes]

## Pipeline Status
- [x] Stage -1: prompt-optimizer
- [x] Stage 0: task-breakdown
- [ ] Stage 1: code-discovery (IN PROGRESS)
...

[continues through all stages until decide-agent outputs COMPLETE]
```

## Key Concepts

### Agent Outputs

- **prompt-optimizer** -> Optimized Prompt (XML structured)
- **task-breakdown** -> TaskSpec
- **code-discovery** -> RepoProfile
- **plan-agent** -> Implementation Plan
- **docs-researcher** -> Documentation Research
- **pre-flight-checker** -> Pre-flight Report
- **build-agent-1 to 55** -> Build Report
- **debugger to debugger-11** -> Debug Report
- **logical-agent** -> Logic Verification Report
- **test-agent** -> Test Report
- **integration-agent** -> Integration Test Report
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
