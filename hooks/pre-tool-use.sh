#!/bin/bash

# Pre-Tool-Use Hook
# 1. Warns before redundant file reads to encourage using capsule data
# 2. Enforces Super Claude Kit tools for dependency analysis
# 3. Auto-logs file access to capsule
# Runs BEFORE each tool call

set -euo pipefail

TOOL_NAME="${1:-}"
TOOL_INPUT="${2:-}"

# Task tool interception - enforce dependency tools
if [ "$TOOL_NAME" == "Task" ]; then
  # Extract prompt from Task tool input
  TASK_PROMPT=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('prompt', ''))" 2>/dev/null || echo "")

  if [ -n "$TASK_PROMPT" ]; then
    # Convert to lowercase for pattern matching
    PROMPT_LOWER=$(echo "$TASK_PROMPT" | tr '[:upper:]' '[:lower:]')

    # Detect dependency-related queries
    if echo "$PROMPT_LOWER" | grep -qE '(depend|import|require|module.*load|circular.*depend|who.*use|what.*import|find.*import)'; then
      cat << 'EOF'

<tool-enforcement type="dependency-analysis">
  <warning>Query appears to be about code dependencies</warning>

  <dont-use tool="Task" reason="inefficient">
    - Slower: Scans files one-by-one
    - Limited: Cannot detect circular dependencies
    - Expensive: High token usage
  </dont-use>

  <use-instead>
    <tool name="query-deps" use-case="what imports X, who uses X">
      bash .claude/tools/query-deps/query-deps.sh &lt;file-path&gt;
    </tool>

    <tool name="impact-analysis" use-case="what would break if I change X">
      bash .claude/tools/impact-analysis/impact-analysis.sh &lt;file-path&gt;
    </tool>

    <tool name="find-circular" use-case="circular dependencies">
      bash .claude/tools/find-circular/find-circular.sh
    </tool>
  </use-instead>

  <benefit>These tools are instant and read pre-built dependency graph</benefit>
</tool-enforcement>

EOF
    fi

    # Detect file search queries
    if echo "$PROMPT_LOWER" | grep -qE '(where.*file|find.*file|locate.*file|search.*file)' && ! echo "$PROMPT_LOWER" | grep -qE '(depend|import|require)'; then
      cat << 'EOF'

<tool-suggestion type="file-search">
  <use-instead tool="Glob" reason="faster-and-direct">
    For finding files by name pattern:
    Glob pattern: **/*&lt;filename&gt;*
  </use-instead>
</tool-suggestion>

EOF
    fi
  fi

  exit 0
fi

# Read tool monitoring and large file detection
if [ "$TOOL_NAME" != "Read" ]; then
  exit 0
fi

FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null || echo "")

# Check file size and recommend progressive-reader for large files
if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
  FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null || echo "0")
  FILE_SIZE_KB=$((FILE_SIZE / 1024))

  if [ "$FILE_SIZE" -gt 51200 ]; then  # 50KB threshold
    cat << EOF

<tool-enforcement type="large-file-reading">
  <warning>File size: ${FILE_SIZE_KB}KB exceeds 50KB threshold</warning>

  <dont-use tool="Read" reason="token-wasteful">
    - Loads entire file even if you need small section
    - No semantic awareness - may truncate or split mid-function
    - Token cost: ~$((FILE_SIZE / 4)) tokens for full file
  </dont-use>

  <use-instead tool="progressive-reader">
    <step1>Preview chunks: progressive-reader --path ${FILE_PATH} --list</step1>
    <step2>Read specific chunk: progressive-reader --path ${FILE_PATH} --chunk N</step2>
    <benefit>Saves 75-97% tokens via semantic chunking</benefit>
  </use-instead>
</tool-enforcement>

EOF
  fi
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Tracking files
RECENT_READS_LOG=".claude/recent_reads.log"
WARNINGS_SHOWN=".claude/read_warnings_shown.log"

# Create logs if they don't exist
mkdir -p .claude
touch "$RECENT_READS_LOG"
touch "$WARNINGS_SHOWN"

# Check if we already warned about this file this session
if grep -q "^${FILE_PATH}$" "$WARNINGS_SHOWN" 2>/dev/null; then
  exit 0
fi

# Check if file was recently accessed
CURRENT_TIME=$(date +%s)
THRESHOLD=300  # 5 minutes in seconds

if grep -q "^${FILE_PATH}," "$RECENT_READS_LOG" 2>/dev/null; then
  # Get last read time
  LAST_READ=$(grep "^${FILE_PATH}," "$RECENT_READS_LOG" | tail -1 | cut -d',' -f2)
  TIME_SINCE=$((CURRENT_TIME - LAST_READ))

  if [ $TIME_SINCE -lt $THRESHOLD ]; then
    # Convert to human readable
    if [ $TIME_SINCE -lt 60 ]; then
      TIME_STR="${TIME_SINCE}s"
    else
      TIME_STR="$((TIME_SINCE / 60))m"
    fi

    # Show warning
    echo "<read-warning file=\"$FILE_PATH\" last-read=\"${TIME_STR} ago\">File recently read - check capsule first</read-warning>"

    # Mark as warned
    echo "$FILE_PATH" >> "$WARNINGS_SHOWN"
  fi
fi

# Record this read attempt
echo "$FILE_PATH,$CURRENT_TIME" >> "$RECENT_READS_LOG"

# Auto-log file access to capsule
if [ -x ".claude/hooks/log-file-access.sh" ]; then
  # Auto-log this read operation (suppress output to avoid noise)
  .claude/hooks/log-file-access.sh "$FILE_PATH" "read" > /dev/null 2>&1 || true
fi

exit 0
