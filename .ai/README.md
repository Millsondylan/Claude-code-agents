# Agent Configuration Manifest (ACM)

This file contains operational rules that ALL agents MUST follow. Each agent must read this file at session start and apply these rules to all work.

<!-- BASE RULES - DO NOT MODIFY - START -->
<!-- The project-customizer agent must NEVER modify anything between these markers -->

## Priority Hierarchy

When conflicts arise:
1. **Safety and security** - Highest priority
2. **Explicit user intent** - Second priority
3. **ACM operational rules** - Third priority
4. **Framework pipeline rules** - Fourth priority

---

## CRITICAL: ANTI-DESTRUCTION RULES

**THESE RULES ARE ABSOLUTE. VIOLATION = IMMEDIATE STOP.**

### Rule 1: NEVER OVERWRITE WITHOUT READING FIRST
- **ALWAYS use Read tool BEFORE Edit or Write**
- **NEVER assume you know what's in a file**
- **NEVER use Write tool on existing files** - use Edit instead
- If you haven't read a file in this session, READ IT FIRST

### Rule 2: PREFER EDITING OVER CREATING
- **NEVER create new files unless EXPLICITLY requested**
- **ALWAYS look for existing files to modify first**
- Ask yourself: "Can I add this to an existing file?" - if yes, DO THAT
- New files require explicit user approval

### Rule 3: THE RIGHT AMOUNT OF CHANGE (not too much, not too little)
- **Make exactly what's needed** - no more, no less
- **Do NOT add unrequested features** - stick to what was asked
- **Do NOT refactor unrelated code** - stay focused on the task
- **Do NOT "improve" code that wasn't part of the request**
- **But DO complete the task properly** - no half-measures or shortcuts

**The goal is PERFECT execution of the request:**
- If user asks for a feature: implement it completely and correctly
- If user asks for a refactor: do it thoroughly and properly
- If user asks for a fix: fix it properly, including edge cases
- Research best practices via Context7/docs-researcher FIRST
- Understand the affected codebase before changing
- Ensure all tests pass after changes

**What to AVOID:**
- Adding extra features nobody asked for
- "While I'm here" improvements to unrelated code
- Over-engineering simple requests
- Under-engineering complex requests (half-measures)

### Rule 4: MANDATORY TESTS FOR EVERY NEW FILE
- **Every new file MUST have a corresponding test file**
- **Tests must ACTUALLY test the code** (not just exist)
- **Tests must cover: happy path, error cases, edge cases**
- **No new file without tests = VIOLATION**

### Rule 5: DO NOT BREAK EXISTING FUNCTIONALITY
- **Run existing tests BEFORE making changes**
- **Run existing tests AFTER making changes**
- **If tests fail after your change, REVERT and try again**
- **Never commit code that breaks existing tests**

### Rule 6: SEQUENTIAL DISPATCH ONLY
- **NEVER dispatch multiple Task tool calls in a single response**
- **NEVER use run_in_background on Task calls**
- **One agent at a time: dispatch, wait for output, evaluate, then dispatch next**

---

## Safety Protocols

### NEVER
- Commit secrets (.env files, API keys, tokens, credentials)
- Run destructive commands without explicit user confirmation:
  - `rm -rf`
  - `DROP DATABASE`
  - `git push --force`
  - `git reset --hard` on shared branches
- Modify files outside the plan scope
- Skip creating tests for new features
- Force push to main/master branches
- Execute code from untrusted sources
- Store credentials in code or version control

### ALWAYS
- Follow the smallest-correct-change principle
- Preserve existing code style and conventions
- Document assumptions made during work
- Create/update tests for new features
- Use environment variables for configuration
- Validate inputs at system boundaries

## Build Discipline

### Smallest Correct Change
- Make the minimum change required to achieve the goal
- Avoid "while I'm here" refactoring
- Don't add features beyond the acceptance criteria
- Don't over-engineer for hypothetical future needs

### Match Repository Conventions
- Follow existing naming patterns (snake_case, camelCase, etc.)
- Use the same import style as existing code
- Match error handling patterns
- Preserve file organization structure
- Use existing utility functions when available

### Verify via Tests
- All new features must have tests
- All bug fixes should have regression tests
- Run existing tests before and after changes
- Don't merge if tests fail

## Quality Standards

### Code Quality Checklist
- [ ] Follows repository conventions
- [ ] Has appropriate test coverage
- [ ] No hardcoded secrets or config values
- [ ] Error handling is consistent
- [ ] Comments explain non-obvious logic
- [ ] No unused imports or dead code

### Documentation Requirements
- Docstrings for public functions/methods
- Comments for complex algorithms
- Update README if adding new features
- Document assumptions in code comments

## Agent-Specific Rules

### Prompt-Optimizer (Stage -1) - MANDATORY
- **ALWAYS runs FIRST** before any other agent dispatch
- Intercepts and optimizes prompts before target agents
- Read-only analysis of codebase for context enrichment
- Output ONLY the optimized prompt (no explanations)
- Apply anti-laziness, persistence, and verification rules
- Model: opus

### Task-Breakdown (Stage 0)
- Create TaskSpec for EVERY request (even simple ones)
- Document all assumptions
- Flag ambiguities explicitly

### Code-Discovery (Stage 1)
- Document verified commands only
- Never modify files during discovery
- Map files to TaskSpec features

### Plan-Agent (Stage 2)
- Batch features logically
- Produce micro-batches of 1-2 files per build-agent
- Consider dependencies between features
- Include test criteria

