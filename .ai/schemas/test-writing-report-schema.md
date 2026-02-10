# Test Writing Report Schema

**Agent:** test-writer
**Stage:** 4.5
**Purpose:** Defines the structured output for test file creation results, including what test files were written, how tests map to acceptance criteria, coverage analysis, and anti-placeholder verification.

---

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `Test Files Created` | array[TestFileEntry] | List of test files that were created or modified |
| `Test Functions Written` | array[TestFunction] | Every test function written with details |
| `Acceptance Criteria Mapping` | array[CriteriaMapping] | How tests map to TaskSpec acceptance criteria |
| `Coverage Analysis` | CoverageAnalysis | Predicted coverage metrics and gap analysis |
| `Anti-Placeholder Check` | AntiPlaceholderCheck | Verification that no placeholder tests exist |
| `Writing Status` | WritingStatus | Overall status of test writing |
| `Next Step` or `CRITICAL: REQUEST` | string | What should happen next |

---

## Object Definitions

### TestFileEntry

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | Yes | Absolute path to the test file created or modified |
| `action` | string | Yes | CREATED or MODIFIED |
| `target_file` | string | Yes | The source file this test file covers |
| `test_count` | integer | Yes | Number of test functions in this file |
| `framework` | string | Yes | Test framework used (pytest, jest, vitest, go test, etc.) |

### TestFunction

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Full test function name (e.g., test_create_user_with_valid_email) |
| `file` | string | Yes | Test file path containing this function |
| `tests_feature` | string | Yes | Feature ID from TaskSpec (e.g., F1, F2) |
| `tests_function` | string | Yes | Source function or method being tested (file:function) |
| `assertion_count` | integer | Yes | Number of real assertions in the test |
| `assertion_types` | array[string] | Yes | Types of assertions used (assertEqual, assertRaises, etc.) |
| `inputs` | string | Yes | Description of test inputs and setup |
| `expected_output` | string | Yes | What the test expects to happen |
| `test_category` | string | Yes | Test category: `happy_path`, `error_path`, or `edge_case` |
| `uses_mocks` | boolean | Yes | Whether this test uses mocks (should be false) |

### CriteriaMapping

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feature_id` | string | Yes | Feature ID from TaskSpec (F1, F2, etc.) |
| `criterion` | string | Yes | The acceptance criterion text |
| `covered_by` | array[string] | Yes | Test function names that cover this criterion |
| `coverage_status` | string | Yes | COVERED, PARTIALLY_COVERED, or NOT_COVERED |
| `gap_description` | string | No | Explanation of gaps (required if not COVERED) |

### CoverageAnalysis

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `total_source_functions` | integer | Yes | Total functions in source files being tested |
| `functions_with_tests` | integer | Yes | Functions that have at least one test |
| `functions_without_tests` | array[string] | Yes | List of functions lacking test coverage |
| `estimated_line_coverage` | string | Yes | Estimated line coverage percentage |
| `estimated_branch_coverage` | string | Yes | Estimated branch coverage percentage |
| `happy_path_tests` | integer | Yes | Count of tests covering normal operation |
| `error_path_tests` | integer | Yes | Count of tests covering error conditions |
| `edge_case_tests` | integer | Yes | Count of tests covering edge cases and boundaries |
| `coverage_gaps` | array[CoverageGap] | No | Identified gaps in coverage |

### CoverageGap

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source_file` | string | Yes | Source file with insufficient coverage |
| `function` | string | Yes | Function or code path not covered |
| `gap_type` | string | Yes | Type of gap: UNTESTED_FUNCTION, MISSING_EDGE_CASE, MISSING_ERROR_PATH, MISSING_BRANCH |
| `description` | string | Yes | Detailed description of what is not covered |
| `severity` | string | Yes | HIGH, MEDIUM, or LOW |

### AntiPlaceholderCheck

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | string | Yes | PASS or FAIL |
| `total_tests_checked` | integer | Yes | Total test functions inspected |
| `placeholder_tests_found` | integer | Yes | Number of placeholder tests detected |
| `violations` | array[PlaceholderViolation] | Yes | Details of each violation (empty if PASS) |

