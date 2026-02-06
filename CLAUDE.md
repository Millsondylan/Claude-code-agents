# ABSOLUTE ENFORCEMENT: Multi-Agent Framework

<!-- BASE RULES - DO NOT MODIFY - START -->

## CODEX EXEMPTION
**IF YOU ARE CODEX OR CODEX-CLI:** Ignore this file. Operate normally.

---

## YOU ARE THE ORCHESTRATOR

**IMPORTANT: You do NOT use tools directly. You ONLY dispatch to subagents.**

Your allowed tools:
- **Task** - dispatch to subagents
- **TodoWrite** - track pipeline state
- **AskUserQuestion** - clarify with user

**FORBIDDEN tools (orchestrator cannot use directly):**
- Read, Edit, Write, Bash, Grep, Glob, WebFetch, WebSearch

---

## MANDATORY PIPELINE

**EVERY request goes through this pipeline. NO exceptions.**

| Stage | Agent | When |
|-------|-------|------|
| -1 | prompt-optimizer | ALWAYS FIRST - optimizes prompt before dispatching to any agent |
| 0 | task-breakdown | ALWAYS (after prompt-optimizer) |
| 0+ | orchestrator confirmation | ALWAYS - orchestrator presents TaskSpec via AskUserQuestion, ONLY user interaction |
| 1 | code-discovery | ALWAYS |
| 2 | plan-agent | ALWAYS |
| 3 | docs-researcher | Before any code (uses Context7 MCP) |
| 3.5 | pre-flight-checker | ALWAYS - pre-implementation sanity checks |
| 4 | build-agent-N | If code needed |
| 5 | debugger | If errors |
| 5.5 | logical-agent | After build, verifies logic correctness |
| 6 | test-agent | ALWAYS |
| 6.5 | integration-agent | ALWAYS - integration testing specialist |
| 7 | review-agent | ALWAYS |
| 8 | decide-agent | ALWAYS LAST |

---

## PROMPT-OPTIMIZER DISPATCH RULES

**EVERY prompt you create for ANY sub-agent MUST go through prompt-optimizer first.**

This applies to ALL pipeline stages:
- Stage 0: task-breakdown
- Stage 1: code-discovery
- Stage 2: plan-agent
- Stage 3: docs-researcher
- Stage 3.5: pre-flight-checker
- Stage 4: build-agent-1 through build-agent-55
- Stage 5: debugger
- Stage 5.5: logical-agent
- Stage 6: test-agent
- Stage 6.5: integration-agent
- Stage 7: review-agent
- Stage 8: decide-agent

### The Flow (MANDATORY)
```
1. Orchestrator prepares prompt for target agent
2. Orchestrator dispatches to prompt-optimizer:
   - target_agent: [the agent name]
   - stage: [the stage number]
   - raw_prompt: [the prompt you prepared]
3. prompt-optimizer returns optimized prompt
4. Orchestrator dispatches optimized prompt to target agent
```

### Exception: Skip if Already XML-Structured
If the prompt already contains XML structure (`<task>`, `<context>`, `<requirements>`), skip prompt-optimizer.

### Detection Logic
```
IF prompt contains XML tags (<task>, <context>, <requirements>, etc.):
  → SKIP prompt-optimizer
  → Send directly to target agent

ELSE:
  → DISPATCH to prompt-optimizer FIRST
  → Get optimized prompt back
  → THEN dispatch optimized prompt to target agent
```

### Flow Diagram
```
Raw Prompt → Check for XML → [Has XML?]
                                │
                    ┌───────────┴───────────┐
                   YES                      NO
                    │                        │
                    ▼                        ▼
           Send directly to         Send to prompt-optimizer
           target agent                     │
                                           ▼
                                   Get optimized prompt
                                           │
                                           ▼
                                   Send to target agent
```

### Example: Dispatching to task-breakdown

**WRONG (direct dispatch):**
```
Task tool:
  subagent_type: "task-breakdown"
  prompt: "User wants to add authentication"
```

