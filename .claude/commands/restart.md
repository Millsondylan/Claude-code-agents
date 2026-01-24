# Restart Pipeline

Restart the multi-agent pipeline from Stage 0.

## Usage
This command restarts the pipeline from the beginning (task-breakdown).

## Instructions for Claude

When this command is invoked:

1. **Clear current pipeline state** - Reset all stage statuses
2. **Restart from Stage 0** - Dispatch to task-breakdown
3. **Preserve context** - Include learnings from previous run if applicable

## When to Use

- After decide-agent outputs RESTART
- When user wants to start fresh with new requirements
- When pipeline is stuck or needs a clean slate

## Output Template

```markdown
## Pipeline Restart

### Previous Pipeline Summary
- Stages completed: [list]
- Reason for restart: [reason]

### New Pipeline Started
- Pipeline Iteration: [N+1]
- Starting Stage: 0 (task-breakdown)

### Pipeline Status
- [ ] Stage 0: task-breakdown [Run 1] (STARTING)
- [ ] Stage 1: code-discovery
- [ ] Stage 2: plan-agent
- [ ] Stage 3: web-syntax-researcher (if needed)
- [ ] Stage 4: build-agent (if needed)
- [ ] Stage 5: debugger (if needed)
- [ ] Stage 6: test-agent
- [ ] Stage 7: review-agent
- [ ] Stage 8: decide-agent

Dispatching to task-breakdown...
```
