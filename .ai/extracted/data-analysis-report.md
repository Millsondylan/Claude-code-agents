# OpenCode Data Storage Analysis Report

**Analysis Date:** March 8, 2026  
**Analyst:** build-agent-1  
**Objective:** Explore OpenCode's data storage to understand how provider usage limit information is stored

---

## Executive Summary

OpenCode stores data across multiple locations using a hybrid approach:
- **Configuration & UI state**: JSON files in macOS Application Support directory
- **Core application data**: Large SQLite database (~2.4GB) in local share directory
- **Authentication**: Separate JSON file with provider credentials
- **Session artifacts**: Individual JSON files per session

**Critical Finding**: No explicit usage limit or quota tables exist in the database. Usage tracking appears to be derived from message/part tables rather than stored as limit metadata.

---

## 1. File Locations and Accessibility

### 1.1 Primary Data Files

| File | Location | Size | Accessibility |
|------|----------|------|---------------|
| `opencode.global.dat` | `~/Library/Application Support/ai.opencode.desktop/` | 432 KB | ✅ Readable (JSON) |
| `opencode.db` | `~/.local/share/opencode/` | 2.4 GB | ✅ Readable (SQLite) |
| `auth.json` | `~/.local/share/opencode/` | ~2.5 KB | ✅ Readable (JSON) |
| Workspace `.dat` files | `~/Library/Application Support/ai.opencode.desktop/` | 0.5-15 KB each | ✅ Readable (JSON) |
| Session diff files | `~/.local/share/opencode/storage/session_diff/` | 1-10 KB each | ✅ Readable (JSON) |

### 1.2 File Permissions

All files are stored with user-level permissions:
- Owner: `dyl` (current user)
- Group: `staff`
- Permissions: `-rw-r--r--` (readable by all, writable by owner)

### 1.3 Database Write-Ahead Log

The SQLite database has active WAL files:
- `opencode.db-shm` (32 KB) - Shared memory file
- `opencode.db-wal` (4 MB) - Write-ahead log

**Implication**: Database may have uncommitted changes in WAL that need to be checkpointed for complete analysis.

---

## 2. File Formats and Encodings

### 2.1 Global Configuration File (`opencode.global.dat`)

**Format**: JSON with nested escaped JSON strings
**Encoding**: UTF-8
**Structure**: Single-level JSON object where values are often JSON strings that require double-parsing

**Top-Level Keys**:
```
notification    - 68,445 chars (UI notifications, session events)
layout          - 6,455 chars (UI layout state)
prompt-history  - 318,189 chars (Prompt input history)
open.app        - 16 chars (Last opened app)
globalSync.project - 1,929 chars (Project sync state)
command.catalog.v1 - 7,149 chars (Command catalog)
server          - 661 chars (Server/project list)
layout.page     - 1,661 chars (Page layout state)
model           - 829 chars (Model configuration)
```

**Key Observation**: The `model` key contains provider/model configuration but no usage data.

### 2.2 SQLite Database (`opencode.db`)

**Format**: SQLite 3
**Size**: 2,457,264,128 bytes (~2.4 GB)
**Tables**: 9 application tables + 1 migrations table
**Indexes**: 6 custom indexes + 9 auto-indexes

### 2.3 Authentication File (`auth.json`)

**Format**: Plain JSON (no nesting)
**Encoding**: UTF-8
**Structure**: Object with provider keys containing credential data

### 2.4 Workspace Data Files

**Pattern**: `opencode.workspace.{base64}.{random}.dat`
**Format**: JSON with session-specific state
**Content**: Terminal buffers, comments, prompts

---

## 3. SQLite Schema Analysis

### 3.1 Database Tables

