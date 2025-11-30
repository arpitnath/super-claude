#!/bin/bash
# Stats Dashboard with Visual Progress Bars

CAPSULE=".claude/capsule.toon"

# Colors
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}Super Claude Kit - Session Stats${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Count files
FILE_COUNT=$(awk '/^FILES\{/,/^$/ {if ($0 ~ /^ /) count++} END {print count+0}' "$CAPSULE" 2>/dev/null || echo "0")
echo -e "  ${BLUE}📁 Files Tracked:${RESET} ${FILE_COUNT}"

# Count tasks
TASK_COUNT=$(awk '/^TASK\{/,/^$/ {if ($0 ~ /^ /) count++} END {print count+0}' "$CAPSULE" 2>/dev/null || echo "0")
echo -e "  ${YELLOW}✓ Tasks:${RESET} ${TASK_COUNT}"

# Session duration
DURATION=$(awk -F',' '/^META\{/,/^$/ {if ($0 ~ /^ /) {print $2; exit}}' "$CAPSULE" 2>/dev/null || echo "0")
if [ "$DURATION" -lt 60 ]; then
  DUR_STR="${DURATION}s"
elif [ "$DURATION" -lt 3600 ]; then
  DUR_STR="$((DURATION / 60))m"
else
  DUR_STR="$((DURATION / 3600))h $((DURATION % 3600 / 60))m"
fi
echo -e "  ${CYAN}⏱  Session Duration:${RESET} ${DUR_STR}"

echo ""
echo -e "  ${GREEN}Token Savings (Estimated):${RESET}"

# Progress bar (20 chars)
ESTIMATED_SAVINGS=$((FILE_COUNT * 3000))
SAVINGS_K=$((ESTIMATED_SAVINGS / 1000))
PERCENT=$((FILE_COUNT * 10))
if [ "$PERCENT" -gt 100 ]; then PERCENT=100; fi
FILLED=$((PERCENT / 5))
EMPTY=$((20 - FILLED))

BAR=""
for i in $(seq 1 $FILLED); do BAR="${BAR}█"; done
for i in $(seq 1 $EMPTY); do BAR="${BAR}░"; done

echo -e "  ${GREEN}${BAR}${RESET} ~${SAVINGS_K}K tokens"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