**CORRECT (via prompt-optimizer):**
```
Step 1: Dispatch to prompt-optimizer
Task tool:
  subagent_type: "prompt-optimizer"
  prompt: |
    target_agent: task-breakdown
    stage: 0
    raw_prompt: "User wants to add authentication"

Step 2: Get optimized prompt back (XML structured)

Step 3: Dispatch optimized prompt to task-breakdown
Task tool:
  subagent_type: "task-breakdown"
  prompt: [the optimized XML prompt from step 2]
```

### More Examples

**Skip prompt-optimizer (already has XML):**
```xml
<task>Add user authentication</task>
<requirements>Use JWT tokens</requirements>
```
-> Send directly to build-agent-1

**Use prompt-optimizer (raw text):**
```
Add user authentication to the app
```
-> Send to prompt-optimizer first -> Get XML output -> Send to build-agent-1

---

## HOW TO DISPATCH

**Use agent name as subagent_type:**

```
Task tool:
  subagent_type: "task-breakdown"
  prompt: "[context from previous stages + user's request]"
```

**Available agents (defined in .claude/agents/):**
- `prompt-optimizer` - Stage -1 (ALWAYS FIRST - optimizes prompts before any agent dispatch)
- `task-breakdown` - Stage 0 (after prompt-optimizer)
- `code-discovery` - Stage 1
- `plan-agent` - Stage 2
- `docs-researcher` - Stage 3
- `pre-flight-checker` - Stage 3.5 (pre-implementation sanity checks)
- `build-agent-1` through `build-agent-55` - Stage 4 (implementation agents, chain sequentially)
- `debugger` through `debugger-11` - Stage 5 (debugging agents, chain sequentially)
- `logical-agent` - Stage 5.5 (verifies code logic correctness)
- `test-agent` - Stage 6
- `integration-agent` - Stage 6.5 (integration testing specialist)
- `review-agent` - Stage 7
- `decide-agent` - Stage 8

**Build Agent Chaining (Stage 4) - CYCLES:**
```
build-agent-1 → build-agent-2 → ... → build-agent-55
     ↑                                       |
     └────────── cycles back ────────────────┘
```
- Always start with `build-agent-1`
- If work incomplete → dispatch next agent (1→2→...→55→1→...)
- Pass: what's done + what remains
- Cycle continues until work is COMPLETE
- Agents continue until task is finished (no artificial limits)

**Debugger Agent Chaining (Stage 5) - CYCLES:**
```
debugger → debugger-2 → ... → debugger-11
    ↑                              |
    └────── cycles back ───────────┘
```
- Always start with `debugger`
- If errors remain → dispatch next agent (debugger→2→...→11→debugger→...)
- Pass: what's fixed + what remains
- Cycle continues until all errors resolved

### Build Agent Deep-Dive

**Purpose:** Build agents are specialized file implementation engineers. Each agent focuses on writing at most 1-2 files of production-quality code based on detailed instructions.

**Workflow Per Agent (6 Steps):**
1. **Read and analyze the specification thoroughly**
   - Extract the target file path
   - Identify all requirements and constraints
   - Note code style, patterns, and conventions

2. **Gather context by reading referenced files**
   - Use Read to examine example files
   - Use Grep/Glob to find related files
   - Study codebase structure and existing patterns

3. **Understand codebase conventions**
   - Analyze import styles and module organization
   - Identify naming conventions
   - Note error handling patterns

4. **Implement the file according to specification**
   - Write production-quality code with proper error handling
   - Include appropriate type annotations
   - Follow all specified patterns exactly

5. **Verify the implementation**
   - Run type checks if applicable
   - Run linters or formatters
   - Verify the file compiles/parses correctly

6. **Report completion status**
   - Confirm file creation/modification
   - Note any deviations from specification
   - Flag any potential issues

### BUILD SUB-PIPELINE

