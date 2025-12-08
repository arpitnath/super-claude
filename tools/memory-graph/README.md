# Memory Graph

A persistent knowledge system for Claude Code that transforms it from a stateless assistant into a cumulative learning agent. Using an Obsidian-inspired architecture of linked markdown files, it enables Claude to remember file summaries, architectural decisions, discoveries, and session context across conversations.

## Features

- **Persistent Context**: Remember files accessed, tasks worked on, and discoveries made
- **Cross-Session Memory**: Context persists across sessions
- **Auto-Capture**: Automatically creates nodes when Claude uses Read/Edit/Write/TodoWrite tools
- **Linked Knowledge**: Wiki-style links between related nodes
- **Fast Queries**: Graph cache for efficient lookups

## Quick Start

### 1. Initialize Memory Graph

```bash
bash tools/memory-graph/init.sh .claude/memory
```

This creates:
- `.claude/memory/nodes/` - Directory for knowledge nodes
- `.claude/memory/graph.json` - Graph cache for fast queries
- `.claude/memory/index.md` - Entry point with recent context
- `.claude/memory/config.json` - Configuration

### 2. Hook Integration

The memory graph integrates with Claude Code hooks:

**PostToolUse** (automatic capture):
- File reads/edits/writes create file-summary nodes
- TodoWrite creates task nodes

**SessionStart** (context injection):
```bash
# Add to session-start hook
source hooks/session-start-memory.sh
```

**UserPromptSubmit** (relevant context):
```bash
# Add to prompt-submit hook
source hooks/prompt-submit-memory.sh
```

**SessionEnd** (persistence):
```bash
# Add to session-end hook
source hooks/session-end-memory.sh
```

## Usage

### Query the Graph

```bash
# Get recent nodes
bash tools/memory-graph/memory-query.sh --recent 5

# Filter by type
bash tools/memory-graph/memory-query.sh --type decision

# Filter by tag
bash tools/memory-graph/memory-query.sh --tag auth

# Get related nodes
bash tools/memory-graph/memory-query.sh --related file-src-auth-ts

# Full-text search
bash tools/memory-graph/memory-query.sh --search "authentication"

# Output formats: summary (default), json, full
bash tools/memory-graph/memory-query.sh --recent 5 --format json
```

### Create Nodes Manually

```bash
# Create a decision node
bash tools/memory-graph/create-node.sh decision "Use JWT Auth" --tags auth,security

# Create a discovery node
bash tools/memory-graph/create-node.sh discovery "Repository Pattern" --tags pattern,data-access

# Create an error node
bash tools/memory-graph/create-node.sh error "Circular Import" --related file-src-auth-ts
```

### Rebuild Graph Cache

```bash
CLAUDE_MEMORY_DIR=".claude/memory" python3 tools/memory-graph/lib/graph.py rebuild
```

## Node Types

| Type | Purpose | Auto-Created |
|------|---------|--------------|
| `file-summary` | File overviews and key exports | Yes (on Read/Edit/Write) |
| `task` | Task tracking from TodoWrite | Yes (on TodoWrite) |
| `decision` | Architectural decisions | No (manual) |
| `discovery` | Learned patterns/insights | No (manual) |
| `session` | Session summaries | Yes (on SessionEnd) |
| `error` | Error resolutions | No (manual) |

## Node Format

All nodes use YAML frontmatter + Markdown:

```markdown
---
id: file-src-auth-ts
type: file-summary
created: 2025-12-08T10:00:00Z
updated: 2025-12-08T14:00:00Z
status: active
tags: [auth, typescript]
related: [[decision-jwt-auth]]
file_path: /src/auth.ts
---

# /src/auth.ts

File accessed via read operation.

## Purpose
JWT authentication module...

## Key Elements
- `login()` - User login
- `verifyToken()` - Token verification
```

## Wiki Links

Use `[[node-id]]` syntax to link nodes:

```markdown
See [[file-src-auth-ts]] for implementation.
Related to [[decision-jwt-auth]].
```

Links are bidirectional - the graph computes backlinks automatically.

## Directory Structure

```
.claude/memory/
├── nodes/
│   ├── files/       # File summaries
│   ├── tasks/       # Task nodes
│   ├── decisions/   # Decision records
│   ├── discoveries/ # Pattern insights
│   ├── sessions/    # Session summaries
│   └── errors/      # Error resolutions
├── graph.json       # Computed link cache
├── index.md         # Entry point
└── config.json      # Configuration
```

## Configuration

`.claude/memory/config.json`:

```json
{
  "version": "1.0.0",
  "capture": {
    "auto_summarize_threshold_kb": 50,
    "capture_todos": true
  },
  "injection": {
    "session_start_max_tokens": 500,
    "prompt_max_tokens": 1000,
    "max_nodes_per_query": 5
  },
  "retention": {
    "max_nodes": 500,
    "prune_strategy": "least_connected_oldest"
  }
}
```

## API Reference

### Python Modules

**parser.py** - Parse markdown nodes
```python
from parser import parse_node, create_node
node = parse_node("/path/to/node.md")
```

**graph.py** - Graph operations
```python
from graph import MemoryGraph
graph = MemoryGraph(".claude/memory")
graph.rebuild()
recent = graph.get_recent(5)
related = graph.get_related("node-id")
```

**capture.py** - Auto-capture functions
```python
from capture import capture_file_access, capture_task
result = capture_file_access(".claude/memory", "/path/to/file.ts", "read")
```

**query.py** - Query formatting
```bash
python3 query.py --command recent --format summary --limit 5
```

**summarize.py** - File summarization
```bash
python3 summarize.py /path/to/file.ts --json
```

## Testing

```bash
# Run full test suite
bash tools/memory-graph/test-memory-graph.sh
```

## Requirements

- Python 3.8+
- PyYAML (`pip install pyyaml`)
- Bash 4+

## License

MIT
