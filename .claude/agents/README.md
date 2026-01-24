# Agent Definitions

This directory contains the agent definition files for the multi-agent framework. Each agent has a specific role in the 9-stage pipeline.

## Agent Files

### Stage -1: prompt-optimizer.md
**Role:** Intercepts and optimizes prompts before they reach target sub-agents
**Always required:** YES (MANDATORY - runs FIRST before any agent dispatch)
**Re-run eligible:** YES
**Special:** Outputs ONLY the optimized prompt, uses haiku model for fast processing
**Model:** Haiku (for speed)

### Stage 0: task-breakdown.md
**Role:** Analyzes user requests and creates structured TaskSpec
**Always required:** YES
**Re-run eligible:** YES

### Stage 1: code-discovery.md
**Role:** Discovers repository structure, tech stack, and conventions
**Always required:** YES
**Re-run eligible:** YES

### Stage 2: plan-agent.md
**Role:** Creates batched implementation plan with feature assignments
**Always required:** YES
**Re-run eligible:** YES

### Stage 3: docs-researcher.md
**Role:** Researches library/framework documentation via Context7 MCP
**Always required:** YES (MANDATORY before any build-agent)
**Re-run eligible:** YES
**Special:** Uses Context7 MCP for up-to-date documentation

### Stage 3b: web-syntax-researcher.md (DEPRECATED - use docs-researcher)
**Role:** Researches uncertain APIs, frameworks, and syntax patterns
**Always required:** NO (superseded by docs-researcher)
**Re-run eligible:** YES

### Stage 4: build-agent.md
**Role:** Implements assigned features per the plan
**Always required:** NO (triggered when code changes needed)
**Re-run eligible:** YES
**Instances:** build-agent-1 through build-agent-5

### Stage 5: debugger.md
**Role:** Diagnoses and fixes errors, test failures, and bugs
**Always required:** NO (triggered on errors)
**Re-run eligible:** YES

### Stage 5.5: logical-agent.md
**Role:** Verifies code logic correctness using deep Opus reasoning
**Always required:** NO (triggered after build-agent, before test-agent)
**Re-run eligible:** YES
**Special:** Read-only verification, detects off-by-one, race conditions, null handling, edge cases
**Model:** Opus (for deep logical reasoning)

### Stage 6: test-agent.md
**Role:** Runs test suite and reports results (NEVER blocks)
**Always required:** YES
**Re-run eligible:** YES
**Special:** MUST request debugger on ANY failure

### Stage 7: review-agent.md
**Role:** Reviews changes against acceptance criteria and quality standards
**Always required:** YES
**Re-run eligible:** YES

### Stage 8: decide-agent.md
**Role:** Makes final decision (COMPLETE, RESTART, or ESCALATE)
**Always required:** YES
**Re-run eligible:** NO (terminal stage only)
**Special:** CANNOT request other agents

### Utility: project-customizer.md
**Role:** Updates project-specific context in CLAUDE.md and ACM
**Trigger:** Periodically after major work, or when context is stale
**Re-run eligible:** YES
**Special:** Can ONLY modify PROJECT-SPECIFIC sections (between markers), NEVER base rules

### Utility: claude-in-chrome.md
**Role:** Browser automation specialist using Claude in Chrome MCP tools
**Trigger:** On-demand for browser automation tasks
**Re-run eligible:** YES
**Special:** Controls Chrome browser via MCP tools (navigate, click, type, screenshot)

## Usage

These agent definitions are intended to be used with Claude's Task tool to spawn subagents. Each definition provides:

1. **Identity**: Who the agent is and what it does
2. **Inputs**: What the agent receives
3. **Responsibilities**: What the agent must do
4. **Outputs**: Required output format
5. **Tools**: Which tools the agent can use
6. **Re-run Rules**: When and how the agent can request other agents
7. **Quality Standards**: Checklists and best practices

## Installation

To use these agents in your repository:

1. **Copy this directory** to your project:
   ```bash
   cp -r agents /path/to/your/project/.claude/agents/
   ```

2. **Update ACM path** in each agent file:
   - Find: `<REPO_ROOT>/.ai/README.md`
   - Replace with: your actual repository path

3. **Create .ai/README.md** (ACM) in your project:
   ```bash
   cp ../.ai/README.md /path/to/your/project/.ai/README.md
   ```

## Framework Rules

### Mandatory Stages
These stages MUST run for EVERY request:
- Stage -1: prompt-optimizer (ALWAYS FIRST - optimizes prompt before any dispatch)
- Stage 0: task-breakdown (ALWAYS SECOND - after prompt-optimizer)
- Stage 1: code-discovery (ALWAYS THIRD)
- Stage 2: plan-agent (ALWAYS FOURTH)
- Stage 6: test-agent (ALWAYS REQUIRED)
- Stage 7: review-agent (ALWAYS REQUIRED)
- Stage 8: decide-agent (ALWAYS FINAL)

### Conditional Stages
These stages run only when needed:
- Stage 3: web-syntax-researcher (when uncertain about APIs/syntax)
- Stage 4: build-agent (when code changes needed)
- Stage 5: debugger (when errors occur)
- Stage 5.5: logical-agent (after build, verifies logic correctness)

### Re-run Rules
- **Any agent (except decide-agent) can request re-runs** of other agents
- **decide-agent is terminal** — it CANNOT request other agents, only output COMPLETE/RESTART/ESCALATE

## Agent Request Hierarchy

| Agent | Can Request | Cannot Request |
|-------|-------------|----------------|
| prompt-optimizer | None (outputs optimized prompt only) | All agents |
| task-breakdown | Any agent | decide-agent mid-pipeline |
| code-discovery | Any agent | decide-agent mid-pipeline |
| plan-agent | Any agent | decide-agent mid-pipeline |
| web-syntax-researcher | Any agent | decide-agent mid-pipeline |
| build-agent-N | Any agent | decide-agent mid-pipeline |
| debugger | Any agent | decide-agent mid-pipeline |
| logical-agent | build-agent, debugger, code-discovery, test-agent | decide-agent mid-pipeline |
| test-agent | Any agent (MUST request debugger on failure) | decide-agent mid-pipeline |
| review-agent | Any agent | decide-agent mid-pipeline |
| **decide-agent** | **NONE** | **ALL agents** |

## Special Policies

### Test-Agent Always-Fix
**CRITICAL:** test-agent NEVER blocks the pipeline. On ANY failure, test-agent MUST request debugger.

### Decide-Agent Terminal
**CRITICAL:** decide-agent is the ONLY agent that cannot request other agents. It runs ONLY after all other stages complete and outputs ONLY: COMPLETE, RESTART, or ESCALATE.

## Cross-References

- **Framework Documentation:** `../CLAUDE.md` or `../../CLAUDE.md`
- **Agent Configuration Manifest (ACM):** `../../.ai/README.md`
- **Integration Guide:** `../../docs/INTEGRATION_GUIDE.md`
- **Quick Start:** `../../docs/QUICK_START.md`

## Contributing

When creating or modifying agent definitions:

1. Follow the standard structure (Identity, Inputs, Responsibilities, Outputs, Tools, Re-run Rules)
2. Include examples for common scenarios
3. Document quality checklists
4. Specify tool usage guidelines
5. Include session start protocol (ACM reference)
6. Test agent behavior in real pipeline execution