```sql
__drizzle_migrations    - Schema migration history
project                 - Project metadata (9 columns)
message                 - Chat messages (5 columns, 24,903 rows)
part                    - Message parts/components (6 columns, 116,495 rows)
permission              - Project permissions (4 columns)
session                 - Chat sessions (18 columns, 1,875 rows)
todo                    - Task items (6 columns)
session_share           - Shared sessions (5 columns)
control_account         - OpenCode account info (8 columns, 0 rows)
workspace               - Workspace configurations (6 columns, 0 rows)
```

### 3.2 Control Account Table Structure

```sql
CREATE TABLE `control_account` (
    `email` text NOT NULL,
    `url` text NOT NULL,
    `access_token` text NOT NULL,
    `refresh_token` text NOT NULL,
    `token_expiry` integer,
    `active` integer NOT NULL,
    `time_created` integer NOT NULL,
    `time_updated` integer NOT NULL,
    CONSTRAINT `control_account_pk` PRIMARY KEY(`email`, `url`)
);
```

**Current State**: EMPTY (0 rows)

**Purpose**: Likely for future OpenCode cloud account integration. Currently unused.

### 3.3 Message Table Schema

```sql
CREATE TABLE `message` (
    `id` text PRIMARY KEY,
    `session_id` text NOT NULL,
    `time_created` integer NOT NULL,
    `time_updated` integer NOT NULL,
    `data` text NOT NULL,
    CONSTRAINT `fk_message_session_id_session_id_fk` 
        FOREIGN KEY (`session_id`) REFERENCES `session`(`id`) ON DELETE CASCADE
);
```

**Data Structure** (JSON in `data` column):
```json
{
  "role": "user",
  "time": {"created": 1772548715332},
  "summary": {"diffs": []},
  "agent": "build",
  "model": {
    "providerID": "zai-coding-plan",
    "modelID": "glm-5"
  }
}
```

### 3.4 Part Table Schema

```sql
CREATE TABLE `part` (
    `id` text PRIMARY KEY,
    `message_id` text NOT NULL,
    `session_id` text NOT NULL,
    `time_created` integer NOT NULL,
    `time_updated` integer NOT NULL,
    `data` text NOT NULL,
    CONSTRAINT `fk_part_message_id_message_id_fk` 
        FOREIGN KEY (`message_id`) REFERENCES `message`(`id`) ON DELETE CASCADE
);
```

**Purpose**: Stores message content parts (text, tool calls, etc.)

### 3.5 Session Table Schema

```sql
CREATE TABLE `session` (
    `id` text PRIMARY KEY,
    `project_id` text NOT NULL,
    `parent_id` text,
    `slug` text NOT NULL,
    `directory` text NOT NULL,
    `title` text NOT NULL,
    `version` text NOT NULL,
    `share_url` text,
    `summary_additions` integer,
    `summary_deletions` integer,
    `summary_files` integer,
    `summary_diffs` text,
    `revert` text,
    `permission` text,
    `time_created` integer NOT NULL,
    `time_updated` integer NOT NULL,
    `time_compacting` integer,
    `time_archived` integer,
    `workspace_id` text,
    CONSTRAINT `fk_session_project_id_project_id_fk` 
        FOREIGN KEY (`project_id`) REFERENCES `project`(`id`) ON DELETE CASCADE
);
```

---

## 4. Provider Data Discovery

### 4.1 Configured Providers (from auth.json)

| Provider | Auth Type | Has Credentials | Expires (Timestamp) |
|----------|-----------|-----------------|---------------------|
| **anthropic** (Claude) | OAuth | ✅ Yes | 1772989764774 (Mar 2026) |
| **kimi-for-coding** (Kimi) | API Key | ✅ Yes | N/A |
| **zai-coding-plan** (GLM) | API Key | ✅ Yes | N/A |
| **google** (Gemini) | API Key | ✅ Yes | N/A |
| **openai** (GPT) | OAuth | ✅ Yes | 1773654495451 (Mar 2026) |

### 4.2 Provider Configuration (from global.dat model key)

