---
name: api-to-notion-api
description: |
  Swagger 스냅샷(api-docs.json)과 코드베이스를 기반으로 Notion API 맵핑 DB에
  API 문서를 등록하고 상세 페이지를 작성하는 스킬입니다. (notion-api.py REST wrapper 사용 버전)
  이 스킬은 다음 상황에서 사용됩니다:
  - 특정 API를 Notion에 문서화할 때 (MCP 비활성화 환경)
  - mcp__notion__* 도구 deprecated/불안정한 경우
  - 사용자가 "api 노션 등록 (api 모드)", "/api-to-notion-api" 등을 요청할 때
---

# API to Notion (REST API 모드)

`api-to-notion` 스킬의 REST API 호출 버전. `mcp__notion__*` 도구가 deprecated이거나 불안정할 때 사용.

> **언제 사용**: MCP Notion 도구가 막혀있거나 비활성화된 환경. 일반 상황은 `/api-to-notion` 사용.

## 도구 매핑

모든 Notion API 호출은 `notion-api.py` 스크립트로 대체한다. **MCP 도구 호출 금지**.

| 기존 (MCP) | 새 (REST wrapper) |
|-----------|------------------|
| `mcp__notion__API-post-search` | `notion-api.py search` |
| `mcp__notion__API-post-page` | `notion-api.py create-page` |
| `mcp__notion__API-retrieve-a-page` | `notion-api.py retrieve-page --page {id}` |
| `mcp__notion__API-patch-page` | `notion-api.py update-page --page {id}` |
| `mcp__notion__API-get-block-children` | `notion-api.py list-children --block {id}` |
| `mcp__notion__API-patch-block-children` | `notion-api.py append-blocks --block {id}` |
| `mcp__notion__API-delete-a-block` | `notion-api.py delete-block --block {id}` |

### 호출 패턴

모든 요청 body는 **stdin JSON**으로 전달. 응답은 stdout JSON.

```bash
# 스크립트 경로 (api-to-notion 스킬의 scripts 디렉토리 공유)
NOTION_API=.claude/skills/api-to-notion/scripts/notion-api.py

# 1. 검색
printf '{"query":"GET_BOM_TEMPLATES","filter":{"property":"object","value":"page"}}' \
  | python3 $NOTION_API search

# 2. DB 페이지 생성 (parent는 반드시 JSON 객체)
printf '{
  "parent": {"database_id": "2d3471f8-dcff-8017-8f2c-f3db7658c869"},
  "properties": {
    "": {"title": [{"text": {"content": "GET_WAREHOUSES"}}]},
    "Endpoint": {"rich_text": [{"text": {"content": "/api/v1/warehouses"}}]},
    "Method": {"select": {"name": "GET"}},
    "Version": {"rich_text": [{"text": {"content": "1.0"}}]}
  }
}' | python3 $NOTION_API create-page

# 3. 페이지 조회
python3 $NOTION_API retrieve-page --page {PAGE_ID}

# 4. 페이지 속성 업데이트
printf '{"properties":{"Version":{"rich_text":[{"text":{"content":"1.1"}}]}}}' \
  | python3 $NOTION_API update-page --page {PAGE_ID}

# 5. 자식 블록 목록
python3 $NOTION_API list-children --block {PAGE_ID}

# 6. 블록 추가 (children 배열)
printf '{"children":[{...block JSON...}]}' \
  | python3 $NOTION_API append-blocks --block {PAGE_ID}

# 7. 블록 삭제
python3 $NOTION_API delete-block --block {BLOCK_ID}
```

### Token Resolution

1. `NOTION_TOKEN` 환경변수
2. `~/.claude.json`에서 `NOTION_TOKEN` 키 검색

별도 설정 불필요. ~/.claude.json에 이미 토큰 저장됨.

## 워크플로우

### 본 스킬 = `/api-to-notion`의 도구 호출만 교체한 버전

워크플로우, 타협 불가능한 규칙, 블록 패턴, 검증 체크리스트는 **모두 `/api-to-notion` 동일**.

다음 항목들은 `/api-to-notion` SKILL.md 참조:
- 전제 조건
- 타협 불가능한 규칙 7개 (API 명시 필수, 추측 금지, 완전 전개, code annotation 등)
- jq 기반 API 추출 (list-apis.jq, extract-api.jq)
- 페이지 작성 흐름 (개요 → 인증 → 요청 → 응답 → 변경이력)
- Notion 블록 패턴 (heading_2, table, code, divider)
- 검증 체크리스트

이 스킬은 **호출 방식만** 다름.

## 차이점 요약

| 항목 | api-to-notion | api-to-notion-api |
|------|--------------|-------------------|
| Notion 호출 | `mcp__notion__*` 도구 | `notion-api.py` REST wrapper |
| 입력 전달 | 도구 인자 | stdin JSON |
| 의존성 | MCP Notion 서버 활성화 | Python 3 + ~/.claude.json |
| Token 처리 | MCP 내부 처리 | env var 또는 ~/.claude.json |
| 사용 시점 | 일반 | MCP 비활성화/deprecated |

## 주의사항

1. **JSON 이스케이프**: stdin 전달 시 쉘 따옴표 주의. 복잡한 JSON은 임시 파일 사용:
   ```bash
   cat > /tmp/notion-blocks.json <<'EOF'
   {"children": [...]}
   EOF
   python3 $NOTION_API append-blocks --block PAGE_ID < /tmp/notion-blocks.json
   ```
2. **Rate limit**: 연속 호출 사이 300ms 대기 권장.
3. **블록 추가 100개 제한**: append-blocks는 한 번에 최대 100개 블록. 초과 시 분할.
4. **에러 처리**: notion-api.py 실패 시 stderr 출력 확인, exit code > 0.

## 연관 스킬

- `api-to-notion`: 원본 스킬 (MCP 도구 사용). 이 스킬의 부모 — 워크플로우/규칙/블록 패턴 모두 동일.
- `swagger-snapshot` / `swagger-snapshot-remote`: 입력 데이터 수집.

## 사용 트리거 예시

- "api 노션 등록해 (REST 모드)"
- "/api-to-notion-api"
- "MCP 안 되니까 python wrapper로 등록"
- "notion-api.py로 문서화"
