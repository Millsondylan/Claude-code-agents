# Prompt Optimization Rules

## PROMPT-OPTIMIZER DISPATCH RULES

**EVERY prompt you create for ANY sub-agent MUST go through prompt-optimizer first.**

This applies to ALL pipeline stages:
- Stage 1: pipeline-scaler
- Stage 3: task-breakdown
- Stage 5: code-discovery
- Stage 6: plan-agent
- Stage 7: docs-researcher
- Stage 8: pre-flight-checker
- Stage 9: build-agent-1 through build-agent-55
- Stage 10: test-writer
- Stage 11: debugger
- Stage 12: logical-agent
- Stage 13: test-agent
- Stage 14: integration-agent
- Stage 15: review-agent
- Stage 16: decide-agent

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
Task tool:
  subagent_type: "task-breakdown"
  prompt: "User wants to add authentication"
```

**CORRECT (via prompt-optimizer):**
```
Step 1: Dispatch to prompt-optimizer
Task tool:
  subagent_type: "prompt-optimizer"
  prompt: |
    target_agent: task-breakdown
    stage: 0
    raw_prompt: "User wants to add authentication"

Step 2: Get optimized prompt back (XML structured)

Step 3: Dispatch optimized prompt to task-breakdown
Task tool:
  subagent_type: "task-breakdown"
  prompt: [the optimized XML prompt from step 2]
```

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
