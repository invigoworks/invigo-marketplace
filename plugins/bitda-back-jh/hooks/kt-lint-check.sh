#!/bin/bash
set -euo pipefail

# PostToolUse hook: .kt 파일 Edit/Write 시에만 ktlintCheck 실행
# stdin JSON에서 file_path 추출
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .kt 파일이 아니면 즉시 통과
if [[ ! "$FILE_PATH" =~ \.kt$ ]]; then
  exit 0
fi

# 변경된 파일이 속한 모듈만 ktlintCheck 실행
MODULE_DIR=$(echo "$FILE_PATH" | sed -n 's|.*/\(modules/[^/]*/[^/]*\)/.*|\1|p')
if [[ -z "$MODULE_DIR" ]]; then
  exit 0
fi

# 모듈명 → Gradle 태스크명 변환 (modules/application/api → :modules:application:api)
GRADLE_MODULE=$(echo "$MODULE_DIR" | sed 's|/|:|g')

LINT_OUTPUT=$(cd "$CLAUDE_PROJECT_DIR" && ./gradlew ":${GRADLE_MODULE}:ktlintCheck" 2>&1) || {
  # ktlint 실패 시 Claude에게 피드백
  ERRORS=$(echo "$LINT_OUTPUT" | grep -E "^\S.*\.kt:" | head -10)
  jq -n \
    --arg reason "ktlint 위반 발견: $FILE_PATH" \
    --arg context "$ERRORS" \
    '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: ("ktlint 오류를 수정하세요:\n" + $context)
      }
    }'
  exit 0
}

exit 0
