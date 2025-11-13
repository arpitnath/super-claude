#!/bin/bash
# Super Claude Kit Update Script
# Checks for updates and upgrades to latest version
# Author: Arpit Nath

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Super Claude Kit Update Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're in a Super Claude Kit installation
if [ ! -d ".claude" ]; then
  echo "❌ Error: Not in a Super Claude Kit installation"
  echo "   Run this from your project directory"
  exit 1
fi

# Get current version
if [ -f ".claude/.super-claude-version" ]; then
  CURRENT_VERSION=$(cat .claude/.super-claude-version)
  echo "Current version: $CURRENT_VERSION"
else
  echo "⚠️  No version file found (pre-v1.1.0 installation)"
  CURRENT_VERSION="unknown"
fi

# Get latest version from GitHub
echo "Checking for updates..."
LATEST_VERSION=$(curl -fsSL --max-time 5 https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/manifest.json 2>/dev/null | python3 -c "import sys, json; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "")

if [ -z "$LATEST_VERSION" ]; then
  echo "❌ Failed to check for updates (network error or timeout)"
  exit 1
fi

echo "Latest version:  $LATEST_VERSION"
echo ""

# Compare versions
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "✅ Already on latest version"
  echo ""
  echo "Current version: $CURRENT_VERSION"
  echo "No update needed"
  exit 0
fi

# Offer update
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Update Available"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Current: $CURRENT_VERSION"
echo "Latest:  $LATEST_VERSION"
echo ""
read -p "Update now? (y/n) " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Update cancelled"
  exit 0
fi

# Backup current installation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 Backing up current installation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BACKUP_DIR=".claude/.backup-$(date +%s)"
mkdir -p "$BACKUP_DIR"

# Backup critical files
if [ -d ".claude/hooks" ]; then
  cp -r .claude/hooks "$BACKUP_DIR/" && echo "✓ Hooks backed up"
fi

if [ -d ".claude/skills" ]; then
  cp -r .claude/skills "$BACKUP_DIR/" && echo "✓ Skills backed up"
fi

if [ -d ".claude/agents" ]; then
  cp -r .claude/agents "$BACKUP_DIR/" && echo "✓ Agents backed up"
fi

if [ -d ".claude/scripts" ]; then
  cp -r .claude/scripts "$BACKUP_DIR/" && echo "✓ Scripts backed up"
fi

if [ -f ".claude/settings.local.json" ]; then
  cp .claude/settings.local.json "$BACKUP_DIR/" && echo "✓ Settings backed up"
fi

echo ""
echo "Backup saved to: $BACKUP_DIR"
echo ""

# Download and run installer
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⬇️  Downloading and installing update..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

curl -fsSL https://raw.githubusercontent.com/arpitnath/super-claude-kit/master/install | bash

echo ""

# Check if migration needed
if [ "$CURRENT_VERSION" != "unknown" ]; then
  OLD_MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1 | tr -d 'v')
  OLD_MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
  NEW_MAJOR=$(echo "$LATEST_VERSION" | cut -d. -f1 | tr -d 'v')
  NEW_MINOR=$(echo "$LATEST_VERSION" | cut -d. -f2)

  # Check if migration script exists
  MIGRATION_SCRIPT=".claude/scripts/migrate-${OLD_MAJOR}.${OLD_MINOR}-to-${NEW_MAJOR}.${NEW_MINOR}.sh"

  if [ "$OLD_MAJOR" != "$NEW_MAJOR" ] || [ "$OLD_MINOR" != "$NEW_MINOR" ]; then
    if [ -f "$MIGRATION_SCRIPT" ]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🔄 Running migration script..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      bash "$MIGRATION_SCRIPT"
      echo ""
    fi
  fi
fi

# Verify new version
if [ -f ".claude/.super-claude-version" ]; then
  INSTALLED_VERSION=$(cat .claude/.super-claude-version)
else
  INSTALLED_VERSION="unknown"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Update Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Old version: $CURRENT_VERSION"
echo "New version: $INSTALLED_VERSION"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "🔄 Restart Claude Code to use the updated version"
echo ""
echo "📖 To see what's new:"
echo "   cat .claude/docs/CHANGELOG.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
