#!/bin/bash
# PostToolUse Hook - Auto-logs file operations and task updates
# Claude Code passes arguments via stdin as JSON, NOT positional args

set -euo pipefail

# Read JSON from stdin (Claude Code's hook protocol)
INPUT_JSON=$(cat)

# Extract fields from JSON using python3
TOOL_NAME=$(echo "$INPUT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tool_name', ''))" 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; import json as j; print(j.dumps(json.load(sys.stdin).get('tool_input', {})))" 2>/dev/null || echo "{}")
TOOL_OUTPUT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; import json as j; r = json.load(sys.stdin).get('tool_response', {}); print(j.dumps(r) if isinstance(r, dict) else str(r))" 2>/dev/null || echo "")

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
      # Clear existing tasks and write new ones directly from Python
      echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    todos = data.get('todos', [])
    with open('.claude/current_tasks.log', 'w') as f:
        for todo in todos:
            status = todo.get('status', 'unknown')
            content = todo.get('content', '')
            if content:
                f.write(f'{status}|{content}\n')
except Exception as e:
    pass
" 2>/dev/null || true
    fi
    ;;
esac

exit 0