### PlaceholderViolation

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `test_name` | string | Yes | Name of the offending test function |
| `file` | string | Yes | File path and line number |
| `violation_type` | string | Yes | Type of placeholder detected |
| `code_snippet` | string | Yes | The offending code |
| `explanation` | string | Yes | Why this is not a real test |

### WritingStatus

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | string | Yes | PASS or FAIL |
| `test_files_created` | integer | Yes | Number of test files created |
| `test_files_modified` | integer | Yes | Number of test files modified |
| `total_test_functions` | integer | Yes | Total test functions written |
| `total_assertions` | integer | Yes | Total assertions across all tests |
| `mock_free` | boolean | Yes | True if no mocks are used anywhere |
| `criteria_coverage` | string | Yes | X/Y acceptance criteria covered (e.g., "8/8") |

### DebuggerRequest (FAIL only)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `REQUEST` | string | Yes | "debugger - [description]" |
| `Failure Context` | FailureContext | Yes | Context for debugger |

### FailureContext (FAIL only)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Summary` | array[string] | Yes | Summary of failures |
| `Files involved` | array[string] | Yes | Files related to failures |
| `Remediation` | string | Yes | Suggested fix approach |

---

## Validation Rules

### Required Validations
1. **Test files listed**: Every test file created or modified must be documented
2. **Test functions detailed**: Every test function must have full details including assertions
3. **Criteria mapped**: Every acceptance criterion from TaskSpec must appear in the mapping
4. **Coverage analyzed**: Must provide function-level coverage analysis
5. **Anti-placeholder check performed**: Must verify no placeholder tests exist
6. **Status present**: Must have clear PASS or FAIL status
7. **Mock-free verified**: Must confirm no mocks are used (uses_mocks must be false for all tests)

### For PASS Reports
- All acceptance criteria show COVERED status
- Anti-placeholder check status is PASS (zero violations)
- Mock-free is true
- Each test function has assertion_count >= 1
- Each test function has explicit inputs and expected_output
- Next step should be "Proceed to logical-agent (Stage 5.5) for verification, or debugger (Stage 5) if errors detected"

### For FAIL Reports
- MUST identify which criteria are NOT_COVERED or PARTIALLY_COVERED
- MUST include gap descriptions for uncovered criteria
- MUST list placeholder violations if any were found
- MUST include REQUEST to build-agent or debugger

### Anti-Placeholder Detection Rules

Test-writer MUST self-check for and reject these patterns:

```python
# VIOLATION: empty-body - Test has no logic
def test_something(): pass

# VIOLATION: trivial-assertion - Assertion proves nothing
def test_thing(): assert True

# VIOLATION: no-assertion - Calls function but never asserts
def test_runs(): my_function()

# VIOLATION: mock-only - Uses mocks instead of real behavior
def test_with_mock():
    mock_db = MagicMock()
    mock_db.get.return_value = "fake"
    assert service.get_user(mock_db) == "fake"

# VIOLATION: assert-not-none-only - Only checks existence, not correctness
def test_returns(): assert my_function() is not None

# VIOLATION: type-check-only - Only checks type, not value
def test_type(): assert isinstance(result, dict)
```

Valid tests MUST have:
- Real inputs (not mocked)
- Real function calls (against real implementations)
- Specific value assertions (assertEqual, exact value comparisons)
- At least one assertion that validates correctness of output

---

## Violation Type Reference

Valid violation types for AntiPlaceholderCheck:
- `empty-body` - Test function body is `pass` or empty
- `trivial-assertion` - Only `assert True` or `assert 1 == 1`
- `no-assertion` - Calls code but never asserts on the result
- `mock-only` - Relies entirely on mocked dependencies
- `assert-not-none-only` - Only checks `is not None` without value verification
- `type-check-only` - Only checks type without value verification
- `commented-out` - Test body is commented out
- `todo-placeholder` - Contains TODO/FIXME instead of implementation

