# Agent Teams: Parallel Execution Exploration

> STATUS: EXPLORATION ONLY
> This document is a design study. Agent Teams is an experimental Claude Code feature.
> Nothing described here is currently implemented or enabled in the pipeline.
> Do not change CLAUDE.md or any agent definitions based on this document without
> explicit team review and testing.

---

## 1. Overview

Claude Code's experimental **Agent Teams** feature introduces a Team Lead + Teammates
architecture where a lead agent can spawn parallel teammate agents, coordinate via a
shared task list, and communicate through mailbox-style messaging (sendMessage). This
is distinct from the current framework, which dispatches one agent at a time and passes
outputs as text between stages.

For this multi-agent pipeline, Agent Teams matters because the biggest source of
latency is the depth of the sequential chain. A request that touches 10 files must
pass through prompt-optimizer, task-breakdown, code-discovery, plan-agent,
docs-researcher, pre-flight-checker, 10 build agents (1-2 files each), test-writer,
debugger loops, test-agent, integration-agent, review-agent, and decide-agent — all
in strict sequence. With Agent Teams, independent workstreams within that chain could
run concurrently, cutting wall-clock time for large features significantly.

The key distinction is: **Agent Teams enables parallelism within a pipeline run.
The pipeline-scaler (Stage -2) enables parallelism across pipeline runs.** Together
they address both dimensions of scale.

---

## 2. How to Enable Agent Teams

Agent Teams is controlled by a single environment variable:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Where to Set It

**Option A — Shell profile (persistent):**
```bash
# Add to ~/.zshrc or ~/.zprofile
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

**Option B — Per-session in switcher.zsh:**

Add the export to `model-switch/switcher.zsh` in the `_cc_load_env` function, alongside
the existing environment variable defaults:

```bash
_cc_load_env() {
  # ... existing env loading ...

  # Experimental: enable Agent Teams for parallel workstreams
  : "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:=1}"
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
}
```

**Option C — Per-invocation (safest for testing):**
```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude "your request here"
```

Option C is the safest approach for the proof-of-concept test plan described in
Section 9, since it scopes the feature to a single invocation without affecting the
default environment.

---

## 3. Current Architecture: Strictly Sequential

The current pipeline enforces **one agent at a time**. This rule is explicit in
CLAUDE.md:

> "ONE Task call per response — NEVER place more than one Task tool call in a single
> message/response."

The full pipeline from Stage -2 to Stage 8:

```
Stage -2: pipeline-scaler
Stage -1: prompt-optimizer
Stage  0: task-breakdown
Stage  0+: user confirmation (AskUserQuestion)
Stage  1: code-discovery
Stage  2: plan-agent
Stage  3: docs-researcher
Stage  3.5: pre-flight-checker
Stage  4: build-agent-1 ... build-agent-55 (chained)
Stage  4.5: test-writer
Stage  5: debugger ... debugger-11 (chained, if needed)
Stage  5.5: logical-agent
Stage  6: test-agent
Stage  6.5: integration-agent
Stage  7: review-agent
Stage  8: decide-agent
```

Every arrow in that chain is sequential. A large feature with 20 files means at
minimum 20 build-agent invocations before any testing begins. Each one waits for
the previous to complete.

---

## 4. What Agent Teams Enables

### 4.1 Team Lead + Teammates Architecture

In an Agent Teams model, the orchestrator becomes a **Team Lead**. Instead of
dispatching one agent and waiting, it can spawn multiple **Teammate** agents
concurrently. Each teammate runs independently in its own context and reports
back when finished.

```
Team Lead (Orchestrator)
├── Teammate A: build-agent (files 1-2)
├── Teammate B: build-agent (files 3-4)
└── Teammate C: build-agent (files 5-6)
         |
         v (all complete)
