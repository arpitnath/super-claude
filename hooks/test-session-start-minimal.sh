#!/bin/bash
# Minimal SessionStart test - just output simple text

echo "TEST: SessionStart hook output"
echo "This should appear in Claude's context at session start"
echo "Timestamp: $(date)"
exit 0