---

## Example: PASS Report

```markdown
## Test Writing Report

### Test Files Created
| Path | Action | Target File | Test Count | Framework |
|------|--------|-------------|------------|-----------|
| /app/tests/test_user_service.py | CREATED | /app/services/user_service.py | 8 | pytest |
| /app/tests/test_pagination.py | CREATED | /app/utils/pagination.py | 6 | pytest |

### Test Functions Written

#### /app/tests/test_user_service.py
1. **test_create_user_with_valid_data**
   - Tests Feature: F1
   - Tests Function: /app/services/user_service.py:create_user
   - Assertions: 3 (assertEqual x2, assertIn x1)
   - Inputs: Valid user dict with name="Alice", email="alice@example.com"
   - Expected: User created with matching fields, returned with generated ID
   - Category: happy_path
   - Uses Mocks: No

2. **test_create_user_with_duplicate_email_raises_error**
   - Tests Feature: F1
   - Tests Function: /app/services/user_service.py:create_user
   - Assertions: 2 (assertRaises x1, assertEqual x1)
   - Inputs: Two users with same email "alice@example.com"
   - Expected: Second creation raises DuplicateEmailError with message
   - Category: error_path
   - Uses Mocks: No

3. **test_get_user_returns_existing_user**
   - Tests Feature: F1
   - Tests Function: /app/services/user_service.py:get_user
   - Assertions: 3 (assertEqual x3)
   - Inputs: Pre-created user with known ID
   - Expected: Returns user with correct name, email, and ID
   - Category: happy_path
   - Uses Mocks: No

4. **test_get_user_nonexistent_returns_none**
   - Tests Feature: F1
   - Tests Function: /app/services/user_service.py:get_user
   - Assertions: 1 (assertIsNone x1)
   - Inputs: Non-existent user ID "nonexistent-uuid"
   - Expected: Returns None
   - Category: error_path
   - Uses Mocks: No

5. **test_update_user_modifies_fields**
   - Tests Feature: F2
   - Tests Function: /app/services/user_service.py:update_user
   - Assertions: 2 (assertEqual x2)
   - Inputs: Existing user, update dict with new name="Bob"
   - Expected: User name updated, email unchanged
   - Category: happy_path
   - Uses Mocks: No

6. **test_update_user_nonexistent_raises_not_found**
   - Tests Feature: F2
   - Tests Function: /app/services/user_service.py:update_user
   - Assertions: 1 (assertRaises x1)
   - Inputs: Non-existent user ID with update data
   - Expected: Raises UserNotFoundError
   - Category: error_path
   - Uses Mocks: No

7. **test_delete_user_removes_from_database**
   - Tests Feature: F2
   - Tests Function: /app/services/user_service.py:delete_user
   - Assertions: 2 (assertTrue x1, assertIsNone x1)
   - Inputs: Pre-created user with known ID
   - Expected: delete returns True, subsequent get returns None
   - Category: happy_path
   - Uses Mocks: No

8. **test_delete_user_nonexistent_raises_not_found**
   - Tests Feature: F2
   - Tests Function: /app/services/user_service.py:delete_user
   - Assertions: 1 (assertRaises x1)
   - Inputs: Non-existent user ID
   - Expected: Raises UserNotFoundError
   - Category: error_path
   - Uses Mocks: No

#### /app/tests/test_pagination.py
1. **test_get_page_returns_correct_slice**
   - Tests Feature: F3
   - Tests Function: /app/utils/pagination.py:get_page
   - Assertions: 2 (assertEqual x2)
   - Inputs: List of 25 items, page=0, page_size=10
   - Expected: Returns first 10 items, correct length
   - Category: happy_path
   - Uses Mocks: No

2. **test_get_page_last_page_partial**
   - Tests Feature: F3
   - Tests Function: /app/utils/pagination.py:get_page
   - Assertions: 2 (assertEqual x2)
   - Inputs: List of 25 items, page=2, page_size=10
   - Expected: Returns last 5 items
   - Category: edge_case
   - Uses Mocks: No

3. **test_get_page_empty_list**
   - Tests Feature: F3
   - Tests Function: /app/utils/pagination.py:get_page
   - Assertions: 2 (assertEqual x2)
   - Inputs: Empty list, page=0, page_size=10
   - Expected: Returns empty list, length 0
   - Category: edge_case
   - Uses Mocks: No

4. **test_get_page_beyond_range_returns_empty**
   - Tests Feature: F3
   - Tests Function: /app/utils/pagination.py:get_page
   - Assertions: 1 (assertEqual x1)
   - Inputs: List of 5 items, page=10, page_size=10
   - Expected: Returns empty list
   - Category: edge_case
   - Uses Mocks: No

5. **test_paginate_results_builds_metadata**
   - Tests Feature: F3
   - Tests Function: /app/utils/pagination.py:paginate_results
   - Assertions: 4 (assertEqual x4)
   - Inputs: List of 50 items, page=1, page_size=10
   - Expected: Returns items 10-19, total_pages=5, total_items=50, current_page=1
   - Category: happy_path
   - Uses Mocks: No

6. **test_paginate_results_negative_page_raises_error**
   - Tests Feature: F3
   - Tests Function: /app/utils/pagination.py:paginate_results
   - Assertions: 1 (assertRaises x1)
   - Inputs: List of 10 items, page=-1, page_size=10
   - Expected: Raises ValueError
   - Category: edge_case
   - Uses Mocks: No

### Acceptance Criteria Mapping
| Feature | Criterion | Covered By | Status |
|---------|-----------|------------|--------|
| F1 | Users can be created with name and email | test_create_user_with_valid_data | COVERED |
| F1 | Duplicate emails are rejected | test_create_user_with_duplicate_email_raises_error | COVERED |
| F1 | Users can be retrieved by ID | test_get_user_returns_existing_user, test_get_user_nonexistent_returns_none | COVERED |
| F2 | User fields can be updated | test_update_user_modifies_fields | COVERED |
| F2 | Users can be deleted | test_delete_user_removes_from_database | COVERED |
| F2 | Operations on non-existent users raise errors | test_update_user_nonexistent_raises_not_found, test_delete_user_nonexistent_raises_not_found | COVERED |
| F3 | Results are paginated correctly | test_get_page_returns_correct_slice, test_paginate_results_builds_metadata | COVERED |
| F3 | Edge cases handled (empty, beyond range, negative) | test_get_page_empty_list, test_get_page_beyond_range_returns_empty, test_paginate_results_negative_page_raises_error | COVERED |

### Coverage Analysis
- **Total Source Functions:** 6
- **Functions With Tests:** 6
- **Functions Without Tests:** (none)
- **Estimated Line Coverage:** 95%
- **Estimated Branch Coverage:** 90%
- **Happy Path Tests:** 6
- **Error Path Tests:** 4
- **Edge Case Tests:** 4

### Anti-Placeholder Check
- **Status:** PASS
- **Total Tests Checked:** 14
- **Placeholder Tests Found:** 0
- **Violations:** None

### Writing Status
- **Status:** PASS
- **Test Files Created:** 2
- **Test Files Modified:** 0
- **Total Test Functions:** 14
- **Total Assertions:** 27
- **Mock-Free:** Yes
- **Criteria Coverage:** 8/8

### Next Step
Proceed to logical-agent (Stage 5.5) for verification, or debugger (Stage 5) if errors detected
```

