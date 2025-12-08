# Claude Memory Graph - Implementation Plan

> **Version**: 1.0.0
> **Date**: 2025-12-08
> **Reference**: [ARCHITECTURE.md](./ARCHITECTURE.md)

## Overview

This document outlines the step-by-step implementation plan for the Claude Memory Graph system. The plan is divided into phases, with each phase building on the previous one.

---

## Implementation Phases

```
Phase 1: Foundation         Phase 2: Capture        Phase 3: Query
(Core Infrastructure)       (Write Path)            (Read Path)
     │                           │                       │
     ▼                           ▼                       ▼
┌─────────────┐           ┌─────────────┐         ┌─────────────┐
│ Directory   │           │ PostToolUse │         │ Query Tool  │
│ Structure   │           │ Integration │         │             │
├─────────────┤           ├─────────────┤         ├─────────────┤
│ Node Parser │           │ File Summary│         │ SessionStart│
│             │           │ Generator   │         │ Hook        │
├─────────────┤           ├─────────────┤         ├─────────────┤
│ Graph Cache │           │ Task Node   │         │ UserPrompt  │
│ Builder     │           │ Capture     │         │ Submit Hook │
└─────────────┘           └─────────────┘         └─────────────┘
     │                           │                       │
     └───────────────────────────┴───────────────────────┘
                                 │
                                 ▼
                         Phase 4: Polish
                    (Testing & Optimization)
```

---

## Phase 1: Foundation (Core Infrastructure)

**Goal**: Create the basic directory structure, node parser, and graph cache builder.

**Language**: Python (with Bash wrappers)

**Duration**: ~2-3 hours

### Task 1.1: Directory Structure Setup

**File**: `tools/memory-graph/init.sh`

```bash
#!/bin/bash
# Initialize memory graph directory structure

MEMORY_DIR=".claude/memory"

mkdir -p "$MEMORY_DIR/nodes/files"
mkdir -p "$MEMORY_DIR/nodes/decisions"
mkdir -p "$MEMORY_DIR/nodes/discoveries"
mkdir -p "$MEMORY_DIR/nodes/sessions"
mkdir -p "$MEMORY_DIR/nodes/tasks"
mkdir -p "$MEMORY_DIR/nodes/errors"

# Create default config
cat > "$MEMORY_DIR/config.json" << 'EOF'
{
  "version": "1.0.0",
  "capture": {
    "auto_summarize_threshold_kb": 50,
    "auto_summarize_languages": ["typescript", "javascript", "python", "go"],
    "capture_todos": true,
    "capture_subagent_results": true
  },
  "injection": {
    "session_start_max_tokens": 500,
    "prompt_max_tokens": 1000,
    "max_nodes_per_query": 5
  },
  "retention": {
    "max_nodes": 500,
    "session_archive_days": 7,
    "prune_strategy": "least_connected_oldest"
  }
}
EOF

# Create empty graph cache
cat > "$MEMORY_DIR/graph.json" << 'EOF'
{
  "version": "1.0.0",
  "updated_at": "",
  "node_count": 0,
  "nodes": {},
  "tags": {},
  "types": {},
  "recent": []
}
EOF

# Create initial index
cat > "$MEMORY_DIR/index.md" << 'EOF'
---
updated: ""
---

# Memory Index

## Project Context
(Auto-populated after first session)

## Active Decisions
(None yet)

## Recent Sessions
(None yet)

## Key Files
(None yet)

## Active Tasks
(None yet)
EOF

echo "✓ Memory graph initialized at $MEMORY_DIR"
```

**Acceptance Criteria**:
- [ ] Running `init.sh` creates all required directories
- [ ] Config file has sensible defaults
- [ ] Graph cache starts empty but valid JSON
- [ ] Index file is valid markdown

---

### Task 1.2: Node Parser

**File**: `tools/memory-graph/lib/parser.py`

