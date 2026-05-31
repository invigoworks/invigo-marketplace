---
name: spec-review
description: |
  노션 기획문서와 실제 구현 코드를 비교 검토하여 누락/상이/권한 이슈를 찾아내고
  일관된 양식의 마크다운 보고서를 생성하는 스킬입니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 사용자가 노션 기획문서 링크를 제공하고 구현 검토를 요청할 때
  - "/spec-review", "/spec-review <노션URL>" 형태로 호출할 때
  - "기획문서 검토", "스펙 리뷰", "구현 검토" 등을 요청할 때
---

# Spec Review

노션 기획문서와 코드베이스 구현을 비교 검토하여 Gap Analysis 보고서를 생성한다.

## 워크플로우

### Step 1: 노션 URL 확보

사용자가 URL을 제공하지 않은 경우, 노션 기획문서 링크를 요청한다.

```
검토할 노션 기획문서 링크를 알려주세요.
```

### Step 2: 노션 문서 읽기

Notion MCP를 사용하여 기획문서 전체 내용을 수집한다.

**2.1 page_id 추출:**
- URL 형식: `https://www.notion.so/{workspace}/{title}-{page_id}`
- page_id는 마지막 `-` 이후 32자 (하이픈 제외)
- UUID 형식으로 변환: `2ff471f8dcff81ca94d3fc48c83840b7` → `2ff471f8-dcff-81ca-94d3-fc48c83840b7`

**2.2 페이지 메타데이터 조회:**
```
mcp__notion__API-retrieve-a-page(page_id)
```

**2.3 본문 블록 수집:**
```
mcp__notion__API-get-block-children(block_id=page_id)
```

**2.4 대용량 문서 처리:**
문서가 클 경우 (토큰 초과 시) 결과가 파일로 저장됨. jq로 파싱:

```bash
# JSON 추출 후 임시 파일 저장
cat {saved_file} | jq -r '.[0].text' > /tmp/notion_blocks.json

# 헤딩 추출 (문서 구조 파악)
jq -r '.results[] | select(.type | startswith("heading")) |
  "\(.type): \(.heading_1.rich_text[0].plain_text // .heading_2.rich_text[0].plain_text // .heading_3.rich_text[0].plain_text)"' /tmp/notion_blocks.json

# 코드 블록 추출 (API 스펙, 타입 정의)
jq -r '.results[] | select(.type == "code") | .code.rich_text[0].plain_text' /tmp/notion_blocks.json
```

**2.5 테이블 블록 처리:**
권한, 필드 명세 등 중요 정보가 테이블에 포함됨. 테이블 블록 ID 추출 후 children 별도 조회:

```bash
# 테이블 블록 ID 목록
jq -r '.results[] | select(.type == "table") | .id' /tmp/notion_blocks.json

# 각 테이블의 행(row) 조회
mcp__notion__API-get-block-children(block_id={table_id})
```

### Step 3: 기획문서 분석

문서에서 다음 항목을 추출한다:

| 항목 | 찾을 패턴 | 주요 위치 |
|------|----------|----------|
| **API 엔드포인트** | `GET/POST/PUT/PATCH/DELETE`, URL 패턴 | code 블록 |
| **화면 필드** | 테이블 형태의 필드 목록 | table 블록 |
| **비즈니스 로직** | "~해야 한다", 검증 규칙, AC(인수조건) | quote/paragraph 블록 |
| **권한 요구사항** | "권한", "Role", 역할별 권한 테이블 | table 블록 |
| **에러 케이스** | "오류", "예외", "실패 시" | quote 블록 |

### Step 4: 코드베이스 탐색

기획문서에서 추출한 항목을 기반으로 코드베이스를 탐색한다.

**4.1 API 엔드포인트 검색:**
```bash
# 도메인 키워드로 Controller 찾기
Grep(pattern="company|Company", path="modules/application/api", glob="*Controller.kt")

# 특정 Controller 읽기
Read(file_path="...Controller.kt")
```

**4.2 권한 검색:**
```bash
# @PreAuthorize 어노테이션 확인
Grep(pattern="@PreAuthorize", path="modules/application/api/src/main/kotlin/.../controller")

# 권한 표현식 확인
Grep(pattern="hasAuthority|hasRole", path="modules")
```

**4.3 DTO/Request/Response 검색:**
```bash
# 요청/응답 DTO 확인
Glob(pattern="**/*Request.kt", path="modules/application/api")
Glob(pattern="**/*Response.kt", path="modules/application/api")
```

**4.4 도메인 모델 검색:**
```bash
# 도메인 엔티티 및 VO 확인
Grep(pattern="require|check", path="modules/domain")
```

### Step 5: Gap Analysis 수행

`references/checklist.md`를 참조하여 다음 카테고리별로 분석한다:

1. **구현 완료** — 기획대로 구현됨
2. **누락** — 기획에 있으나 구현되지 않음
3. **상이** — 구현되었으나 기획과 다름 (사유 포함: 정당함/협의 필요)
4. **추가 구현** — 기획에 없으나 구현됨
5. **권한 이슈** — 권한 미적용 또는 부적절한 적용

**심각도 분류:**
- **Critical**: 권한 미적용, API 누락
- **High**: 필수 필드 누락, 비즈니스 로직 상이
- **Medium**: 응답 필드 상이, 에러 메시지 불일치
- **Low**: 네이밍 차이, 타입 강화

### Step 6: 보고서 생성

**6.1 디렉토리 생성:**
```bash
mkdir -p docs/spec-review
```

**6.2 보고서 작성:**
`assets/report-template.md` 양식을 사용하여 보고서를 생성한다.

**출력 위치:** `docs/spec-review/{문서제목}_{YYYYMMDD}.md`

**파일명 규칙:**
- 노션 문서 제목에서 괄호/특수문자 제거
- 공백은 `-`로 대체
- 날짜는 검토일 기준
- 예: `회사-정보_20260215.md`

## Resources

### references/

- `checklist.md` — 검토 체크리스트 및 판단 기준

### assets/

- `report-template.md` — 보고서 마크다운 템플릿
