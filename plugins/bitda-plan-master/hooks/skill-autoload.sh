#!/bin/bash
# Skill Auto-Load Hook for UserPromptSubmit
# Analyzes user prompts and suggests relevant skills/agents

PROMPT="$CLAUDE_USER_PROMPT"

# Convert to lowercase for matching
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Skill/Agent patterns with priority (skills take precedence over agents for specific tasks)
declare -A PATTERNS

# === Project Skills (High Priority) ===
PATTERNS["skill:plan-developer"]="기획|기능 설계|스펙 작성|요구사항|feature spec|planning document"
PATTERNS["skill:plan-reviewer"]="기획 검토|기획서 리뷰|논리 검증|빠진 거 없|plan review"
PATTERNS["skill:ui-designer"]="ui 코드|화면 만들|shadcn|컴포넌트 생성|/cui|/iui|/rui|블록으로"
PATTERNS["skill:ui-improver"]="ui 개선|ui 분석|디자인 개선|ui-improve"
PATTERNS["skill:github-deployer"]="github.*배포|코드 푸시|pr 만들|배포해줘|깃헙에 올려"
PATTERNS["skill:notion-uploader"]="노션.*등록|notion db|화면 db.*올려|컴포넌트 등록"
PATTERNS["skill:notion-validator"]="노션 검수|업로드 검증|화면 db 검수|notion 검증"
PATTERNS["skill:agent-browser"]="브라우저.*테스트|스크린샷|웹 자동화|폼 채우|e2e test"

# === Agents (Lower Priority - suggest when skills don't match) ===
# Development
PATTERNS["agent:fullstack-developer"]="풀스택|전체 기능|end.to.end|api.*프론트"
PATTERNS["agent:frontend-developer"]="react.*복잡|상태 관리|성능 최적화|프론트 개발"
PATTERNS["agent:backend-architect"]="api 설계|백엔드 아키텍처|마이크로서비스"
PATTERNS["agent:database-architect"]="db 설계|스키마|데이터 모델링|erd"

# DevOps
PATTERNS["agent:devops-engineer"]="인프라|ci/cd|모니터링|terraform|devops"
PATTERNS["agent:deployment-engineer"]="kubernetes|k8s|helm|도커|컨테이너"

# Code Quality
PATTERNS["agent:code-reviewer"]="코드 리뷰|pr 리뷰|보안 검토"
PATTERNS["agent:architect-reviewer"]="아키텍처 리뷰|solid|구조 검토|설계 검토"
PATTERNS["agent:test-engineer"]="테스트 전략|테스트 자동화|커버리지|jest|playwright"

# Debugging
PATTERNS["agent:debugger"]="버그|에러|오류|스택트레이스|테스트 실패"
PATTERNS["agent:error-detective"]="로그 분석|프로덕션 에러|시스템 장애|anomaly"

# Language Specialists
PATTERNS["agent:typescript-pro"]="타입스크립트|제네릭|타입 추론|type.*복잡"
PATTERNS["agent:javascript-pro"]="자바스크립트|async|promise|이벤트 루프"
PATTERNS["agent:python-pro"]="파이썬|decorator|generator|asyncio"

# AI/LLM
PATTERNS["agent:ai-engineer"]="rag|llm.*통합|벡터|에이전트 개발"
PATTERNS["agent:prompt-engineer"]="프롬프트|시스템 프롬프트|prompt"
PATTERNS["agent:mcp-expert"]="mcp 서버|mcp 설정|protocol"

# Other
PATTERNS["agent:api-documenter"]="api 문서|swagger|openapi|sdk"
PATTERNS["agent:search-specialist"]="리서치|검색|조사|분석.*자료"
PATTERNS["agent:mobile-developer"]="react native|flutter|모바일"
PATTERNS["agent:ui-ux-designer"]="ux 리뷰|접근성|디자인 시스템|와이어프레임"

# Check patterns and collect matches
MATCHED_SKILLS=""
MATCHED_AGENTS=""

for key in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$key]}"
    if echo "$PROMPT_LOWER" | grep -qiE "$pattern"; then
        type="${key%%:*}"
        name="${key#*:}"

        if [ "$type" = "skill" ]; then
            if [ -z "$MATCHED_SKILLS" ]; then
                MATCHED_SKILLS="$name"
            else
                MATCHED_SKILLS="$MATCHED_SKILLS, $name"
            fi
        else
            if [ -z "$MATCHED_AGENTS" ]; then
                MATCHED_AGENTS="$name"
            else
                MATCHED_AGENTS="$MATCHED_AGENTS, $name"
            fi
        fi
    fi
done

# Output results (skills take priority)
OUTPUT=""
if [ -n "$MATCHED_SKILLS" ]; then
    OUTPUT="Suggested skills: $MATCHED_SKILLS"
fi
if [ -n "$MATCHED_AGENTS" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="$OUTPUT | Agents: $MATCHED_AGENTS"
    else
        OUTPUT="Suggested agents: $MATCHED_AGENTS"
    fi
fi

if [ -n "$OUTPUT" ]; then
    echo "$OUTPUT"
fi

exit 0
