# PipelineState Schema

**Agent:** Orchestrator (managed internally)
**Stage:** Cross-session persistence
**Purpose:** Defines the state persistence structure for long-running pipelines, enabling recovery and restart tracking.

---

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Unique identifier for the pipeline session |
| `status` | string | "running" or "complete" - current pipeline status |
| `checkpoint` | Checkpoint | Last successful checkpoint state |
| `recovery_protocol` | RecoveryProtocol | How to recover from failures |
| `persistence_metadata` | PersistenceMetadata | Timing and storage info |

---

## Object Definitions

### Checkpoint

Last known good state for recovery.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stage` | number | Yes | Last completed stage (-1 to 8) |
| `agent` | string | Yes | Last agent that completed |
| `timestamp` | string | Yes | ISO 8601 timestamp of checkpoint |
| `context_hash` | string | No | Hash of PipelineContext at checkpoint |
| `outputs_snapshot` | object | No | Snapshot of stage outputs at checkpoint |

### RecoveryProtocol

Defines how to recover from different failure modes.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `on_agent_failure` | string | Yes | "retry" or "escalate" |
| `on_session_interrupt` | string | Yes | "resume_from_checkpoint" or "restart" |
| `on_external_blocker` | string | Yes | "escalate" or "wait" |
| `max_recovery_attempts` | number | Yes | Maximum recovery attempts before escalation |

### PersistenceMetadata

Timing and storage information.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `first_started` | string | Yes | ISO 8601 timestamp of first pipeline start |
| `last_checkpoint` | string | Yes | ISO 8601 timestamp of last checkpoint |
| `total_runtime_ms` | number | Yes | Total runtime in milliseconds |
| `storage_location` | string | No | Where state is persisted (e.g., ".claude/.state/") |

---

## Validation Rules

### Required Validations
1. **session_id unique**: Must be unique across pipeline runs
2. **status valid**: Must be "running" or "complete"
3. **checkpoint valid**: Stage must be -1 to 8

### Quality Validations
- Timestamps must be valid ISO 8601
- context_hash should be SHA-256 if provided
- total_runtime_ms must be reasonable (not negative, not impossibly large)

---

## Recovery Protocol Details

### On Agent Failure

```
1. Check current recovery attempt count
2. If < max_recovery_attempts:
   - Retry agent with improved prompt
   - Log recovery attempt
3. If >= max_recovery_attempts:
   - Escalate to decide-agent
   - decide-agent outputs RESTART or ESCALATE
```

### On Session Interrupt

```
1. Load last checkpoint from storage
2. Restore PipelineContext from checkpoint
3. Resume from last completed stage
4. Continue pipeline normally
```

### On External Blocker

```
1. Document the blocker
2. If recoverable: wait and retry
3. If not recoverable: escalate to user
4. decide-agent may output ESCALATE
```

---

## Example: First Pass State

```markdown
## PipelineState

### Session ID
pipeline_2025-02-03_abc123

### Status
running

### Checkpoint
- **Stage:** 4
- **Agent:** build-agent-1
- **Timestamp:** 2025-02-03T10:15:30Z

### Recovery Protocol
- **On Agent Failure:** retry
- **On Session Interrupt:** resume_from_checkpoint
- **On External Blocker:** escalate
- **Max Recovery Attempts:** 3

### Persistence Metadata
- **First Started:** 2025-02-03T10:00:00Z
- **Last Checkpoint:** 2025-02-03T10:15:30Z
- **Total Runtime:** 930000ms
```

---

## Downstream Usage

The PipelineState is used by:
- **Orchestrator**: Manages state persistence and recovery
- **decide-agent**: Checks status before COMPLETE decision
- **All agents**: May read state for context (read-only)

---

## Schema Version
- **Version:** 1.0
- **Last Updated:** 2025-02-03