```python
#!/usr/bin/env python3
"""
Node Parser - Parse markdown nodes with YAML frontmatter
"""

import os
import re
import yaml
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from datetime import datetime

@dataclass
class NodeMetadata:
    id: str
    type: str
    created: str
    updated: str
    path: str  # File path to the node
    tags: List[str] = None
    related: List[str] = None
    status: str = "active"
    supersedes: Optional[str] = None
    file_path: Optional[str] = None  # For file-summary nodes
    session_id: Optional[str] = None

    def __post_init__(self):
        self.tags = self.tags or []
        self.related = self.related or []

@dataclass
class Node:
    metadata: NodeMetadata
    content: str
    links: List[str]  # Extracted [[wiki-links]]

    def to_dict(self) -> Dict:
        return {
            "metadata": asdict(self.metadata),
            "content": self.content,
            "links": self.links
        }


def parse_frontmatter(text: str) -> tuple[Dict, str]:
    """Extract YAML frontmatter and remaining content."""
    pattern = r'^---\s*\n(.*?)\n---\s*\n(.*)$'
    match = re.match(pattern, text, re.DOTALL)

    if not match:
        return {}, text

    try:
        frontmatter = yaml.safe_load(match.group(1)) or {}
        content = match.group(2)
        return frontmatter, content
    except yaml.YAMLError:
        return {}, text


def extract_wiki_links(content: str) -> List[str]:
    """Extract all [[wiki-links]] from content."""
    pattern = r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]'
    matches = re.findall(pattern, content)
    return list(set(matches))  # Dedupe


def extract_tags(content: str) -> List[str]:
    """Extract all #tags from content."""
    pattern = r'(?<!\S)#([a-zA-Z][a-zA-Z0-9_-]*)'
    matches = re.findall(pattern, content)
    return list(set(matches))


def parse_node(file_path: str) -> Optional[Node]:
    """Parse a markdown node file into a Node object."""
    if not os.path.exists(file_path):
        return None

    with open(file_path, 'r', encoding='utf-8') as f:
        text = f.read()

    frontmatter, content = parse_frontmatter(text)

    if not frontmatter.get('id') or not frontmatter.get('type'):
        return None  # Invalid node

    # Extract links from content
    links = extract_wiki_links(content)

    # Add links from frontmatter 'related' field
    related = frontmatter.get('related', [])
    if isinstance(related, list):
        for r in related:
            if isinstance(r, str):
                # Handle [[node-id]] format
                link_match = re.match(r'\[\[([^\]]+)\]\]', r)
                if link_match:
                    links.append(link_match.group(1))
                else:
                    links.append(r)

    links = list(set(links))  # Dedupe

    # Merge tags from frontmatter and content
    fm_tags = frontmatter.get('tags', [])
    content_tags = extract_tags(content)
    all_tags = list(set(fm_tags + content_tags))

    metadata = NodeMetadata(
        id=frontmatter['id'],
        type=frontmatter['type'],
        created=frontmatter.get('created', ''),
        updated=frontmatter.get('updated', ''),
        path=file_path,
        tags=all_tags,
        related=frontmatter.get('related', []),
        status=frontmatter.get('status', 'active'),
        supersedes=frontmatter.get('supersedes'),
        file_path=frontmatter.get('file_path') or frontmatter.get('path'),
        session_id=frontmatter.get('session_id')
    )

    return Node(metadata=metadata, content=content, links=links)


def create_node(
    node_id: str,
    node_type: str,
    content: str,
    tags: List[str] = None,
    related: List[str] = None,
    extra_frontmatter: Dict = None
) -> str:
    """Create a markdown node with frontmatter."""
    now = datetime.utcnow().isoformat() + 'Z'

    frontmatter = {
        'id': node_id,
        'type': node_type,
        'created': now,
        'updated': now,
        'status': 'active',
        'tags': tags or [],
        'related': [f'[[{r}]]' for r in (related or [])]
    }

    if extra_frontmatter:
        frontmatter.update(extra_frontmatter)

    yaml_content = yaml.dump(frontmatter, default_flow_style=False, sort_keys=False)

    return f"---\n{yaml_content}---\n\n{content}"


if __name__ == "__main__":
    # Test parsing
    import sys
    if len(sys.argv) > 1:
        node = parse_node(sys.argv[1])
        if node:
            import json
            print(json.dumps(node.to_dict(), indent=2))
        else:
            print("Failed to parse node")
```

**Acceptance Criteria**:
- [ ] Can parse node with YAML frontmatter
- [ ] Extracts all `[[wiki-links]]`
- [ ] Extracts all `#tags`
- [ ] Handles missing or malformed frontmatter gracefully
- [ ] Can create new nodes with proper format

---

### Task 1.3: Graph Cache Builder

**File**: `tools/memory-graph/lib/graph.py`

