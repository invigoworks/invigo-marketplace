#!/bin/bash
# Dev Docs Reminder Hook
# Reminds to check dev docs for context continuity

PROJECT_ROOT="/Users/gimjinhyeog/Desktop/coding/plan-master"
DEV_DOCS="$PROJECT_ROOT/docs/dev"

# Check if dev docs exist
if [ ! -d "$DEV_DOCS" ]; then
    exit 0
fi

# Check if plan.md has active work
PLAN_FILE="$DEV_DOCS/plan.md"
if [ -f "$PLAN_FILE" ]; then
    # Check if there's an active feature (not "없음" or empty)
    ACTIVE=$(grep -A1 "^\*\*기능명\*\*:" "$PLAN_FILE" | tail -1 | tr -d ' ')
    if [ -n "$ACTIVE" ] && [ "$ACTIVE" != "(없음)" ]; then
        echo "Active plan detected in docs/dev/plan.md"
    fi
fi

# Check if there are incomplete tasks
TASKS_FILE="$DEV_DOCS/tasks.md"
if [ -f "$TASKS_FILE" ]; then
    IN_PROGRESS=$(grep -c "^\- \[ \]" "$TASKS_FILE" 2>/dev/null || echo "0")
    if [ "$IN_PROGRESS" -gt 0 ]; then
        echo "Pending tasks: $IN_PROGRESS in docs/dev/tasks.md"
    fi
fi

exit 0
