# OpenCode Agentic Framework

A **production-grade multi-agent system** for software development. Instead of one AI trying to do everything, 83+ specialized agents work in a strict pipeline to build, test, and review code with engineering discipline.

> **⚡ Core Philosophy**: Orchestrator dispatches, agents execute, quality gates enforce, pipeline continues until complete.

---

## 🎯 What Makes This Different

| Traditional AI | OpenCode Framework |
|---------------|-------------------|
| One model does everything | 83+ specialized agents |
| Gets overwhelmed by complexity | Pipeline scales to any project size |
| May skip steps or forget context | Sequential execution, no shortcuts |
| Can get "lazy" or take shortcuts | Agents enforce rules on each other |
| Single point of failure | Distributed, fault-tolerant |

---

## 🏗️ The Pipeline (Stages 1-16)

Every request flows through 16 stages sequentially:

```
Stage 1:  pipeline-scaler      → Analyze complexity, create scaling plan
Stage 2:  prompt-optimizer     → Optimize request for processing
Stage 3:  task-breakdown       → Create detailed TaskSpec
Stage 4:  [USER CONFIRMATION]  → You approve the plan (only pause point)
Stage 5:  code-discovery       → Analyze codebase structure
Stage 6:  plan-agent           → Create implementation strategy
Stage 7:  docs-researcher      → Research library documentation
Stage 8:  pre-flight-checker   → Validate environment ready
Stage 9:  build-agent-N        → Implement code (1-2 files per agent)
Stage 10: test-writer          → Write comprehensive tests
Stage 11: debugger             → Fix errors (11 debuggers in chain)
Stage 12: logical-agent        → Verify logic correctness
Stage 13: test-agent           → Run full test suite
Stage 14: integration-agent    → Test component integration
Stage 15: review-agent         → Security & quality review
Stage 16: decide-agent         → COMPLETE or RESTART
```

**Key**: Pipeline auto-continues. No "should I continue?" No "next steps." It runs until it's ACTUALLY done.

---

## 🤖 Agent Distribution

Agents are assigned to models based on task complexity:

| Model | Count | Cost | Best For |
|-------|-------|------|----------|
| **Kimi K2.5** | ~45 | $2-3/M tokens | Coding, most implementation |
| **GLM-5** | ~15 | $0.50-1/M tokens | Validation, simple tasks |
| **Claude Sonnet 4.6** | 11 | $3-5/M tokens | Debugger chain |
| **Claude Opus 4.6** | 3 | $15-30/M tokens | Critical decisions only |

**Result**: 90% of work uses cheap models. Opus reserved for final decisions and complex planning.

---

## 🔧 Special Features

### Debugger Chain (11 Agents)
When errors occur, the system doesn't give up:
```
debugger → debugger-2 → debugger-3 → ... → debugger-10 → debugger-11
  Sonnet     Sonnet       Sonnet              Sonnet       Opus
```
Each debugger analyzes, attempts fix, passes to next if needed. debugger-11 (Opus) is last resort for complex issues.

### Build-Agent Chain (55 Agents)
Files are implemented sequentially:
- Each build-agent handles 1-2 files
- Alternates between Kimi and GLM-5 for cost optimization
- Chain continues until all files implemented

### Flutter Best Practices
For Flutter projects, agents automatically follow:
- ✅ `const` constructors on all immutable widgets
- ✅ Extract widget classes (never `buildX()` helper methods)
- ✅ Drift for database (not abandoned Isar/Hive)
- ✅ Three-layer error handling
- ✅ Material 3 theming
- ✅ NEVER hardcode colors/sizes

### Multi-Run Scaling
Complex features split across multiple pipeline runs:
1. pipeline-scaler analyzes and creates ScalingPlan
2. Features grouped into runs
3. Each run executes full pipeline
4. Auto-continue between runs
5. Final aggregated review

---

## 🚫 What The Orchestrator CANNOT Do

**Critical Rules** (violations blocked by system):

- ❌ **NO CODING** - Orchestrator only dispatches agents, never writes code
- ❌ **NO SKIPPING** - Cannot skip pipeline-scaler or any stage
- ❌ **NO PARALLEL** - One agent at a time, always
- ❌ **NO STOPPING** - Auto-continue between stages
- ❌ **NO SUGGESTIONS** - Cannot say "next steps" or "you could..."
- ❌ **NO "SHOULD I"** - Just execute, don't ask for permission