```python
#!/usr/bin/env python3
"""
Graph Cache Builder - Build and query the memory graph
"""

import os
import json
from typing import Dict, List, Optional, Set
from datetime import datetime
from pathlib import Path

from parser import parse_node, Node

class MemoryGraph:
    def __init__(self, memory_dir: str = ".claude/memory"):
        self.memory_dir = memory_dir
        self.nodes_dir = os.path.join(memory_dir, "nodes")
        self.cache_path = os.path.join(memory_dir, "graph.json")
        self.cache: Dict = {}
        self.load_cache()

    def load_cache(self) -> None:
        """Load existing cache from disk."""
        if os.path.exists(self.cache_path):
            with open(self.cache_path, 'r') as f:
                self.cache = json.load(f)
        else:
            self.cache = {
                "version": "1.0.0",
                "updated_at": "",
                "node_count": 0,
                "nodes": {},
                "tags": {},
                "types": {},
                "recent": []
            }

    def save_cache(self) -> None:
        """Save cache to disk."""
        self.cache["updated_at"] = datetime.utcnow().isoformat() + 'Z'
        with open(self.cache_path, 'w') as f:
            json.dump(self.cache, f, indent=2)

    def rebuild(self) -> None:
        """Rebuild entire cache by scanning all nodes."""
        nodes = {}
        tags: Dict[str, List[str]] = {}
        types: Dict[str, List[str]] = {}

        # Scan all node files
        for root, dirs, files in os.walk(self.nodes_dir):
            for file in files:
                if not file.endswith('.md'):
                    continue

                file_path = os.path.join(root, file)
                node = parse_node(file_path)

                if not node:
                    continue

                node_id = node.metadata.id
                mtime = os.path.getmtime(file_path)

                # Add to nodes
                nodes[node_id] = {
                    "path": file_path,
                    "type": node.metadata.type,
                    "tags": node.metadata.tags,
                    "links_to": node.links,
                    "linked_from": [],  # Computed below
                    "created": node.metadata.created,
                    "updated": node.metadata.updated,
                    "status": node.metadata.status,
                    "mtime": mtime
                }

                # Add to tags index
                for tag in node.metadata.tags:
                    if tag not in tags:
                        tags[tag] = []
                    tags[tag].append(node_id)

                # Add to types index
                node_type = node.metadata.type
                if node_type not in types:
                    types[node_type] = []
                types[node_type].append(node_id)

        # Compute backlinks (linked_from)
        for node_id, node_data in nodes.items():
            for link_target in node_data["links_to"]:
                if link_target in nodes:
                    nodes[link_target]["linked_from"].append(node_id)

        # Compute recent (sorted by updated time)
        recent = sorted(
            nodes.keys(),
            key=lambda nid: nodes[nid]["updated"],
            reverse=True
        )[:20]

        # Update cache
        self.cache["nodes"] = nodes
        self.cache["tags"] = tags
        self.cache["types"] = types
        self.cache["recent"] = recent
        self.cache["node_count"] = len(nodes)

        self.save_cache()

    def get_node(self, node_id: str) -> Optional[Dict]:
        """Get node metadata from cache."""
        return self.cache["nodes"].get(node_id)

    def get_by_type(self, node_type: str) -> List[str]:
        """Get all node IDs of a specific type."""
        return self.cache["types"].get(node_type, [])

    def get_by_tag(self, tag: str) -> List[str]:
        """Get all node IDs with a specific tag."""
        return self.cache["tags"].get(tag, [])

    def get_recent(self, limit: int = 5) -> List[str]:
        """Get most recently updated node IDs."""
        return self.cache["recent"][:limit]

    def get_related(self, node_id: str, limit: int = 5) -> List[str]:
        """Get related nodes (links + backlinks + tag overlap)."""
        node = self.get_node(node_id)
        if not node:
            return []

        related: Set[str] = set()

        # Add direct links
        related.update(node.get("links_to", []))
        related.update(node.get("linked_from", []))

        # Add nodes with overlapping tags
        node_tags = set(node.get("tags", []))
        for tag in node_tags:
            for related_id in self.get_by_tag(tag):
                if related_id != node_id:
                    related.add(related_id)

        # Remove self
        related.discard(node_id)

        # Sort by connection strength (more shared tags = higher)
        def connection_strength(nid: str) -> int:
            other = self.get_node(nid)
            if not other:
                return 0
            score = 0
            # Direct link = 3 points
            if nid in node.get("links_to", []):
                score += 3
            if nid in node.get("linked_from", []):
                score += 3
            # Shared tags = 1 point each
            other_tags = set(other.get("tags", []))
            score += len(node_tags & other_tags)
            return score

        sorted_related = sorted(related, key=connection_strength, reverse=True)
        return sorted_related[:limit]

    def search(self, query: str, limit: int = 10) -> List[str]:
        """Full-text search in node content."""
        results = []
        query_lower = query.lower()

        for node_id, node_data in self.cache["nodes"].items():
            file_path = node_data.get("path")
            if not file_path or not os.path.exists(file_path):
                continue

            with open(file_path, 'r') as f:
                content = f.read().lower()

            if query_lower in content:
                results.append(node_id)

            if len(results) >= limit:
                break

        return results


if __name__ == "__main__":
    import sys

    graph = MemoryGraph()

    if len(sys.argv) < 2:
        print("Usage: graph.py <command> [args]")
        print("Commands: rebuild, recent, type <type>, tag <tag>, related <id>")
        sys.exit(1)

    command = sys.argv[1]

    if command == "rebuild":
        graph.rebuild()
        print(f"✓ Rebuilt graph with {graph.cache['node_count']} nodes")

    elif command == "recent":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        print(json.dumps(graph.get_recent(limit), indent=2))

    elif command == "type":
        node_type = sys.argv[2] if len(sys.argv) > 2 else "file-summary"
        print(json.dumps(graph.get_by_type(node_type), indent=2))

    elif command == "tag":
        tag = sys.argv[2] if len(sys.argv) > 2 else "auth"
        print(json.dumps(graph.get_by_tag(tag), indent=2))

    elif command == "related":
        node_id = sys.argv[2] if len(sys.argv) > 2 else ""
        limit = int(sys.argv[3]) if len(sys.argv) > 3 else 5
        print(json.dumps(graph.get_related(node_id, limit), indent=2))

    else:
        print(f"Unknown command: {command}")
```

**Acceptance Criteria**:
- [ ] Scans all nodes and builds complete index
- [ ] Computes backlinks correctly
- [ ] Tag and type indexes work
- [ ] Related nodes algorithm returns meaningful results
- [ ] Full-text search works

---

### Task 1.4: Memory Query Tool (Bash Wrapper)

**File**: `tools/memory-graph/memory-query.sh`

```bash
#!/bin/bash
# Memory Query Tool - Query the memory graph

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_DIR="${CLAUDE_MEMORY_DIR:-.claude/memory}"

# Parse arguments
COMMAND=""
FORMAT="summary"
LIMIT=5
QUERY=""
STATUS="active"

while [[ $# -gt 0 ]]; do
    case $1 in
        --id)
            COMMAND="id"
            QUERY="$2"
            shift 2
            ;;
        --type)
            COMMAND="type"
            QUERY="$2"
            shift 2
            ;;
        --tag)
            COMMAND="tag"
            QUERY="$2"
            shift 2
            ;;
        --related)
            COMMAND="related"
            QUERY="$2"
            shift 2
            ;;
        --recent)
            COMMAND="recent"
            shift
            ;;
        --search)
            COMMAND="search"
            QUERY="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Run the Python query engine
python3 "$SCRIPT_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command "$COMMAND" \
    --query "$QUERY" \
    --format "$FORMAT" \
    --limit "$LIMIT" \
    --status "$STATUS"
```

**File**: `tools/memory-graph/lib/query.py`