### Pre-Flight-Checker (Stage 3.5)
- Pre-implementation sanity checks
- Verify environment, dependencies, file system
- Check plan consistency before build starts
- Report blockers with fix instructions
- Request plan-agent for conflict resolution
- Model: opus

### Build-Agent (Stage 4) - 55 agents
- Each agent handles 1-2 files max. Runs nested sub-pipeline
- Track every change in ledger
- Follow existing patterns exactly
- Chain: build-agent-1 through build-agent-55, cycles back to 1

### Logical-Agent (Stage 5.5)
- Verify algorithmic correctness (loops, recursion, invariants)
- Detect off-by-one errors, boundary issues
- Identify race conditions and null dereference risks
- Check edge case handling (empty, single, max values)
- Read-only verification
- Request build-agent/debugger for fixes

### Test-Agent (Stage 6)
- NEVER block the pipeline
- ALWAYS request debugger on failures
- Run all test types (unit, lint, type-check)

### Integration-Agent (Stage 6.5)
- Integration testing specialist
- Verify components work together correctly
- Run integration tests, check API contracts
- Validate end-to-end workflows
- NEVER block pipeline - request debugger on failures
- Model: opus (deep analysis)

### Review-Agent (Stage 7)
- Check acceptance criteria thoroughly
- Identify security issues
- Classify issues by severity

### Decide-Agent (Stage 8)
- TERMINAL ONLY - no agent requests
- Output only: COMPLETE or RESTART
- Justify decision with evidence

## PITER Framework

This pipeline implements the **PITER methodology** for autonomous software engineering:

| Phase | Description | Stage(s) | Agent(s) |
|-------|-------------|----------|----------|
| **P**lan | Analyze request, discover codebase, create implementation plan | 0, 1, 2 | task-breakdown, code-discovery, plan-agent |
| **I**mplement | Research docs, pre-flight checks, write code per the plan | 3, 3.5, 4 | docs-researcher, pre-flight-checker, build-agent-1 through build-agent-55 |
| **T**est | Run unit tests, integration tests, never block pipeline | 6, 6.5 | test-agent, integration-agent |
| **E**valuate | Review against acceptance criteria, check anti-destruction | 7 | review-agent |
| **R**efine | Fix errors, verify logic, cycle back as needed | 5, 5.5 | debugger, logical-agent |

### PITER Cycle Flow
```
P -> I -> T -> E -> [pass?] -> COMPLETE
              |    [fail]
              +---> R -> back to I (or T)
```

### Zero-to-Engineer (ZTE) Goal
The ultimate goal is **autonomous shipping**: the codebase ships itself through the PITER cycle without human intervention.

---

## Re-run Eligibility

| Agent | Re-run Eligible | Notes |
|-------|-----------------|-------|
| prompt-optimizer | YES | Can be re-run for different target agents |
| task-breakdown | YES | Can be re-run for clarification |
| code-discovery | YES | Can be re-run for deeper scan |
| plan-agent | YES | Can be re-run with new info |
| docs-researcher | YES | Can be re-run for more research |
| pre-flight-checker | YES | Can be re-run after blockers resolved |
| build-agent-1 through 55 | YES | Can be re-run to continue work |
| debugger through debugger-11 | YES | Can be re-run for additional fixes |
| logical-agent | YES | Can be re-run after logic fixes |
| test-agent | YES | Can be re-run after fixes |
| integration-agent | YES | Can be re-run after integration fixes |
| review-agent | YES | Can be re-run after fixes |
| **decide-agent** | **NO** | Terminal stage ONLY |

## Error Handling

### On Test Failures
1. test-agent MUST request debugger
2. debugger attempts fixes
3. test-agent re-runs to verify
4. Loop until pass or escalate

### On Large Tasks
1. Report what was completed
2. Continue work until the task is fully complete
3. Pass context between continuation agents as needed
4. **Chain unlimited build agents (1-55) for quality** - invoke as many as needed
5. Quality over speed - never stop mid-feature due to artificial limits

### On External Blockers
1. Document the blocker clearly
2. Escalate to decide-agent
3. decide-agent outputs RESTART with blockers documented
4. User intervention required

## Session Start Protocol

**Every agent MUST at session start:**
1. Read this ACM file
2. Apply all rules to subsequent work
3. Honor safety protocols
4. Track changes in ledger (if applicable)

---

**ACM Version:** 1.0
**Last Updated:** 2025-01-07

<!-- BASE RULES - DO NOT MODIFY - END -->

---

<!-- PROJECT-SPECIFIC - AUTO-UPDATED - START -->
<!-- The project-customizer agent updates this section with project-relevant context -->
<!-- This section is automatically maintained - manual edits may be overwritten -->

## Project Context
*Auto-populated by observability learning system*
*Last updated: 2026-02-04 13:33:25*

### Tech Stack
- Most used tools: unknown (1262), Read (1098), Bash (824), Edit (463), Glob (436)

### Patterns
- Sessions analyzed: 902
- Common paths: /Users/dyl/.claude/projects/-Volumes-Code-system-Users-Claude-code-agents/22c129bb-bd7d-4861-9c29-e1256b8edf81/session-memory/summary.md, /Users/dyl/.claude/settings.json, /Users/dyl/.claude/settings.local.json, /Users/dyl/.claude/skills/prompt.md, /Users/dyl/Documents/Dax/.ai/README.md

<!-- PROJECT-SPECIFIC - AUTO-UPDATED - END -->