Team Lead resumes, merges results
```

### 4.2 Shared Task List

Agent Teams provides a shared Task List that all members of the team can read and
update. This solves a coordination problem: in the current pipeline, agents cannot
see what sibling agents are doing. With a shared task list:

- build-agent-2 can mark "src/auth.ts" as claimed before it starts writing
- build-agent-3 sees that claim and skips that file, avoiding conflicts
- The Team Lead can track completion of all parallel workstreams in real time

### 4.3 Mailbox-Style Messaging (sendMessage)

Agent Teams introduces `sendMessage`, which allows agents to communicate
directly with each other rather than routing everything through the orchestrator.
This enables patterns like:

- test-writer sending a message to build-agent when it finds a gap in coverage
- integration-agent notifying a build-agent that its output broke an interface
- A build-agent asking docs-researcher for a specific API clarification without
  going through the full pipeline

Example conceptual flow:
```
build-agent-3 -> sendMessage(test-writer, "Implemented src/payments.ts, ready for test generation")
test-writer -> sendMessage(build-agent-3, "Tests written at src/payments.test.ts, check line 47 assertion")
```

### 4.4 Parallel Execution of Independent Workstreams

The most direct benefit: truly independent work runs at the same time. If features
F1 (user auth) and F2 (product catalog) touch completely separate files and have no
shared imports, there is no reason they must be built serially. Agent Teams allows
them to be built in parallel, with the Team Lead merging build reports when both
finish.

---

## 5. Stages That Could Benefit from Parallelism

### 5.1 Stage 4 — Build Agents on Independent Features

This is the highest-impact opportunity. When the plan-agent produces an
ImplementationPlan where features are explicitly marked as independent (no shared
files, no shared imports), build agents implementing those features could run
concurrently.

**Example:**
The plan-agent identifies:
- Batch A: `src/auth/login.ts`, `src/auth/session.ts` (feature: user authentication)
- Batch B: `src/catalog/product.ts`, `src/catalog/search.ts` (feature: product catalog)
- Batch C: `src/cart/cart.ts`, `src/cart/checkout.ts` (feature: shopping cart, depends on A)

Batch A and B are independent. Under Agent Teams, they run simultaneously. Batch C
waits for Batch A to complete (dependency declared in the plan). Total time: max(A, B)
+ C instead of A + B + C.

**Coordination mechanism:** The shared Task List shows which files are claimed, preventing
two build agents from attempting to edit the same file simultaneously.

### 5.2 Stage 6 + 6.5 — test-agent and integration-agent Simultaneously

Currently, test-agent (Stage 6) must complete before integration-agent (Stage 6.5)
starts. In practice, these often cover different ground:

- test-agent: runs unit tests, checks individual file behavior
- integration-agent: checks cross-module interactions, API contracts, end-to-end flows

For most features, unit tests and integration tests are independent enough to run
in parallel. Both read the same built files but do not write to them. There is no
write-write conflict.

**Example parallel dispatch:**
```
Team Lead spawns:
  Teammate A: test-agent (run unit tests for src/auth/, src/catalog/)
  Teammate B: integration-agent (check API contract between auth and catalog)

Both complete -> Team Lead evaluates both reports -> proceeds to review-agent
```

If either fails, the Team Lead dispatches a debugger, the fix is applied, and both
test stages re-run. This removes one sequential wait from every pipeline run.

### 5.3 Stage 1 — code-discovery Scanning Multiple Directories in Parallel

For large monorepos or repositories with many distinct domains (frontend, backend,
infrastructure, data layer), the code-discovery agent currently scans everything
sequentially. With Agent Teams, the Team Lead could spawn multiple discovery agents,
each responsible for one directory tree:

```
Team Lead spawns:
  Teammate A: code-discovery (scan src/frontend/)
  Teammate B: code-discovery (scan src/backend/)
  Teammate C: code-discovery (scan infrastructure/)

