# Agent Output Schemas

This directory contains formal schema definitions for all agent outputs in the multi-agent pipeline. These schemas define the required structure, fields, and validation rules for data passed between agents.

## Schema Index

| Schema | Agent | Stage | Description |
|--------|-------|-------|-------------|
| [taskspec-schema.md](./taskspec-schema.md) | task-breakdown | 0 | Task specification with features and acceptance criteria |
| [repoprofile-schema.md](./repoprofile-schema.md) | code-discovery | 1 | Repository profile with tech stack and conventions |
| [implementation-plan-schema.md](./implementation-plan-schema.md) | plan-agent | 2 | Batched implementation plan with file mappings |
| [preflight-check-schema.md](./preflight-check-schema.md) | pre-flight-checker | 3.5 | Pre-flight check report with blockers |
| [pipeline-context-schema.md](./pipeline-context-schema.md) | Orchestrator | Cross-stage | Aggregated context with loop-back triggers |
| [build-report-schema.md](./build-report-schema.md) | build-agent-1 through build-agent-55 | 4 | Build report with changes and status |
| [debug-report-schema.md](./debug-report-schema.md) | debugger through debugger-11 | 5 | Debug report with fixes and verification |
| [logic-verification-schema.md](./logic-verification-schema.md) | logical-agent | 5.5 | Logic verification report with issues |
| [test-report-schema.md](./test-report-schema.md) | test-agent | 6 | Test execution report with results |
| [integration-test-schema.md](./integration-test-schema.md) | integration-agent | 6.5 | Integration test report with API/workflow validation |
| [review-report-schema.md](./review-report-schema.md) | review-agent | 7 | Review report with quality assessment |
| [decision-schema.md](./decision-schema.md) | decide-agent | 8 | Final decision output |

## Usage

### For Agents
Each agent MUST:
1. Read its output schema before generating output
2. Validate output matches schema structure
3. Include all required fields
4. Follow field type specifications

### For Orchestrator
The orchestrator uses these schemas to:
1. Validate agent outputs before proceeding
2. Parse structured data between stages
3. Detect malformed or incomplete outputs

### For Validators
Hook validators (`.claude/hooks/validators/`) use these schemas as reference for:
1. Automated output validation
2. Required field checking
3. Format verification

## Schema Format

Each schema file contains:
1. **Purpose** - What the schema defines
2. **Required Fields** - Table of mandatory fields with types
3. **Object Definitions** - Nested object structures
4. **Validation Rules** - What makes output valid
5. **Example** - Complete valid output example

## Data Flow

```
TaskSpec (Stage 0)
    |
    v
RepoProfile (Stage 1)
    |
    v
Implementation Plan (Stage 2)
    |
    v
Docs Research (Stage 3)
    |
    v
Pre-Flight Check (Stage 3.5)
    |
    v
Build Report (Stage 4) <---> Debug Report (Stage 5)
    |                            ^
    v                            |
Logic Verification (Stage 5.5) --+
    |
    v
Test Report (Stage 6) ---------> Debug Report (Stage 5)
    |
    v
Integration Test (Stage 6.5) --> Debug Report (Stage 5)
    |
    v
Review Report (Stage 7) -------> Build Report (Stage 4)
    |
    v
Decision (Stage 8)
```

## Version

- **Schema Version:** 1.1
- **Last Updated:** 2026-02-05
- **Compatible Pipeline Version:** 1.0+
