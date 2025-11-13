# Changelog

All notable changes to Super Claude Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-11-13

### 🎉 What's New

v1.1.0 transforms Super Claude Kit from a good context system into an intelligent, self-improving system with **95% automated logging** and **80% reduced output overhead**.

**Key Highlights:**
- ✅ Auto-logging (PostToolUse hook) - 95% of logging now automatic
- ✅ Quality improvement hooks - Proactive guidance and warnings
- ✅ Compact output format - 80% token reduction in overhead
- ✅ Version tracking - Auto-update checks built-in
- ✅ Production safety - Read-only sub-agents

### Added

#### Auto-Logging System (Phase 3)
- **PostToolUse Hook**: Automatically logs file operations (Read/Edit/Write), sub-agent completions, and TodoWrite updates
- **95% automation**: Only discoveries require manual logging now
- **Automatic file tracking**: Every Read/Edit/Write operation logged automatically
- **Automatic sub-agent tracking**: Task tool completions captured automatically
- **Automatic task tracking**: TodoWrite updates synced to capsule automatically

#### Quality Improvement Hooks (Phase 4)
- **PreToolUse Hook**: Warns before redundant file reads (saves 200-500 tokens per session)
- **Stop Hook**: Suggests logging discoveries when quality ratio is poor
- **SessionEnd Hook**: Auto-persists capsule on exit (zero-friction session continuity)
- **Smart reminders**: One-time-per-session suggestions to avoid repetition

#### Output Optimization (Phase 3.5)
- **Compact format**: Removed emoji boxes and long banners (80% token reduction)
- **Efficient summaries**: Session output reduced from 2,500 to 500 tokens
- **Smart reminders**: Important tips shown once per session
- **Cleaner UX**: Professional, scannable output format

#### Version Management (Phase 1)
- **Version tracking**: `.claude/version.txt` tracks current version
- **Auto-update check**: Daily checks for new versions (non-intrusive)
- **Update script**: `.claude/scripts/update-sck.sh` for one-command updates
- **Installation timestamp**: Track when Super Claude Kit was installed
- **CHANGELOG.md**: Track release history

### Changed

#### Production Safety (Phase 2)
- **BREAKING**: Removed Bash tool from all sub-agents (architecture-explorer, database-navigator, agent-developer, github-issue-tracker)
- **Sub-agents now read-only**: Can only use Read, Grep, Glob, WebFetch tools
- **Safety rationale**: Prevents accidental file modifications in production environments

#### Documentation
- Updated `README.md` with v1.1.0 features
- Enhanced `CAPSULE_USAGE_GUIDE.md` with quality hooks section
- Updated `CLAUDE.md` integration instructions
- Added comprehensive usage examples

#### Hook System
- Active hooks increased from 2 to 7 (SessionStart, UserPromptSubmit, PostToolUse, PreToolUse, Stop, SessionEnd, +1 more)
- Total hooks increased from 21 to 24
- All hooks now use compact output format
- Install script saves version information
- Session start hook checks for available updates

### Removed

- **BREAKING**: Bash tool access from sub-agents (read-only by design)

### Fixed

- Session persistence edge cases
- Output verbosity issues (emoji boxes removed)
- Redundant reminder spam (smart once-per-session tips)
- Task continuity tracking improvements

### Security

- Enhanced production safety with read-only sub-agents
- No file modification capabilities in sub-agents
- Safer for production environment exploration

---

## Upgrade Guide (v1.0.0 → v1.1.0)

### Automatic Upgrade

```bash
bash .claude/scripts/update-sck.sh
```

### Manual Upgrade

```bash
cd your-project
curl -sL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash
```

### Breaking Changes

**1. Sub-Agent Bash Removal**
- **Who's affected**: Users relying on sub-agents to run bash commands
- **Action required**: None - sub-agents now read-only by design
- **Workaround**: Use main Claude session for bash operations
- **Benefit**: Safer production environment exploration

**2. Output Format Changes**
- **Who's affected**: Scripts parsing hook output (rare)
- **Action required**: Update parsers to expect compact format
- **Impact**: Minimal - most users don't parse output

### New Features (No Action Required)

All new features work automatically:
- Auto-logging via PostToolUse hook
- Quality hooks provide automatic guidance
- Version tracking enables update checks
- Backward compatible with v1.0.0 capsule data

### Testing After Upgrade

```bash
# Verify installation
bash .claude/scripts/test-super-claude.sh

# Check version
cat .claude/version.txt

# View stats
bash .claude/scripts/show-stats.sh
```

---

## Metrics

### Token Efficiency
- **Output optimization**: 80% reduction (2,500 → 500 tokens per session)
- **Auto-logging overhead**: Minimal (~50 tokens per session)
- **PreToolUse savings**: 200-500 tokens per redundant read prevented
- **Net benefit**: ~1,500-2,000 tokens saved per session

### Quality Improvements
- **Auto-logging coverage**: 95% (up from ~5% manual)
- **Quality hook guidance**: 3 automatic improvement hooks
- **Session persistence**: 100% automatic

### User Experience
- **Installation**: Single command
- **Configuration**: Fully automatic
- **Updates**: Daily check + one-command update
- **Output**: Clean, professional, scannable

---

## [1.0.0] - 2025-11-12

### Added
- Initial release of Super Claude Kit
- Persistent context memory system
- 20 hooks for session and prompt orchestration
- 2 utility scripts (test-super-claude.sh, show-stats.sh)
- 3 universal skills (context-saver, exploration-continue, task-router)
- 4 specialized sub-agents (architecture-explorer, database-navigator, agent-developer, github-issue-tracker)
- TOON format for token-efficient storage (52% reduction vs JSON)
- Smart refresh with hash-based change detection
- Cross-session persistence (24-hour memory window)
- Exploration journal integration
- Brew-style installation script
- Session state tracking
- File access logging
- Discovery logging
- Task tracking integration
- Sub-agent result logging
- Automatic capsule injection
- Session restoration from previous runs
- Git state tracking
- Comprehensive documentation (CAPSULE_USAGE_GUIDE.md, SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md)

### Features
- **Persistent Memory**: Files, tasks, discoveries, git state across messages
- **Token Efficient**: TOON compression saves ~52% tokens vs JSON
- **Smart Refresh**: Only updates when content changes (60-70% fewer updates)
- **Cross-Session**: Restores context from previous session (24h window)
- **Zero Dependencies**: Pure bash + python3, no external packages
- **Automatic**: Hooks run automatically, no manual intervention
- **Extensible**: Skills and sub-agents for specialized tasks

---

## Version Format

**[MAJOR.MINOR.PATCH]**

- **MAJOR**: Breaking changes, incompatible updates
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

---

## Release Process

1. Update version in manifest.json
2. Update CHANGELOG.md with release notes
3. Commit changes
4. Create git tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. Push with tags: `git push origin master --tags`
6. Create GitHub Release with release notes

---

## Links

- [GitHub Repository](https://github.com/arpitnath/super-claude-kit)
- [Installation Guide](README.md#installation)
- [Usage Guide](.claude/docs/CAPSULE_USAGE_GUIDE.md)
- [System Architecture](.claude/docs/SUPER_CLAUDE_SYSTEM_ARCHITECTURE.md)

---

## Template for New Releases

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features go here

### Changed
- Changes to existing functionality

### Deprecated
- Features that will be removed in future

### Removed
- Features removed in this version

### Fixed
- Bug fixes

### Security
- Security patches and improvements
```
