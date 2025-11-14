#!/bin/bash
# Pre-task analysis hook - analyzes user prompt and suggests optimal approach
# Runs before Claude responds to encourage best practices and efficient workflows

USER_PROMPT=$(timeout 0.1 cat 2>/dev/null || echo "$1")

MESSAGE_COUNT_FILE=".claude/message_count.txt"
if [ -f "$MESSAGE_COUNT_FILE" ]; then
  COUNT=$(cat "$MESSAGE_COUNT_FILE")
  NEW_COUNT=$((COUNT + 1))
  echo $NEW_COUNT > "$MESSAGE_COUNT_FILE"
else
  NEW_COUNT=1
  echo "1" > "$MESSAGE_COUNT_FILE"
fi

# Output JSON with systemMessage on first message BEFORE any plain text
# (Ensures first character is '{' for proper JSON parsing)
if [ "$NEW_COUNT" -eq 1 ]; then
  cat << 'EOF'
{
  "systemMessage": "🚀 Super Claude Kit v2.0 Active - Context and tools loaded"
}
EOF
fi

if ./.claude/hooks/check-refresh-needed.sh 2>/dev/null; then
  ./.claude/hooks/detect-changes.sh 2>/dev/null
  ./.claude/hooks/update-capsule.sh 2>/dev/null
  ./.claude/hooks/inject-capsule.sh 2>/dev/null
else
  :
fi

SUGGESTIONS_MADE=false

if echo "$USER_PROMPT" | grep -qiE "explore|find.*file|search.*code|where.*is|how does.*work|understand.*architecture|locate|discover|investigate|show.*me"; then
    echo ""
    echo "DELEGATION SUGGESTION: Explore sub-agent"
    echo "   Task Type: Codebase exploration/discovery"
    echo "   Best Approach: Use 'Explore' sub-agent"
    echo "   Why: Fast multi-round investigation, pattern matching"
    echo ""
    echo "   Usage: Task tool with subagent_type='Explore'"
    echo "   Thoroughness: 'quick', 'medium', or 'very thorough'"
    echo ""
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "plan|implement|build|create|develop|design|architect|add.*feature|new.*system"; then
    echo ""
    echo "DELEGATION SUGGESTION: Plan sub-agent"
    echo "   Task Type: Planning/Implementation"
    echo "   Best Approach: Use 'Plan' sub-agent"
    echo "   Why: Creates systematic implementation strategy"
    echo ""
    echo "   Usage: Task tool with subagent_type='Plan'"
    echo "   Returns: Detailed implementation plan with steps"
    echo ""
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "fix.*and.*test|migrate.*and.*verify|update.*across|refactor.*entire"; then
    echo ""
    echo "DELEGATION SUGGESTION: general-purpose sub-agent"
    echo "   Task Type: Complex multi-step task"
    echo "   Best Approach: Use 'general-purpose' sub-agent"
    echo "   Why: Handles complex workflows with multiple operations"
    echo ""
    echo "   Usage: Task tool with subagent_type='general-purpose'"
    echo ""
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "and|also|both|multiple|all three|check.*check|verify.*verify"; then
    echo ""
    echo "PERFORMANCE TIP: Parallel Tool Calls"
    echo "   Detected: Multiple independent operations"
    echo "   Best Practice: Execute tool calls in parallel"
    echo "   Why: Faster execution (single message, multiple tools)"
    echo ""
    echo "   Example: Read 3 files -> Use 3 Read calls in one message"
    echo ""
    SUGGESTIONS_MADE=true
fi

if echo "$USER_PROMPT" | grep -qiE "continue|resume|pick.*up|where.*left|last.*time|previous|what.*next"; then
    if [ -f "docs/exploration/CURRENT_SESSION.md" ]; then
        echo ""
        echo "MEMORY AVAILABLE: Exploration Journal Found"
        echo "   Action Required: Read exploration journal FIRST"
        echo "   Location: docs/exploration/CURRENT_SESSION.md"
        echo "   Why: Avoid repeating work, maintain continuity"
        echo ""
        echo "   Next: Summarize previous session for user"
        echo ""
        SUGGESTIONS_MADE=true
    fi
fi

if echo "$USER_PROMPT" | grep -qiE "implement|build|create|fix.*bug|add.*feature"; then
    echo ""
    echo "REMINDER: Use TodoWrite for task tracking"
    echo "   Break complex work into trackable steps"
    echo ""
    SUGGESTIONS_MADE=true
fi

if [ "$SUGGESTIONS_MADE" = false ]; then
    PROMPT_LENGTH=${#USER_PROMPT}
    if [ $PROMPT_LENGTH -gt 200 ]; then
        echo ""
        echo "REMINDER: Complex task detected (long prompt)"
        echo "   Available sub-agents: Plan, Explore, general-purpose"
        echo "   Consider: Breaking into smaller tasks with TodoWrite"
        echo ""
    fi
fi

if [ -f "./.claude/hooks/tool-auto-suggest.sh" ]; then
    ./.claude/hooks/tool-auto-suggest.sh "$USER_PROMPT" 2>/dev/null || true
fi

exit 0
