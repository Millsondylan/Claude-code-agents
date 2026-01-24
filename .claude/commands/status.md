# Show Pipeline Status

Display the current status of the multi-agent pipeline.

## Usage
This command shows the current state of pipeline execution.

## Instructions for Claude

When this command is invoked:

1. **Review current todo list** - Check TodoWrite for active tasks
2. **Display pipeline status** - Show which stages are complete/pending
3. **Show agent dispatch chain** - List agents that have run
4. **Indicate next steps** - What stage runs next

## Output Template

```markdown
## Pipeline Status

### Current Stage
[Stage N: agent-name] - [IN PROGRESS / COMPLETE / PENDING]

### Stage Checklist
- [x] Stage 0: task-breakdown [Run 1]
- [x] Stage 1: code-discovery [Run 1]
- [ ] Stage 2: plan-agent [Run 1] (IN PROGRESS)
- [ ] Stage 3: web-syntax-researcher (if needed)
- [ ] Stage 4: build-agent (if needed)
- [ ] Stage 5: debugger (if needed)
- [ ] Stage 6: test-agent
- [ ] Stage 7: review-agent
- [ ] Stage 8: decide-agent

### Agent Dispatch Chain
1. task-breakdown (Run 1) - COMPLETE
2. code-discovery (Run 1) - COMPLETE
3. plan-agent (Run 1) - IN PROGRESS

### Next Steps
[What will happen next in the pipeline]
```