All complete -> Team Lead merges into unified RepoProfile
```

For a repo with 200+ files spread across 5 domains, this could cut discovery time
substantially, particularly for the file-by-file Grep and Read passes.

### 5.4 Stage 4.5 — test-writer Running Alongside Ongoing Builds

Currently, test-writer waits for all build agents to complete before writing tests.
With Agent Teams, test-writer could start generating tests for completed batches while
later build batches are still running:

```
Batch A completes -> Team Lead spawns test-writer(A) immediately
Batch B still running...
Batch B completes -> Team Lead spawns test-writer(B) immediately
test-writer(A) and test-writer(B) may overlap in time
```

This is safe because test-writer only reads source files (never writes to them)
and writes to test files that are uniquely named per batch (e.g., `auth.test.ts`,
`catalog.test.ts`). No write-write conflict exists.

---

## 6. Stages That Must Remain Sequential

### 6.1 Stage -2 — pipeline-scaler

The pipeline-scaler must complete before any other stage can start. Its ScalingPlan
determines how many pipeline runs are needed and how work is partitioned. Without this
output, no downstream agent knows what to build or whether to split across runs. There
is no meaningful work that can proceed in parallel with the pipeline-scaler.

**Why it cannot be parallelized:** It has no peers. It is the first agent in the
chain, and its output is an input to every other stage.

### 6.2 Stage 0 — task-breakdown

The task-breakdown agent reads the optimized prompt (from Stage -1) and produces the
TaskSpec — the definitive list of features with acceptance criteria. Every downstream
agent (plan-agent, build agents, test-writer, review-agent) depends on the TaskSpec.
No implementation can begin until features are formally defined.

**Why it cannot be parallelized:** Its output is a universal dependency. Running
anything in parallel with task-breakdown would be operating without a TaskSpec, which
means agents would have no acceptance criteria to satisfy.

### 6.3 Stage 0+ — User Confirmation

The orchestrator presents the TaskSpec to the user via AskUserQuestion and waits
for approval. This is the only human-in-the-loop interaction in the pipeline. It is
by definition sequential: the user must read and confirm before implementation begins.
Parallelizing around a human approval gate is not meaningful.

**Why it cannot be parallelized:** It is a human interaction checkpoint. No agent
can proceed before the user confirms intent.

### 6.4 Stage 8 — decide-agent

The decide-agent makes the final COMPLETE / RESTART / ESCALATE decision after
reviewing all prior stage outputs. It needs the full PipelineContext — TaskSpec,
RepoProfile, Build Reports, Test Report, Integration Report, Review Report — before
it can render a verdict. If any upstream stage output is missing, the decision is
incomplete.

**Why it cannot be parallelized:** It is the terminal stage. By definition it comes
last and depends on all prior outputs. It also cannot be split — there is only one
final decision per pipeline run.

---

## 7. Risk Assessment

### 7.1 File System Race Conditions

If two build agents are both assigned files and one of them is also touched by the
other (e.g., a shared utility file or a re-exported index file), they could
simultaneously attempt to edit the same file. The last write wins, and one agent's
changes could overwrite the other's.

**Mitigation:** The plan-agent must explicitly partition files with no overlap. Each
batch in the ImplementationPlan must list files exclusively — no file appears in two
batches. The shared Task List in Agent Teams provides a claim mechanism, but it
requires that build agents actually check the Task List before editing a file and
that the orchestrator enforces this protocol.

**Current risk level:** High. File partitioning is not currently enforced at the
plan-agent level in a way that would be Agent Teams-aware.

### 7.2 Context Window Competition

Each teammate agent in an Agent Teams session draws from a shared token budget or
competes for the model's context capacity. For Opus 4.6 with a 200K token default
context window, running 5 build agents simultaneously means 5 concurrent model
invocations, each consuming their own context independently. The risk is not shared
context exhaustion (each agent has its own context) but rather:

- API rate limits (concurrent requests may hit throughput limits)
- Cost amplification (parallel agents multiply API spend proportionally)
- Subagent output cap: each teammate output is capped at approximately 32K tokens,
  which may be insufficient for complex build tasks that currently spread across
  multiple sequential agents

**Mitigation:** Limit team size to 2-3 parallel agents maximum in the proof-of-concept.
Monitor API rate limit responses and add retry logic before scaling up.

### 7.3 Non-Deterministic Ordering Makes Debugging Harder

In the current sequential pipeline, every stage has a fixed position in the chain.
When something fails, the orchestrator knows exactly which stage produced the bad
output. With parallel execution, the order in which agents complete is non-deterministic.
Build reports arrive in an unpredictable sequence. A bug introduced by build-agent-A
may not surface until test-agent runs after build-agent-B has completed. Attributing
the failure to the correct agent becomes harder.

**Mitigation:** Each agent's output must be tagged with its agent identifier and the
specific files it touched. The debugger receives this attribution information so it can
target the correct agent's work.

### 7.4 Experimental Feature Stability

Agent Teams is explicitly experimental as of the time this document was written.
Experimental features may have undocumented limitations, breaking changes in future
versions, or behaviors that differ from the documentation. Shipping pipeline logic
that depends on an experimental feature introduces fragility.

**Mitigation:** Use Option C from Section 2 (per-invocation env var) for all testing.
Do not change the default pipeline behavior until Agent Teams has been validated
through the proof-of-concept test plan and has moved to stable status.

---

## 8. Relationship to Pipeline-Scaler

The pipeline-scaler (Stage -2) and Agent Teams address parallelism at different
levels of the architecture.

### 8.1 What Pipeline-Scaler Does

The pipeline-scaler produces a **ScalingPlan** that partitions the user's request
into multiple sequential pipeline runs. Each run is a complete pass through all
pipeline stages (-1 through 8). The runs themselves are sequential by default:
Run 1 completes before Run 2 starts (because Run 2 may depend on Run 1's output).

Example ScalingPlan for a 3-run request:
```
Run 1: User Authentication (14 files)
Run 2: REST to GraphQL Migration (22 files, depends on Run 1)
Run 3: Real-Time Notification System (18 files, depends on Run 1)
```

### 8.2 Where Agent Teams Fits

Within a single pipeline run, Agent Teams can parallelize the build stage. The
ScalingPlan already identifies which features belong to which run. Within Run 1
("User Authentication"), the plan-agent may identify sub-batches that are
independent (e.g., login flow vs. session management). These sub-batches could
run as parallel teammates.

### 8.3 Composing the Two

```
pipeline-scaler ScalingPlan
        |
        v
Run 1 starts (15-stage pipeline)
    Stage 4: Agent Teams active
    ├── build-agent: login flow files
    └── build-agent: session management files (parallel)
