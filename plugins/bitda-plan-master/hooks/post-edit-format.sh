#!/bin/bash
# Post-Edit Formatting Hook
# Auto-formats files after editing

FILE_PATH="$CLAUDE_FILE_PATH"
PROJECT_ROOT="/Users/gimjinhyeog/Desktop/coding/plan-master"

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Only format specific file types
case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss)
        ;;
    *)
        exit 0
        ;;
esac

# Check if prettier is available
if ! command -v npx &> /dev/null; then
    exit 0
fi

# Check if prettier config exists
if [ ! -f "$PROJECT_ROOT/.prettierrc" ] && [ ! -f "$PROJECT_ROOT/.prettierrc.json" ] && [ ! -f "$PROJECT_ROOT/prettier.config.js" ]; then
    exit 0
fi

# Format the file
cd "$PROJECT_ROOT"
npx prettier --write "$FILE_PATH" 2>/dev/null

exit 0
