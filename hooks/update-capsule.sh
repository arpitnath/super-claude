#!/bin/bash
# Context Capsule Update Script
# Updates the context capsule with current session state
# Format: TOON (Token-Oriented Object Notation)

set -euo pipefail

CAPSULE_FILE=".claude/capsule.toon"
CAPSULE_TEMP=".claude/capsule.toon.tmp"
SESSION_ID="${SESSION_ID:-default}"
TIMESTAMP=$(date +%s)

# Initialize capsule file if it doesn't exist
if [ ! -f "$CAPSULE_FILE" ]; then
  touch "$CAPSULE_FILE"
fi

# Start building the capsule
cat > "$CAPSULE_TEMP" << EOF
CAPSULE[$SESSION_ID]{$TIMESTAMP}:

EOF

# ====================
# GIT SECTION
# ====================
if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
  BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")

  cat >> "$CAPSULE_TEMP" << EOF
GIT{branch,head,dirty_count,ahead,behind}:
 $BRANCH,$HEAD,$DIRTY_COUNT,$AHEAD,$BEHIND

EOF
fi

# ====================
# FILES SECTION
# ====================
# Track files that have been accessed (read/edited/written) this session
# We maintain a session log of tool calls
FILE_LOG=".claude/session_files.log"

if [ -f "$FILE_LOG" ]; then
  echo "FILES{path,action,timestamp}:" >> "$CAPSULE_TEMP"

  # Read last 20 file operations, remove duplicates (keep latest), sort by timestamp
  tail -n 50 "$FILE_LOG" 2>/dev/null | \
    awk -F',' '!seen[$1]++ {print}' | \
    sort -t',' -k3 -rn | \
    head -n 20 | \
    while IFS=',' read -r path action ts; do
      AGE=$((TIMESTAMP - ts))
      echo " $path,$action,$AGE" >> "$CAPSULE_TEMP"
    done

  echo "" >> "$CAPSULE_TEMP"
fi

# ====================
# TASK SECTION
# ====================
# Extract current todos if they exist
# This is a placeholder - in reality, todos are managed by Claude Code internally
# We'll try to detect them from recent conversation context
TASK_FILE=".claude/current_tasks.log"

if [ -f "$TASK_FILE" ]; then
  echo "TASK{status,content}:" >> "$CAPSULE_TEMP"

  cat "$TASK_FILE" | while IFS='|' read -r status content; do
    # Escape commas in content
    SAFE_CONTENT=$(echo "$content" | tr ',' ';')
    echo " $status,$SAFE_CONTENT" >> "$CAPSULE_TEMP"
  done

  echo "" >> "$CAPSULE_TEMP"
fi

# ====================
# SUB-AGENT SECTION
# ====================
# Track sub-agent completions
SUBAGENT_LOG=".claude/subagent_results.log"

if [ -f "$SUBAGENT_LOG" ] && [ -s "$SUBAGENT_LOG" ]; then
  echo "SUBAGENT{timestamp,type,summary}:" >> "$CAPSULE_TEMP"

  # Show last 5 sub-agent results
  tail -n 5 "$SUBAGENT_LOG" 2>/dev/null | while IFS=',' read -r ts type summary; do
    AGE=$((TIMESTAMP - ts))
    echo " $AGE,$type,$summary" >> "$CAPSULE_TEMP"
  done

  echo "" >> "$CAPSULE_TEMP"
fi

# ====================
# DISCOVERY SECTION
# ====================
# Track session discoveries
DISCOVERY_LOG=".claude/session_discoveries.log"

if [ -f "$DISCOVERY_LOG" ] && [ -s "$DISCOVERY_LOG" ]; then
  echo "DISCOVERY{timestamp,category,content}:" >> "$CAPSULE_TEMP"

  # Show last 5 discoveries
  tail -n 5 "$DISCOVERY_LOG" 2>/dev/null | while IFS=',' read -r ts category content; do
    AGE=$((TIMESTAMP - ts))
    echo " $AGE,$category,$content" >> "$CAPSULE_TEMP"
  done

  echo "" >> "$CAPSULE_TEMP"
fi

# ====================
# TOOLS SECTION
# ====================
# List available custom tools
TOOL_RUNNER_PATH=".claude/lib/tool-runner.sh"

if [ -f "$TOOL_RUNNER_PATH" ]; then
  # Source the tool runner
  source "$TOOL_RUNNER_PATH"

  # Discover tools
  TOOLS_JSON=$(discover_tools 2>/dev/null)

  if [ -n "$TOOLS_JSON" ] && [ "$TOOLS_JSON" != "[]" ]; then
    echo "TOOLS{name,description,type}:" >> "$CAPSULE_TEMP"

    # Extract tool info (name, description, type)
    echo "$TOOLS_JSON" | jq -r '.[] | "\(.name),\(.description // "No description"),\(.type // "bash")"' 2>/dev/null | \
      while IFS=',' read -r name desc type; do
        # Truncate long descriptions
        SHORT_DESC=$(echo "$desc" | cut -c1-60)
        echo " $name,$SHORT_DESC,$type" >> "$CAPSULE_TEMP"
      done

    echo "" >> "$CAPSULE_TEMP"
  fi
fi

# ====================
# SESSION METADATA
# ====================
# Track basic session info
MESSAGE_COUNT_FILE=".claude/message_count.txt"
MESSAGE_COUNT="0"

if [ -f "$MESSAGE_COUNT_FILE" ]; then
  MESSAGE_COUNT=$(cat "$MESSAGE_COUNT_FILE")
fi

SESSION_START_FILE=".claude/session_start.txt"
SESSION_DURATION="0"

if [ -f "$SESSION_START_FILE" ]; then
  SESSION_START=$(cat "$SESSION_START_FILE")
  SESSION_DURATION=$((TIMESTAMP - SESSION_START))
fi

cat >> "$CAPSULE_TEMP" << EOF
META{messages,duration_seconds,updated_at}:
 $MESSAGE_COUNT,$SESSION_DURATION,$TIMESTAMP

EOF

# Move temp file to final location
mv "$CAPSULE_TEMP" "$CAPSULE_FILE"

# Output success
echo "✓ Capsule updated: $CAPSULE_FILE" >&2
