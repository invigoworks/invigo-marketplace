#!/bin/bash
set -euo pipefail

# SessionStart hook: ai-agent-guide.md 내용을 systemMessage로 주입
GUIDE_PATH="$CLAUDE_PROJECT_DIR/docs/standards/ai-agent-guide.md"

if [[ ! -f "$GUIDE_PATH" ]]; then
  exit 0
fi

CONTENT=$(cat "$GUIDE_PATH")

jq -n --arg msg "$CONTENT" '{ systemMessage: $msg }'
