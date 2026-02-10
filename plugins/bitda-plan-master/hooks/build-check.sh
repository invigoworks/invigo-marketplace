#!/bin/bash
# Build Check Hook (Improved)
# Validates TypeScript after editing app/package files
# - Covers apps/ and packages/ directories
# - Shows first 5 errors with details
# - Highlights errors in the edited file

FILE_PATH="$CLAUDE_FILE_PATH"
PROJECT_ROOT="/Users/gimjinhyeog/Desktop/coding/plan-master"

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Only check TypeScript/JavaScript files
case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx)
        ;;
    *)
        exit 0
        ;;
esac

# Determine check directory
if echo "$FILE_PATH" | grep -q "apps/"; then
    APP_NAME=$(echo "$FILE_PATH" | sed -n 's|.*/apps/\([^/]*\)/.*|\1|p')
    CHECK_DIR="$PROJECT_ROOT/apps/$APP_NAME"
elif echo "$FILE_PATH" | grep -q "packages/"; then
    PKG_NAME=$(echo "$FILE_PATH" | sed -n 's|.*/packages/\([^/]*\)/.*|\1|p')
    CHECK_DIR="$PROJECT_ROOT/packages/$PKG_NAME"
else
    exit 0
fi

# Verify directory exists
if [ -z "$CHECK_DIR" ] || [ ! -d "$CHECK_DIR" ]; then
    exit 0
fi

# Check for tsconfig
if [ ! -f "$CHECK_DIR/tsconfig.json" ] || ! command -v npx &> /dev/null; then
    exit 0
fi

cd "$CHECK_DIR"

TEMP_FILE="/tmp/tsc-check-$$.log"
npx tsc --noEmit --pretty false > "$TEMP_FILE" 2>&1 &
TSC_PID=$!

# Wait up to 10 seconds
WAIT_COUNT=0
while kill -0 $TSC_PID 2>/dev/null && [ $WAIT_COUNT -lt 10 ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

# Kill if still running
if kill -0 $TSC_PID 2>/dev/null; then
    kill $TSC_PID 2>/dev/null
    wait $TSC_PID 2>/dev/null
    rm -f "$TEMP_FILE"
    exit 0
fi

wait $TSC_PID 2>/dev/null

# Check results
if [ -s "$TEMP_FILE" ]; then
    TOTAL_ERRORS=$(grep -c "error TS" "$TEMP_FILE" 2>/dev/null || echo "0")
    if [ "$TOTAL_ERRORS" -gt 0 ]; then
        # Check if edited file has errors
        BASENAME=$(basename "$FILE_PATH")
        FILE_ERRORS=$(grep "$BASENAME" "$TEMP_FILE" | grep "error TS" | wc -l | tr -d ' ')

        if [ "$FILE_ERRORS" -gt 0 ]; then
            echo ">> TypeScript: $TOTAL_ERRORS error(s), $FILE_ERRORS in edited file ($BASENAME)"
        else
            echo ">> TypeScript: $TOTAL_ERRORS error(s) detected"
        fi

        # Show first 5 errors with details
        grep "error TS" "$TEMP_FILE" | head -5 | while IFS= read -r line; do
            echo "  $line"
        done

        if [ "$TOTAL_ERRORS" -gt 5 ]; then
            echo "  ... and $((TOTAL_ERRORS - 5)) more errors"
        fi
    fi
fi

rm -f "$TEMP_FILE"
exit 0
