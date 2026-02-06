# Implementation Plan Schema

**Agent:** plan-agent
**Stage:** 2
**Purpose:** Defines the structured output for batched implementation plans with feature assignments and file mappings.

---

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `Batch Summary` | BatchSummary | Overview of features and batches |
| `Batches` | array[Batch] | List of implementation batches |
| `Test Criteria` | TestCriteria | Pre/post implementation checks |
| `Risks` | array[string] | Identified risks from TaskSpec + planning |
| `Dependencies` | array[string] | External dependencies or blockers |

---

## Object Definitions

### BatchSummary

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Total Features` | integer | Yes | Count of features to implement |
| `Total Batches` | integer | Yes | Count of implementation batches |
| `Estimated Build Agents` | integer | Yes | Expected build-agent instances needed |

### Batch

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Batch Number` | integer | Yes | Sequential batch number (1, 2, 3...) |
| `Assigned To` | string | Yes | build-agent instance (build-agent-1, etc.) |
| `Feature IDs` | array[string] | Yes | Feature IDs in this batch (F1, F2) |
| `Features` | array[BatchFeature] | Yes | Detailed feature specifications |

### BatchFeature

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ID` | string | Yes | Feature ID (F1, F2, etc.) |
| `Name` | string | Yes | Feature name |
| `Complexity` | string | Yes | Simple, Medium-Low, Medium, High |
| `Files to Modify` | array[FileChange] | Yes | Existing files to change |
| `Files to Create` | array[FileChange] | Yes | New files to create |
| `Tests` | array[FileChange] | Yes | Test files to create/update |
| `Implementation Notes` | array[string] | No | Specific guidance for build-agent |

### FileChange

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | Yes | Absolute or relative file path |
| `description` | string | Yes | What to change or create |

### TestCriteria

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Pre-implementation` | array[Criterion] | Yes | Checks before starting |
| `Post-implementation` | array[Criterion] | Yes | Checks after completion |

### Criterion

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | Yes | Criterion description |
| `checked` | boolean | No | Whether criterion is met |

---

## Validation Rules

### Required Validations
1. **All features included**: Every TaskSpec feature must appear in a batch
2. **Sequential batches**: Batch numbers must be sequential (1, 2, 3...)
3. **Build-agent assignment**: Each batch must have assigned build-agent
4. **Complexity specified**: Every feature must have complexity rating
5. **Files mapped**: Every feature must have file mappings (modify/create/tests)
6. **Test criteria present**: Pre and post implementation criteria required

### Quality Validations
- Dependencies between features should be respected in batch order
- Complex features may span multiple batches
- Each batch should target at most 1-2 files
- Implementation notes should reference RepoProfile patterns
- Test criteria should map to TaskSpec acceptance criteria

---

## Example

```markdown
## Implementation Plan

### Batch Summary
- **Total Features:** 3
- **Total Batches:** 2
- **Estimated Build Agents:** 2

### Batch 1: F1, F2
**Assigned to:** build-agent-1
**Features:** F1, F2

#### F1: Health Check Endpoint
**Complexity:** Simple
**Files to Modify:**
- /app/routes/__init__.py - Register health route

**Files to Create:**
- /app/routes/health.py - Health check handler

**Tests:**
- /tests/routes/test_health.py - Health endpoint tests

**Implementation Notes:**
- Follow existing route pattern from /app/routes/user.py
- Return JSON: {"status": "ok", "timestamp": <ISO>}
- Use Flask jsonify for response

#### F2: Logging Middleware
**Complexity:** Medium-Low
**Files to Modify:**
- /app/__init__.py - Register middleware

**Files to Create:**
- /app/middleware/logging.py - Request logging middleware

**Tests:**
- /tests/middleware/test_logging.py - Logging tests

**Implementation Notes:**
- Log request method, path, duration
- Use existing logger from /app/utils/logger.py

---

### Batch 2: F3
**Assigned to:** build-agent-2
**Features:** F3

#### F3: JWT Authentication
**Complexity:** Medium
**Files to Modify:**
- /app/__init__.py - Register auth middleware
- /app/routes/__init__.py - Apply auth to protected routes

**Files to Create:**
- /app/middleware/auth.py - JWT verification middleware
- /app/utils/jwt.py - JWT helper functions

**Tests:**
- /tests/middleware/test_auth.py - Auth middleware tests
- /tests/utils/test_jwt.py - JWT helper tests

**Implementation Notes:**
- Use PyJWT library (already in requirements.txt)
- Get JWT_SECRET from environment variable
- Return 401 for invalid/expired tokens

---

### Test Criteria
**Pre-implementation:**
- [ ] Baseline tests pass

**Post-implementation:**
- [ ] All tests pass (unit, integration, lint)
- [ ] New tests cover acceptance criteria
- [ ] No regressions

### Risks
- JWT secret must be configured in environment
- Database connection required for user lookup

### Dependencies
- PyJWT library (verify installed)
- Environment variable JWT_SECRET required
```

---

## Downstream Usage

The Implementation Plan is consumed by:
- **build-agent** (Stage 4): Implements features per batch specifications
- **logical-agent** (Stage 5.5): Reviews changes against plan
- **review-agent** (Stage 7): Validates implementation matches plan
- **decide-agent** (Stage 8): Confirms all planned features complete

---

## Schema Version
- **Version:** 1.0
- **Last Updated:** 2025-02-03