**User Models** (visibility settings):
```json
{
  "user": [
    {"modelID": "k2p5", "providerID": "kimi-for-coding", "visibility": "show"},
    {"providerID": "anthropic", "modelID": "claude-sonnet-4-6", "visibility": "show"},
    {"providerID": "anthropic", "modelID": "claude-opus-4-6", "visibility": "show"},
    {"modelID": "gemini-3.1-pro-preview-customtools", "providerID": "google", "visibility": "show"},
    {"providerID": "zai-coding-plan", "modelID": "glm-5", "visibility": "show"},
    {"providerID": "zai-coding-plan", "modelID": "glm-4.7-flashx", "visibility": "hide"},
    {"modelID": "gpt-5.4", "providerID": "openai", "visibility": "show"}
  ]
}
```

### 4.3 Usage Statistics from Terminal Buffer

Found in workspace `.dat` files - terminal buffer shows historical usage data:

**Session Summary** (from 1,867 sessions):
- Total Messages: 24,819
- Days Active: 6
- Total Cost: $0.00

**Provider Usage**:
| Provider/Model | Messages | Input Tokens | Output Tokens | Cache Read | Cache Write |
|----------------|----------|--------------|---------------|------------|-------------|
| kimi-for-coding/k2p5 | 9,551 | 32.1M | 4.8M | 354.8M | 0 |
| anthropic/claude-opus-4-6 | 3,975 | 4.5K | 2.2M | 185.3M | 19.0M |
| zai-coding-plan/glm-5 | 3,839 | 13.7M | 2.2M | 109.6M | 0 |
| anthropic/claude-sonnet-4-6 | 2,690 | 2.9K | 1.3M | 199.4M | 10.8M |
| openai/gpt-5.4 | 2,526 | 22.6M | 1.8M | 217.3M | 0 |
| google/gemini-3.1-pro-preview-customtools | 1 | 0 | 0 | 0 | 0 |

**Dashboard URLs Found**:
- Claude: https://console.anthropic.com/settings/usage (5-hour weekly limit)
- Kimi: https://platform.moonshot.cn/console/usage (5-hour weekly limit)
- GLM: https://open.bigmodel.cn/overview (weekly quota)

---

## 5. Usage/Quota Data Patterns

### 5.1 What Was NOT Found

❌ **No explicit usage limit tables** in the database  
❌ **No quota tracking columns** in provider tables  
❌ **No rate limit metadata** stored locally  
❌ **No billing or cost tracking** in database schema  
❌ **control_account table is empty** (not currently used)

### 5.2 What WAS Found

✅ **Message/part tables** contain provider/model metadata per message  
✅ **Historical usage data** in terminal buffers (derived/calculated)  
✅ **Auth credentials** stored separately with expiry timestamps  
✅ **Provider dashboard URLs** mentioned in documentation buffers  

### 5.3 Derived Usage Pattern

OpenCode appears to calculate usage statistics by:

1. **Counting messages** per provider from `message.data` JSON
2. **Aggregating token usage** from part content analysis
3. **Storing historical summaries** in workspace terminal buffers
4. **Real-time calculation** rather than pre-stored quotas

**Query to derive provider usage**:
```sql
SELECT 
    json_extract(data, '$.model.providerID') as provider,
    json_extract(data, '$.model.modelID') as model,
    COUNT(*) as message_count
FROM message 
WHERE json_extract(data, '$.model.providerID') IS NOT NULL
GROUP BY provider, model;
```

**Results**:
- zai-coding-plan
- anthropic
- kimi-for-coding
- google
- openai

---

## 6. Technical Constraints Encountered

### 6.1 Data Access Constraints

| Constraint | Description | Impact |
|------------|-------------|--------|
| **No direct limit API** | Usage limits not stored in local DB | Cannot extract real-time quotas without API calls |
| **Empty control_account** | Account table exists but unused | No OpenCode account data to extract |
| **Large database size** | 2.4 GB with 116K+ parts | Query performance concerns for full scans |
| **WAL files active** | Uncommitted changes in WAL | May need checkpointing for consistent reads |
| **Credentials present** | OAuth tokens and API keys in plaintext | Security consideration for extraction scripts |