```python
#!/usr/bin/env python3
"""
Query Engine - Format and filter memory graph queries
"""

import argparse
import json
import os
import sys
from typing import List, Dict

from graph import MemoryGraph
from parser import parse_node


def format_summary(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes as brief summaries for context injection."""
    lines = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if not node_data:
            continue

        file_path = node_data.get("path")
        if not file_path or not os.path.exists(file_path):
            continue

        node = parse_node(file_path)
        if not node:
            continue

        # Extract first line of content as summary
        content_lines = node.content.strip().split('\n')
        title = ""
        summary = ""

        for line in content_lines:
            line = line.strip()
            if line.startswith('#'):
                title = line.lstrip('#').strip()
            elif line and not summary:
                summary = line[:100]

        node_type = node.metadata.type
        display = title or summary or node_id

        lines.append(f"[{node_type}] {display}")

    return '\n'.join(lines)


def format_json(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes as JSON."""
    nodes = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if node_data:
            nodes.append({
                "id": node_id,
                **node_data
            })

    return json.dumps({"nodes": nodes, "count": len(nodes)}, indent=2)


def format_full(node_ids: List[str], graph: MemoryGraph) -> str:
    """Format nodes with full content."""
    parts = []

    for node_id in node_ids:
        node_data = graph.get_node(node_id)
        if not node_data:
            continue

        file_path = node_data.get("path")
        if not file_path or not os.path.exists(file_path):
            continue

        with open(file_path, 'r') as f:
            content = f.read()

        parts.append(f"--- {node_id} ---\n{content}")

    return '\n\n'.join(parts)


def main():
    parser = argparse.ArgumentParser(description="Query memory graph")
    parser.add_argument("--memory-dir", default=".claude/memory")
    parser.add_argument("--command", required=True)
    parser.add_argument("--query", default="")
    parser.add_argument("--format", default="summary", choices=["summary", "json", "full"])
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--status", default="active")

    args = parser.parse_args()

    graph = MemoryGraph(args.memory_dir)

    # Get node IDs based on command
    node_ids: List[str] = []

    if args.command == "recent":
        node_ids = graph.get_recent(args.limit)

    elif args.command == "type":
        node_ids = graph.get_by_type(args.query)[:args.limit]

    elif args.command == "tag":
        node_ids = graph.get_by_tag(args.query)[:args.limit]

    elif args.command == "related":
        node_ids = graph.get_related(args.query, args.limit)

    elif args.command == "search":
        node_ids = graph.search(args.query, args.limit)

    elif args.command == "id":
        if graph.get_node(args.query):
            node_ids = [args.query]

    # Filter by status
    if args.status != "all":
        filtered = []
        for nid in node_ids:
            node_data = graph.get_node(nid)
            if node_data and node_data.get("status") == args.status:
                filtered.append(nid)
        node_ids = filtered

    # Format output
    if args.format == "summary":
        print(format_summary(node_ids, graph))
    elif args.format == "json":
        print(format_json(node_ids, graph))
    elif args.format == "full":
        print(format_full(node_ids, graph))


if __name__ == "__main__":
    main()
```

**Acceptance Criteria**:
- [ ] `memory-query --recent 5` returns recent nodes
- [ ] `memory-query --tag auth` filters by tag
- [ ] `memory-query --related file-auth-ts` finds related nodes
- [ ] Format options (summary, json, full) work correctly
- [ ] Status filtering works

---

## Phase 2: Capture (Write Path)

**Goal**: Automatically capture knowledge during tool usage.

**Language**: Bash hooks + Python helpers

**Duration**: ~2-3 hours

### Task 2.1: File Summary Generator

**File**: `tools/memory-graph/lib/summarize.py`

```python
#!/usr/bin/env python3
"""
File Summary Generator - Create summaries for large files
Uses heuristics (not LLM) for automatic summarization.
"""

import os
import re
import sys
from typing import Dict, List, Optional
from pathlib import Path

def extract_exports_ts(content: str) -> List[str]:
    """Extract exported functions/classes from TypeScript/JavaScript."""
    exports = []

    # export function name
    for match in re.finditer(r'export\s+(?:async\s+)?function\s+(\w+)', content):
        exports.append(f"function {match.group(1)}")

    # export class name
    for match in re.finditer(r'export\s+class\s+(\w+)', content):
        exports.append(f"class {match.group(1)}")

    # export const name
    for match in re.finditer(r'export\s+const\s+(\w+)', content):
        exports.append(f"const {match.group(1)}")

    # export default
    for match in re.finditer(r'export\s+default\s+(?:class|function)?\s*(\w+)?', content):
        name = match.group(1) or "default"
        exports.append(f"default {name}")

    return exports[:10]  # Limit to 10


def extract_imports_ts(content: str) -> List[str]:
    """Extract import sources from TypeScript/JavaScript."""
    imports = []

    for match in re.finditer(r"from\s+['\"]([^'\"]+)['\"]", content):
        imports.append(match.group(1))

    return list(set(imports))[:10]


def extract_functions_py(content: str) -> List[str]:
    """Extract function/class definitions from Python."""
    defs = []

    for match in re.finditer(r'^(?:async\s+)?def\s+(\w+)', content, re.MULTILINE):
        defs.append(f"def {match.group(1)}")

    for match in re.finditer(r'^class\s+(\w+)', content, re.MULTILINE):
        defs.append(f"class {match.group(1)}")

    return defs[:10]


def detect_language(file_path: str) -> str:
    """Detect programming language from file extension."""
    ext = Path(file_path).suffix.lower()
    lang_map = {
        '.ts': 'typescript',
        '.tsx': 'typescript',
        '.js': 'javascript',
        '.jsx': 'javascript',
        '.py': 'python',
        '.go': 'go',
        '.rs': 'rust',
        '.java': 'java',
        '.md': 'markdown',
    }
    return lang_map.get(ext, 'unknown')


def generate_summary(file_path: str, content: str) -> Dict:
    """Generate a summary for a file."""
    language = detect_language(file_path)
    lines = content.split('\n')
    line_count = len(lines)
    size_kb = len(content) / 1024

    summary = {
        "path": file_path,
        "language": language,
        "line_count": line_count,
        "size_kb": round(size_kb, 1),
        "exports": [],
        "imports": [],
        "description": ""
    }

    # Extract based on language
    if language in ['typescript', 'javascript']:
        summary["exports"] = extract_exports_ts(content)
        summary["imports"] = extract_imports_ts(content)
    elif language == 'python':
        summary["exports"] = extract_functions_py(content)

    # Try to extract description from top comments
    desc_lines = []
    for line in lines[:20]:
        line = line.strip()
        if line.startswith('//') or line.startswith('#') or line.startswith('*'):
            clean = re.sub(r'^[/#*\s]+', '', line)
            if clean and not clean.startswith('@'):
                desc_lines.append(clean)
        elif line.startswith('"""') or line.startswith("'''"):
            # Python docstring
            continue

    if desc_lines:
        summary["description"] = ' '.join(desc_lines[:3])[:200]

    return summary


def format_as_markdown(summary: Dict) -> str:
    """Format summary as markdown content for a node."""
    lines = [f"# {summary['path']}", ""]

    if summary["description"]:
        lines.append(f"{summary['description']}")
        lines.append("")

    lines.append("## Overview")
    lines.append(f"- **Language**: {summary['language']}")
    lines.append(f"- **Lines**: {summary['line_count']}")
    lines.append(f"- **Size**: {summary['size_kb']} KB")
    lines.append("")

    if summary["exports"]:
        lines.append("## Exports")
        for exp in summary["exports"]:
            lines.append(f"- `{exp}`")
        lines.append("")

    if summary["imports"]:
        lines.append("## Dependencies")
        for imp in summary["imports"]:
            lines.append(f"- `{imp}`")
        lines.append("")

    return '\n'.join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: summarize.py <file_path>")
        sys.exit(1)

    file_path = sys.argv[1]

    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        sys.exit(1)

    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    summary = generate_summary(file_path, content)

    if "--json" in sys.argv:
        import json
        print(json.dumps(summary, indent=2))
    else:
        print(format_as_markdown(summary))
```

