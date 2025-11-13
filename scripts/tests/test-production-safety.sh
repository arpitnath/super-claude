#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"

start_test_suite "Production Safety"

check_agent_tools() {
  local agent_file="$1"
  local agent_name="$2"

  if ! assert_file_exists "$agent_file"; then
    fail "Agent file exists: $agent_name"
    return 1
  fi

  local tools=$(grep "^tools:" "$agent_file" 2>/dev/null || echo "")

  if echo "$tools" | grep -q "Bash"; then
    fail "$agent_name should not have Bash tool"
    return 1
  fi

  if echo "$tools" | grep -q "Edit"; then
    fail "$agent_name should not have Edit tool"
    return 1
  fi

  if echo "$tools" | grep -q "Write"; then
    fail "$agent_name should not have Write tool"
    return 1
  fi

  if echo "$tools" | grep -q "Read"; then
    pass "$agent_name has Read tool (allowed)"
  else
    fail "$agent_name missing Read tool"
    return 1
  fi

  if grep -q "Read-only" "$agent_file" 2>/dev/null; then
    pass "$agent_name documented as read-only"
  else
    fail "$agent_name missing read-only documentation"
    return 1
  fi
}

check_agent_tools "agents/architecture-explorer.md" "architecture-explorer"
check_agent_tools "agents/database-navigator.md" "database-navigator"
check_agent_tools "agents/agent-developer.md" "agent-developer"
check_agent_tools "agents/github-issue-tracker.md" "github-issue-tracker"

if grep -q "Production-Safe" README.md 2>/dev/null; then
  pass "Test 9: README mentions production safety"
else
  fail "Test 9: README mentions production safety"
fi

if grep -q "Production Safety" CLAUDE_TEMPLATE.md 2>/dev/null; then
  pass "Test 10: CLAUDE_TEMPLATE documents safety"
else
  fail "Test 10: CLAUDE_TEMPLATE documents safety"
fi

end_test_suite
