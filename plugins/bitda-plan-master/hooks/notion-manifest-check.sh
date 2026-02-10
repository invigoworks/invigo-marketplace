#!/bin/bash
# Notion 매니페스트 신선도 체크 (PreToolUse Hook)
# Notion MCP 도구 호출 전에 매니페스트가 오래되었으면 자동 동기화
#
# 트리거: mcp__plugin_Notion_notion__* (모든 Notion MCP 도구)
# 동작: 매니페스트 7일+ 경과 → notion-sync.sh 자동 실행 → Claude에 알림

set -euo pipefail

# stdin에서 JSON 입력 읽기
INPUT=$(cat)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/Users/gimjinhyeog/Desktop/coding/plan-master}"
MANIFEST="$PROJECT_DIR/.claude/shared-references/notion-manifest.md"
SYNC_SCRIPT="$PROJECT_DIR/.claude/shared-references/notion-sync.sh"
ENV_FILE="$PROJECT_DIR/.env"

# .env 없으면 동기화 불가 → 조용히 통과
if [[ ! -f "$ENV_FILE" ]]; then
  exit 0
fi

# 매니페스트 없으면 → 동기화 실행
if [[ ! -f "$MANIFEST" ]]; then
  if [[ -x "$SYNC_SCRIPT" ]]; then
    "$SYNC_SCRIPT" >/dev/null 2>&1 || true
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"⚠️ Notion 매니페스트가 없어 자동 생성했습니다. .claude/shared-references/notion-manifest.md를 읽어서 활용하세요."}}'
  fi
  exit 0
fi

# 매니페스트 나이 확인 (macOS stat)
CURRENT_TIME=$(date +%s)
FILE_TIME=$(stat -f %m "$MANIFEST" 2>/dev/null || stat -c %Y "$MANIFEST" 2>/dev/null || echo "$CURRENT_TIME")
AGE=$(( CURRENT_TIME - FILE_TIME ))
SEVEN_DAYS=604800

if [[ $AGE -gt $SEVEN_DAYS ]]; then
  DAYS_OLD=$(( AGE / 86400 ))

  if [[ -x "$SYNC_SCRIPT" ]]; then
    "$SYNC_SCRIPT" >/dev/null 2>&1 || true
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"additionalContext\":\"🔄 Notion 매니페스트가 ${DAYS_OLD}일 경과하여 자동 동기화했습니다. 최신 매니페스트로 작업을 진행합니다.\"}}"
  else
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"additionalContext\":\"⚠️ Notion 매니페스트가 ${DAYS_OLD}일 경과했습니다. .claude/shared-references/notion-sync.sh를 실행하여 갱신하세요.\"}}"
  fi
  exit 0
fi

# 매니페스트가 신선하면 → 조용히 통과
exit 0