Run 1 complete
        |
        v
Run 2 starts (depends on Run 1)
    Stage 4: Agent Teams active
    ├── build-agent: schema files
    └── build-agent: resolver files (parallel)
Run 2 complete
...
```

The ScalingPlan's `Dependencies` field (e.g., "Requires Run 1 complete") gates
when the next run starts. Within each run, Agent Teams enables intra-run
parallelism. The two mechanisms compose cleanly because they operate at different
granularities: across-runs (pipeline-scaler) and within-runs (Agent Teams).

### 8.4 Mapping ScalingPlan to Team Formation

When Agent Teams is enabled, the orchestrator could use the ScalingPlan's feature
list to form teams within each run:

```
ScalingPlan Run 1 features:
- F1: User signup flow (src/auth/signup.ts)
- F2: User login flow (src/auth/login.ts)     <- independent of F1
- F3: Auth middleware (src/middleware/auth.ts) <- depends on F1 and F2

Team formation:
  Teammates: build-agent(F1), build-agent(F2)  [parallel]
  After both complete: build-agent(F3)          [sequential, gated on F1+F2]
```

The plan-agent is the natural place to annotate which batches are parallelizable
and which have dependencies, since it already reasons about file-level groupings.

---

## 9. Proof-of-Concept Test Plan

This section outlines concrete steps to validate Agent Teams integration with the
pipeline. All steps use Option C (per-invocation env var) to avoid side effects.

### Step 1 — Baseline Measurement (no Agent Teams)

Run a medium-complexity request (4-8 files, 2 independent features) through the
current sequential pipeline. Record:

- Total wall-clock time from prompt to decide-agent COMPLETE
- Number of build-agent invocations
- Files modified by each build agent

```bash
# Baseline run (no Agent Teams)
claude "Add a health check endpoint and a metrics endpoint to the API"
```

Save the pipeline status log and total time.

### Step 2 — Enable Agent Teams, Same Request

Run the identical request with Agent Teams enabled:

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude "Add a health check endpoint and a metrics endpoint to the API"
```

Observe:
- Does the orchestrator spawn parallel build agents for the two endpoints?
- Do both agents complete without file conflicts?
- Is the total time shorter than the baseline?

### Step 3 — Verify File System Safety

Inspect the files produced by Step 2:
- Confirm no file was partially overwritten
- Confirm both features are fully implemented (not just the one that "won" a race)
- Confirm test files for both endpoints exist

If any file is missing or corrupted, treat this as a race condition failure and
document the exact conditions.

### Step 4 — Test Parallel Test Stages (Stage 6 + 6.5)

Specifically test whether test-agent and integration-agent can run concurrently.
Use a request that will exercise both stages:

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude "Add a user profile API endpoint with unit tests and verify it integrates with the auth middleware"
```

Observe:
- Does Stage 6 and Stage 6.5 overlap in execution time?
- Do both reports arrive in the pipeline context before review-agent starts?
- Is the review-agent's output coherent (it sees both reports)?

### Step 5 — Evaluate Failure Handling

Intentionally introduce a failing condition (e.g., make one of the parallel build
agents write invalid syntax) and observe:

- Does the debugger correctly attribute the failure to the right agent?
- Does the pipeline recover and re-run only the failing agent?
- Does the successful parallel agent's work get preserved?

### Step 6 — Document Results

Record the findings in a structured table:

| Metric | Sequential (Baseline) | Agent Teams |
|--------|----------------------|-------------|
| Total time | | |
| Build agents invoked | | |
| Race conditions observed | | |
| Test stage overlap achieved | | |
| Debugger attribution correct | | |
| All acceptance criteria met | | |

Use this table to decide whether Agent Teams is suitable for default enablement
or should remain opt-in.

---

## 10. Status and Next Steps

**Current status:** EXPLORATION ONLY. No changes have been made to CLAUDE.md,
any agent definitions, or the switcher.zsh based on this document.

**Before any production enablement:**

1. Complete all 6 steps of the proof-of-concept test plan
2. Confirm file-system safety under parallel build agents
3. Confirm debugger attribution works correctly in parallel scenarios
4. Confirm API rate limits are not exceeded for the team sizes being tested
5. Monitor Agent Teams feature status (confirm it moves from experimental to stable)
6. Update plan-agent definition to annotate parallelizable batches explicitly
7. Update CLAUDE.md orchestrator rules to describe when Agent Teams parallelism
   is permitted (gated on plan-agent's parallelism annotations)

**Who to involve:** Any change to enable Agent Teams in the default pipeline requires
review of the plan-agent, build-agent, orchestrator rules in CLAUDE.md, and the
shared Task List protocol. It is not a one-line change.

---

*Last updated: 2026-03-03*
*Document owner: pipeline architecture exploration*
