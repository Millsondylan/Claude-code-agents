---
description: "Optimize a raw prompt via the prompt-optimizer agent"
---

# Optimize Prompt

Invoke the prompt-optimizer agent to transform a raw prompt into an optimized, context-rich prompt.

## Usage

```
/prompt <target_agent> <task_type> <raw_prompt>
```

Arguments: $ARGUMENTS

## Parameters

- **target_agent**: The agent the optimized prompt will be sent to (e.g., build-agent-1, task-breakdown)
- **task_type**: feature | bugfix | refactor | migrate
- **raw_prompt**: The original prompt to optimize

## Example

```
/prompt build-agent-1 feature "Add user authentication to the app"
```

## What It Does

1. Dispatches to prompt-optimizer agent
2. Analyzes codebase for context using read, grep, glob, bash
3. Applies anti-laziness, persistence, and verification rules
4. Returns ONLY the optimized prompt

## Instructions

When this command is invoked:

1. Parse the arguments: target_agent=$1, task_type=$2, raw_prompt=$3
2. Dispatch to prompt-optimizer with:
   - target_agent: the value of $1
   - stage: the stage number matching the target agent
   - raw_prompt: the value of $3
3. Return the optimized XML-structured prompt to the user

## Output

The optimized prompt in XML format, ready to send to the target agent.