**Acceptance Criteria**:
- [ ] Extracts exports from TypeScript/JavaScript files
- [ ] Extracts function definitions from Python
- [ ] Generates readable markdown summary
- [ ] Handles large files without timeout

---

### Task 2.2: PostToolUse Hook Integration

**File**: `hooks/post-tool-use-memory.sh` (to be added to existing hook)

```bash
#!/bin/bash
# PostToolUse Memory Integration
# Add to hooks/post-tool-use.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_DIR=".claude/memory"
TOOLS_DIR="tools/memory-graph"

# Function to create file summary node
create_file_summary_node() {
    local FILE_PATH="$1"
    local FILE_SIZE="$2"

    # Only for files > 50KB
    if [ "$FILE_SIZE" -lt 51200 ]; then
        return
    fi

    # Generate node ID from path
    local NODE_ID="file-$(echo "$FILE_PATH" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')"
    local NODE_DIR="$MEMORY_DIR/nodes/files"
    local NODE_PATH="$NODE_DIR/$NODE_ID.md"

    mkdir -p "$NODE_DIR"

    # Check if node exists and is fresh
    if [ -f "$NODE_PATH" ]; then
        local NODE_MTIME=$(stat -f %m "$NODE_PATH" 2>/dev/null || stat -c %Y "$NODE_PATH" 2>/dev/null)
        local FILE_MTIME=$(stat -f %m "$FILE_PATH" 2>/dev/null || stat -c %Y "$FILE_PATH" 2>/dev/null)

        if [ "$NODE_MTIME" -ge "$FILE_MTIME" ]; then
            return  # Node is fresh
        fi
    fi

    # Generate summary
    local SUMMARY=$(python3 "$TOOLS_DIR/lib/summarize.py" "$FILE_PATH")

    if [ -z "$SUMMARY" ]; then
        return
    fi

    # Create node with frontmatter
    local NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$NODE_PATH" << EOF
---
id: $NODE_ID
type: file-summary
path: $FILE_PATH
created: $NOW
updated: $NOW
status: active
tags: []
related: []
---

$SUMMARY
EOF

    # Rebuild graph cache
    python3 "$TOOLS_DIR/lib/graph.py" rebuild >/dev/null 2>&1 &
}

# Function to update task nodes from TodoWrite
update_task_nodes() {
    local TODOS_JSON="$1"
    local NODE_DIR="$MEMORY_DIR/nodes/tasks"
    local NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    mkdir -p "$NODE_DIR"

    # Parse todos and create/update nodes
    echo "$TODOS_JSON" | python3 -c "
import sys
import json
import os
import re

data = json.load(sys.stdin)
todos = data.get('todos', [])

for todo in todos:
    content = todo.get('content', '')
    status = todo.get('status', 'pending')

    if not content:
        continue

    # Generate node ID
    node_id = 'task-' + re.sub(r'[^a-zA-Z0-9]+', '-', content.lower())[:50]
    node_path = f'$NODE_DIR/{node_id}.md'

    # Create simple task node
    node_content = f'''---
id: {node_id}
type: task
created: $NOW
updated: $NOW
status: {status}
tags: [task]
related: []
---

# {content}

Status: {status}
'''

    with open(node_path, 'w') as f:
        f.write(node_content)
"

    # Rebuild graph cache
    python3 "$TOOLS_DIR/lib/graph.py" rebuild >/dev/null 2>&1 &
}
```

**Integration**: Add to existing `hooks/post-tool-use.sh`:

```bash
# At end of post-tool-use.sh, add:

# Source memory integration if available
if [ -f "./hooks/post-tool-use-memory.sh" ]; then
    source "./hooks/post-tool-use-memory.sh"

    case "$TOOL_NAME" in
        "Read")
            FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null)
            if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
                FILE_SIZE=$(wc -c < "$FILE_PATH")
                create_file_summary_node "$FILE_PATH" "$FILE_SIZE" &
            fi
            ;;

        "TodoWrite")
            update_task_nodes "$TOOL_INPUT" &
            ;;
    esac
fi
```

**Acceptance Criteria**:
- [ ] Large files (>50KB) get summary nodes created
- [ ] TodoWrite updates create task nodes
- [ ] Graph cache is rebuilt after changes
- [ ] Operations are non-blocking (run in background)

---

### Task 2.3: Discovery and Decision Capture

