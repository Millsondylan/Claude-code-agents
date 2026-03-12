# Operational Policies

## ACM (Agent Configuration Manifest)

All agents must read `.ai/README.md` at session start. It contains:
- Anti-destruction rules (read before edit, no overwrites, real tests)
- Safety protocols
- Quality standards

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

## KIMI K2.5 CONTEXT WINDOW & TOKEN MANAGEMENT

### Model Capabilities

| Capability | Value | Notes |
|------------|-------|-------|
| Context window | 256K tokens | Fixed; no extended window |
| Max output tokens | 33K tokens | Per response |
| Subagent output cap | ~33K tokens | Task tool output may truncate at this limit |

### Context Management Strategy

The orchestrator and agents do not need to set `contextWindow` or `max_tokens` in agent definition frontmatter -- these are handled automatically by the runtime.

**Subagent output cap:** Subagent (task tool) output may be truncated at approximately 33K tokens. When dispatching build agents for large implementations, prefer smaller micro-batches (1-2 files) to keep output within the cap.

### Compaction Strategy

When context usage grows high, the runtime may compact the conversation. The compaction threshold can be overridden:

```
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70
```

This triggers compaction when context usage reaches 70% (default varies by runtime). Lower values compact more aggressively, preserving headroom for long pipelines. **For token reduction:** use `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` to compact earlier. For multi-stage pipelines, 50-70 is recommended.

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | Set max output tokens per response | Runtime default |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | Override compaction threshold (percentage) | Runtime default |

**Note:** `CLAUDE_CODE_MAX_OUTPUT_TOKENS` may not fully apply to subagent output due to the ~33K subagent cap. Use it for top-level responses only.

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
