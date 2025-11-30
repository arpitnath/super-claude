#!/bin/bash
# Smart Refresh Heuristics
# Determines if capsule needs updating based on state changes
# Returns: 0 if refresh needed, 1 if can skip

set -euo pipefail

REFRESH_STATE_FILE=".claude/last_refresh_state.txt"
TIMESTAMP=$(date +%s)

# Helper: Calculate hash of current state
calculate_state_hash() {
  local state_string=""

  # Git state (if available)
  if git rev-parse --git-dir > /dev/null 2>&1; then
    state_string+=$(git status --porcelain 2>/dev/null | md5 -q 2>/dev/null || echo "")
  else
    # Fallback: use timestamp of last modified file
    state_string+=$(find . -type f -not -path "./.claude/*" -not -path "./.git/*" -not -path "./node_modules/*" -printf "%T@\n" 2>/dev/null | sort -n | tail -1 || echo "0")
  fi

  # File log size (number of lines)
  if [ -f ".claude/session_files.log" ]; then
    state_string+=$(wc -l < .claude/session_files.log 2>/dev/null || echo "0")
  fi

  # Task log size
  if [ -f ".claude/current_tasks.log" ]; then
    state_string+=$(wc -l < .claude/current_tasks.log 2>/dev/null || echo "0")
  fi

  # Sub-agent log size
  if [ -f ".claude/subagent_results.log" ]; then
    state_string+=$(wc -l < .claude/subagent_results.log 2>/dev/null || echo "0")
  fi

  # Discovery log size
  if [ -f ".claude/session_discoveries.log" ]; then
    state_string+=$(wc -l < .claude/session_discoveries.log 2>/dev/null || echo "0")
  fi

  # Return hash of combined state
  echo "$state_string" | md5 -q 2>/dev/null || echo "$state_string" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$state_string"
}

# Get current state hash
CURRENT_HASH=$(calculate_state_hash)

# Check if we have previous state
if [ -f "$REFRESH_STATE_FILE" ]; then
  # Read previous state
  LAST_HASH=$(cut -d',' -f1 "$REFRESH_STATE_FILE" 2>/dev/null || echo "")
  LAST_REFRESH=$(cut -d',' -f2 "$REFRESH_STATE_FILE" 2>/dev/null || echo "0")
  TIME_SINCE_REFRESH=$((TIMESTAMP - LAST_REFRESH))

  # Compare hashes
  if [ "$CURRENT_HASH" = "$LAST_HASH" ]; then
    # State unchanged - check if too much time passed
    if [ $TIME_SINCE_REFRESH -lt 300 ]; then
      # Less than 5 minutes - safe to skip
      exit 1  # Skip refresh
    else
      # Over 5 minutes - force refresh for freshness
      echo "$CURRENT_HASH,$TIMESTAMP" > "$REFRESH_STATE_FILE"
      exit 0  # Need refresh
    fi
  else
    # State changed - need refresh
    echo "$CURRENT_HASH,$TIMESTAMP" > "$REFRESH_STATE_FILE"
    exit 0  # Need refresh
  fi
else
  # First run - need refresh
  echo "$CURRENT_HASH,$TIMESTAMP" > "$REFRESH_STATE_FILE"
  exit 0  # Need refresh
fi
