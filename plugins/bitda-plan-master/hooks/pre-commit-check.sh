#!/bin/bash
# Pre-Commit Validation Hook
# Runs before git commit to ensure code quality

set -e

PROJECT_ROOT="/Users/gimjinhyeog/Desktop/coding/plan-master"
cd "$PROJECT_ROOT"

# Check if this is a git commit operation
if [[ "$CLAUDE_TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Check if the command contains git commit
if ! echo "$CLAUDE_TOOL_INPUT" | grep -q "git commit"; then
    exit 0
fi

echo "Running pre-commit checks..."

# 1. Check for TypeScript errors (if tsconfig exists)
if [ -f "tsconfig.json" ]; then
    echo "Checking TypeScript..."
    if command -v npx &> /dev/null; then
        npx tsc --noEmit 2>/dev/null || {
            echo "TypeScript errors found. Please fix before committing."
            exit 1
        }
    fi
fi

# 2. Check for ESLint errors (if eslint config exists)
if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f "eslint.config.js" ]; then
    echo "Running ESLint..."
    if command -v npx &> /dev/null; then
        npx eslint . --max-warnings=0 2>/dev/null || {
            echo "ESLint errors found. Please fix before committing."
            exit 1
        }
    fi
fi

# 3. Run Prettier check (if prettier config exists)
if [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] || [ -f "prettier.config.js" ]; then
    echo "Checking Prettier formatting..."
    if command -v npx &> /dev/null; then
        npx prettier --check "**/*.{ts,tsx,js,jsx,json,md}" 2>/dev/null || {
            echo "Formatting issues found. Run 'npx prettier --write .' to fix."
            # Warning only, don't block
        }
    fi
fi

echo "Pre-commit checks passed!"
exit 0