### 6.2 Provider-Specific Constraints

| Provider | Limit Info Location | Extraction Difficulty |
|----------|---------------------|----------------------|
| **Anthropic/Claude** | Dashboard only (console.anthropic.com) | Requires web scraping or API |
| **Kimi** | Dashboard only (platform.moonshot.cn) | Requires web scraping or API |
| **GLM** | Dashboard only (open.bigmodel.cn) | Requires web scraping or API |
| **OpenAI** | Dashboard + API available | API accessible with OAuth token |
| **Google** | Cloud console | Requires separate auth flow |

### 6.3 JSON Parsing Complexity

The `global.dat` file uses **double-encoded JSON**:
```json
{
  "model": "{\"user\":[{...}]}"
}
```

Requires two-step parsing:
1. Parse outer JSON
2. Parse inner JSON string values

### 6.4 Database Query Considerations

- **JSON extraction** requires SQLite JSON1 extension (available)
- **Time fields** are stored as Unix timestamps (milliseconds)
- **No native date/time types** - requires conversion
- **Foreign key constraints** enabled (cascading deletes)

---

## 7. Recommendations for Extraction Script

### 7.1 Phase 1: Data Collection (Current)

✅ **COMPLETED** - Discovery and schema analysis

### 7.2 Phase 2: Extraction Strategy

Based on findings, the extraction script should:

1. **Read auth.json** to identify configured providers
2. **Query message table** to count usage per provider/model
3. **Calculate derived statistics** (message count, estimated tokens)
4. **Note**: Real-time limits require provider API calls or web scraping

### 7.3 Data Sources for Extraction

| Data Point | Source | Method |
|------------|--------|--------|
| Provider list | auth.json | Direct JSON read |
| Message counts | opencode.db | SQL query with JSON extraction |
| Model configurations | global.dat | Double JSON parse |
| Historical usage | Terminal buffers (workspace .dat) | Pattern matching |
| Real-time limits | Provider APIs | Requires credentials + API calls |

### 7.4 Security Considerations

⚠️ **CREDENTIALS IN PLAINTEXT**: The auth.json file contains live OAuth tokens and API keys

- Do NOT commit credentials to version control
- Consider using keychain/keyring for secure storage
- Tokens have expiry dates and will need refresh

---

## 8. Files Summary

### 8.1 Primary Configuration
- `~/Library/Application Support/ai.opencode.desktop/opencode.global.dat` - Main config (JSON, 432KB)

### 8.2 Primary Database
- `~/.local/share/opencode/opencode.db` - Main data (SQLite, 2.4GB)

### 8.3 Authentication
- `~/.local/share/opencode/auth.json` - Provider credentials (JSON, 2.5KB)

### 8.4 Session Storage
- `~/.local/share/opencode/storage/session_diff/*.json` - Session artifacts
- `~/Library/Application Support/ai.opencode.desktop/opencode.workspace.*.dat` - Workspace state

### 8.5 Snapshots
- `~/.local/share/opencode/snapshot/*/` - Version control snapshots

---

## 9. Conclusion

OpenCode's data architecture reveals that **usage limits are not stored locally**. The application:

1. Tracks usage by counting messages/parts per provider
2. Stores credentials for API access but not quota metadata
3. Relies on provider dashboards for limit information
4. Has infrastructure for cloud accounts (`control_account` table) but it's not currently utilized

**For a complete usage limit extraction system**, the implementation will need to:
- Query local database for historical usage statistics
- Make API calls to provider endpoints using stored credentials
- Scrape provider dashboards (for providers without APIs)
- Cache results locally for display

---

**Report Generated By**: build-agent-1  
**Next Step**: Build extraction script based on discovered schema (Run 2)
