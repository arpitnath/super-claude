# Global Installation Guide

Super Claude Kit supports both **project-local** and **global** installation modes.

## Installation Modes

### Project-Local (Default)
```bash
cd /path/to/your/project
curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash
```

This installs Super Claude Kit into your project's `.claude/` directory. Each project has its own separate installation.

### Global Installation
```bash
cd ~
curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash
```

This installs Super Claude Kit into `~/.claude/` and works for **all projects** under your home directory.

## How Global Installation Works

### The Problem
Claude Code automatically creates a `.claude/` directory in each project for its own settings (like `settings.local.json`). This caused issues with previous versions because the hook walk-up logic would stop at the first `.claude/` directory it found, even if it didn't contain any hooks.

### The Solution
The walk-up logic now searches for **specific hook files** rather than just the `.claude/` directory:

```bash
# OLD (broken): Stops at any .claude/ directory
[ -d "$DIR/.claude" ] && cd "$DIR" && exec bash .claude/hooks/session-start.sh

# NEW (fixed): Only stops when the hook FILE exists
[ -f "$DIR/.claude/hooks/session-start.sh" ] && cd "$DIR" && exec bash .claude/hooks/session-start.sh
```

### Project Directory Tracking
When launching from a subdirectory, Super Claude Kit:
1. Captures the original project directory (`CLAUDE_PROJECT_DIR`)
2. Saves it to `~/.claude/current_project_dir`
3. Other hooks read from this file (handles cases where Claude Code changes `pwd` during session)

## Example Directory Structure

```
/home/user/                          # Global installation here
├── .claude/
│   ├── hooks/                       # Super Claude Kit hooks
│   │   ├── session-start.sh
│   │   ├── pre-tool-use.sh
│   │   └── ...
│   ├── settings.local.json          # Hook configuration
│   └── current_project_dir          # Saved project path
│
├── project-a/                       # Project A
│   └── .claude/                     # Claude Code auto-created (empty)
│       └── settings.local.json      # Project-specific settings
│
└── project-b/                       # Project B
    └── src/
```

When you launch Claude Code from `/home/user/project-a/`:
1. Walk-up searches for `session-start.sh`
2. Finds it at `/home/user/.claude/hooks/session-start.sh`
3. `CLAUDE_PROJECT_DIR` is set to `/home/user/project-a`
4. Git operations use `-C "$PROJECT_DIR"` to work on the correct repo

## Benefits of Global Installation

- **Single installation** for all projects
- **Consistent behavior** across all workspaces
- **No duplication** of hooks and tools
- **Easier updates** - update once, applies everywhere
- **Works with any directory** - even non-git directories

## Troubleshooting

### Hooks not running
Check that the hook files exist:
```bash
ls -la ~/.claude/hooks/session-start.sh
```

### Wrong project directory
Check `current_project_dir`:
```bash
cat ~/.claude/current_project_dir
```

### Debug mode
Enable debug logging:
```bash
export CLAUDE_DEBUG_HOOKS=true
claude
# Check: ~/.claude/session-start-debug.log
```
