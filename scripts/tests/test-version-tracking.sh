#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"
source "$SCRIPT_DIR/helpers/mock-data.sh"

start_test_suite "Version Tracking"

create_mock_version

if assert_file_exists ".claude/.super-claude-version"; then
  pass "Test 1: Version file exists"
else
  fail "Test 1: Version file exists"
fi

if assert_file_exists ".claude/.super-claude-installed"; then
  pass "Test 2: Installation timestamp exists"
else
  fail "Test 2: Installation timestamp exists"
fi

VERSION=$(cat .claude/.super-claude-version 2>/dev/null || echo "")
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  pass "Test 3: Version has valid semver format ($VERSION)"
else
  fail "Test 3: Version has valid semver format" "Got: $VERSION"
fi

TIMESTAMP=$(cat .claude/.super-claude-installed 2>/dev/null || echo "")
if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" -gt 0 ] 2>/dev/null; then
  pass "Test 4: Installation timestamp is valid"
else
  fail "Test 4: Installation timestamp is valid" "Got: $TIMESTAMP"
fi

if assert_file_exists ".claude/scripts/update-super-claude.sh"; then
  pass "Test 5: Update script exists"
else
  fail "Test 5: Update script exists"
fi

if assert_executable ".claude/scripts/update-super-claude.sh"; then
  pass "Test 6: Update script is executable"
else
  fail "Test 6: Update script is executable"
fi

if grep -q "super-claude-version" .claude/hooks/session-start.sh 2>/dev/null; then
  pass "Test 7: session-start.sh checks version"
else
  fail "Test 7: session-start.sh checks version"
fi

if grep -q "last-update-check" .claude/hooks/session-start.sh 2>/dev/null; then
  pass "Test 8: Update check is rate-limited"
else
  fail "Test 8: Update check is rate-limited"
fi

if grep -q "86400" .claude/hooks/session-start.sh 2>/dev/null; then
  pass "Test 9: Rate limit is 24 hours (86400s)"
else
  fail "Test 9: Rate limit is 24 hours"
fi

if grep -q "curl.*--max-time" .claude/hooks/session-start.sh 2>/dev/null; then
  pass "Test 10: Update check has timeout"
else
  fail "Test 10: Update check has timeout"
fi

if grep -q "backup" .claude/scripts/update-super-claude.sh 2>/dev/null; then
  pass "Test 11: Update script creates backups"
else
  fail "Test 11: Update script creates backups"
fi

if grep -q "LATEST_VERSION" .claude/scripts/update-super-claude.sh 2>/dev/null; then
  pass "Test 12: Update script fetches latest version"
else
  fail "Test 12: Update script fetches latest version"
fi

end_test_suite