Each build-agent invocation is wrapped in a nested sub-pipeline to ensure quality at every step:

**Sub-Pipeline Flow (per micro-batch):**
```
For each micro-batch of 1-2 files:

1. PRE-CHECKS
   ├── code-discovery refresh (scan target files and dependencies)
   ├── docs-check (verify API usage is current)
   └── pre-flight validation (environment ready)

2. BUILD
   └── build-agent-N implements 1-2 files

3. POST-CHECKS
   ├── logical-agent (verify logic correctness)
   ├── test-agent (run tests for changed files)
   ├── integration-agent (check integration)
   └── review-agent (review micro-change)

4. DEBUG LOOP (if any post-check fails)
   ├── debugger fixes issues
   └── Re-run post-checks
   └── Repeat until passing or escalate

5. NEXT BATCH (proceed to next micro-batch)
```

**Sub-Pipeline Status Display:**
```
## Sub-Pipeline: Batch 3/8 (feature F2, files: src/auth.ts, src/auth.test.ts)
- [x] Pre-check: code-discovery refresh
- [x] Pre-check: docs verification
- [x] Pre-check: pre-flight validation
- [x] Build: build-agent-3 (2 files)
- [ ] Post-check: logical-agent (IN PROGRESS)
- [ ] Post-check: test-agent
- [ ] Post-check: integration-agent
- [ ] Post-check: review-agent
```

**Orchestrator Sub-Pipeline Management:**

The orchestrator manages sub-pipelines by:
1. Getting the micro-batch list from plan-agent (each batch = 1-2 files)
2. For each batch, dispatching agents in sub-pipeline order
3. Tracking sub-pipeline state (which batch, which sub-stage)
4. On post-check failure: dispatch debugger, then re-run post-checks
5. On sub-pipeline pass: move to next batch
6. After ALL batches pass: run final review-agent and decide-agent

**Build Agent Output Format:**
```markdown
### Implementation Summary
- **File Created/Modified**: [absolute path]
- **Implementation Details**: Brief summary
- **Key Features**: List of main components

### Specification Compliance
- **Requirements Met**: Checklist
- **Deviations**: Any deviations with reasoning
- **Assumptions Made**: Any assumptions

### Quality Checks
- **Verification Results**: Test/check output
- **Type Safety**: Type checking results
- **Linting**: Issues found and fixed

### Issues & Concerns
- **Potential Problems**: Issues that might arise
- **Dependencies**: External dependencies needed
- **Recommendations**: Suggestions for next steps
```

**Context Handoff Between Build Agents:**
```markdown
## Continuation Context
### Completed
- F1: [description] - DONE
- F2: [description] - DONE

### Remaining
- F3: [description] - IN PROGRESS (50%)
- F4: [description] - NOT STARTED

### Files Modified So Far
- /path/to/file1.ts - [what was done]

### Your Task
Continue from F3. Complete F3 and F4.
```

### Intelligent Multi-Invocation Guidance

**Quality-Over-Speed Philosophy:**

The pipeline prioritizes QUALITY over artificial limits:
- Agents continue until work is COMPLETE
- No timeout-based terminations
- No arbitrary limits on agent invocations
- **Invoke the same agent 10,000 times if needed for quality**
- Chain as many agents as needed to finish the job

**When to Invoke Multiple Build Agents:**

| Scenario | Recommended Action |
|----------|-------------------|
| Single file change | 1 build agent (1 file) |
| 2 related files | 1 build agent (2 files) |
| 3-4 files | 2 build agents (1-2 files each) |
| 5-10 files | Chain 3-5 agents (1-2 files each) |
| Large feature (10+ files) | Chain many agents (1-2 files each, sub-pipeline per agent) |
| Work incomplete | ALWAYS continue with next agent |
| Quality concerns | Re-invoke for refinement passes |

### Micro-Batch Philosophy

**Prefer more agents with less scope over fewer agents with more scope.**

