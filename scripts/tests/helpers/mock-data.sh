#!/bin/bash

MOCK_FILE_LOG='file: "src/main.ts", action: "read", time: 120'
MOCK_DISCOVERY='category: "pattern", content: "Uses JWT auth", time: 300'
MOCK_TASK='status: "in_progress", content: "Implementing auth", time: 180'
MOCK_SUBAGENT='type: "Explore", summary: "Found 10 files", time: 240'

MOCK_PERSISTENCE='{
  "last_session_end": 1700000000,
  "session_duration": 900,
  "message_count": 15,
  "discoveries": [
    {"category": "pattern", "content": "Auth uses JWT", "time": 300},
    {"category": "architecture", "content": "Microservices pattern", "time": 600}
  ],
  "files": [
    {"file": "server/auth.ts", "action": "edit", "time": 200},
    {"file": "api/routes.go", "action": "read", "time": 400}
  ],
  "subagents": [
    {"type": "Explore", "summary": "Found auth module", "time": 500}
  ]
}'

create_mock_logs() {
  mkdir -p .claude

  echo "$MOCK_FILE_LOG" > .claude/session_files.log
  echo "$MOCK_DISCOVERY" > .claude/session_discoveries.log
  echo "$MOCK_TASK" > .claude/session_tasks.log
  echo "$MOCK_SUBAGENT" > .claude/session_subagents.log
}

create_mock_persistence() {
  mkdir -p .claude
  echo "$MOCK_PERSISTENCE" > .claude/capsule_persist.json
}

create_mock_version() {
  mkdir -p .claude
  echo "1.1.0" > .claude/.super-claude-version
  date +%s > .claude/.super-claude-installed
}