**File**: `tools/memory-graph/create-node.sh`

```bash
#!/bin/bash
# Create a memory node manually

set -euo pipefail

usage() {
    echo "Usage: create-node.sh <type> <title> [--tags tag1,tag2] [--related id1,id2]"
    echo ""
    echo "Types: decision, discovery, error"
    echo ""
    echo "Example:"
    echo "  create-node.sh decision 'Use JWT Auth' --tags auth,security"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

TYPE="$1"
TITLE="$2"
shift 2

TAGS=""
RELATED=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --related)
            RELATED="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

MEMORY_DIR=".claude/memory"
NODE_DIR="$MEMORY_DIR/nodes/${TYPE}s"
NODE_ID="${TYPE}-$(echo "$TITLE" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | head -c 50)"
NODE_PATH="$NODE_DIR/$NODE_ID.md"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$NODE_DIR"

# Format tags as YAML array
TAGS_YAML="[]"
if [ -n "$TAGS" ]; then
    TAGS_YAML="[$(echo "$TAGS" | sed 's/,/, /g')]"
fi

# Format related as YAML array
RELATED_YAML="[]"
if [ -n "$RELATED" ]; then
    RELATED_YAML="[$(echo "$RELATED" | sed 's/,/]], [[/g' | sed 's/^/[[/' | sed 's/$/]]/')]"
fi

cat > "$NODE_PATH" << EOF
---
id: $NODE_ID
type: $TYPE
created: $NOW
updated: $NOW
status: active
tags: $TAGS_YAML
related: $RELATED_YAML
---

# $TITLE

## Context
(Add context here)

## Details
(Add details here)

EOF

echo "✓ Created node: $NODE_PATH"
echo ""
echo "Edit the node to add content, then run:"
echo "  python3 tools/memory-graph/lib/graph.py rebuild"
```

**Acceptance Criteria**:
- [ ] Can create decision nodes
- [ ] Can create discovery nodes
- [ ] Tags and related links are properly formatted
- [ ] Node file is created in correct directory

---

## Phase 3: Query (Read Path)

**Goal**: Inject relevant context at session start and before each prompt.

**Language**: Bash hooks

**Duration**: ~2 hours

### Task 3.1: SessionStart Context Injection

**File**: `hooks/session-start-memory.sh`

```bash
#!/bin/bash
# SessionStart Memory Injection
# Injects memory context at session start

set -euo pipefail

MEMORY_DIR=".claude/memory"
TOOLS_DIR="tools/memory-graph"

# Check if memory graph exists
if [ ! -d "$MEMORY_DIR/nodes" ]; then
    exit 0
fi

# Get recent context
echo "# Memory Context"
echo ""

# Recent session summary
RECENT_SESSION=$(python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query session \
    --format summary \
    --limit 1 \
    --status all 2>/dev/null || echo "")

if [ -n "$RECENT_SESSION" ]; then
    echo "## Last Session"
    echo "$RECENT_SESSION"
    echo ""
fi

# Active decisions
DECISIONS=$(python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query decision \
    --format summary \
    --limit 3 \
    --status active 2>/dev/null || echo "")

if [ -n "$DECISIONS" ]; then
    echo "## Active Decisions"
    echo "$DECISIONS"
    echo ""
fi

# In-progress tasks
TASKS=$(python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query task \
    --format summary \
    --limit 5 \
    --status in_progress 2>/dev/null || echo "")

if [ -n "$TASKS" ]; then
    echo "## Active Tasks"
    echo "$TASKS"
    echo ""
fi

# Recent file knowledge
FILES=$(python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command recent \
    --format summary \
    --limit 5 \
    --status active 2>/dev/null || echo "")

if [ -n "$FILES" ]; then
    echo "## Recent Context"
    echo "$FILES"
    echo ""
fi

exit 0
```

**Integration**: Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": ".*",
        "command": "bash ./hooks/session-start-memory.sh"
      }
    ]
  }
}
```

**Acceptance Criteria**:
- [ ] Context is injected at session start
- [ ] Shows recent session summary
- [ ] Shows active decisions
- [ ] Shows in-progress tasks
- [ ] Output is concise (<500 tokens)

---

### Task 3.2: UserPromptSubmit Context Injection

**File**: `hooks/prompt-submit-memory.sh`

```bash
#!/bin/bash
# UserPromptSubmit Memory Injection
# Injects relevant context based on user's prompt

set -euo pipefail

MEMORY_DIR=".claude/memory"
TOOLS_DIR="tools/memory-graph"

# Read prompt from stdin
INPUT_JSON=$(cat)
PROMPT=$(echo "$INPUT_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('prompt', ''))" 2>/dev/null || echo "")

if [ -z "$PROMPT" ]; then
    exit 0
fi

# Check if memory graph exists
if [ ! -d "$MEMORY_DIR/nodes" ]; then
    exit 0
fi

# Extract potential file paths from prompt
FILE_MATCHES=$(echo "$PROMPT" | grep -oE '[a-zA-Z0-9_/-]+\.(ts|js|py|go|rs|java|md)' | head -3 || echo "")

# Extract keywords (simple approach)
KEYWORDS=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | grep -oE '\b[a-z]{4,}\b' | sort -u | head -5 || echo "")

CONTEXT=""

# Search for file-related knowledge
for FILE in $FILE_MATCHES; do
    NODE_ID="file-$(echo "$FILE" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')"
    RESULT=$(python3 "$TOOLS_DIR/lib/query.py" \
        --memory-dir "$MEMORY_DIR" \
        --command related \
        --query "$NODE_ID" \
        --format summary \
        --limit 2 \
        --status active 2>/dev/null || echo "")

    if [ -n "$RESULT" ]; then
        CONTEXT="$CONTEXT$RESULT\n"
    fi
done

