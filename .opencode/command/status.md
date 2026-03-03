---
description: "Display the current status of the multi-agent pipeline"
---

# Show Pipeline Status

Display the current status of the multi-agent pipeline.

## Usage

This command shows the current state of pipeline execution.

## Instructions

When this command is invoked:

1. **Review current todo list** - Check todowrite for active tasks
2. **Display pipeline status** - Show which stages are complete/pending
3. **Show agent dispatch chain** - List agents that have run
4. **Indicate next steps** - What stage runs next

## Output Template

```markdown
## Pipeline Status

### Current Stage
[Stage N: agent-name] - [IN PROGRESS / COMPLETE / PENDING]

### Stage Checklist
- [x] Stage -2: pipeline-scaler [Run 1]
- [x] Stage -1: prompt-optimizer [Run 1]
- [x] Stage 0: task-breakdown [Run 1]
- [x] Stage 1: code-discovery [Run 1]
- [ ] Stage 2: plan-agent [Run 1] (IN PROGRESS)
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

### Agent Dispatch Chain
1. pipeline-scaler (Run 1) - COMPLETE
2. prompt-optimizer (Run 1) - COMPLETE
3. task-breakdown (Run 1) - COMPLETE
4. code-discovery (Run 1) - COMPLETE
5. plan-agent (Run 1) - IN PROGRESS

### Next Steps
[What will happen next in the pipeline]
```