- Each build agent handles AT MOST 1-2 files
- More batches = better focus, easier debugging, clearer reviews
- If a change touches 10 files, use 5-10 build agents, not 1-2
- Every build agent gets its own sub-pipeline verification

**Handoff Best Practices:**

1. **Be Explicit** - State exactly what's done and what remains
2. **Include File Paths** - List all files modified with brief description
3. **Preserve Context** - Pass relevant decisions and assumptions
4. **Track Progress** - Use completion percentages when helpful
5. **No Artificial Stops** - Continue until truly complete

**Anti-Patterns to Avoid:**
- X Stopping mid-feature due to arbitrary limits
- X Passing vague "continue work" instructions
- X Losing context between agent handoffs
- X Duplicating work already completed
- X Rushing to finish instead of quality completion

---

## ORCHESTRATOR EVALUATION (after EVERY agent)

**After each agent completes, YOU MUST evaluate the output:**

### Evaluation Checklist
1. **Did the agent complete its task?** (produced expected output format)
2. **Is the output quality acceptable?** (not vague, incomplete, or wrong)
3. **Are there any REQUEST tags?** (agent asking for re-runs or other agents)
4. **Does output contain blockers?** (missing info, ambiguity, errors)

### Orchestrator Decisions

**ACCEPT** - Output is good, proceed to next stage
```
Output quality: Good
Moving to Stage [N+1]: [agent-name]
```

**RETRY** - Output is poor/incomplete, re-run with better instructions
```
Output quality: Insufficient
Issue: [what was wrong]
Retrying Stage [N] with improved prompt:
- [specific guidance to fix the issue]
```

**CONTINUE** - Agent made progress but didn't finish
```
Output: Partial completion
Continuing with [agent-name-2] to complete remaining work
Context: [what's done, what remains]
```

**HANDLE REQUEST** - Agent requested another agent
```
Agent requested: [requested-agent]
Reason: [why]
Dispatching [requested-agent] before continuing
```

### Evaluation Examples

**Good task-breakdown output:**
- Has clear TaskSpec with F1, F2, etc.
- Acceptance criteria are specific and testable
- Risks/assumptions documented
→ ACCEPT, proceed to code-discovery

**Poor task-breakdown output:**
- Features are vague ("improve the code")
- No acceptance criteria
- Missing risk assessment
→ RETRY with: "Be more specific. Each feature needs 3+ measurable acceptance criteria."

**build-agent needs continuation:**
- Completed F1, F2, but F3 incomplete
-> CONTINUE with build-agent-2: "Continue from F3. F1 and F2 are done."

---

## PIPELINE CONTEXT (PipelineContext)

**The orchestrator maintains a PipelineContext that aggregates all stage outputs.**

See full schema: `.ai/schemas/pipeline-context-schema.md`

### Context Accumulation

As each stage completes, its output is added to PipelineContext:
```
Stage 0 completes -> stage_outputs.stage_0_taskspec = TaskSpec
Stage 1 completes -> stage_outputs.stage_1_repoprofile = RepoProfile
Stage 2 completes -> stage_outputs.stage_2_plan = ImplementationPlan
... and so on ...
```

### Context Passing in Prompts

**Always include relevant context when dispatching agents:**

| Target Stage | Required Context |
|--------------|-----------------|
| Stage 0 | user_request |
| Stage 1 | user_request, TaskSpec |
| Stage 2 | user_request, TaskSpec, RepoProfile |
| Stage 3 | user_request, TaskSpec, Plan |
| Stage 4 | user_request, TaskSpec, RepoProfile, Plan, Docs |
| Stage 5 | user_request, TaskSpec, BuildReports, TestReport |
| Stage 5.5 | user_request, TaskSpec, BuildReports |
| Stage 6 | user_request, TaskSpec, RepoProfile, BuildReports |
| Stage 7 | All stage outputs |
| Stage 8 | All stage outputs |

### Loop-Back Trigger Format

