# Agent Dispatch & Build Pipeline Rules

## HOW TO DISPATCH

**Use agent name as subagent_type:**

```
task tool:
  subagent_type: "task-breakdown"
  prompt: "[context from previous stages + user's request]"
```

**Available agents (defined in .opencode/agents/):**
- `pipeline-scaler` - Stage -2 (scales pipeline resources based on task complexity)
- `prompt-optimizer` - Stage -1 (ALWAYS FIRST - optimizes prompts before any agent dispatch)
- `task-breakdown` - Stage 0 (after prompt-optimizer)
- `code-discovery` - Stage 1
- `plan-agent` - Stage 2
- `docs-researcher` - Stage 3
- `pre-flight-checker` - Stage 3.5 (pre-implementation sanity checks)
- `build-agent-1` through `build-agent-55` - Stage 4 (implementation agents, chain sequentially)
- `test-writer` - Stage 4.5 (writes tests for implemented features)
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

---

## BUILD AGENT DEEP-DIVE

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

---

## BUILD SUB-PIPELINE

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

2.5 TEST WRITING
   └── test-writer generates tests for implemented files

3. POST-CHECKS
   ├── test-writer (generate tests for implemented files)
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
- [ ] Post-check: test-writer
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

---

## INTELLIGENT MULTI-INVOCATION GUIDANCE

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

## AGENT INTERNALS REFERENCE

### Agent Definition Location

All agent definitions are stored in `.opencode/agents/{agent-name}.md` with YAML frontmatter:

```yaml
---
description: {when to use this agent}
mode: subagent
model: {provider/model-id}
hidden: true
color: "#HEXCOLOR"
tools:
  write: true
  read: true
  edit: true
  grep: true
  glob: true
  bash: true
---
```

Note: OpenCode uses structured YAML `tools:` map (not comma-separated string) and full model IDs like `anthropic/claude-opus-4-6`, `kimi-for-coding/k2p5`, `zai-coding-plan/glm-5` (not shorthand like `opus`, `sonnet`, `haiku`).

### Agent Capabilities by Type

| Agent Type | Tools Available | Primary Function |
|------------|-----------------|------------------|
| **pipeline-scaler** | Read, Bash, Glob | Scale pipeline resources for task complexity |
| **prompt-optimizer** | Read, Grep, Glob, Bash | Optimize prompts before dispatch |
| **task-breakdown** | Read, Grep, Glob, Bash | Decompose requests into TaskSpec |
| **code-discovery** | Read, Grep, Glob, Bash | Analyze codebase, create RepoProfile |
| **plan-agent** | Read, Grep, Glob, Bash | Create batched implementation plan |
| **docs-researcher** | Read, WebSearch, WebFetch | Research library documentation |
| **pre-flight-checker** | Read, Bash, Glob | Pre-implementation sanity checks |
| **build-agent-1 to 55** | write, read, edit, grep, glob, bash, todowrite | Implement code changes |
| **test-writer** | Write, Read, Edit, Grep, Glob, Bash | Write tests for implemented features |
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
