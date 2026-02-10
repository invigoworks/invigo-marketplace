#!/bin/bash
# Error Tracker Hook
# Tracks errors during session and reminds about unfixed issues

ERROR_LOG="/tmp/claude-errors-$$.log"
PROJECT_ROOT="/Users/gimjinhyeog/Desktop/coding/plan-master"

# Check tool output for errors
TOOL_OUTPUT="$CLAUDE_TOOL_OUTPUT"

# Common error patterns
ERROR_PATTERNS=(
    "error:"
    "Error:"
    "ERROR"
    "failed"
    "Failed"
    "FAILED"
    "Cannot find"
    "not found"
    "TypeError"
    "SyntaxError"
    "ReferenceError"
    "Module not found"
    "Build failed"
    "Compilation failed"
)

# Check for errors in output
for pattern in "${ERROR_PATTERNS[@]}"; do
    if echo "$TOOL_OUTPUT" | grep -q "$pattern"; then
        # Log the error
        echo "[$(date '+%H:%M:%S')] $CLAUDE_TOOL_NAME: Found '$pattern' in output" >> "$ERROR_LOG"

        # If multiple errors accumulated, remind
        ERROR_COUNT=$(wc -l < "$ERROR_LOG" 2>/dev/null || echo "0")
        if [ "$ERROR_COUNT" -ge 3 ]; then
            echo "Warning: Multiple errors detected in this session. Consider reviewing error log."
        fi
        break
    fi
done

exit 0