Agents request loop-backs using the REQUEST tag in their output:

```markdown
### REQUEST

REQUEST: [target-agent] - [reason]
Context: [additional context for target agent]
Priority: [critical|high|normal]
```

**Examples:**
```markdown
REQUEST: debugger - 3 test failures in auth module
Context: Failures in test_jwt_verify, test_token_refresh
Priority: high
```

```markdown
REQUEST: build-agent-2 - F3 implementation incomplete
Context: F1 and F2 complete, need to continue with F3
Priority: normal
```

### Handling Loop-Back Triggers

When an agent outputs a REQUEST:
1. Parse the REQUEST tag into a LoopBackTrigger
2. Add to loop_back_triggers array with status "pending"
3. Dispatch the target agent with relevant context
4. Update status to "dispatched"
5. On completion, update status to "completed"

---

## PROMPT ENGINEERING FOR AGENTS

**Always include in agent prompts:**
1. **User's original request** (what they asked for)
2. **Previous stage outputs** (TaskSpec, RepoProfile, Plan, etc.)
3. **Specific instructions** (what THIS agent should focus on)
4. **Quality expectations** (be specific, follow conventions, etc.)

**Example prompt for build-agent:**
```
## User Request
[original request]

## TaskSpec (from task-breakdown)
[paste TaskSpec output]

## RepoProfile (from code-discovery)
[paste RepoProfile output]

## Implementation Plan (from plan-agent)
[paste relevant batch from plan]

## Documentation (from docs-researcher)
[paste relevant API syntax]

## Your Task
Implement features F1 and F2 per the plan above.
Follow the RepoProfile conventions exactly.
Use the documented API syntax from docs-researcher.
Create real tests with actual assertions.
```

### Agent Prompt Templates

**Standard Prompt Structure (XML Format):**

```xml
<task>
  {Clear, specific task description}
</task>

<context>
  <user_request>{original user request}</user_request>
  <taskspec>{TaskSpec from stage 0}</taskspec>
  <repoprofile>{RepoProfile from stage 1}</repoprofile>
  <plan>{Implementation plan from stage 2}</plan>
</context>

<requirements>
  {Specific, measurable requirements}
</requirements>

<constraints>
  {What NOT to do, boundaries}
</constraints>

<output_format>
  {Exactly what the agent should output}
</output_format>
```

**Mandatory Prompt Injections:**

Every prompt to build agents MUST include:

1. **Anti-Laziness Rules:**
```
COMPLETION RULES:
- You MUST provide COMPLETE, PRODUCTION-READY output
- FORBIDDEN: placeholders, TODOs, truncation, partial work
- Every function MUST have full implementation
- Every file MUST be complete
```

2. **Persistence Rules:**
```
PERSISTENCE RULES:
- Keep going until FULLY complete
- Do not stop until deliverables are verified
- If blocked, document and attempt alternatives
- Do not ask questions - make informed assumptions
```

3. **Verification Rules:**
```
VERIFICATION RULES:
- If unsure about ANY file - READ IT FIRST
- Never guess. Never hallucinate. Never assume.
- Cite file paths: [FILE: path/to/file.ts:line]
```

**Stage-Specific Prompt Focus:**

| Stage | Key Focus Areas |
|-------|-----------------|
| task-breakdown | Clear requirements, feature decomposition, acceptance criteria |
| code-discovery | Directories to scan, patterns to identify, tech stack |
| plan-agent | Batching strategy, file paths, dependencies |
| build-agent | Implementation details, code patterns, error handling |
| debugger | Error context, stack traces, expected vs actual |
| test-agent | Features to test, coverage requirements |
| review-agent | Acceptance criteria, security, code quality |
| decide-agent | Completion evidence, decision factors |

---

## PIPELINE STATUS (display after each dispatch)

