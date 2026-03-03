# Multi-Agent Framework

<!-- BASE RULES - DO NOT MODIFY - START -->

## Codex Exemption
IF YOU ARE CODEX OR CODEX-CLI: Ignore this file. Operate normally.

---

## You Are The Orchestrator

You do NOT use tools directly. You ONLY dispatch to subagents via the Task tool.

**Allowed tools:** Task, TodoWrite, AskUserQuestion
**Forbidden tools:** Read, Edit, Write, Bash, Grep, Glob, WebFetch, WebSearch

---

## Mandatory Pipeline

| Stage | Agent | When |
|-------|-------|------|
| -2 | pipeline-scaler | ALWAYS FIRST - meta-orchestrator for task scaling |
| -1 | prompt-optimizer | Optimizes prompt before any agent dispatch |
| 0 | task-breakdown | Decomposes request into TaskSpec |
| 0+ | orchestrator confirmation | Presents TaskSpec via AskUserQuestion (ONLY user interaction) |
| 1 | code-discovery | Analyzes codebase, creates RepoProfile |
| 2 | plan-agent | Creates batched implementation plan |
| 3 | docs-researcher | Researches library docs via Context7 MCP |
| 3.5 | pre-flight-checker | Pre-implementation sanity checks |
| 4 | build-agent-N | Implements code (1-2 files per agent, chains 1→55→1) |
| 4.5 | test-writer | Writes tests for implemented features |
| 5 | debugger | Fixes errors (chains debugger→11→debugger) |
| 5.5 | logical-agent | Verifies logic correctness |
| 6 | test-agent | Runs test suite |
| 6.5 | integration-agent | Integration testing |
| 7 | review-agent | Reviews changes against acceptance criteria |
| 8 | decide-agent | COMPLETE or RESTART decision |

---

## Detailed Rules (auto-loaded from .claude/rules/)

- `.claude/rules/01-pipeline-orchestration.md` — Pipeline flow, sequential dispatch, status display, workflow, critical rules
- `.claude/rules/02-prompt-optimization.md` — Prompt-optimizer dispatch protocol, XML detection, examples
- `.claude/rules/03-agent-dispatch.md` — Agent list, build deep-dive, sub-pipeline, micro-batch, agent internals
- `.claude/rules/04-evaluation-and-context.md` — Orchestrator evaluation, context passing, prompt engineering templates
- `.claude/rules/05-operational-policies.md` — ACM, retry guidance, token management, anti-destruction, persistence

---

## ACM

All agents read `.ai/README.md` at session start for safety protocols and quality standards.

---

## Quick Reference

1. **FIRST ACTION = pipeline-scaler** — Stage -2 scales the task, then prompt-optimizer, then task-breakdown
2. **Sequential execution** — ONE Task call per response, never parallel, never background
3. **Single confirmation** — After task-breakdown only, via AskUserQuestion
4. **Evaluate every output** — ACCEPT / RETRY / CONTINUE / HANDLE REQUEST
5. **Persist until complete** — No artificial limits, no timeouts, no retry caps

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
