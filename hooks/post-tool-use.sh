#!/bin/bash

set -euo pipefail

TOOL_NAME="${1:-}"
TOOL_INPUT="${2:-}"
TOOL_OUTPUT="${3:-}"

if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

case "$TOOL_NAME" in
  "Read")
    if FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null); then
      if [ -n "$FILE_PATH" ]; then
        ./.claude/hooks/log-file-access.sh "$FILE_PATH" "read" 2>/dev/null || true
      fi
    fi
    ;;

  "Edit")
    if FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null); then
      if [ -n "$FILE_PATH" ]; then
        ./.claude/hooks/log-file-access.sh "$FILE_PATH" "edit" 2>/dev/null || true
      fi
    fi
    ;;

  "Write")
    if FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null); then
      if [ -n "$FILE_PATH" ]; then
        ./.claude/hooks/log-file-access.sh "$FILE_PATH" "write" 2>/dev/null || true
      fi
    fi
    ;;

  "Task")
    if AGENT_TYPE=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('subagent_type', ''))" 2>/dev/null); then
      if [ -n "$AGENT_TYPE" ] && [ -n "$TOOL_OUTPUT" ]; then
        SUMMARY=$(echo "$TOOL_OUTPUT" | head -c 200 | tr '\n' ' ')
        ./.claude/hooks/log-subagent.sh "$AGENT_TYPE" "$SUMMARY" 2>/dev/null || true
      fi
    fi
    ;;

  "Bash")
    # Log progressive-reader usage and output
    if echo "$TOOL_INPUT" | grep -q "progressive-reader"; then
      if FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '\-\-path [^ ]+' | cut -d' ' -f2); then
        if [ -n "$FILE_PATH" ]; then
          ./.claude/hooks/log-file-access.sh "$FILE_PATH" "progressive-read" 2>/dev/null || true
        fi
      fi
      # Log progressive-reader output for debugging
      if [ -n "$TOOL_OUTPUT" ]; then
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] progressive-reader output:" >> .claude/progressive-reader.log
        echo "$TOOL_OUTPUT" >> .claude/progressive-reader.log
        echo "---" >> .claude/progressive-reader.log
      fi
    fi
    ;;

  "TodoWrite")
    if [ -n "$TOOL_INPUT" ]; then
      # Clear existing tasks and log all new ones
      > .claude/current_tasks.log

      echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    todos = data.get('todos', [])
    for todo in todos:
        status = todo.get('status', 'unknown')
        content = todo.get('content', '')
        print(f'{status}|{content}')
except:
    pass
" 2>/dev/null | while IFS='|' read -r status content; do
        if [ -n "$content" ]; then
          echo "${status}|${content}" >> .claude/current_tasks.log
        fi
      done
    fi
    ;;
esac

exit 0
