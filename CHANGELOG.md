# Changelog

All notable changes to Super Claude Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Version tracking system (creates .claude/.super-claude-version)
- Installation timestamp tracking (.claude/.super-claude-installed)
- Update script for upgrading to latest version
- Auto-check for updates on session start (once per day)
- CHANGELOG.md for tracking release history

### Changed
- Install script now saves version information
- Session start hook checks for available updates

### Deprecated

### Removed

### Fixed

### Security

---

## [1.0.0] - 2025-11-13

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
