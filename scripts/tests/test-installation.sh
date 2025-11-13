#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"

start_test_suite "Installation"

if assert_dir_exists ".claude/hooks"; then
  pass "Test 1: .claude/hooks directory exists"
else
  fail "Test 1: .claude/hooks directory exists"
fi

if assert_dir_exists ".claude/agents"; then
  pass "Test 2: .claude/agents directory exists"
else
  fail "Test 2: .claude/agents directory exists"
fi

if assert_dir_exists ".claude/skills"; then
  pass "Test 3: .claude/skills directory exists"
else
  fail "Test 3: .claude/skills directory exists"
fi

if assert_dir_exists ".claude/docs"; then
  pass "Test 4: .claude/docs directory exists"
else
  fail "Test 4: .claude/docs directory exists"
fi

if assert_file_exists ".claude/hooks/session-start.sh"; then
  pass "Test 5: session-start.sh exists"
else
  fail "Test 5: session-start.sh exists"
fi

if assert_file_exists ".claude/hooks/pre-task-analysis.sh"; then
  pass "Test 6: pre-task-analysis.sh exists"
else
  fail "Test 6: pre-task-analysis.sh exists"
fi

if assert_file_exists ".claude/settings.local.json"; then
  pass "Test 7: settings.local.json exists"
else
  fail "Test 7: settings.local.json exists"
fi

executable_count=$(find .claude/hooks -name "*.sh" -perm +111 2>/dev/null | wc -l | tr -d ' ')
if [ "$executable_count" -gt 0 ]; then
  pass "Test 8: $executable_count hooks are executable"
else
  fail "Test 8: Hooks are executable" "No executable hooks found"
fi

end_test_suite
