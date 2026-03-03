---
description: "Restart the multi-agent pipeline from Stage 0"
---

# Restart Pipeline

Restart the multi-agent pipeline from Stage 0.

## Usage

This command restarts the pipeline from the beginning (task-breakdown).

## Instructions

When this command is invoked:

1. **Clear current pipeline state** - Reset all stage statuses in todowrite
2. **Restart from Stage -2** - Dispatch to pipeline-scaler, then prompt-optimizer, then task-breakdown
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
- Starting Stage: -2 (pipeline-scaler)

### Pipeline Status
- [ ] Stage -2: pipeline-scaler [Run 1] (STARTING)
- [ ] Stage -1: prompt-optimizer
- [ ] Stage 0: task-breakdown
- [ ] Stage 1: code-discovery
- [ ] Stage 2: plan-agent
- [ ] Stage 3: docs-researcher (if needed)
- [ ] Stage 3.5: pre-flight-checker
- [ ] Stage 4: build-agent (if needed)
- [ ] Stage 4.5: test-writer
- [ ] Stage 5: debugger (if needed)
- [ ] Stage 5.5: logical-agent
- [ ] Stage 6: test-agent
- [ ] Stage 6.5: integration-agent
- [ ] Stage 7: review-agent
- [ ] Stage 8: decide-agent

Dispatching to pipeline-scaler...
```
