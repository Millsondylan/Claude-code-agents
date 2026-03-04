# Prompt Optimization Rules

## PROMPT-OPTIMIZER DISPATCH RULES

**EVERY prompt you create for ANY sub-agent MUST go through prompt-optimizer first.**

This applies to ALL pipeline stages:
- Stage -2: pipeline-scaler
- Stage -1: prompt-optimizer (optimizes for Stage 0)
- Stage 0: task-breakdown (needs prompt-optimizer first)
- Stage 1: code-discovery (needs prompt-optimizer first)
- Stage 2: plan-agent (needs prompt-optimizer first)
- Stage 3: docs-researcher (needs prompt-optimizer first)
- Stage 3.5: pre-flight-checker (needs prompt-optimizer first)
- Stage 4: build-agent-1 through build-agent-55 (each needs prompt-optimizer first)
- Stage 4.5: test-writer (needs prompt-optimizer first)
- Stage 5: debugger (needs prompt-optimizer first)
- Stage 5.5: logical-agent (needs prompt-optimizer first)
- Stage 6: test-agent (needs prompt-optimizer first)
- Stage 6.5: integration-agent (needs prompt-optimizer first)
- Stage 7: review-agent (needs prompt-optimizer first)
- Stage 8: decide-agent (needs prompt-optimizer first)

### The Flow (MANDATORY)
```
1. Orchestrator prepares prompt for target agent
2. Orchestrator dispatches to prompt-optimizer:
   - target_agent: [the agent name]
   - stage: [the stage number]
   - raw_prompt: [the prompt you prepared]
3. prompt-optimizer returns optimized prompt
4. Orchestrator dispatches optimized prompt to target agent
```

### Exception: Skip if Already XML-Structured
If the prompt already contains XML structure (`<task>`, `<context>`, `<requirements>`), skip prompt-optimizer.

### Detection Logic
```
IF prompt contains XML tags (<task>, <context>, <requirements>, etc.):
  → SKIP prompt-optimizer
  → Send directly to target agent

ELSE:
  → DISPATCH to prompt-optimizer FIRST
  → Get optimized prompt back
  → THEN dispatch optimized prompt to target agent
```

### Flow Diagram
```
Raw Prompt → Check for XML → [Has XML?]
                                │
                    ┌───────────┴───────────┐
                   YES                      NO
                    │                        │
                    ▼                        ▼
           Send directly to         Send to prompt-optimizer
           target agent                     │
                                           ▼
                                   Get optimized prompt
                                           │
                                           ▼
                                   Send to target agent
```

### Example: Dispatching to task-breakdown

**WRONG (direct dispatch):**
```
task tool:
  subagent_type: "task-breakdown"
  prompt: "User wants to add authentication"
```

**CORRECT (via prompt-optimizer):**
```
Step 1: Dispatch to prompt-optimizer
task tool:
  subagent_type: "prompt-optimizer"
  prompt: |
    target_agent: task-breakdown
    stage: 0
    task_type: feature
    raw_prompt: "User wants to add authentication"
    original_request: "User wants to add authentication with email/password signup, login, logout, and session management using JWT tokens stored in httpOnly cookies"

Step 2: Get optimized prompt back (XML structured)
   - Prompt-optimizer saves to .claude/.prompts/{timestamp}_task-breakdown_stage0.md
   - Verify file exists and contains complete original request

Step 3: Dispatch optimized prompt to task-breakdown
task tool:
  subagent_type: "task-breakdown"
  prompt: [the optimized XML prompt from step 2]
```

### REQUIRED Fields for prompt-optimizer

ALWAYS include these 5 fields when dispatching to prompt-optimizer:

```yaml
target_agent: "name-of-target-agent"      # REQUIRED - Which agent will receive the optimized prompt
stage: "stage-number"                     # REQUIRED - Pipeline stage number (e.g., "0", "1", "4")
task_type: "feature|bugfix|refactor|migrate"  # REQUIRED - Type of work
raw_prompt: "..."                         # REQUIRED - Your prepared prompt for the target agent
original_request: "..."                   # REQUIRED - COMPLETE original user request (NEVER truncate)
```

**CRITICAL:** The `original_request` field must contain the FULL user request, not a summary. This ensures the prompt-optimizer and all downstream agents have complete context.

### Verification Steps

After dispatching prompt-optimizer:

1. **Check prompt file was created:**
   ```bash
   ls -la .claude/.prompts/
   ```

2. **Verify file contents:**
   - Target agent name matches
   - Stage number matches
   - Original request is COMPLETE (not truncated)
   - Optimized prompt has XML structure

3. **If verification fails:**
   - RETRY prompt-optimizer with clearer instructions
   - Emphasize saving to .claude/.prompts/
   - Emphasize including complete original_request

### More Examples

**Skip prompt-optimizer (already has XML):**
```xml
<task>Add user authentication</task>
<requirements>Use JWT tokens</requirements>
```
-> Send directly to build-agent-1

**Use prompt-optimizer (raw text):**
```
Add user authentication to the app
```
-> Send to prompt-optimizer first -> Get XML output -> Send to build-agent-1
