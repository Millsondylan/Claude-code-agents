#!/usr/bin/env python3
"""
Tests for validate-task-output.py hook script.

Tests the modern Claude Code hooks API format (hookSpecificOutput).

Run with: python3 -m pytest .claude/hooks/test_validate_task_output.py -v
Or simply: python3 .claude/hooks/test_validate_task_output.py

Modern API Output Format:
- Allow: {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "..."}}
- Deny:  {"hookSpecificOutput": {"hookEventName": "PostToolUse", "permissionDecision": "deny", ...}}
"""
import json
import subprocess
import os
import sys


# Path to the script being tested
SCRIPT_PATH = os.path.join(os.path.dirname(__file__), 'validate-task-output.py')
CWD = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))


def run_validator(input_data):
    """Helper function to run the validator script with given input."""
    result = subprocess.run(
        ['python3', SCRIPT_PATH],
        input=json.dumps(input_data),
        capture_output=True,
        text=True,
        cwd=CWD
    )
    return json.loads(result.stdout), result.returncode


def get_context(output):
    """Extract additionalContext from hookSpecificOutput."""
    return output.get('hookSpecificOutput', {}).get('additionalContext', '')


def is_allowed(output):
    """Check if output allows (no permissionDecision: deny)."""
    hook_output = output.get('hookSpecificOutput', {})
    return hook_output.get('permissionDecision') != 'deny'


def is_warning(output):
    """Check if output is a warning (contains [VALIDATION WARNING])."""
    context = get_context(output)
    return '[VALIDATION WARNING]' in context


def has_hook_specific_output(output):
    """Check if output uses modern hookSpecificOutput format."""
    return 'hookSpecificOutput' in output


# ============================================
# Modern API Format Tests
# ============================================

def test_output_uses_modern_api_format():
    """Test that output uses hookSpecificOutput format."""
    input_data = {
        'cwd': CWD,
        'tool_input': {'subagent_type': 'nonexistent-agent'},
        'tool_response': 'Some output'
    }
    output, code = run_validator(input_data)

    # Must have hookSpecificOutput
    assert has_hook_specific_output(output), "Output should use hookSpecificOutput format"

    # Must have hookEventName
    assert output['hookSpecificOutput'].get('hookEventName') == 'PostToolUse', \
        "hookEventName should be PostToolUse"

    assert code == 0


def test_hook_event_name_present():
    """Test that hookEventName is always PostToolUse."""
    test_cases = [
        {'cwd': CWD, 'tool_input': {'subagent_type': 'test'}},
        {'cwd': CWD, 'tool_input': {}},
    ]

    for input_data in test_cases:
        output, code = run_validator(input_data)
        assert output.get('hookSpecificOutput', {}).get('hookEventName') == 'PostToolUse'


# ============================================
# Approval/Allow Tests
# ============================================

def test_nonexistent_agent_allows():
    """Test that a nonexistent agent type is allowed (no validator)."""
    input_data = {
        'cwd': CWD,
        'tool_input': {'subagent_type': 'nonexistent-agent'},
        'tool_response': 'Some output'
    }
    output, code = run_validator(input_data)

    assert is_allowed(output), "Should allow when no validator exists"
    assert 'No validator for agent: nonexistent-agent' in get_context(output)
    assert code == 0


def test_empty_agent_type_allows():
    """Test that missing/empty agent type is handled gracefully."""
    input_data = {
        'cwd': CWD,
        'tool_input': {},
        'tool_response': 'Some output'
    }
    output, code = run_validator(input_data)

    assert is_allowed(output), "Should allow with empty agent type"
    assert code == 0


def test_valid_prompt_optimizer_output():
    """Test prompt-optimizer with valid XML output passes validation."""
    input_data = {
        'cwd': CWD,
        'tool_input': {'subagent_type': 'prompt-optimizer'},
        'tool_response': '<task>Test task</task><requirements>Test requirements</requirements><context>Test context</context>'
    }
    output, code = run_validator(input_data)

    # Should allow (may have warnings but should pass)
    assert is_allowed(output), "Should allow valid prompt-optimizer output"
    assert code == 0


# ============================================
# Validation Failure Tests (now allows with warning)
# ============================================

def test_invalid_plan_agent_output_allows_with_warning():
    """Test plan-agent with missing required sections allows with warning (F3 behavior)."""
    input_data = {
        'cwd': CWD,
        'tool_input': {'subagent_type': 'plan-agent'},
        'tool_response': 'Invalid output without required sections'
    }
    output, code = run_validator(input_data)

    # F3: Now allows with warning instead of blocking
    assert is_allowed(output), "Should allow (with warning) per F3 non-blocking behavior"
    assert is_warning(output), "Should have [VALIDATION WARNING] in context"
    assert 'Missing required section' in get_context(output)
    # Exit code is 0 because we output valid JSON
    assert code == 0