---

## Example: FAIL Report

```markdown
## Test Writing Report

### Test Files Created
| Path | Action | Target File | Test Count | Framework |
|------|--------|-------------|------------|-----------|
| /app/tests/test_user_service.py | CREATED | /app/services/user_service.py | 5 | pytest |

### Test Functions Written

#### /app/tests/test_user_service.py
1. **test_create_user**
   - Tests Feature: F1
   - Tests Function: /app/services/user_service.py:create_user
   - Assertions: 1 (assertEqual x1)
   - Inputs: Valid user dict
   - Expected: User created
   - Category: happy_path
   - Uses Mocks: No

2. **test_get_user**
   - Tests Feature: F1
   - Tests Function: /app/services/user_service.py:get_user
   - Assertions: 0 (VIOLATION)
   - Inputs: User ID
   - Expected: Returns user
   - Category: happy_path
   - Uses Mocks: No

3. **test_update_user**
   - Tests Feature: F2
   - Tests Function: /app/services/user_service.py:update_user
   - Assertions: 1 (assertTrue x1)
   - Inputs: Mocked user service
   - Expected: Update succeeds
   - Category: happy_path
   - Uses Mocks: Yes (VIOLATION)

4. **test_delete_user**
   - Tests Feature: F2
   - Tests Function: /app/services/user_service.py:delete_user
   - Assertions: 0 (VIOLATION)
   - Inputs: None
   - Expected: None
   - Category: happy_path
   - Uses Mocks: No

5. **test_placeholder**
   - Tests Feature: F3
   - Tests Function: /app/utils/pagination.py:get_page
   - Assertions: 0 (VIOLATION)
   - Inputs: None
   - Expected: None
   - Category: happy_path
   - Uses Mocks: No

### Acceptance Criteria Mapping
| Feature | Criterion | Covered By | Status |
|---------|-----------|------------|--------|
| F1 | Users can be created with name and email | test_create_user | PARTIALLY_COVERED |
| F1 | Duplicate emails are rejected | (none) | NOT_COVERED |
| F1 | Users can be retrieved by ID | test_get_user (no assertion) | NOT_COVERED |
| F2 | User fields can be updated | test_update_user (uses mocks) | NOT_COVERED |
| F2 | Users can be deleted | test_delete_user (no assertion) | NOT_COVERED |
| F2 | Operations on non-existent users raise errors | (none) | NOT_COVERED |
| F3 | Results are paginated correctly | test_placeholder (empty body) | NOT_COVERED |
| F3 | Edge cases handled (empty, beyond range, negative) | (none) | NOT_COVERED |

**Gap Description:**
- F1 create: Only one assertion checks the return value; does not verify all fields
- F1 duplicate email: No test exists for this criterion
- F1 get user: test_get_user calls get_user but has zero assertions
- F2 update: test_update_user uses mocks instead of real database; does not test real behavior
- F2 delete: test_delete_user has no assertions, just calls the function
- F2 error handling: No tests for non-existent user operations
- F3 pagination: test_placeholder has an empty body
- F3 edge cases: No edge case tests written

### Coverage Analysis
- **Total Source Functions:** 6
- **Functions With Tests:** 3
- **Functions Without Tests:** paginate_results, delete_user (real test), update_user (real test)
- **Estimated Line Coverage:** 40%
- **Estimated Branch Coverage:** 25%
- **Happy Path Tests:** 1
- **Error Path Tests:** 0
- **Edge Case Tests:** 0

**Coverage Gaps:**
| Source File | Function | Gap Type | Description | Severity |
|-------------|----------|----------|-------------|----------|
| /app/services/user_service.py | create_user | MISSING_EDGE_CASE | No duplicate email test | HIGH |
| /app/services/user_service.py | get_user | MISSING_ERROR_PATH | No test for non-existent user | HIGH |
| /app/services/user_service.py | update_user | UNTESTED_FUNCTION | Only tested with mocks | HIGH |
| /app/services/user_service.py | delete_user | UNTESTED_FUNCTION | No real assertions | HIGH |
| /app/utils/pagination.py | get_page | UNTESTED_FUNCTION | Only placeholder test | HIGH |
| /app/utils/pagination.py | paginate_results | UNTESTED_FUNCTION | No test exists | HIGH |

### Anti-Placeholder Check
- **Status:** FAIL
- **Total Tests Checked:** 5
- **Placeholder Tests Found:** 3
- **Violations:**

1. **test_get_user**
   - File: /app/tests/test_user_service.py:15
   - Violation Type: no-assertion
   - Code:
     ```python
     def test_get_user():
         user = get_user("some-id")
     ```
   - Explanation: Calls get_user but never asserts on the returned value. This only verifies the function does not raise, not that it returns the correct data.

2. **test_delete_user**
   - File: /app/tests/test_user_service.py:28
   - Violation Type: empty-body
   - Code:
     ```python
     def test_delete_user():
         pass
     ```
   - Explanation: Test body is empty. No function call, no assertion, tests nothing.

3. **test_placeholder**
   - File: /app/tests/test_user_service.py:32
   - Violation Type: empty-body
   - Code:
     ```python
     def test_placeholder():
         pass
     ```
   - Explanation: Test body is empty. Named as a placeholder, tests nothing.

### Writing Status
- **Status:** FAIL
- **Test Files Created:** 1
- **Test Files Modified:** 0
- **Total Test Functions:** 5
- **Total Assertions:** 2
- **Mock-Free:** No (1 test uses mocks)
- **Criteria Coverage:** 1/8

### CRITICAL: REQUEST
**REQUEST:** build-agent - Rewrite test file with real, complete tests

**Failure Context:**
- 3 placeholder tests detected (empty bodies, no assertions)
- 1 test uses mocks instead of real implementation
- Only 1 of 8 acceptance criteria fully covered
- Estimated coverage at 40% (target: 100%)
- Files involved: /app/tests/test_user_service.py
- Remediation: Rewrite all 5 tests with real inputs, real function calls, and specific value assertions. Add missing tests for untested criteria (duplicate email, error paths, pagination edge cases). Remove all mocks.
```

