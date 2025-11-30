#!/bin/bash
# Cross-Session Capsule Persistence
# Saves key session state for next session to restore

set -euo pipefail

# First, show session summary
./.claude/hooks/summarize-session.sh 2>/dev/null

PERSIST_FILE=".claude/capsule_persist.json"
TIMESTAMP=$(date +%s)
SESSION_START=$(cat .claude/session_start.txt 2>/dev/null || echo "$TIMESTAMP")
SESSION_DURATION=$((TIMESTAMP - SESSION_START))

# Get git info if available
if git rev-parse --git-dir > /dev/null 2>&1; then
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "none")
  GIT_HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
else
  GIT_BRANCH="none"
  GIT_HEAD="none"
fi

# Create persistence object
cat > "$PERSIST_FILE" << EOF
{
  "last_session": {
    "ended_at": $TIMESTAMP,
    "duration_seconds": $SESSION_DURATION,
    "branch": "$GIT_BRANCH",
    "head": "$GIT_HEAD"
  },
  "discoveries": [
EOF

# Add last 10 discoveries
if [ -f ".claude/session_discoveries.log" ]; then
  tail -n 10 .claude/session_discoveries.log 2>/dev/null | while IFS=',' read -r ts category content; do
    # Escape content for JSON
    SAFE_CONTENT=$(echo "$content" | sed 's/"/\\"/g' | sed "s/'/\\'/g")
    echo "    {\"timestamp\": $ts, \"category\": \"$category\", \"content\": \"$SAFE_CONTENT\"}," >> "$PERSIST_FILE"
  done

  # Remove trailing comma from last item
  sed -i.bak '$ s/,$//' "$PERSIST_FILE" 2>/dev/null || sed -i '$ s/,$//' "$PERSIST_FILE" 2>/dev/null
  rm -f "$PERSIST_FILE.bak" 2>/dev/null || true
fi

cat >> "$PERSIST_FILE" << EOF
  ],
  "key_files": [
EOF

# Add last 15 accessed files
if [ -f ".claude/session_files.log" ]; then
  tail -n 15 .claude/session_files.log 2>/dev/null | awk -F',' '{print $1}' | sort -u | while read -r file; do
    echo "    \"$file\"," >> "$PERSIST_FILE"
  done

  # Remove trailing comma
  sed -i.bak '$ s/,$//' "$PERSIST_FILE" 2>/dev/null || sed -i '$ s/,$//' "$PERSIST_FILE" 2>/dev/null
  rm -f "$PERSIST_FILE.bak" 2>/dev/null || true
fi

cat >> "$PERSIST_FILE" << EOF
  ],
  "sub_agents": [
EOF

# Add last 5 sub-agent results
if [ -f ".claude/subagent_results.log" ]; then
  tail -n 5 .claude/subagent_results.log 2>/dev/null | while IFS=',' read -r ts type summary; do
    SAFE_SUMMARY=$(echo "$summary" | sed 's/"/\\"/g' | sed "s/'/\\'/g")
    echo "    {\"timestamp\": $ts, \"type\": \"$type\", \"summary\": \"$SAFE_SUMMARY\"}," >> "$PERSIST_FILE"
  done

  # Remove trailing comma
  sed -i.bak '$ s/,$//' "$PERSIST_FILE" 2>/dev/null || sed -i '$ s/,$//' "$PERSIST_FILE" 2>/dev/null
  rm -f "$PERSIST_FILE.bak" 2>/dev/null || true
fi

cat >> "$PERSIST_FILE" << EOF
  ]
}
EOF

# Also sync discoveries to exploration journal
./.claude/hooks/sync-to-journal.sh 2>/dev/null

echo "✓ Session state persisted for next session" >&2
