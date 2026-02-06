---
name: finish
description: Run the full multi-agent pipeline to complete a task from start to finish
---

# /finish - Complete a Task

Invoke the full multi-agent pipeline to complete a task end-to-end, from analysis through implementation, testing, and verification.

## Usage
```
/finish <task_description>
```

## Parameters
- **task_description**: The task to complete (required). Can be a feature request, bug fix, refactor, or any code change.

## Examples
```
/finish Add a health check endpoint at GET /health that returns 200 OK with JSON body {"status": "healthy"}
```

```
/finish Fix the authentication bug where expired tokens return 500 instead of 401 Unauthorized
```

## What It Does
Runs the complete multi-agent pipeline:

1. **Stage -1: prompt-optimizer** - Optimizes the task prompt
2. **Stage 0: task-breakdown** - Creates TaskSpec with features and acceptance criteria
3. **Stage 1: code-discovery** - Discovers codebase structure and conventions
5. **Stage 2: plan-agent** - Creates batched implementation plan
6. **Stage 3: docs-researcher** - Researches relevant documentation
7. **Stage 3.5: pre-flight-checker** - Pre-implementation sanity checks
8. **Stage 4: build-agent** - Implements features (chains through build-agent-1 to 55)
9. **Stage 5: debugger** - Fixes errors if any (chains through debugger to debugger-11)
10. **Stage 5.5: logical-agent** - Verifies code logic correctness
11. **Stage 6: test-agent** - Runs all tests
12. **Stage 6.5: integration-agent** - Runs integration tests
13. **Stage 7: review-agent** - Reviews against acceptance criteria
14. **Stage 8: decide-agent** - Makes final COMPLETE or RESTART decision

## Completion Behavior

The pipeline runs continuously until the task is complete. There are no artificial restart requirements or pass limits. The decide-agent outputs COMPLETE when all acceptance criteria are met and tests pass, or RESTART if issues remain that need further work.

## Orchestrator Integration

The orchestrator dispatches agents sequentially and evaluates each output before proceeding.

### Orchestrator Decisions
- **ACCEPT** - Output good, proceed to next stage
- **RETRY** - Re-run with improved instructions
- **CONTINUE** - Chain to next agent (e.g., build-agent-2)
- **HANDLE REQUEST** - Agent requested another agent

## Output

Pipeline status updates after each stage:

```
## Pipeline Status
- [x] Stage -1: prompt-optimizer
- [x] Stage 0: task-breakdown
- [x] Stage 1: code-discovery
- [ ] Stage 2: plan-agent (IN PROGRESS)
- [ ] Stage 3: docs-researcher
- [ ] Stage 3.5: pre-flight-checker
- [ ] Stage 4: build-agent
- [ ] Stage 5: debugger
- [ ] Stage 5.5: logical-agent
- [ ] Stage 6: test-agent
- [ ] Stage 6.5: integration-agent
- [ ] Stage 7: review-agent
- [ ] Stage 8: decide-agent
```

Culminates in either:
- **COMPLETE** - All criteria met, tests passing, implementation verified
- **RESTART** - Issues detected, restarting pipeline from Stage 0
