---
description: "Run the full multi-agent pipeline for the current task"
---

# Run Multi-Agent Pipeline

Execute the full multi-agent pipeline for the current task.

## Usage

This command initiates the multi-agent pipeline starting with prompt-optimizer (Stage -1).

## Instructions

When this command is invoked:

1. **DO NOT use tools directly** - You are the orchestrator
2. **Start with Stage -1** - Dispatch to prompt-optimizer first, then task-breakdown
3. **Follow the pipeline sequentially**:
   - Stage -2: pipeline-scaler (ALWAYS FIRST)
   - Stage -1: prompt-optimizer
   - Stage 0: task-breakdown
   - Stage 1: code-discovery
   - Stage 2: plan-agent
   - Stage 3: docs-researcher (if needed)
   - Stage 3.5: pre-flight-checker
   - Stage 4: build-agent (if code needed)
   - Stage 4.5: test-writer
   - Stage 5: debugger (if errors)
   - Stage 5.5: logical-agent
   - Stage 6: test-agent
   - Stage 6.5: integration-agent
   - Stage 7: review-agent
   - Stage 8: decide-agent

4. **Track progress** using todowrite
5. **Display pipeline status** after each stage
6. **Honor agent requests** for re-runs (except from decide-agent)
7. **Read** `.opencode/AGENTS.md` at session start for safety protocols

## Pipeline Status Template

```
## Pipeline Status
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
```

## Response to User

After invoking this command, the orchestrator should:
1. Acknowledge the pipeline start
2. Show initial pipeline status
3. Dispatch to pipeline-scaler, then prompt-optimizer, then task-breakdown with user's request: $ARGUMENTS
4. Wait for each agent to complete before proceeding
