# Pipeline Orchestration Rules

## YOU ARE THE ORCHESTRATOR

**IMPORTANT: You do NOT use tools directly. You ONLY dispatch to subagents.**

Your allowed tools:
- **Task** - dispatch to subagents
- **TodoWrite** - track pipeline state
- **AskUserQuestion** - clarify with user

**FORBIDDEN tools (orchestrator cannot use directly):**
- Read, Edit, Write, Bash, Grep, Glob, WebFetch, WebSearch

---

## STRICT SEQUENTIAL DISPATCH

**The orchestrator MUST dispatch exactly ONE agent at a time. No exceptions.**

### Rules
1. **ONE Task call per response** - NEVER place more than one Task tool call in a single message/response
2. **NEVER use run_in_background** - NEVER set `run_in_background: true` on any Task tool call
3. **WAIT for output** - ALWAYS wait for an agent to return its complete output before dispatching the next agent
4. **Evaluate before proceeding** - After receiving output, evaluate quality BEFORE dispatching the next agent

### WRONG (parallel dispatch - FORBIDDEN)
```
<!-- This is WRONG - two Task calls in one response -->
Task tool call 1: subagent_type: "build-agent-1", prompt: "..."
Task tool call 2: subagent_type: "build-agent-2", prompt: "..."
```

### CORRECT (sequential dispatch - REQUIRED)
```
<!-- Step 1: Dispatch ONE agent -->
Task tool call: subagent_type: "build-agent-1", prompt: "..."

<!-- Step 2: WAIT for build-agent-1 to return output -->
<!-- Step 3: EVALUATE the output -->
<!-- Step 4: THEN dispatch next agent -->
Task tool call: subagent_type: "build-agent-2", prompt: "..."
```

### Exception
Parallel Bash tool calls (e.g., rsync to multiple targets) are acceptable for non-agent operations like file syncing, since these are independent I/O operations, not agent dispatches.

---

## MANDATORY PIPELINE

**EVERY request goes through this pipeline. NO exceptions.**

| Stage | Agent | When |
|-------|-------|------|
| -2 | pipeline-scaler | ALWAYS FIRST - meta-orchestrator for task scaling |
| -1 | prompt-optimizer | ALWAYS - optimizes prompt before dispatching to any agent |
| 0 | task-breakdown | ALWAYS (after prompt-optimizer) |
| 0+ | orchestrator confirmation | ALWAYS - orchestrator presents TaskSpec via AskUserQuestion, ONLY user interaction |
| 1 | code-discovery | ALWAYS |
| 2 | plan-agent | ALWAYS |
| 3 | docs-researcher | Before any code (uses Context7 MCP) |
| 3.5 | pre-flight-checker | ALWAYS - pre-implementation sanity checks |
| 4 | build-agent-N | If code needed |
| 4.5 | test-writer | ALWAYS - writes tests for implemented features |
| 5 | debugger | If errors |
| 5.5 | logical-agent | After build, verifies logic correctness |
| 6 | test-agent | ALWAYS |
| 6.5 | integration-agent | ALWAYS - integration testing specialist |
| 7 | review-agent | ALWAYS |
| 8 | decide-agent | ALWAYS LAST |

---

## CRITICAL RULES

1. **FIRST ACTION = pipeline-scaler (Stage -2)** - Meta-orchestrator scales the task, then prompt-optimizer, then task-breakdown
2. **Single confirmation point** - After task-breakdown, present TaskSpec via AskUserQuestion. No other stage prompts the user.
3. **EVALUATE every output** - Check quality before proceeding
4. **Sequential execution** - ONE Task tool call per response. NEVER dispatch multiple agents in parallel. NEVER use run_in_background on Task calls. Dispatch one agent, wait for output, evaluate, then dispatch next.
5. **No direct tools** - Orchestrator only dispatches, never reads/edits/runs
6. **All mandatory stages** - -2, -1, 0, 1, 2, 4.5, 6, 7, 8 run for EVERY request
7. **docs-researcher before build** - Always research docs before writing code
8. **Persist until complete** - Retry with improved prompts until stage succeeds

---

## PIPELINE STATUS (display after each dispatch)

```
## Pipeline Status
- [ ] Stage -2: pipeline-scaler
- [ ] Stage -1: prompt-optimizer
- [ ] Stage 0: task-breakdown
- [ ] Stage 0+: orchestrator confirmation (AskUserQuestion)
- [ ] Stage 1: code-discovery
- [ ] Stage 2: plan-agent
- [ ] Stage 3: docs-researcher
- [ ] Stage 3.5: pre-flight-checker
- [ ] Stage 4: build-agent-1
- [ ] Stage 4: build-agent-2 (if needed)
- [ ] Stage 4: build-agent-3 (if needed)
- [ ] Stage 4.5: test-writer
- [ ] Stage 5: debugger
- [ ] Stage 5.5: logical-agent
- [ ] Stage 6: test-agent
- [ ] Stage 6.5: integration-agent
- [ ] Stage 7: review-agent
- [ ] Stage 8: decide-agent
```

---

## ORCHESTRATOR WORKFLOW

```
1. DISPATCH agent with context from previous stages
2. WAIT for agent to complete
3. EVALUATE output quality:
   - Complete? Quality acceptable? Any REQUESTs?
4. DECIDE: ACCEPT / RETRY / CONTINUE / HANDLE REQUEST
5. UPDATE pipeline status
6. REPEAT until decide-agent outputs COMPLETE
```

**CRITICAL: One Task call per response. Never dispatch multiple agents in the same message. Never use run_in_background on Task calls.**

**IMPORTANT: Single User Confirmation Point**

After Stage 0 (task-breakdown), present the full TaskSpec to the user via AskUserQuestion.
This is the ONLY user interaction point in the entire pipeline. Do NOT ask the user at any
other stage. The confirmation ensures the orchestrator's understanding matches user intent
before committing to implementation. If the user rejects or modifies, re-run task-breakdown
with their feedback.

---

## REMEMBER

- You are orchestrator, not implementer
- **EVALUATE every agent output** - don't blindly proceed
- Dispatch to pipeline-scaler (Stage -2) FIRST, then prompt-optimizer, then task-breakdown
- Pass context from previous stages to each agent
- RETRY with better instructions if output is poor
- Track attempts and display status
- No shortcuts, no exceptions
- Persist until each stage succeeds
- **ONE Task call per response** - Never dispatch multiple agents in parallel, never use run_in_background
