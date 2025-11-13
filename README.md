# Super Claude Kit

**Transform Claude Code from a stateless tourist into a stateful resident.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-blue.svg)](https://claude.ai)

---

## The Problem

[Claude Code](https://github.com/anthropics/claude-code) is brilliant, but it's **stateless**. Every session starts from scratch.

You're the tour guide, and Claude is the tourist who keeps asking for directions to the same place.

## The Solution

**Super Claude Kit** adds persistent memory to Claude Code using:

- ✅ **Session state tracking** - Remembers files, tasks, discoveries
- ✅ **Cross-session persistence** - 24-hour memory window
- ✅ **Token-efficient storage** - 52% reduction with TOON format
- ✅ **Smart refresh** - 60-70% fewer context updates
- ✅ **Exploration journal** - Permanent knowledge base

**No external dependencies. No databases. Pure bash + hooks.**

**⭐ If Super Claude Kit helps you, please star the repo!**

---

## Features

### 🧠 Persistent Memory

Claude remembers across messages and sessions (24-hour window):
- Files accessed
- Current tasks
- Sub-agent results
- Session discoveries
- Git state

### 📊 Context Capsule

Before every prompt, Claude sees a compact summary of the session state - git status, files in context, current tasks, discoveries, and more.

**See detailed examples in [System Architecture](.claude/docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md)**

### 🔄 Cross-Session Restoration

Start a new session within 24 hours and Claude automatically restores context from the previous session.

**See [Usage Guide](.claude/docs/CAPSULE_USAGE_GUIDE.md) for details**



### 🤖 Specialized Sub-Agents

Super Claude Kit includes 4 built-in sub-agents for common development tasks:

1. **architecture-explorer** - Understand codebases, service boundaries, data flows
2. **database-navigator** - Explore database schemas, migrations, relationships
3. **agent-developer** - Build and debug AI agents with MCP integration
4. **github-issue-tracker** - Create well-formatted GitHub issues from discoveries

**Production-Safe Design:**
All sub-agents are **read-only** for safety. They can:
- ✅ Read files, search code, find files, fetch web content
- ❌ **Cannot** execute bash commands, modify files, or delete files

This prevents accidental modifications in production environments.

**Use them by launching the Task tool with `subagent_type`:**
```
Task tool with subagent_type="architecture-explorer"
```

### 🎯 Quality Hooks (NEW in v1.1.0)

Automatic quality improvements:

- **PreToolUse** - Warns before redundant file reads (saves tokens)
- **Stop** - Suggests logging discoveries when ratio poor (improves quality)
- **SessionEnd** - Auto-persists capsule on exit (zero friction)

Example warnings:
```
[TIP] File recently read (2m ago) - check capsule first

[QUALITY TIP] Accessed 5 files but logged 0 discoveries
Consider: ./.claude/hooks/log-discovery.sh "<category>" "<finding>"
```

---

## Installation

### Requirements

- **Claude Code** (any version with hooks)
- **Git** (recommended, but not required)

### Quick Install (Recommended)

```bash
cd your-project
curl -sL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash
```

**That's it.** Next time you start Claude Code:

```
🚀 Super Claude Kit ACTIVATED - Context Loaded
```

### What Gets Installed

- ✅ 24 hooks (automatic automation + quality improvements)
- ✅ 7 active hooks (SessionStart, UserPromptSubmit, PostToolUse, PreToolUse, Stop, SessionEnd, +1 more)
- ✅ 3 utility scripts (testing, stats, updates)
- ✅ 3 skills (context-saver, exploration-continue, task-router)
- ✅ 4 sub-agents (architecture-explorer, database-navigator, agent-developer, github-issue-tracker)
- ✅ Documentation & usage guides
- ✅ Updated `.gitignore` with session files
- ✅ Updated `CLAUDE.md` with integration instructions

### Test Installation

```bash
# Verify everything works
bash .claude/scripts/test-super-claude.sh

# View usage statistics
bash .claude/scripts/show-stats.sh
```

---

## Usage

### Automatic Features (v1.1.0)

Everything works automatically with zero configuration:

- ✅ **95% Auto-logging** - File operations, sub-agents, tasks tracked automatically
- ✅ **Quality hooks** - Smart warnings and suggestions
- ✅ **Smart refresh** - Updates only when needed
- ✅ **Session persistence** - Auto-saves on exit, auto-restores on start
- ✅ **Git tracking** - Current branch and status always visible

**Only discoveries require manual logging** - Claude decides what's important:
```bash
./.claude/hooks/log-discovery.sh "pattern" "Auth uses JWT tokens"
./.claude/hooks/log-discovery.sh "decision" "Using PostgreSQL for storage"
```

**For complete usage guide, see [CAPSULE_USAGE_GUIDE.md](.claude/docs/CAPSULE_USAGE_GUIDE.md)**


---

## Troubleshooting

**Quick checks:**

```bash
# Verify installation
bash .claude/scripts/test-super-claude.sh

# View current stats
bash .claude/scripts/show-stats.sh

# Check version
cat .claude/version.txt
```

**Common issues:**

- **Hooks not running?** Check `.claude/settings.local.json` has SessionStart and UserPromptSubmit configured
- **Capsule not updating?** Run `rm .claude/last_refresh_state.txt` to force refresh
- **Session not persisting?** SessionEnd hook auto-persists on exit (v1.1.0+)

**For detailed troubleshooting, see [System Architecture](.claude/docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md)**

---

## Contributing

Contributions welcome!

**To contribute:**
1. Fork the repo
2. Create a feature branch
3. Submit a pull request



## Acknowledgments

- **[Anthropic](https://www.anthropic.com/)** - For Claude and Claude Code
- **[TOON](https://github.com/toon-format/toon)** - Token-Oriented Object Notation (TOON) – Compact, human-readable, schema-aware JSON for LLM prompts.
- **The developer community** - For inspiration and feedback
- **Early testers** - For bug reports and suggestions

---

## Author

**Arpit Nath**
- GitHub: [@arpitnath](https://github.com/arpitnath)
- LinkedIn: [@Arpit](https://www.linkedin.com/in/arpit-nath-38280a173/)


## License

[MIT License](https://opensource.org/licenses/MIT) - Copyright (c) 2025 Arpit Nath
