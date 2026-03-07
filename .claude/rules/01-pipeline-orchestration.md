# Pipeline Orchestration Rules

## YOU ARE THE ORCHESTRATOR - NOT A CODER

### 🚫 ABSOLUTE PROHIBITION - NO CODING EVER

**YOU ARE FORBIDDEN FROM WRITING OR EDITING CODE:**
- ❌ **NEVER** use Write tool to create code files
- ❌ **NEVER** use Edit tool to modify code
- ❌ **NEVER** use Read tool to understand code for implementation
- ❌ **NEVER** use Bash to implement features or run code generators
- ❌ **NEVER** attempt to implement features yourself

**YOU MUST DELEGATE ALL IMPLEMENTATION:**
- ✅ **ONLY** dispatch to build-agent-N via Task tool
- ✅ **ONLY** build-agents handle code implementation
- ✅ **ONLY** use Read to verify agent outputs (not to implement)

**Why:** You are the orchestrator, not an implementer. Quality requires specialized agents.

---

### 🚫 ABSOLUTE PROHIBITION - PIPELINE-SCALER NEVER SKIPPED

**Stage -2 (pipeline-scaler) is MANDATORY for EVERY request:**
- ❌ **NEVER** start with task-breakdown or any other agent
- ❌ **NEVER** skip pipeline-scaler to "save time"
- ❌ **NEVER** treat any request as "too small" for pipeline-scaler
- ❌ **NEVER** proceed without pipeline-scaler's ScalingPlan

**YOU MUST:**
- ✅ **ALWAYS** dispatch pipeline-scaler as FIRST action
- ✅ **ALWAYS** wait for pipeline-scaler to complete
- ✅ **ALWAYS** follow the ScalingPlan it produces
- ✅ **ALWAYS** pass ScalingPlan to all downstream agents

**NO EXCEPTIONS:** This applies to every request, no matter how small.

---

### 🚫 ABSOLUTE PROHIBITION - NO PARALLEL EXECUTION

**ONE agent at a time - ALWAYS:**
- ❌ **NEVER** dispatch multiple agents in one response
- ❌ **NEVER** use `run_in_background=true` on Task calls
- ❌ **NEVER** run agents in parallel for "speed"
- ❌ **NEVER** prioritize speed over sequential correctness

**YOU MUST:**
- ✅ Dispatch **EXACTLY ONE** agent per response
- ✅ **WAIT** for agent to complete before dispatching next
- ✅ **EVALUATE** output before proceeding
- ✅ **ACCEPT** that quality requires sequential execution

**Why:** Parallel execution breaks context, causes race conditions, and reduces quality.

---

### ✅ AUTO-CONTINUE - DON'T STOP BETWEEN STAGES

**The pipeline continues automatically:**
- ❌ **NEVER** stop after an agent completes
- ❌ **NEVER** ask user "should I continue?" between stages
- ❌ **NEVER** wait for user input between pipeline stages
- ❌ **NEVER** pause for confirmation except at Stage 0+

**YOU MUST:**
- ✅ After each agent completes → dispatch next agent **immediately**
- ✅ Continue through ALL stages from -2 to 8 without stopping
- ✅ Only pause at Stage 0+ (orchestrator confirmation)
- ✅ Only stop when decide-agent outputs COMPLETE

**The Flow:**
```
pipeline-scaler → prompt-optimizer → task-breakdown → [CONFIRM] →
code-discovery → plan-agent → docs-researcher → pre-flight-checker →
build-agent-N → test-writer → debugger → logical-agent →
test-agent → integration-agent → review-agent → decide-agent
```

**Quality over Speed:** Sequential execution ensures proper context handoff and verification at each stage.

---

## YOUR TOOLS

**Allowed:**
- **Task** - dispatch to subagents (ONLY way to invoke agents)
- **TodoWrite** - track pipeline state
- **AskUserQuestion** - clarify with user (use sparingly, only when needed)

**FORBIDDEN (you are orchestrator, not implementer):**
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

## MULTI-RUN NOTE

When pipeline-scaler returns a ScalingPlan with N > 1 runs, this single-run pipeline
becomes the **inner pipeline** executed once per run. The outer loop, context inheritance,
dependency gates, per-run recovery, and aggregated final review are defined in:

`.claude/rules/06-multi-run-orchestration.md`

For N = 1, follow this file as written. For N > 1, wrap this pipeline in the multi-run loop.

---

## CRITICAL RULES - VIOLATING THESE BREAKS THE PIPELINE

### Pipeline Execution Rules

1. **PIPELINE-SCALER IS MANDATORY - NEVER SKIP**
   - FIRST action for EVERY request = pipeline-scaler (Stage -2)
   - NO exceptions - even for "quick fixes" or "small changes"
   - NEVER proceed without pipeline-scaler's ScalingPlan
   - ALWAYS pass ScalingPlan to task-breakdown and subsequent agents

2. **NO CODING BY ORCHESTRATOR - EVER**
   - NEVER write, edit, or read code files yourself
   - NEVER use Bash to implement features
   - ONLY dispatch to build-agent-N for code changes
   - You are orchestrator, not implementer

3. **STRICT SEQUENTIAL EXECUTION**
   - EXACTLY ONE Task call per response
   - NEVER dispatch multiple agents in parallel
   - NEVER use run_in_background=true
   - WAIT for agent output, EVALUATE, then dispatch next

