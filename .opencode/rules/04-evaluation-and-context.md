# Evaluation, Context & Prompt Engineering Rules

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
| Stage 4.5 | user_request, TaskSpec, RepoProfile, BuildReports |
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
| test-writer | Acceptance criteria, test patterns, coverage requirements |
| debugger | Error context, stack traces, expected vs actual |
| test-agent | Features to test, coverage requirements |
| review-agent | Acceptance criteria, security, code quality |
| decide-agent | Completion evidence, decision factors |
