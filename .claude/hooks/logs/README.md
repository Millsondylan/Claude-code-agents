# Validation Logs

This directory stores validation logs from the agent pipeline hooks.

## Log Naming Convention

```
{timestamp}_{agent}_{result}.log
```

Examples:
- `20260121_143052_task-breakdown_valid.log`
- `20260121_143105_build-agent-1_invalid.log`
- `20260121_143200_review-agent_valid.log`

## Log Format

Each log file contains JSON lines (JSONL) with the following structure:

```json
{
  "timestamp": "2026-01-21T14:30:52Z",
  "agent": "task-breakdown",
  "session_id": "abc123",
  "validation": {
    "valid": true,
    "errors": [],
    "warnings": ["Missing section: Risks (recommended)"]
  },
  "result": "valid",
  "output_preview": "## TaskSpec\n### Request Summary..."
}
```

## Fields

| Field | Description |
|-------|-------------|
| `timestamp` | ISO 8601 timestamp of validation |
| `agent` | Agent name (e.g., task-breakdown, build-agent-1) |
| `session_id` | Claude session ID for correlation |
| `validation` | Validator output (valid, errors, warnings) |
| `result` | Overall result: "valid" or "invalid" |
| `output_preview` | First 500 characters of agent output |

## Auto-Cleanup Policy

Logs older than 7 days are automatically cleaned up.

To manually clean up old logs:
```bash
find .claude/hooks/logs -name "*.log" -mtime +7 -delete
```

## Usage

Logs are written by the hook system when validators run. They help with:
1. Debugging validation failures
2. Tracking agent output quality over time
3. Identifying patterns in validation warnings
4. Auditing pipeline execution

## Log Rotation

For high-volume usage, consider:
1. Compressing logs older than 1 day: `gzip *.log`
2. Archiving weekly logs to a separate directory
3. Setting up logrotate for automatic management