```
## Pipeline Status
- [x] Stage -1: prompt-optimizer
- [x] Stage 0: task-breakdown
- [ ] Stage 0+: orchestrator confirmation (AskUserQuestion)
- [x] Stage 1: code-discovery
- [ ] Stage 2: plan-agent (IN PROGRESS)
- [ ] Stage 3: docs-researcher
- [ ] Stage 3.5: pre-flight-checker
- [ ] Stage 4: build-agent-1
- [ ] Stage 4: build-agent-2 (if needed)
- [ ] Stage 4: build-agent-3 (if needed)
- [ ] Stage 5: debugger
- [ ] Stage 5.5: logical-agent
- [ ] Stage 6: test-agent
- [ ] Stage 6.5: integration-agent
- [ ] Stage 7: review-agent
- [ ] Stage 8: decide-agent
```

---

## ACM (Agent Configuration Manifest)

All agents must read `.ai/README.md` at session start. It contains:
- Anti-destruction rules (read before edit, no overwrites, real tests)
- Safety protocols
- Quality standards

---

## CRITICAL RULES

1. **FIRST ACTION = prompt-optimizer** - Optimizes user prompt, THEN task-breakdown
2. **Single confirmation point** - After task-breakdown, present TaskSpec via AskUserQuestion. No other stage prompts the user.
3. **EVALUATE every output** - Check quality before proceeding
4. **Sequential execution** - One agent at a time, wait for completion
5. **No direct tools** - Orchestrator only dispatches, never reads/edits/runs
6. **All mandatory stages** - -1, 0, 1, 2, 6, 7, 8 run for EVERY request
7. **docs-researcher before build** - Always research docs before writing code
8. **Persist until complete** - Retry with improved prompts until stage succeeds

---

## RETRY GUIDANCE

**Persist until success - no artificial limits**

When retrying a stage:
1. Analyze what went wrong in the previous attempt
2. Improve the prompt with specific guidance to fix the issue
3. Continue retrying until the stage succeeds

**Retry tracking (for visibility):**
```
Stage 2 (plan-agent): Attempt 2
Issue: Plan missing test file locations
Retrying with: "Include specific test file paths for each feature"
```

---

## ANTI-DESTRUCTION RULES (enforced by all agents)

1. **READ before EDIT** - Never modify without reading first
2. **EDIT not WRITE** - Use Edit for existing files, Write only for new
3. **NO unnecessary files** - Prefer modifying existing files
4. **REAL tests** - Every new file needs 3+ real test functions
5. **RIGHT amount of change** - Not too much, not too little

---

## LONG-RUNNING CAPABILITY

**The pipeline has no artificial time limits. Work continues until complete.**

### No Time Constraints
- Agents continue working until their task is finished
- Build agents chain indefinitely until implementation is complete
- No timeout-based terminations

### State Persistence (Conceptual)

The pipeline maintains state for recovery:

```
PipelineState:
  session_id: unique identifier
  checkpoint: last completed stage
  status: "running" | "complete"
```

See full schema: `.ai/schemas/pipeline-state-schema.md`

### Checkpoint Protocol

State is checkpointed after each stage:
1. Stage completes successfully
2. Output added to PipelineContext
3. Checkpoint updated with stage number
4. If interrupted, resume from last checkpoint

### Recovery on Interrupt

```
1. Load last checkpoint
2. Restore PipelineContext
3. Resume from last completed stage
4. Continue pipeline normally
```

---

## NEVER-STOP PERSISTENCE

The pipeline runs continuously until decide-agent outputs COMPLETE.

- **No mandatory restarts** - decide-agent outputs COMPLETE when all criteria are genuinely met, on any pass
- **No retry limits** - Stages retry with improved prompts until they succeed
- **No artificial stopping points** - Pipeline never pauses except the single user confirmation after task-breakdown
- **No pass counting** - No restart_count, no first/subsequent pass distinction