# Search for keyword matches
for KEYWORD in $KEYWORDS; do
    RESULT=$(python3 "$TOOLS_DIR/lib/query.py" \
        --memory-dir "$MEMORY_DIR" \
        --command tag \
        --query "$KEYWORD" \
        --format summary \
        --limit 2 \
        --status active 2>/dev/null || echo "")

    if [ -n "$RESULT" ]; then
        CONTEXT="$CONTEXT$RESULT\n"
    fi
done

# Dedupe and output
if [ -n "$CONTEXT" ]; then
    echo "# Relevant Memory"
    echo ""
    echo -e "$CONTEXT" | sort -u | head -10
    echo ""
fi

exit 0
```

**Integration**: Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "command": "bash ./hooks/prompt-submit-memory.sh"
      }
    ]
  }
}
```

**Acceptance Criteria**:
- [ ] Detects file paths in prompt
- [ ] Extracts keywords from prompt
- [ ] Queries memory for relevant nodes
- [ ] Output is focused (<1000 tokens)
- [ ] Non-blocking (fast execution)

---

### Task 3.3: SessionEnd Persistence

**File**: `hooks/session-end-memory.sh`

```bash
#!/bin/bash
# SessionEnd Memory Persistence
# Creates session summary and updates index

set -euo pipefail

MEMORY_DIR=".claude/memory"
TOOLS_DIR="tools/memory-graph"

# Read session info from stdin
INPUT_JSON=$(cat)

# Get session ID from environment or generate
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +"%Y-%m-%d")

NODE_DIR="$MEMORY_DIR/nodes/sessions"
NODE_ID="session-$TODAY-$SESSION_ID"
NODE_PATH="$NODE_DIR/$NODE_ID.md"

mkdir -p "$NODE_DIR"

# Get completed tasks
COMPLETED_TASKS=$(python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query task \
    --format summary \
    --status completed \
    --limit 10 2>/dev/null || echo "")

# Get active tasks
ACTIVE_TASKS=$(python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query task \
    --format summary \
    --status in_progress \
    --limit 5 2>/dev/null || echo "")

# Get recent files
RECENT_FILES=$(python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command type \
    --query file-summary \
    --format summary \
    --limit 5 2>/dev/null || echo "")

# Create session summary node
cat > "$NODE_PATH" << EOF
---
id: $NODE_ID
type: session
created: $NOW
updated: $NOW
status: archived
tags: [session]
related: []
session_id: $SESSION_ID
---

# Session: $TODAY

## Summary
(Session summary - auto-generated)

## Tasks Completed
$COMPLETED_TASKS

## Tasks In Progress
$ACTIVE_TASKS

## Files Accessed
$RECENT_FILES
EOF

# Update index.md
INDEX_PATH="$MEMORY_DIR/index.md"

cat > "$INDEX_PATH" << EOF
---
updated: $NOW
---

# Memory Index

## Last Session
[[$NODE_ID]]

## Active Tasks
$ACTIVE_TASKS

## Recent Files
$RECENT_FILES
EOF

# Rebuild graph
python3 "$TOOLS_DIR/lib/graph.py" rebuild >/dev/null 2>&1 &

echo "✓ Session persisted: $NODE_ID"

exit 0
```

**Acceptance Criteria**:
- [ ] Creates session summary node
- [ ] Updates index.md
- [ ] Includes completed and active tasks
- [ ] Includes recently accessed files
- [ ] Runs without blocking session end

---

## Phase 4: Polish (Testing & Optimization)

**Goal**: Test the complete system, optimize performance, add documentation.

**Duration**: ~2 hours

### Task 4.1: Integration Test

**File**: `tools/memory-graph/test/integration-test.sh`

```bash
#!/bin/bash
# Integration test for memory graph

set -e

echo "=== Memory Graph Integration Test ==="
echo ""

MEMORY_DIR=".claude/memory"
TOOLS_DIR="tools/memory-graph"

# 1. Initialize
echo "1. Initializing memory graph..."
bash "$TOOLS_DIR/init.sh"
[ -d "$MEMORY_DIR/nodes" ] && echo "✓ Directories created"
[ -f "$MEMORY_DIR/graph.json" ] && echo "✓ Graph cache created"
[ -f "$MEMORY_DIR/index.md" ] && echo "✓ Index created"

# 2. Create test nodes
echo ""
echo "2. Creating test nodes..."

# Create a file-summary node
mkdir -p "$MEMORY_DIR/nodes/files"
cat > "$MEMORY_DIR/nodes/files/file-test-ts.md" << 'EOF'
---
id: file-test-ts
type: file-summary
path: /src/test.ts
created: 2025-12-08T10:00:00Z
updated: 2025-12-08T10:00:00Z
status: active
tags: [test, typescript]
related: [[decision-test]]
---

# /src/test.ts

Test file for memory graph.
EOF
echo "✓ Created file-summary node"

# Create a decision node
mkdir -p "$MEMORY_DIR/nodes/decisions"
cat > "$MEMORY_DIR/nodes/decisions/decision-test.md" << 'EOF'
---
id: decision-test
type: decision
created: 2025-12-08T11:00:00Z
updated: 2025-12-08T11:00:00Z
status: active
tags: [test, architecture]
related: [[file-test-ts]]
---

# Decision: Test Decision

This is a test decision.
EOF
echo "✓ Created decision node"

# 3. Rebuild graph
echo ""
echo "3. Rebuilding graph..."
python3 "$TOOLS_DIR/lib/graph.py" rebuild
echo "✓ Graph rebuilt"

# 4. Test queries
echo ""
echo "4. Testing queries..."

echo ""
echo "Recent nodes:"
python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command recent \
    --format summary \
    --limit 5 \
    --status all

echo ""
echo "Nodes by tag 'test':"
python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command tag \
    --query test \
    --format summary \
    --limit 5 \
    --status all

echo ""
echo "Related to file-test-ts:"
python3 "$TOOLS_DIR/lib/query.py" \
    --memory-dir "$MEMORY_DIR" \
    --command related \
    --query file-test-ts \
    --format summary \
    --limit 5 \
    --status all

# 5. Verify graph cache
echo ""
echo "5. Verifying graph cache..."
NODE_COUNT=$(python3 -c "import json; print(json.load(open('$MEMORY_DIR/graph.json'))['node_count'])")
echo "Node count: $NODE_COUNT"
[ "$NODE_COUNT" -eq 2 ] && echo "✓ Node count correct"

# Check backlinks
HAS_BACKLINK=$(python3 -c "
import json
g = json.load(open('$MEMORY_DIR/graph.json'))
print('yes' if 'file-test-ts' in g['nodes']['decision-test']['linked_from'] else 'no')
")
[ "$HAS_BACKLINK" = "yes" ] && echo "✓ Backlinks computed correctly"

# 6. Cleanup (optional)
# rm -rf "$MEMORY_DIR"

echo ""
echo "=== All Tests Passed ==="
```

