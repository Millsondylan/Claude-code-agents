# Usage Extractor Tests

Comprehensive test suite for the OpenCode Usage Extractor implementation.

## Test Files

| File | Description | Test Count |
|------|-------------|------------|
| `usage-extractor.test.ts` | Main test suite for extraction logic | 50+ tests |
| `output-validation.test.ts` | Validates provider-usage-data.json output | 25+ tests |
| `setup.ts` | Test utilities and fixtures | N/A |

## Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage report
npm run test:coverage

# Run specific test file
npx jest usage-extractor.test.ts
```

## Test Coverage Areas

### 1. Database Connectivity (`Database Connectivity` describe block)
- ✅ SQLite database connection establishment
- ✅ Message table querying
- ✅ Part table querying
- ✅ Querying with LIKE filters for providerID
- ✅ Error handling for missing database

### 2. Auth Configuration (`readAuthConfig` describe block)
- ✅ Reading auth.json and extracting providers
- ✅ Handling single and multiple providers
- ✅ Empty provider configuration
- ✅ Missing file error handling
- ✅ Invalid JSON error handling

### 3. Token Calculation (`Token Calculation from Messages` describe block)
- ✅ Aggregating token data from messages
- ✅ Aggregating token data from parts
- ✅ Handling messages without token data
- ✅ Skipping unknown providers
- ✅ All token types (input, output, reasoning, cache read/write)

### 4. Rolling 5-Hour Windows (`calculateRolling5HourWindows` describe block)
- ✅ Empty events handling
- ✅ Single window calculation
- ✅ Percentage of limit calculation
- ✅ Multiple window handling
- ✅ Chronological ordering
- ✅ Window limit (last 10 windows)
- ✅ Undefined limit handling
- ✅ Overlapping windows

### 5. Weekly Usage (`calculateWeeklyUsage` describe block)
- ✅ Empty events handling
- ✅ Current week filtering
- ✅ Previous week exclusion
- ✅ Percentage calculation
- ✅ Zero limit handling
- ✅ Sunday week start

### 6. Provider Detection (`Provider Detection and Configuration` describe block)
- ✅ All provider detection from auth.json
- ✅ Provider configuration initialization
- ✅ Unknown provider defaults

### 7. Time Window Tracking (`Time Window Tracking` describe block)
- ✅ Time window tracking for each provider
- ✅ Valid ISO date strings
- ✅ Start before end validation

### 8. Notes Generation (`Notes Generation` describe block)
- ✅ 5-hour window notes
- ✅ Weekly usage notes
- ✅ No token data notes

### 9. JSON Output Format (`JSON Output Format` describe block)
- ✅ Valid output structure
- ✅ Correct data types
- ✅ JSON serialization

### 10. Edge Cases (`Edge Cases and Error Handling` describe block)
- ✅ Missing tables
- ✅ Invalid JSON in message data
- ✅ Empty database handling
- ✅ Missing providerID
- ✅ Large token counts
- ✅ Concurrent provider data

### 11. Output Validation (`output-validation.test.ts`)
- ✅ Top-level structure validation
- ✅ Data source section validation
- ✅ Providers array validation
- ✅ Summary section validation
- ✅ Known provider detection

## Test Data

Tests use a real SQLite in-memory database created in `setup.ts` with:
- 7 test messages (various providers, with/without tokens)
- 2 test parts
- Multiple providers: anthropic, kimi-for-coding, openai, google
- Various time ranges: now, 5 hours ago, yesterday
- Various token configurations

## No Mocks Policy

All tests use real dependencies:
- Real SQLite database (better-sqlite3)
- Real file system operations
- Real JSON parsing
- Real date calculations

This ensures tests catch real-world issues and provide confidence in the implementation.
