---
name: prompt
description: Run the prompt-optimizer agent to enhance a prompt before sending to target agent
---

# /prompt - Optimize a Prompt

Invoke the prompt-optimizer agent to transform a raw prompt into an optimized, context-rich prompt.

## Usage
```
/prompt <target_agent> <task_type> <raw_prompt>
```

## Parameters
- **target_agent**: The agent the optimized prompt will be sent to (e.g., build-agent-1, task-breakdown)
- **task_type**: feature | bugfix | refactor | migrate
- **raw_prompt**: The original prompt to optimize

## Example
```
/prompt build-agent-1 feature "Add user authentication to the app"
```

## What It Does
1. Dispatches to prompt-optimizer agent (opus model)
2. Analyzes codebase for context
3. Applies anti-laziness, persistence, and verification rules
4. Returns ONLY the optimized prompt

## Output
The optimized prompt in XML format, ready to send to the target agent.
