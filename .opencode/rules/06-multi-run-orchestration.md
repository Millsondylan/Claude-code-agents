# Multi-Run Orchestration Rules

## OVERVIEW

When pipeline-scaler (Stage -2) outputs a ScalingPlan with N > 1 runs, the orchestrator
executes N complete sequential pipeline runs — one after another — before issuing a final
aggregated review. Each run is a full pipeline (Stages -1 through 8) scoped to that run's
features only.

**For N = 1:** Skip this file. Follow 01-pipeline-orchestration.md normally.
**For N > 1:** This file governs the outer loop wrapping each inner pipeline.

---

## MULTI-RUN EXECUTION LOOP

```
ScalingPlan received (N runs)
│
├── [OUTER LOOP] For each run R (1 to N):
│     │
│     ├── Check dependency gate (R > 1 only)
│     ├── Extract run R features from ScalingPlan
│     ├── Execute full inner pipeline for run R:
│     │     Stage -1: prompt-optimizer
│     │     Stage  0: task-breakdown  ← receives ONLY run R features
│     │     Stage 0+: user confirmation (Run 1 only — see below)
│     │     Stage  1: code-discovery  ← sees all files including prior runs
│     │     Stage  2: plan-agent      ← knows what prior runs completed
│     │     Stage  3: docs-researcher
│     │     Stage 3.5: pre-flight-checker
│     │     Stage  4: build-agent-N   ← implements run R features only
│     │     Stage 4.5: test-writer
│     │     Stage  5: debugger        ← if errors
│     │     Stage 5.5: logical-agent
│     │     Stage  6: test-agent
│     │     Stage 6.5: integration-agent
│     │     Stage  7: review-agent
│     │     Stage  8: decide-agent    ← outputs COMPLETE or RESTART
│     │
│     ├── If decide-agent → RESTART: retry run R only (do not restart prior runs)
│     └── If decide-agent → COMPLETE: proceed to run R+1
│
└── [AFTER ALL RUNS] Final aggregated review-agent pass → decide-agent
```

---

## USER CONFIRMATION RULE

**Single confirmation for the entire multi-run pipeline.**

- Run 1 task-breakdown: present TaskSpec in response to user as normal
- Run 2+ task-breakdown: NO user confirmation — proceed automatically
- The user confirmed intent at Run 1. Subsequent runs are autonomous.

---

## CONTEXT INHERITANCE

Each run inherits accumulated context from all prior runs. Pass the following to each
inner pipeline stage:

| What to Pass | To Whom | Content |
|---|---|---|
| ScalingPlan | Every stage | Full ScalingPlan with all runs and their features |
| RunContext | Every stage | Which run this is (R of N), this run's features |
| CompletedRuns | code-discovery, plan-agent | List of features completed in runs 1..R-1 |
| FilesModified | code-discovery | All files modified or created in runs 1..R-1 |
| BuildReports | plan-agent, test-agent | Accumulated build reports from prior runs |

**Example context block to inject into every run R prompt:**
```
## Multi-Run Context
- ScalingPlan: [N] total runs
- Current run: R of N — "[Run R title]"
- This run's features: [list from ScalingPlan Run R]
- Completed in prior runs: [list from runs 1..R-1, or "None" for Run 1]
- Files modified so far: [list, or "None" for Run 1]
```

---

## RUN-SPECIFIC TASK FILTERING

task-breakdown and plan-agent MUST scope their output to the current run only.

**task-breakdown prompt injection (runs R > 1):**
```
SCOPE CONSTRAINT: You are generating a TaskSpec for Run R of N only.
Features in scope: [list from ScalingPlan Run R]
Features already complete (from prior runs): [list from runs 1..R-1]
DO NOT include prior-run features in this TaskSpec.
DO NOT redesign or modify completed prior-run work.
```

**plan-agent prompt injection (runs R > 1):**
```
SCOPE CONSTRAINT: Plan only the features for Run R.
Already implemented (do not re-plan): [list with file paths from prior runs]
Build on top of prior-run code — do not duplicate or replace it.
```

---

## DEPENDENCY GATES

Before starting run R, verify its declared dependencies from the ScalingPlan.

**Dependency Check Logic:**
```
IF run R has Dependencies: "None"
  → proceed immediately

IF run R has Dependencies: "Requires Run X complete"
  → verify run X decide-agent output is COMPLETE
  → if run X is not yet complete → ERROR: cannot start run R, re-run run X first
  → if run X is complete → proceed to run R
```

**Gate Display:**
```
## Dependency Gate: Run R
- Required: Run X complete ✓ (confirmed COMPLETE)
- Proceeding to Run R pipeline
```

---

## RECOVERY STRATEGY (Per-Run Retry)

If a run's decide-agent outputs RESTART:
1. Retry ONLY that run — do not restart prior completed runs
2. Pass the decide-agent's feedback into the re-run's prompt
3. Re-run the full inner pipeline for that run (Stages -1 through 8)
4. Track retry count per run (no limit, persist until COMPLETE)

**Retry context block:**
```
## Run R Retry Context
- Previous attempt: RESTART
- Decide-agent feedback: [paste feedback]
- Prior runs still complete — build on them as before
- Focus this retry on fixing: [specific issues from feedback]
```

---

## AGGREGATED FINAL REVIEW

After ALL N runs reach COMPLETE:

1. Dispatch review-agent with full cross-run context:
   - All N TaskSpecs
   - All N BuildReports
   - All files modified across all runs
   - Original user request
2. review-agent checks that all features from the ScalingPlan are implemented cohesively
3. Dispatch decide-agent with review output
4. If decide-agent → COMPLETE: pipeline ends
5. If decide-agent → RESTART: identify which run(s) need repair and re-run only those

---

## STATUS DISPLAY (Multi-Run)

Display after each agent dispatch:

```
## Multi-Run Pipeline Status
Runs: [R of N complete] | Current: Run R — "[title]"

### Run R Inner Pipeline
- [x] Stage -1: prompt-optimizer
- [x] Stage  0: task-breakdown
- [ ] Stage  1: code-discovery (IN PROGRESS)
- [ ] Stage  2: plan-agent
- [ ] Stage  3: docs-researcher
- [ ] Stage 3.5: pre-flight-checker
- [ ] Stage  4: build-agent
- [ ] Stage 4.5: test-writer
- [ ] Stage  5: debugger
- [ ] Stage 5.5: logical-agent
- [ ] Stage  6: test-agent
- [ ] Stage 6.5: integration-agent
- [ ] Stage  7: review-agent
- [ ] Stage  8: decide-agent

### Completed Runs
- [x] Run 1: [title] — COMPLETE
- [ ] Run 2: [title] — IN PROGRESS
- [ ] Run 3: [title] — PENDING
```

---

## CRITICAL RULES (Multi-Run Specific)

1. **Never restart prior runs** — A completed run stays complete. Only retry the failing run.
2. **Single user confirmation** — Only after Run 1 task-breakdown. Runs 2+ are autonomous.
3. **Always pass RunContext** — Every stage in every run must know which run it is and what prior runs completed.
4. **Dependency gates are blocking** — Never start a run before its declared dependencies are complete.
5. **Aggregated review is mandatory** — Even if each run passed its own review, run the final cross-run review-agent.
6. **ONE task call per response** — The sequential dispatch rule from 01-pipeline-orchestration.md applies inside every run.
