# PipelineContext Schema

**Agent:** Orchestrator (managed internally)
**Stage:** Cross-stage aggregation
**Purpose:** Defines the aggregated context structure that accumulates outputs from all pipeline stages and enables loop-back triggers for re-runs.

---

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `user_request` | string | Original user request (preserved verbatim) |
| `current_stage` | number | Current pipeline stage (-1 to 8) |
| `stage_outputs` | StageOutputs | Aggregated outputs from completed stages |
| `loop_back_triggers` | array[LoopBackTrigger] | Pending re-run requests from agents |
| `retry_history` | array[RetryRecord] | History of retried stages |
| `metadata` | ContextMetadata | Pipeline execution metadata |

---

## Object Definitions

### StageOutputs

Aggregated outputs from each completed stage.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stage_neg1_prompt` | string | No | Optimized prompt from prompt-optimizer |
| `stage_0_taskspec` | TaskSpec | No | TaskSpec from task-breakdown |
| `stage_1_repoprofile` | RepoProfile | No | RepoProfile from code-discovery |
| `stage_2_plan` | ImplementationPlan | No | Plan from plan-agent |
| `stage_3_docs` | DocsResearchOutput | No | Documentation from docs-researcher |
| `stage_3_5_preflight` | PreFlightCheck | No | Pre-flight check from pre-flight-checker |
| `stage_4_builds` | array[BuildReport] | No | Build reports from build-agent-N |
| `stage_5_debug` | array[DebugReport] | No | Debug reports from debugger |
| `stage_5_5_logic` | LogicVerification | No | Logic verification from logical-agent |
| `stage_6_tests` | TestReport | No | Test report from test-agent |
| `stage_6_5_integration` | IntegrationTestReport | No | Integration test report from integration-agent |
| `stage_7_review` | ReviewReport | No | Review report from review-agent |
| `sub_pipeline_results` | array[SubPipelineResult] | No | Results from nested build sub-pipelines |

### SubPipelineResult

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `build_agent` | string | Yes | Build agent ID |
| `files_targeted` | array[string] | Yes | Files assigned (1-2 max) |
| `pre_check_passed` | boolean | Yes | Pre-checks passed |
| `build_completed` | boolean | Yes | Build completed |
| `post_check_passed` | boolean | Yes | Post-checks passed |
| `debug_iterations` | number | Yes | Debug attempts (0+) |
| `final_status` | string | Yes | "success" or "needs_external_debug" |

### LoopBackTrigger

Defines a request for an agent to re-run or for the pipeline to loop back.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `trigger_id` | string | Yes | Unique identifier (LB1, LB2, LB3...) |
| `source_agent` | string | Yes | Agent that requested the loop-back |
| `source_stage` | number | Yes | Stage number of requesting agent |
| `target_agent` | string | Yes | Agent to dispatch |
| `target_stage` | number | Yes | Stage to loop back to |
| `reason` | string | Yes | Why the loop-back is needed |
| `context` | string | No | Additional context for target agent |
| `priority` | string | Yes | "critical", "high", "normal" |
| `status` | string | Yes | "pending", "dispatched", "completed" |

### RetryRecord

Records a retry attempt for a stage.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stage` | number | Yes | Stage that was retried |
| `agent` | string | Yes | Agent that was retried |
| `attempt` | number | Yes | Attempt number (1, 2, 3...) |
| `issue` | string | Yes | What went wrong |
| `improvement` | string | Yes | How the retry prompt was improved |
| `timestamp` | string | Yes | ISO 8601 timestamp |

### ContextMetadata

Execution metadata for the pipeline.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pipeline_start` | string | Yes | ISO 8601 timestamp of pipeline start |
| `last_updated` | string | Yes | ISO 8601 timestamp of last update |
| `total_agent_calls` | number | Yes | Total number of agent dispatches |
| `build_agent_cycle` | number | No | Current build agent cycle (1-3) |
| `build_agent_index` | number | No | Current build agent index (1-5) |

### DocsResearchOutput

Output from docs-researcher stage.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `queries` | array[string] | Yes | Documentation queries made |
| `findings` | array[DocFinding] | Yes | Relevant documentation found |
| `api_patterns` | array[string] | No | Extracted API usage patterns |

### DocFinding

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source` | string | Yes | Documentation source (URL or file) |
| `topic` | string | Yes | Topic of the finding |
| `content` | string | Yes | Relevant content extracted |
| `relevance` | string | Yes | How it applies to the task |