**Acceptance Criteria**:
- [ ] All test steps pass
- [ ] Nodes are created correctly
- [ ] Graph cache is accurate
- [ ] Queries return expected results
- [ ] Backlinks are computed

---

### Task 4.2: Performance Optimization

**Optimizations to implement**:

1. **Incremental graph rebuild**: Only update changed nodes
2. **Query caching**: Cache recent query results
3. **Lazy loading**: Only parse node content when needed
4. **Background processing**: All writes run async

**File**: `tools/memory-graph/lib/graph.py` (add incremental update)

```python
def update_node(self, node_id: str, file_path: str) -> None:
    """Update a single node in the cache without full rebuild."""
    node = parse_node(file_path)
    if not node:
        return

    mtime = os.path.getmtime(file_path)

    # Update node entry
    self.cache["nodes"][node_id] = {
        "path": file_path,
        "type": node.metadata.type,
        "tags": node.metadata.tags,
        "links_to": node.links,
        "linked_from": [],  # Recomputed below
        "created": node.metadata.created,
        "updated": node.metadata.updated,
        "status": node.metadata.status,
        "mtime": mtime
    }

    # Update tag index
    for tag in node.metadata.tags:
        if tag not in self.cache["tags"]:
            self.cache["tags"][tag] = []
        if node_id not in self.cache["tags"][tag]:
            self.cache["tags"][tag].append(node_id)

    # Update type index
    node_type = node.metadata.type
    if node_type not in self.cache["types"]:
        self.cache["types"][node_type] = []
    if node_id not in self.cache["types"][node_type]:
        self.cache["types"][node_type].append(node_id)

    # Recompute all backlinks (necessary for consistency)
    for nid in self.cache["nodes"]:
        self.cache["nodes"][nid]["linked_from"] = []

    for nid, ndata in self.cache["nodes"].items():
        for link_target in ndata["links_to"]:
            if link_target in self.cache["nodes"]:
                self.cache["nodes"][link_target]["linked_from"].append(nid)

    # Update recent
    if node_id not in self.cache["recent"]:
        self.cache["recent"].insert(0, node_id)
        self.cache["recent"] = self.cache["recent"][:20]

    self.cache["node_count"] = len(self.cache["nodes"])
    self.save_cache()
```

---

### Task 4.3: Documentation

**Files to create**:

1. `tools/memory-graph/README.md` - Usage guide
2. `docs/memory-graph/USER_GUIDE.md` - User-facing docs

---

## Summary: Implementation Checklist

### Phase 1: Foundation
- [ ] Task 1.1: Directory structure setup
- [ ] Task 1.2: Node parser (Python)
- [ ] Task 1.3: Graph cache builder (Python)
- [ ] Task 1.4: Memory query tool (Bash wrapper)

### Phase 2: Capture
- [ ] Task 2.1: File summary generator
- [ ] Task 2.2: PostToolUse hook integration
- [ ] Task 2.3: Discovery and decision capture

### Phase 3: Query
- [ ] Task 3.1: SessionStart context injection
- [ ] Task 3.2: UserPromptSubmit context injection
- [ ] Task 3.3: SessionEnd persistence

### Phase 4: Polish
- [ ] Task 4.1: Integration test
- [ ] Task 4.2: Performance optimization
- [ ] Task 4.3: Documentation

---

## Dependencies

| Dependency | Required | Notes |
|------------|----------|-------|
| Python 3.x | Yes | For parsing and graph operations |
| PyYAML | Yes | `pip install pyyaml` |
| Bash 4+ | Yes | For hook scripts |

---

## File Summary

| File | Purpose | Language |
|------|---------|----------|
| `tools/memory-graph/init.sh` | Initialize memory directory | Bash |
| `tools/memory-graph/memory-query.sh` | Query CLI wrapper | Bash |
| `tools/memory-graph/create-node.sh` | Manual node creation | Bash |
| `tools/memory-graph/lib/parser.py` | Parse markdown nodes | Python |
| `tools/memory-graph/lib/graph.py` | Build/query graph cache | Python |
| `tools/memory-graph/lib/query.py` | Query engine | Python |
| `tools/memory-graph/lib/summarize.py` | File summarization | Python |
| `hooks/session-start-memory.sh` | Session start injection | Bash |
| `hooks/prompt-submit-memory.sh` | Prompt context injection | Bash |
| `hooks/session-end-memory.sh` | Session end persistence | Bash |
| `hooks/post-tool-use-memory.sh` | Auto-capture from tools | Bash |

---

## Next Steps

1. **Review this plan** with stakeholder
2. **Start Phase 1** - Create directory structure and parser
3. **Test incrementally** - Verify each task before moving on
4. **Iterate** - Adjust based on real-world usage