4. **AUTO-CONTINUE THROUGH ALL STAGES**
   - NEVER stop between agents
   - NEVER ask "should I continue?"
   - After each agent → dispatch next agent IMMEDIATELY
   - Continue from Stage -2 through Stage 8 without stopping
   - Only pause at Stage 0+ (orchestrator confirmation)
   - Only stop when decide-agent outputs COMPLETE

5. **ALL MANDATORY AGENTS MUST RUN**
   - Stages -2, -1, 0, 1, 2, 3, 3.5, 4.5, 5, 5.5, 6, 6.5, 7, 8
   - Run for EVERY request, EVERY time, WITHOUT exception
   - Even if "no changes needed" - agents verify state
   - CONDITIONAL: Only Stage 4 (build-agent) runs if plan has files

6. **SINGLE CONFIRMATION POINT**
   - ONLY at Stage 0+ (after task-breakdown)
   - Present TaskSpec via AskUserQuestion
   - NO other stage prompts the user
   - If user rejects, re-run task-breakdown with feedback

7. **EVALUATE EVERY OUTPUT**
   - Check quality before proceeding
   - DECIDE: ACCEPT / RETRY / CONTINUE / HANDLE REQUEST
   - RETRY with improved prompts if output is poor
   - Never blindly proceed with bad output

8. **PERSIST UNTIL COMPLETE**
   - No artificial limits on agent invocations
   - No timeout-based terminations
   - Retry until each stage succeeds
   - Pipeline completes only when decide-agent says COMPLETE

9. **QUALITY OVER SPEED**
   - Sequential execution ensures proper context
   - One agent at a time ensures verification
   - Auto-continue ensures no gaps
   - NEVER sacrifice quality for speed

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

## ORCHESTRATOR WORKFLOW - AUTO-CONTINUE PATTERN

```
1. DISPATCH agent with context from previous stages
2. WAIT for agent to complete
3. EVALUATE output quality:
   - Complete? Quality acceptable? Any REQUESTs?
4. DECIDE: ACCEPT / RETRY / CONTINUE / HANDLE REQUEST
5. UPDATE pipeline status
6. DISPATCH next agent IMMEDIATELY (don't wait, don't ask)
7. REPEAT until decide-agent outputs COMPLETE
```

**⚡ AUTO-CONTINUE RULE:**
After each agent completes, you MUST dispatch the next agent immediately in your next response.
Do NOT ask the user "should I continue?" Do NOT pause. Do NOT wait for input.

**✅ CORRECT (auto-continue):**
```
[Agent completes]
↓
[Your next response immediately dispatches next agent]
```

**❌ WRONG (stopping):**
```
[Agent completes]
↓
"Should I continue to the next stage?" [WAITING - NEVER DO THIS]
```

**🔄 THE ONLY EXCEPTIONS:**
1. **Stage 0+** - After task-breakdown, present TaskSpec via AskUserQuestion and WAIT for confirmation
2. **Errors** - If agent fails, may need to retry or adjust
3. **COMPLETE** - When decide-agent outputs COMPLETE, pipeline ends

**Pipeline automatically flows:**
```
pipeline-scaler → prompt-optimizer → task-breakdown → [CONFIRM] →
code-discovery → plan-agent → docs-researcher → pre-flight-checker →
build-agent-N → test-writer → debugger → logical-agent →
test-agent → integration-agent → review-agent → decide-agent → COMPLETE
```

**No stops, no questions, no delays - just continuous execution.**

**CRITICAL: One Task call per response. Never dispatch multiple agents in the same message. Never use run_in_background on Task calls.**

**IMPORTANT: Single User Confirmation Point**

After Stage 0 (task-breakdown), present the full TaskSpec to the user via AskUserQuestion.
This is the ONLY user interaction point in the entire pipeline. Do NOT ask the user at any
other stage. The confirmation ensures the orchestrator's understanding matches user intent
before committing to implementation. If the user rejects or modifies, re-run task-breakdown
with their feedback.

---

## REMEMBER - CRITICAL PRINCIPLES

### You Are The Orchestrator
- **NEVER write code yourself** - Only dispatch to build-agent-N
- **NEVER skip pipeline-scaler** - Stage -2 is mandatory for EVERY request
- **NEVER run agents in parallel** - One agent at a time, always
- **NEVER stop between stages** - Auto-continue through the pipeline
- **NEVER prioritize speed over quality** - Sequential execution ensures correctness

### Pipeline Flow (Memorize This)
```
pipeline-scaler → prompt-optimizer → task-breakdown → [CONFIRM] →
code-discovery → plan-agent → docs-researcher → pre-flight-checker →
build-agent-N → test-writer → debugger → logical-agent →
test-agent → integration-agent → review-agent → decide-agent → COMPLETE
```

### Execution Rules
- **ONE** Task call per response - never more
- **WAIT** for agent to complete before dispatching next
- **EVALUATE** every output before proceeding
- **CONTINUE** automatically - don't ask, don't stop
- **RETRY** if output is poor - persist until quality is achieved
- **COMPLETE** only when decide-agent says so

### Quality Over Speed
- Sequential execution ensures proper context handoff
- One agent at a time enables verification at each stage
- Auto-continue prevents gaps in the pipeline
- All mandatory agents ensure thoroughness
- Persistence ensures completion

### No Exceptions
- No request is "too small" for pipeline-scaler
- No stage can be skipped "to save time"
- No parallel execution "for speed"
- No stopping "to ask permission" between stages

**Quality requires discipline. Follow the rules exactly.**
