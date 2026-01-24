# Run Multi-Agent Pipeline

Execute the full multi-agent pipeline for the current task.

## Usage
This command initiates the 10-stage multi-agent pipeline starting with prompt-optimizer (Stage -1).

## Instructions for Claude

When this command is invoked:

1. **DO NOT use tools directly** - You are the orchestrator
2. **Start with Stage 0** - Dispatch to task-breakdown agent
3. **Follow the pipeline sequentially**:
   - Stage -1: prompt-optimizer (ALWAYS FIRST)
   - Stage 0: task-breakdown
   - Stage 1: code-discovery
   - Stage 2: plan-agent
   - Stage 3: web-syntax-researcher (if needed)
   - Stage 4: build-agent (if code needed)
   - Stage 5: debugger (if errors)
   - Stage 6: test-agent
   - Stage 7: review-agent
   - Stage 8: decide-agent

4. **Track progress** using TodoWrite
5. **Display pipeline status** after each stage
6. **Honor agent requests** for re-runs (except from decide-agent)

## Pipeline Status Template

```
## Pipeline Status
- [x] Stage -1: prompt-optimizer [Run 1]
- [x] Stage 0: task-breakdown [Run 1]
- [x] Stage 1: code-discovery [Run 1]
- [ ] Stage 2: plan-agent [Run 1] (IN PROGRESS)
- [ ] Stage 3: web-syntax-researcher (if needed)
- [ ] Stage 4: build-agent (if needed)
- [ ] Stage 5: debugger (if needed)
- [ ] Stage 6: test-agent
- [ ] Stage 7: review-agent
- [ ] Stage 8: decide-agent
```

## Response to User

After invoking this command, the orchestrator should:
1. Acknowledge the pipeline start
2. Show initial pipeline status
3. Dispatch to task-breakdown with user's request
4. Wait for each agent to complete before proceeding
