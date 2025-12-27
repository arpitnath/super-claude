#!/bin/bash
# Fix hook error issue for existing installations
# Patches settings.local.json to add explicit exit handling to walk-up patterns

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Fixing Hook Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -f ".claude/settings.local.json" ]; then
    echo "No settings.local.json found - nothing to fix"
    exit 0
fi

# Backup first
cp .claude/settings.local.json .claude/settings.local.json.backup
echo "✓ Backup created: .claude/settings.local.json.backup"

# Python script to patch hooks
python3 << 'EOF'
import json

with open('.claude/settings.local.json', 'r') as f:
    settings = json.load(f)

# Fix all hook commands that use walk-up pattern
fixed_count = 0
for hook_type in settings.get('hooks', {}).keys():
    for matcher in settings['hooks'][hook_type]:
        for hook in matcher.get('hooks', []):
            if hook.get('type') == 'command':
                cmd = hook['command']
                # Check if it's a walk-up pattern without exit 0
                if 'while [ "$DIR" != "/" ]' in cmd and 'done\'' in cmd:
                    if not cmd.endswith('exit 0\''):
                        # Add exit 0 before closing quote
                        hook['command'] = cmd.replace('done\'', 'done; exit 0\'')
                        fixed_count += 1

with open('.claude/settings.local.json', 'w') as f:
    json.dump(settings, f, indent=2)

print(f"✓ Fixed {fixed_count} hook commands")
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Hook Configuration Updated"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔄 Restart Claude Code to apply changes"
echo ""