**The orchestrator's only job**: Dispatch agents in order until decide-agent says COMPLETE.

---

## ✅ User Controls

### Full Pipeline (Default)
```
User: "Add user authentication"
System: Runs stages 1-16 automatically
```

### Single Agent Override
```
User: "Just run code-discovery"
System: Skips pipeline, runs only that agent
```

### Confirmation Point
Only Stage 4 (after task-breakdown) pauses for your approval. Everything else runs autonomously.

---

## 🔒 Use Only This Repo's OpenCode Setup

If you have multiple OpenCode configs elsewhere, force this repo to use only its local `.opencode/`:

```bash
source scripts/use-local-opencode.sh   # each terminal
# or use direnv: direnv allow          # auto-loads on cd
```

---

## 📁 Repository Structure

```
Claude-code-agents/
├── AGENTS.md                    # Main orchestrator rules
├── README.md                    # This file
├── .opencode/
│   ├── agents/                  # 84 agent definitions
│   │   ├── build-agent-1.md → build-agent-55.md
│   │   ├── debugger.md → debugger-11.md
│   │   ├── pipeline-scaler.md
│   │   ├── task-breakdown.md
│   │   └── ... (other agents)
│   └── rules/
│       ├── 01-pipeline-orchestration.md
│       ├── 02-prompt-optimization.md
│       ├── 06-multi-run-orchestration.md
│       └── 07-flutter-best-practices.md
└── .claude/                     # Claude-specific configs
    ├── agents/
    └── rules/
```

---

## 🚀 Usage Example

**Request**: "Add user authentication to my Flutter app"

**What Happens**:

1. **pipeline-scaler**: "This needs 1 run, 3 features"
2. **prompt-optimizer**: Structures the request
3. **task-breakdown**: Creates TaskSpec:
   - F1: Auth service with JWT
   - F2: Login/signup UI
   - F3: Route protection middleware
4. **[YOU CONFIRM]** ✅
5. **code-discovery**: Finds existing auth code
6. **plan-agent**: Strategy - service → UI → middleware
7. **docs-researcher**: JWT best practices for Flutter
8. **pre-flight-checker**: Dependencies ready
9. **build-agent-1**: Writes `auth_service.dart`
10. **build-agent-2**: Writes `login_page.dart`
11. **build-agent-3**: Writes `auth_middleware.dart`
12. **test-writer**: Writes comprehensive tests
13. **debugger**: Fixes null error in service
14. **logical-agent**: Logic verification passed
15. **test-agent**: All tests pass ✅
16. **integration-agent**: Login flow works end-to-end ✅
17. **review-agent**: Security approved, minor style notes
18. **decide-agent**: **COMPLETE** ✅

**Total**: 18 agents, 0 orchestrator code, fully tested & reviewed.

---

## 🎓 Philosophy

This system treats AI not as a "smart autocomplete" but as a **software development team**:

- **Specialization**: Each agent has one job and does it well
- **Process**: Pipeline enforces engineering best practices
- **Quality**: Every change reviewed, tested, verified
- **Scale**: Works for 1 file or 1,000 files
- **Reliability**: No shortcuts, no forgetting, no "lazy" outputs

**The goal**: Industrial-grade software development with AI assistance, not AI replacement.

---

## 📊 Stats

- **83+ Agents** across the pipeline
- **16 Sequential Stages**
- **55 Build-Agents** for implementation
- **11 Debuggers** for error resolution
- **4 Model Tiers** for cost optimization
- **Zero Code** written by orchestrator
- **100% Tested** before completion

---

## 🏆 Why It Works

1. **No Magic**: Explicit pipeline, no hidden shortcuts
2. **Accountability**: Each agent output checked by next agent
3. **Scalability**: More files = more build-agents, same process
4. **Cost Control**: Cheap models for 90% of work
5. **Quality Gates**: Cannot complete without passing all checks
6. **Persistence**: Continues until ACTUALLY done

---

**Built for production. Designed for scale. Enforced by agents.**

---

*This is the OpenCode Agentic Framework. Run the pipeline, trust the process, ship quality code.*