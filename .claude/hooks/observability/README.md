# Observability Hooks

This directory contains hooks for tracing and logging all tool calls for debugging and observability.

## Hooks

### trace-tool-call.sh (PreToolUse)
- **Trigger:** Before any tool is executed
- **Purpose:** Log tool name, input preview, and timestamp
- **Output:** JSONL logs in `.claude/hooks/logs/observability/`

### log-response.sh (PostToolUse)
- **Trigger:** After any tool completes
- **Purpose:** Log tool output preview and timing
- **Output:** JSONL logs in `.claude/hooks/logs/observability/`

## Log Format

Logs are stored in JSONL (JSON Lines) format for easy parsing:

```json
{"timestamp": "20260121_120000", "event": "PreToolUse", "tool": "Read", "session": "12345", "input_preview": "..."}
{"timestamp": "20260121_120001", "event": "PostToolUse", "tool": "Read", "session": "12345", "output_preview": "..."}
```

## Usage

These hooks are automatically registered in `.claude/settings.json` and run for all tool calls.

To analyze logs:
```bash
# View recent tool calls
cat .claude/hooks/logs/observability/*_trace.jsonl | jq .

# Count tool usage
cat .claude/hooks/logs/observability/*_trace.jsonl | jq -r '.tool' | sort | uniq -c

# Filter by session
cat .claude/hooks/logs/observability/*.jsonl | jq 'select(.session == "SESSION_ID")'
```

## Cleanup

Logs are not automatically cleaned up. To clear old logs:
```bash
find .claude/hooks/logs/observability -name "*.jsonl" -mtime +7 -delete
```
