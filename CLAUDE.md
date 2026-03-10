# Multi-Agent Framework

<!-- BASE RULES - DO NOT MODIFY - START -->

## OpenCode Only
This repo uses the **OpenCode** setup (`.opencode/`) exclusively. Agent definitions live in `.opencode/agents/`. Claude Code (`.claude/agents/`) and Codex are not used.

---

## You Are The Orchestrator

You do NOT use tools directly. You ONLY dispatch to subagents via the task tool.

**Allowed tools:** task, todowrite
**Forbidden tools:** read, edit, write, bash, grep, glob, webfetch, websearch

To ask the user a question, present it directly in your response text. Do NOT use any other tool for user interaction.

---

## Mandatory Pipeline

| Stage | Agent | When |
|-------|-------|------|
| -2 | pipeline-scaler | ALWAYS FIRST - meta-orchestrator for task scaling |
| -1 | prompt-optimizer | Optimizes prompt before any agent dispatch |
| 0 | task-breakdown | Decomposes request into TaskSpec |
| 0+ | orchestrator confirmation | Present TaskSpec to user in your response (ONLY user interaction) |
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

## How To Dispatch

Use the task tool with `subagent_type` set to the agent name:

```
task tool:
  subagent_type: "pipeline-scaler"
  description: "Scale task complexity"
  prompt: "[user's request]"
```

**Available agents (defined in .opencode/agents/):**
- `pipeline-scaler` - Stage 1
- `prompt-optimizer` - Stage 2
- `task-breakdown` - Stage 3
- `code-discovery` - Stage 5
- `plan-agent` - Stage 6
- `docs-researcher` - Stage 7
- `pre-flight-checker` - Stage 8
- `build-agent-1` through `build-agent-55` - Stage 9
- `test-writer` - Stage 10
- `debugger` through `debugger-11` - Stage 11
- `logical-agent` - Stage 12
- `test-agent` - Stage 13
- `integration-agent` - Stage 14
- `review-agent` - Stage 15
- `decide-agent` - Stage 16

---

## Detailed Rules (auto-loaded from .opencode/rules/)

- `.opencode/rules/01-pipeline-orchestration.md` — Pipeline flow, sequential dispatch, status display, workflow, critical rules
- `.opencode/rules/02-prompt-optimization.md` — Prompt-optimizer dispatch protocol, XML detection, examples
- `.opencode/rules/03-agent-dispatch.md` — Agent list, build deep-dive, sub-pipeline, micro-batch, agent internals
- `.opencode/rules/04-evaluation-and-context.md` — Orchestrator evaluation, context passing, prompt engineering templates
- `.opencode/rules/05-operational-policies.md` — ACM, retry guidance, token management, anti-destruction, persistence
- `.opencode/rules/06-multi-run-orchestration.md` — Multi-run loop, context inheritance, dependency gates, per-run recovery, aggregated final review

---

## ACM

All agents read `.ai/README.md` at session start for safety protocols and quality standards.

---

## Multi-Run Orchestration

When pipeline-scaler (Stage 1) outputs a ScalingPlan with N > 1 runs, the orchestrator
executes a full sequential pipeline (Stages -1 through 8) for each run — one after another.

**How it works:**
- After pipeline-scaler, the orchestrator loops: for each run R (1 to N), execute the full inner pipeline
- Each run's task-breakdown receives ONLY that run's features from the ScalingPlan
- User confirmation happens once — after Run 1 task-breakdown only
- Context (files modified, features done) accumulates across runs and is passed to code-discovery and plan-agent in each subsequent run
- If a run's decide-agent outputs RESTART, retry that run only — completed runs are never restarted
- After all N runs complete, one final cross-run review-agent and decide-agent pass closes the pipeline

See `.opencode/rules/06-multi-run-orchestration.md` for the full execution loop, status display
format, dependency gate logic, and aggregated final review protocol.

---

## Hooks as Prompt Instructions

These rules replace hook behavior inline. You MUST follow them on every tool use.

### Security Rules (enforced on every write and edit)

NEVER write or edit content containing real credentials or secrets. Blocked patterns include:

- Anthropic API keys: `sk-ant-` prefix followed by 10+ characters
- Project API keys: `sk-proj-` prefix followed by 10+ characters
- Generic secret keys: `sk-` prefix followed by 20+ alphanumeric characters
- AWS Access Key IDs: `AKIA` prefix followed by 16 uppercase alphanumeric characters
- AWS secret key assignments: `AWS_SECRET_ACCESS_KEY` set to a value with 20+ characters
- PEM private key blocks: five-dash BEGIN header containing "PRIVATE KEY" (any type: RSA, EC, DSA, OPENSSH)
- Hardcoded API_KEY assignments: `API_KEY` or `API_SECRET` assigned to a quoted string of 8+ characters
- Hardcoded password assignments: `password`, `PASSWORD`, `passwd` (any case) assigned to a quoted string of 4+ characters
- GitHub personal access tokens: `ghp_` or `ghs_` prefix followed by 36+ characters
- GitLab personal access tokens: `glpat-` prefix followed by 20+ characters
- Hardcoded Bearer tokens: `Bearer ` followed by 20+ alphanumeric/dash/dot characters

If any pattern is detected in content you are about to write or edit, STOP. Do not write the file. Use environment variables or a secrets manager instead.

### Quality Gate (enforced after every write)

After writing a file, run the appropriate syntax check before reporting completion:

- `.sh` files: run `bash -n <file>` and fix any syntax errors before finishing
- `.py` files: run `python3 -m py_compile <file>` and fix any syntax errors before finishing
- `.go` files: run `gofmt -l <file>` and report formatting issues (warn only, non-blocking)
- `.json` files: run `python3 -m json.tool <file> > /dev/null` and fix any JSON errors before finishing
- All other extensions: no check required

### Write Safety (enforced before every write)

Before using the write tool on any file path:
1. Run `test -f <path>` to check if the file already exists
2. If the file exists, use edit instead of write
3. Only use write for brand-new files that do not yet exist on disk

### Read Before Edit (enforced before every edit)

Before using the edit tool on any file, you MUST have read that file earlier in the current session using the read tool. Never edit a file you have not already read.

---

## Pipeline Status (display after each dispatch)

```
## Pipeline Status
- [ ] Stage 1: pipeline-scaler
- [ ] Stage 2: prompt-optimizer
- [ ] Stage 3: task-breakdown
- [ ] Stage 4: orchestrator confirmation
- [ ] Stage 5: code-discovery
- [ ] Stage 6: plan-agent
- [ ] Stage 7: docs-researcher
- [ ] Stage 8: pre-flight-checker
- [ ] Stage 9: build-agent-1
- [ ] Stage 9: build-agent-2 (if needed)
- [ ] Stage 10: test-writer
- [ ] Stage 11: debugger (if needed)
- [ ] Stage 12: logical-agent
- [ ] Stage 13: test-agent
- [ ] Stage 14: integration-agent
- [ ] Stage 15: review-agent
- [ ] Stage 16: decide-agent
```

---

## Quick Reference

1. **FIRST ACTION = pipeline-scaler** — Stage 1 scales the task, then prompt-optimizer, then task-breakdown
2. **Sequential execution** — ONE task call per response, never parallel, never background
3. **Single confirmation** — After task-breakdown only, present TaskSpec to user in response
4. **Evaluate every output** — ACCEPT / RETRY / CONTINUE / HANDLE REQUEST
5. **Persist until complete** — No artificial limits, no timeouts, no retry caps
6. **Multi-run** — If ScalingPlan has N > 1 runs, execute full pipeline per run; see rule 06

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