def test_invalid_task_breakdown_allows_with_warning():
    """Test task-breakdown with missing sections allows with warning."""
    input_data = {
        'cwd': CWD,
        'tool_input': {'subagent_type': 'task-breakdown'},
        'tool_response': 'Just some random text without structure'
    }
    output, code = run_validator(input_data)

    # Should allow with warning
    assert is_allowed(output), "Should allow (with warning)"
    assert is_warning(output), "Should have [VALIDATION WARNING]"
    assert code == 0


# ============================================
# Graceful Degradation Tests
# ============================================

def test_malformed_json_input_handled():
    """Test that malformed JSON input is handled gracefully."""
    result = subprocess.run(
        ['python3', SCRIPT_PATH],
        input='not valid json',
        capture_output=True,
        text=True,
        cwd=CWD
    )
    output = json.loads(result.stdout)

    # Should allow (graceful degradation)
    assert is_allowed(output), "Should allow on malformed input"
    context = get_context(output)
    assert 'JSON' in context or 'error' in context.lower(), \
        "Should mention JSON error in context"
    assert result.returncode == 0


def test_missing_cwd_uses_default():
    """Test that missing cwd field uses default path (via PWD env)."""
    input_data = {
        'tool_input': {'subagent_type': 'some-agent'},
        'tool_response': 'Output'
    }
    output, code = run_validator(input_data)

    # Should not crash, should allow
    assert is_allowed(output), "Should allow with missing cwd"
    assert code == 0


def test_empty_stdin_handled():
    """Test that empty stdin is handled gracefully."""
    result = subprocess.run(
        ['python3', SCRIPT_PATH],
        input='',
        capture_output=True,
        text=True,
        cwd=CWD
    )
    output = json.loads(result.stdout)

    assert is_allowed(output), "Should allow on empty stdin"
    assert result.returncode == 0


# ============================================
# Output Format Validation Tests
# ============================================

def test_script_returns_valid_json_with_modern_format():
    """Test that script always returns valid JSON with hookSpecificOutput."""
    test_cases = [
        {'cwd': CWD, 'tool_input': {'subagent_type': 'test'}},
        {'cwd': CWD, 'tool_input': {}},
        {'cwd': '/nonexistent/path', 'tool_input': {'subagent_type': 'x'}},
    ]

    for input_data in test_cases:
        result = subprocess.run(
            ['python3', SCRIPT_PATH],
            input=json.dumps(input_data),
            capture_output=True,
            text=True,
            cwd=CWD
        )
        # Should be valid JSON
        output = json.loads(result.stdout)

        # Must have hookSpecificOutput
        assert 'hookSpecificOutput' in output, \
            f"Missing hookSpecificOutput for input: {input_data}"

        # Must have hookEventName
        assert output['hookSpecificOutput'].get('hookEventName') == 'PostToolUse', \
            f"Missing or wrong hookEventName for input: {input_data}"


def test_warning_format():
    """Test that warnings use [VALIDATION WARNING] prefix."""
    input_data = {
        'cwd': CWD,
        'tool_input': {'subagent_type': 'plan-agent'},
        'tool_response': 'Missing all required sections'
    }
    output, code = run_validator(input_data)

    context = get_context(output)
    if is_warning(output):
        assert context.startswith('[VALIDATION WARNING]'), \
            "Warning should start with [VALIDATION WARNING]"


if __name__ == '__main__':
    # Simple test runner - updated for modern API tests
    test_functions = [
        # Modern API format tests
        test_output_uses_modern_api_format,
        test_hook_event_name_present,
        # Approval/Allow tests
        test_nonexistent_agent_allows,
        test_empty_agent_type_allows,
        test_valid_prompt_optimizer_output,
        # Validation failure tests (F3: allow with warning)
        test_invalid_plan_agent_output_allows_with_warning,
        test_invalid_task_breakdown_allows_with_warning,
        # Graceful degradation tests
        test_malformed_json_input_handled,
        test_missing_cwd_uses_default,
        test_empty_stdin_handled,
        # Output format validation
        test_script_returns_valid_json_with_modern_format,
        test_warning_format,
    ]

    passed = 0
    failed = 0

    print("=" * 50)
    print("Python Dispatcher Tests (Modern API Format)")
    print("=" * 50)
    print()

    for test_func in test_functions:
        try:
            test_func()
            print(f"PASS: {test_func.__name__}")
            passed += 1
        except AssertionError as e:
            print(f"FAIL: {test_func.__name__} - {e}")
            failed += 1
        except Exception as e:
            print(f"ERROR: {test_func.__name__} - {e}")
            failed += 1

    print()
    print("=" * 50)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 50)
    sys.exit(0 if failed == 0 else 1)