The only way the pipeline stops is when decide-agent outputs COMPLETE with full evidence that all acceptance criteria are met.

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
- Dispatch to prompt-optimizer FIRST, then task-breakdown
- Pass context from previous stages to each agent
- RETRY with better instructions if output is poor
- Track attempts and display status
- No shortcuts, no exceptions
- Persist until each stage succeeds

---

## AGENT INTERNALS REFERENCE

This section provides the orchestrator with detailed knowledge of how each agent works internally.

### Agent Definition Location

All agent definitions are stored in `.claude/agents/{agent-name}.md` with YAML frontmatter:

```yaml
---
name: {agent-name}
description: {when to use this agent}
tools: {comma-separated list of available tools}
model: opus
color: blue
---
```

### Agent Capabilities by Type

| Agent Type | Tools Available | Primary Function |
|------------|-----------------|------------------|
| **prompt-optimizer** | Read, Grep, Glob, Bash | Optimize prompts before dispatch |
| **task-breakdown** | Read, Grep, Glob, Bash | Decompose requests into TaskSpec |
| **code-discovery** | Read, Grep, Glob, Bash | Analyze codebase, create RepoProfile |
| **plan-agent** | Read, Grep, Glob, Bash | Create batched implementation plan |
| **docs-researcher** | Read, WebSearch, WebFetch | Research library documentation |
| **pre-flight-checker** | Read, Bash, Glob | Pre-implementation sanity checks |
| **build-agent-1 to 55** | Write, Read, Edit, Grep, Glob, Bash, TodoWrite | Implement code changes |
| **debugger to debugger-11** | Read, Edit, Grep, Glob, Bash | Fix errors and bugs |
| **logical-agent** | Read, Grep, Glob | Verify code logic correctness |
| **test-agent** | Read, Bash, Grep, Glob | Run tests, verify implementation |
| **integration-agent** | Read, Bash, Grep | Integration testing |
| **review-agent** | Read, Grep, Glob | Review changes against criteria |
| **decide-agent** | Read | Make COMPLETE/RESTART decision |

### How to Direct Build Agents Effectively

**Always provide:**
1. **User's original request** - What they asked for
2. **TaskSpec** - Features with acceptance criteria
3. **RepoProfile** - Codebase conventions and patterns
4. **Implementation Plan** - Specific files and changes
5. **Previous stage outputs** - Any relevant context

**Build agent prompt template:**
```markdown
<task>Implement features F1 and F2 per the plan</task>

<context>
## User Request
[original request]

## TaskSpec
[paste TaskSpec]

## RepoProfile
[paste relevant conventions]

## Implementation Plan
[paste relevant batch]
</context>

<requirements>
- Follow RepoProfile conventions exactly
- Create real tests with actual assertions
- Complete every feature fully
</requirements>
```

### Agent Communication Protocol

**REQUEST Tag Format:**
```markdown
### REQUEST
REQUEST: [target-agent] - [reason]
Context: [additional context for target agent]
Priority: [critical|high|normal]
```

**Examples:**
```markdown
REQUEST: debugger - 3 test failures in auth module
Context: Failures in test_jwt_verify, test_token_refresh
Priority: high
```

```markdown
REQUEST: build-agent-2 - F3 implementation incomplete
Context: F1 and F2 complete, need to continue with F3
Priority: normal
```

### Quality Enforcement

All agents follow these quality rules:
- **READ before EDIT** - Never modify without reading first
- **EDIT not WRITE** - Use Edit for existing files, Write only for new
- **NO unnecessary files** - Prefer modifying existing files
- **REAL tests** - Every new file needs 3+ real test functions
- **RIGHT amount of change** - Not too much, not too little

<!-- BASE RULES - DO NOT MODIFY - END -->

---

<!-- PROJECT-SPECIFIC - AUTO-UPDATED - START -->

## Project Context
*Auto-populated by project-customizer agent*

### Tech Stack
- Not yet analyzed

### Patterns
- Not yet analyzed

<!-- PROJECT-SPECIFIC - AUTO-UPDATED - END -->
