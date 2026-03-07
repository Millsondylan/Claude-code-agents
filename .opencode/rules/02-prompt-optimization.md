# Prompt Optimization Rules

## PROMPT-OPTIMIZER DISPATCH RULES

**Prompt-optimizer runs ONCE after pipeline-scaler (Stage -1), NOT before every agent.**

The prompt-optimizer's job is to:
1. Take the raw user request after pipeline-scaler
2. Optimize it into a structured format for task-breakdown (Stage 0)
3. Save the optimized prompt for reference
4. Return the XML-structured prompt to the orchestrator

**Subsequent agents (Stages 1+) receive prompts prepared directly by the orchestrator** with proper context from previous stages.

---

## When to Use Prompt-Optimizer

### ALWAYS Use (Stage -1 → Stage 0)
```
User Request
    ↓
Stage -2: pipeline-scaler
    ↓
Stage -1: DISPATCH to prompt-optimizer
    ↓
prompt-optimizer optimizes for task-breakdown
    ↓
Stage 0: task-breakdown receives optimized prompt
```

### NEVER Use (Stages 1+)
For subsequent agents, the orchestrator prepares prompts directly:
```
Stage 0: task-breakdown completes
    ↓
Orchestrator prepares prompt for Stage 1 (code-discovery)
    ↓
DISPATCH directly to code-discovery (no prompt-optimizer)
    ↓
Stage 1 completes
    ↓
Orchestrator prepares prompt for Stage 2 (plan-agent)
    ↓
DISPATCH directly to plan-agent (no prompt-optimizer)
```

**The orchestrator acts as the prompt router after Stage 0.**

---

## The Flow

### Stage -1: Prompt Optimizer (MANDATORY)

```
1. Orchestrator prepares prompt with:
   - target_agent: "task-breakdown"
   - stage: "0"
   - task_type: [feature|bugfix|refactor]
   - raw_prompt: [prepared prompt]
   - original_request: [COMPLETE user request]

2. DISPATCH to prompt-optimizer

3. prompt-optimizer:
   - Reads task-breakdown agent definition
   - Optimizes into XML structure
   - Saves to .claude/.prompts/{timestamp}_task-breakdown_stage0.md
   - Returns optimized prompt

4. Orchestrator receives optimized prompt

5. DISPATCH optimized prompt to task-breakdown
```

### Stages 1+: Orchestrator Prepares Directly

```
1. Previous agent completes

2. Orchestrator prepares prompt with:
   - Context from all previous stages
   - Target agent name
   - Stage number
   - Task type
   - Full original request
   - Special requirements

3. DISPATCH directly to target agent

4. Agent receives context-rich prompt
```

---

## REQUIRED Fields for Stage -1 (Prompt Optimizer)

When dispatching to prompt-optimizer (Stage -1), include:

```yaml
target_agent: "task-breakdown"           # REQUIRED - Always task-breakdown
stage: "0"                                # REQUIRED - Stage 0
task_type: "feature|bugfix|refactor|migrate"  # REQUIRED
raw_prompt: "..."                         # REQUIRED - Your prepared prompt
original_request: "..."                   # REQUIRED - COMPLETE user request
```

**CRITICAL:** The `original_request` field must contain the FULL user request, not a summary.

---

## Example: Stage -1 → Stage 0 Flow

**Step 1: Dispatch to prompt-optimizer (Stage -1)**
```
task tool:
  subagent_type: "prompt-optimizer"
  prompt: |
    target_agent: task-breakdown
    stage: 0
    task_type: feature
    raw_prompt: "User wants to add authentication"
    original_request: "User wants to add authentication with email/password signup, login, logout, and session management using JWT tokens stored in httpOnly cookies"
```

**Step 2: Get optimized prompt back**
- Prompt-optimizer saves to `.claude/.prompts/{timestamp}_task-breakdown_stage0.md`
- Returns XML-structured prompt

**Step 3: Verify prompt file was created**
```bash
ls -la .claude/.prompts/
```

**Step 4: Dispatch optimized prompt to task-breakdown (Stage 0)**
```
task tool:
  subagent_type: "task-breakdown"
  prompt: [the optimized XML prompt from step 2]
```

---

## Example: Stage 1+ (Orchestrator Prepares Directly)

**After task-breakdown completes, dispatch to code-discovery:**
```
task tool:
  subagent_type: "code-discovery"
  prompt: |
    ## TaskSpec
    [TaskSpec from task-breakdown]
    
    ## Context
    Original request: [full request]
    
    ## Your Task
    Analyze the codebase and create a RepoProfile...
```

**NO prompt-optimizer needed** — orchestrator prepares the prompt directly.

---

## Summary

| Stage | Use Prompt-Optimizer? | Who Prepares Prompt |
|-------|----------------------|-------------------|
| -2 | N/A (pipeline-scaler) | Orchestrator |
| -1 | YES (optimizes for Stage 0) | Orchestrator → Prompt-Optimizer |
| 0 | Receives optimized prompt | Prompt-Optimizer output |
| 1+ | NO | Orchestrator prepares directly |

**Rule:** Prompt-optimizer runs ONCE after pipeline-scaler. All other stages receive prompts prepared directly by the orchestrator.