---

## Validation Rules

### Required Validations
1. **user_request present**: Must contain the original user request
2. **current_stage valid**: Must be -1 to 8
3. **stage_outputs consistent**: Only completed stages should have outputs
4. **loop_back_triggers unique**: Each trigger_id must be unique
5. **retry_history ordered**: Records should be in chronological order

### Quality Validations
- Stage outputs should match their respective schemas
- Loop-back triggers must have actionable reasons
- Metadata timestamps must be valid ISO 8601

---

## Context Flow Pattern

```
User Request
     |
     v
+------------------+
| PipelineContext  |  <-- Created at start
| - user_request   |
| - current_stage  |
| - stage_outputs  |
| - loop_triggers  |
+------------------+
     |
     v
Stage 0 completes --> stage_outputs.stage_0_taskspec = TaskSpec
     |
     v
Stage 1 completes --> stage_outputs.stage_1_repoprofile = RepoProfile
     |
     v
  ... continues ...
     |
     v
Agent requests loop-back --> loop_back_triggers.push(LoopBackTrigger)
     |
     v
Orchestrator handles --> loop_back_triggers[i].status = "dispatched"
     |
     v
Loop-back completes --> loop_back_triggers[i].status = "completed"
```

---

## Loop-Back Trigger Format

Agents request loop-backs using the REQUEST tag:

```markdown
### REQUEST

REQUEST: [target-agent] - [reason]
Context: [additional context for target agent]
Priority: [critical|high|normal]
```

The orchestrator parses this and creates a LoopBackTrigger:

```json
{
  "trigger_id": "LB1",
  "source_agent": "test-agent",
  "source_stage": 6,
  "target_agent": "debugger",
  "target_stage": 5,
  "reason": "3 test failures in auth module",
  "context": "Failures in test_jwt_verify, test_token_refresh, test_auth_middleware",
  "priority": "high",
  "status": "pending"
}
```

---

## Context Passing Rules

### What to Include in Agent Prompts

| Target Stage | Required Context |
|--------------|-----------------|
| Stage 0 | user_request |
| Stage 1 | user_request, stage_0_taskspec |
| Stage 2 | user_request, stage_0_taskspec, stage_1_repoprofile |
| Stage 3 | user_request, stage_0_taskspec, stage_2_plan |
| Stage 4 | user_request, stage_0_taskspec, stage_1_repoprofile, stage_2_plan, stage_3_docs |
| Stage 5 | user_request, stage_0_taskspec, stage_4_builds, stage_6_tests (if available) |
| Stage 5.5 | user_request, stage_0_taskspec, stage_4_builds |
| Stage 6 | user_request, stage_0_taskspec, stage_1_repoprofile, stage_4_builds |
| Stage 7 | All stage outputs |
| Stage 8 | All stage outputs |

### Minimal Context Principle
- Pass only what the agent needs
- Summarize large outputs when possible
- Always include user_request for context

---

## Example

```markdown
## PipelineContext

### User Request
Add a REST API health check endpoint that returns service status.

### Current Stage
4 (build-agent-1)

### Stage Outputs

#### Stage 0: TaskSpec
[TaskSpec output here]

#### Stage 1: RepoProfile
[RepoProfile output here]

#### Stage 2: Implementation Plan
[Plan output here]

#### Stage 3: Documentation
[Docs output here]

### Loop-Back Triggers
- None pending

### Retry History
- Stage 2 (plan-agent): Attempt 2 - Added test file paths per feedback

### Metadata
- Pipeline Start: 2025-02-03T10:00:00Z
- Last Updated: 2025-02-03T10:05:30Z
- Total Agent Calls: 5
- Build Agent Cycle: 1
- Build Agent Index: 1
```

---

## Downstream Usage

The PipelineContext is used by:
- **Orchestrator**: Manages context accumulation and loop-back handling
- **All agents**: Receive relevant context in their prompts
- **decide-agent**: Uses full context for final decision

---

## Schema Version
- **Version:** 1.0
- **Last Updated:** 2025-02-03
