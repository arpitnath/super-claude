#!/bin/bash
# Automatic Change Detection Script
# Detects file changes, tool usage, and discoveries since last prompt
# Called by pre-task-analysis hook

set -euo pipefail

SNAPSHOT_FILE=".claude/last_snapshot.txt"
FILE_LOG=".claude/session_files.log"
TIMESTAMP=$(date +%s)

# Create snapshot file if doesn't exist
mkdir -p .claude
touch "$SNAPSHOT_FILE"

# ============================================
# GIT-BASED FILE DETECTION (if available)
# ============================================
# Detect files that changed since last snapshot
if git rev-parse --git-dir > /dev/null 2>&1 && [ -f "$SNAPSHOT_FILE" ]; then
  # Get current git status
  CURRENT_STATUS=$(git status --porcelain 2>/dev/null || echo "")
  LAST_STATUS=$(cat "$SNAPSHOT_FILE" 2>/dev/null || echo "")

  # Compare and find new/modified files
  while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi

    # Parse git status line (e.g., " M file.txt", "A  file.txt")
    STATUS_CODE="${line:0:2}"
    FILE_PATH="${line:3}"

    # Skip if this file was already in last snapshot
    if echo "$LAST_STATUS" | grep -qF "$FILE_PATH"; then
      # File was already modified, check if it changed further
      continue
    fi

    # New change detected, log it
    case "$STATUS_CODE" in
      *M*|" M")
        echo "$FILE_PATH,edit,$TIMESTAMP" >> "$FILE_LOG"
        ;;
      A*|"A ")
        echo "$FILE_PATH,write,$TIMESTAMP" >> "$FILE_LOG"
        ;;
      D*|"D ")
        echo "$FILE_PATH,delete,$TIMESTAMP" >> "$FILE_LOG"
        ;;
    esac
  done <<< "$CURRENT_STATUS"

  # Save current status as snapshot
  echo "$CURRENT_STATUS" > "$SNAPSHOT_FILE"
elif git rev-parse --git-dir > /dev/null 2>&1; then
  # First run with git, save snapshot
  git status --porcelain 2>/dev/null > "$SNAPSHOT_FILE" || touch "$SNAPSHOT_FILE"
else
  # No git available, mark as initialized
  touch "$SNAPSHOT_FILE"
fi

# ============================================
# FILE MODIFICATION TIME TRACKING
# ============================================
# Track recently modified files in project (last 60 seconds)
if command -v find >/dev/null 2>&1; then
  # Find files modified in last 60 seconds
  find . -type f \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./.claude/*" \
    -not -path "./build/*" \
    -not -path "./dist/*" \
    -mtime -60s 2>/dev/null | while read -r file; do

    # Check if already logged recently
    if grep -qF "$file" "$FILE_LOG" 2>/dev/null; then
      LAST_LOG=$(grep -F "$file" "$FILE_LOG" | tail -1 | cut -d',' -f3)
      # Only log if more than 30 seconds since last log
      if [ $((TIMESTAMP - LAST_LOG)) -gt 30 ]; then
        echo "$file,edit,$TIMESTAMP" >> "$FILE_LOG"
      fi
    else
      echo "$file,read,$TIMESTAMP" >> "$FILE_LOG"
    fi
  done
fi

exit 0
