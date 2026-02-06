# Agent Output Validators

This directory contains validation scripts for each agent type in the multi-agent pipeline. These validators are called by Claude hooks to ensure agent outputs conform to expected formats.

## Hook Integration

These validators are designed to work with Claude's PostToolUse hooks. They:
1. Read agent output via stdin as JSON
2. Validate the output format
3. Return JSON result with valid/errors/warnings
4. Exit with code 0 (valid) or 2 (invalid, blocks and feeds stderr to Claude)

## Validator Files

| Validator | Agent | Stage | Required Sections |
|-----------|-------|-------|-------------------|
| `validate-prompt-optimizer.sh` | prompt-optimizer | -1 | XML structured prompt |
| `validate-task-breakdown.sh` | task-breakdown | 0 | TaskSpec, Features, Acceptance Criteria |
| `validate-code-discovery.sh` | code-discovery | 1 | RepoProfile, Directory Structure, Tech Stack |
| `validate-plan-agent.sh` | plan-agent | 2 | Implementation Plan, Batches, File Mappings |
| `validate-docs-researcher.sh` | docs-researcher | 3 | Documentation Report, Libraries Researched |
| `validate-pre-flight-checker.sh` | pre-flight-checker | 3.5 | Pre-Flight Check Report, Blockers |
| `validate-build-agent.sh` | build-agent-1 through build-agent-55 | 4 | Build Report, Files Changed, Change Ledger |
| `validate-debugger.sh` | debugger through debugger-11 | 5 | Debug Report, Root Cause, Fix Applied |
| `validate-logical-agent.sh` | logical-agent | 5.5 | Logic Verification Report, Issues Found |
| `validate-test-agent.sh` | test-agent | 6 | Test Report, Tests Run, Results |
| `validate-integration-agent.sh` | integration-agent | 6.5 | Integration Test Report, API/Workflow Validation |
| `validate-review-agent.sh` | review-agent | 7 | Review Report, Acceptance Criteria Review |
| `validate-decide-agent.sh` | decide-agent | 8 | Decision (COMPLETE or RESTART) |

### Deprecated Validators

| Validator | Status | Note |
|-----------|--------|------|
| `validate-web-syntax-researcher.sh` | Deprecated | Superseded by docs-researcher (Stage 3) |

## Input Format

Validators receive PostToolUse JSON via stdin:
```json
{
  "session_id": "...",
  "tool_name": "Task",
  "tool_input": {...},
  "tool_response": "The agent's output text"
}
```

The `tool_response` field contains the actual agent output to validate.

## Output Format

Validators must output valid JSON:
```json
{
  "valid": true,
  "errors": [],
  "warnings": []
}
```

Or on failure:
```json
{
  "valid": false,
  "errors": ["Missing required section: TaskSpec"],
  "warnings": ["Acceptance criteria count is low"]
}
```

## Exit Codes

- **0**: Valid output (JSON parsed, validation passed)
- **2**: Invalid output (blocks hook, stderr fed to Claude for correction)

## Usage

These validators are called by the hook configuration in `.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": {"tool_name": "Task"},
        "command": "/path/to/validators/validate-{agent}.sh"
      }
    ]
  }
}
```

## Making Validators Executable

All validators must be executable:
```bash
chmod +x .claude/hooks/validators/*.sh
```

## Testing Validators

To test a validator manually:
```bash
echo '{"tool_response": "## TaskSpec\n### Features\n..."}' | ./validate-task-breakdown.sh
```