---

## Example: FAIL with Mock Violations

```markdown
## Test Writing Report (Partial)

### Anti-Placeholder Check
- **Status:** FAIL
- **Total Tests Checked:** 8
- **Placeholder Tests Found:** 2
- **Violations:**

1. **test_fetch_user_data**
   - File: /app/tests/test_api_client.py:22
   - Violation Type: mock-only
   - Code:
     ```python
     def test_fetch_user_data():
         mock_client = MagicMock()
         mock_client.get.return_value = {"name": "Alice"}
         result = fetch_user(mock_client, "user-1")
         assert result["name"] == "Alice"
     ```
   - Explanation: The entire test operates on a mock. It verifies that the mock returns what it was told to return, not that fetch_user works correctly with a real HTTP client. This test would pass even if fetch_user was completely broken.

2. **test_save_record**
   - File: /app/tests/test_repository.py:45
   - Violation Type: assert-not-none-only
   - Code:
     ```python
     def test_save_record():
         repo = Repository(db_connection)
         result = repo.save({"key": "value"})
         assert result is not None
     ```
   - Explanation: Only checks that save returns something, not that the record was actually saved with the correct data. A function returning any truthy value would pass this test.

### Writing Status
- **Status:** FAIL
- **Mock-Free:** No (1 test uses mocks)
- **Criteria Coverage:** 4/8

### CRITICAL: REQUEST
**REQUEST:** build-agent - Replace mock-based tests with real implementation tests

**Failure Context:**
- 1 test uses MagicMock instead of real client (test_fetch_user_data)
- 1 test has insufficient assertions (test_save_record)
- Files involved: /app/tests/test_api_client.py, /app/tests/test_repository.py
- Remediation: Replace mock_client with real test client/fixture. Add value assertions to test_save_record verifying the saved record contains correct data.
```

---

## Downstream Usage

The Test Writing Report is consumed by:
- **test-agent** (Stage 6): Runs the written tests, verifies they pass against the implementation
- **logical-agent** (Stage 5.5): Verifies the logic of the test assertions themselves
- **review-agent** (Stage 7): Checks test coverage against acceptance criteria, confirms no placeholders
- **debugger** (Stage 5): Receives context if tests need rewriting
- **decide-agent** (Stage 8): Requires PASS status and full criteria coverage for COMPLETE decision

---

## Schema Version
- **Version:** 1.0
- **Last Updated:** 2026-02-10
