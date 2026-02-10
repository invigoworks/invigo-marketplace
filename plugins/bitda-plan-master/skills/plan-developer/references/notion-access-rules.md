# Notion 접근 규칙 (절대 준수)

> **⚠️ 절대 금지**: Notion 페이지나 데이터베이스에 접근할 때 다음 도구들을 **절대 사용하지 마세요**:
> - ❌ `WebFetch` - Notion URL을 직접 fetch하지 말 것
> - ❌ `Playwright` (browser_navigate, browser_snapshot 등) - Notion 페이지를 브라우저로 열지 말 것
> - ❌ 기타 웹 스크래핑 도구

> **✅ 반드시 사용**: Notion 관련 모든 작업은 **Notion MCP 도구**만 사용

---

## 사용 가능한 Notion MCP 도구 목록

### 핵심 도구

| 도구 | 용도 | 주요 파라미터 |
|------|------|-------------|
| `notion-search` | 시맨틱 검색 (워크스페이스, DB 내부, 페이지 내부) | `query`, `data_source_url?`, `page_url?`, `filters?` |
| `notion-fetch` | 페이지/DB 조회 (속성 + 콘텐츠 모두 반환) | `id` (URL 또는 UUID) |
| `notion-update-page` | 페이지 속성/콘텐츠 업데이트 | `data: { page_id, command, ... }` |
| `notion-create-pages` | 페이지 생성 (최대 100건 일괄) | `pages[]`, `parent?` |
| `notion-update-data-source` | DB 스키마 수정 (속성 추가/삭제/이름 변경) | `data_source_id` |

### 보조 도구

| 도구 | 용도 |
|------|------|
| `notion-get-users` | 사용자 조회 (`user_id: "self"` → 연결 확인용) |
| `notion-get-teams` | 팀스페이스 목록 조회 |
| `notion-get-comments` | 페이지 댓글 조회 |
| `notion-create-comment` | 페이지 댓글 추가 |
| `notion-move-pages` | 페이지 이동 |
| `notion-duplicate-page` | 페이지 복제 (비동기) |
| `notion-create-database` | 새 DB 생성 |

---

## notion-fetch 사용법 (CRITICAL)

> **파라미터: `id` 하나만 존재**. `page_id`, `block_id` 등은 없음.
> URL 또는 UUID 모두 가능.

```typescript
// ✅ 올바른 사용법 - id 파라미터만 사용
notion-fetch({ id: "2e9471f8-dcff-81d9-ba35-c3c691ebc883" })
notion-fetch({ id: "https://notion.so/workspace/Page-2e9471f8dcff81d9ba35c3c691ebc883" })

// ❌ 잘못된 사용법 - page_id, block_id 파라미터는 존재하지 않음
notion-fetch({ page_id: "xxx" })   // ERROR: 없는 파라미터
notion-fetch({ block_id: "xxx" })  // ERROR: 없는 파라미터
```

### notion-fetch 반환값
- **페이지 조회 시**: 속성(properties) + 전체 콘텐츠(Notion-flavored Markdown) 모두 반환
- **DB 조회 시**: DB 스키마 + `<data-source url="collection://xxx">` 태그 반환

---

## notion-search 사용법

> **시맨틱 검색** 도구. 키워드가 아닌 **의미 기반** 검색.

```typescript
// 워크스페이스 전체 검색
notion-search({ query: "창고 관리 기획서" })

// 특정 DB 내부 검색 (data_source_url 사용)
// ⚠️ DB ID가 아닌 collection:// URL 사용
notion-search({
  query: "창고 관리",
  data_source_url: "collection://2df471f8-dcff-8083-8ce6-000b81ceb6f9"
})

// 특정 페이지 내부 검색
notion-search({
  query: "BulkDeleteButton",
  page_url: "2e9471f8-dcff-81d9-ba35-c3c691ebc883"
})

// 날짜 + 작성자 필터
notion-search({
  query: "기획서",
  filters: {
    created_date_range: { start_date: "2026-01-01" },
    created_by_user_ids: ["user-uuid"]
  }
})
```

### 중요: data_source_url 얻는 방법
```
Step 1: notion-fetch({ id: "DB_ID" })
Step 2: 응답에서 <data-source url="collection://xxx"> 태그 확인
Step 3: 해당 collection:// URL을 data_source_url에 사용
```

---

## notion-update-page 사용법 (CRITICAL)

> **`data` 래퍼 + `command` 필드 필수**. 4가지 command 존재.

### Command 1: 속성 업데이트
```typescript
notion-update-page({
  data: {
    page_id: "xxx",
    command: "update_properties",
    properties: {
      "진행 단계": "기획 확정",
      "버전": 2.0,
      "디자인 핸드오프": "__YES__",
      "date:마감일:start": "2026-03-01",
      "date:마감일:is_datetime": 0
    }
  }
})
```

### Command 2: 전체 콘텐츠 교체
```typescript
notion-update-page({
  data: {
    page_id: "xxx",
    command: "replace_content",
    new_str: "# 새로운 내용\n전체 교체됨"
  }
})
```

### Command 3: 부분 콘텐츠 교체 (가장 유용)
```typescript
// selection_with_ellipsis: 시작 ~10자 + "..." + 끝 ~10자
notion-update-page({
  data: {
    page_id: "xxx",
    command: "replace_content_range",
    selection_with_ellipsis: "### 2.3 삭제...선택 삭제 완료",
    new_str: "### 2.3 삭제 규칙\n새로운 삭제 규칙 내용"
  }
})
```

### Command 4: 콘텐츠 삽입
```typescript
notion-update-page({
  data: {
    page_id: "xxx",
    command: "insert_content_after",
    selection_with_ellipsis: "### 2.2 수정...수정 완료 토스트",
    new_str: "\n### 2.3 삭제 규칙\n삽입할 새 내용"
  }
})
```

### 속성 타입별 값 형식

| 속성 타입 | 형식 | 예시 |
|----------|------|------|
| Title | 문자열 | `"기획 명칭": "BITDA-CM-MST-WHS"` |
| Status/Select | 옵션명 문자열 | `"진행 단계": "기획 확정"` |
| Number | 숫자 | `"버전": 2.0` |
| Checkbox | `__YES__` / `__NO__` | `"디자인 핸드오프": "__YES__"` |
| URL | 문자열 | `"퍼블리싱 결과 확인": "https://..."` |
| Date | 분리 키 | `"date:마감일:start": "2026-03-01"` |
| null | 속성값 제거 | `"속성명": null` |

> **주의**: `id`, `url` 이름의 속성은 `"userDefined:URL"` 접두사 필요

---

## notion-create-pages 사용법

### DB에 페이지 생성 (data_source_id 사용)
```typescript
// ⚠️ DB가 여러 data source를 가진 경우 database_id 대신 data_source_id 사용
notion-create-pages({
  parent: { data_source_id: "2df471f8-dcff-8083-8ce6-000b81ceb6f9" },
  pages: [{
    properties: {
      "기획 명칭": "BITDA-CM-MST-NEW-S001-PAGE-(신규 기능)",
      "진행 단계": "기획 초벌",
      "버전": 1.0,
      "우선 순위": "P2"
    },
    content: "# PART 1: 화면 DB\n..."
  }]
})
```

### 일반 페이지 생성
```typescript
notion-create-pages({
  parent: { page_id: "parent-page-uuid" },
  pages: [{
    properties: { "title": "페이지 제목" },
    content: "# 내용"
  }]
})
```

> **중요**: 콘텐츠 작성 시 반드시 `notion://docs/enhanced-markdown-spec` 리소스를 먼저 확인.
> Notion-flavored Markdown은 표준 Markdown과 다름 (테이블, 토글, 컬럼 등).

---

## Notion URL에서 Page ID 추출

사용자가 Notion URL을 제공하면 다음 절차를 따릅니다:

1. **URL 형식 분석**
   ```
   https://www.notion.so/workspace/[페이지명]-[page_id]
   https://www.notion.so/[page_id]
   https://notion.so/workspace/[페이지명]-[page_id]?pvs=xx
   ```

2. **Page ID 추출**
   - URL의 마지막 32자리 16진수 문자열이 Page ID
   - 예: `ENH-2e9471f8dcff81d9ba35c3c691ebc883` → `2e9471f8dcff81d9ba35c3c691ebc883`
   - 하이픈 추가하여 UUID 형식: `2e9471f8-dcff-81d9-ba35-c3c691ebc883`

3. **조회** (notion-fetch는 URL도 직접 받음)
   ```typescript
   // UUID 사용
   notion-fetch({ id: "2e9471f8-dcff-81d9-ba35-c3c691ebc883" })

   // URL 직접 사용도 가능
   notion-fetch({ id: "https://notion.so/workspace/Page-2e9471f8dcff81d9ba35c3c691ebc883" })
   ```

---

## 잘못된 접근 예시 (하지 말 것)

```typescript
// ❌ WebFetch 사용
WebFetch({ url: "https://www.notion.so/..." })

// ❌ Playwright 사용
browser_navigate({ url: "https://www.notion.so/..." })

// ❌ 존재하지 않는 파라미터
notion-fetch({ page_id: "xxx" })
notion-fetch({ block_id: "xxx" })

// ❌ data 래퍼 없이 update
notion-update-page({ page_id: "xxx", properties: {...} })

// ❌ 존재하지 않는 도구
notion-database-query(...)   // 이 도구는 없음
notion-get-self(...)         // 이 도구는 없음
```

---

## Notion MCP 연결 확인 (필수 선행 단계)

> **CRITICAL**: 작업 시작 전 반드시 연결 상태 확인

### 연결 확인 절차

```typescript
// ✅ 올바른 연결 확인 방법
notion-get-users({ user_id: "self" })
// → 성공: 현재 봇 사용자 정보 반환
// → 실패: 에러 메시지

// ❌ 잘못된 방법 (존재하지 않는 도구)
notion-get-self()  // ERROR: 이 도구는 없음
```

### 연결 상태별 동작

| 상태 | 동작 |
|------|------|
| ✅ 연결됨 | 워크플로우 정상 진행 |
| ❌ 연결 안됨 | 에러 메시지 표시 + 재연결 안내 |
| ⚠️ 토큰 만료 | 재인증 안내 |

---

## 매니페스트 시스템 (Hooks 기반 자동 관리)

> 매니페스트는 **2개의 Hook이 자동 관리**합니다. 수동 관리 불필요.

### Hook 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│ [PreToolUse Hook] notion-manifest-check.sh                   │
│ 트리거: Notion MCP 도구 호출 전 (자동)                         │
│ 역할: 매니페스트 부재/7일 경과 → notion-sync.sh 자동 실행       │
├─────────────────────────────────────────────────────────────┤
│ [Hookify Rule] require-notion-manifest-sync                  │
│ 트리거: notion-fetch 결과와 매니페스트 값 불일치 시 (AI 판단)    │
│ 역할: 전체 동기화 강제 (수동 수정 금지)                         │
├─────────────────────────────────────────────────────────────┤
│ [동기화 스크립트] .claude/shared-references/notion-sync.sh     │
│ 동작: Notion REST API로 4개 상태 그룹 쿼리 → 매니페스트 재생성  │
│ 비용: ~5k 토큰 (MCP 대비 99% 절감), 100% 정확도               │
└─────────────────────────────────────────────────────────────┘
```

### 파일 위치

| 파일 | 용도 |
|------|------|
| `.claude/shared-references/notion-manifest.md` | 기획문서 캐시 (ID, 제목, 진행 단계, 버전, 검토 상태) |
| `.claude/shared-references/notion-sync.sh` | REST API 동기화 스크립트 |
| `.claude/hooks/notion-manifest-check.sh` | PreToolUse Hook (신선도 체크) |
| `.claude/hookify.notion-manifest-sync.local.md` | Hookify Rule (불일치 감지) |

### 매니페스트 사용법

```typescript
// ✅ 매니페스트에서 Page ID 목록 즉시 조회 (0 토큰)
Read(".claude/shared-references/notion-manifest.md")

// ✅ 특정 페이지의 콘텐츠가 필요할 때만 notion-fetch
notion-fetch({ id: "매니페스트에서 찾은 page_id" })
// → Hook이 자동으로 매니페스트 신선도 체크
// → Hookify Rule이 불일치 발견 시 전체 동기화 강제

// ❌ 매니페스트 없이 매번 전체 DB 스캔 (156k 토큰 낭비)
// ❌ 불일치 발견 후 해당 페이지만 수동 수정 (다른 변경 누락 위험)
```

### 수동 동기화 (필요 시)

```bash
# 전체 동기화
./.claude/shared-references/notion-sync.sh

# 변경 감지 + 전체 동기화
./.claude/shared-references/notion-sync.sh --diff
```

### On-Write Sync (MCP로 Notion 수정 후)

| 트리거 | 동작 |
|--------|------|
| `notion-create-pages` 완료 | `notion-sync.sh` 실행하여 매니페스트 갱신 |
| `notion-update-page`로 상태/버전 변경 | `notion-sync.sh` 실행하여 매니페스트 갱신 |

### Data Source URL 참조

> `notion-fetch(DB_ID)` 호출 없이 `planning-db-schema.md`의 하드코딩 값을 직접 사용.
> 상세: `references/planning-db-schema.md` → "DB 연동 정보" 섹션

---

## 데이터베이스 검색 (중요)

> **⚠️ 핵심 사실**: Notion MCP `notion-search`는 **시맨틱 검색**만 지원.
> 속성 필터링은 `notion-sync.sh`(REST API)가 담당하며, Hook이 자동 관리.

### DB 내부 검색 워크플로우

```
┌─────────────────────────────────────────────────────────────┐
│ Step 0: 매니페스트 확인 (FIRST!)                              │
│ → .claude/shared-references/notion-manifest.md 읽기           │
│ → 필요한 정보가 있으면 Step 1-2 생략                           │
│ → (Hook이 신선도를 자동 보장하므로 수동 체크 불필요)              │
├─────────────────────────────────────────────────────────────┤
│ Step 1: data_source_url 확인 (하드코딩 사용)                   │
│ → planning-db-schema.md에서 Data Source URL 참조              │
│ → notion-fetch(DB_ID) 호출 불필요                             │
├─────────────────────────────────────────────────────────────┤
│ Step 2: 필요한 페이지만 개별 조회                              │
│ → notion-fetch({ id: "page_id" })                            │
│ → (Hookify Rule이 불일치 시 자동 동기화 강제)                   │
└─────────────────────────────────────────────────────────────┘
```

### 속성값 필터링이 필요한 경우

속성값(예: "진행 단계" = "부서 협의중")으로 필터링해야 할 때:

```typescript
// Step 1: DB의 data_source_url 확보
notion-fetch({ id: "2df471f8-dcff-80b2-9a6d-f9972b15aa06" })
// → <data-source url="collection://2df471f8-dcff-8083-8ce6-000b81ceb6f9">

// Step 2: 관련 문서 시맨틱 검색
notion-search({
  query: "부서 협의중 기획서",
  data_source_url: "collection://2df471f8-dcff-8083-8ce6-000b81ceb6f9"
})
// → 후보 페이지 목록 반환

// Step 3: 개별 페이지 속성 확인 (필요 시)
// ⚠️ Context Overflow 주의: 3건+ 조회 시 subagent 사용!
notion-fetch({ id: "candidate_page_id" })
// → properties에서 "진행 단계" 값 확인
```

### 도구 선택 가이드

| 목적 | 올바른 도구 | 잘못된 도구 |
|------|------------|------------|
| 워크스페이스 전체 검색 | `notion-search({ query })` | - |
| DB 내부 검색 | `notion-search({ query, data_source_url })` | ❌ `notion-search({ query })` (범위 초과) |
| 특정 페이지 조회 | `notion-fetch({ id })` | ❌ `notion-fetch({ page_id })` |
| 속성 업데이트 | `notion-update-page({ data: { command: "update_properties" } })` | ❌ `notion-update-page({ properties })` |
| 콘텐츠 부분 수정 | `notion-update-page({ data: { command: "replace_content_range" } })` | ❌ `notion-update-page({ content })` |
| DB 스키마 수정 | `notion-update-data-source({ data_source_id })` | - |
| 연결 확인 | `notion-get-users({ user_id: "self" })` | ❌ `notion-get-self()` |

---

## 컨텍스트 관리 (CRITICAL - Context Overflow 방지)

> **⚠️ 경고**: 기획문서 1건의 `notion-fetch` 응답은 **10,000~20,000 토큰**입니다.
> 메인 컨텍스트에서 3건 이상 fetch하면 **context overflow**가 발생합니다.

### 토큰 예산 기준

| 작업 유형 | 메인 컨텍스트 허용 | 초과 시 |
|----------|-------------------|--------|
| 단일 페이지 조회/수정 | 1~2건 fetch OK | - |
| 다수 페이지 조회/수정 (3건+) | **금지** | 반드시 subagent 사용 |
| DB 스키마 조회 | OK (가벼움) | - |
| notion-search 결과 | OK (요약만 반환) | - |

### 잘못된 접근 (Context Overflow 발생)

```typescript
// ❌ 잘못됨 - 메인 컨텍스트에서 다수 페이지 순차 fetch
const pages = [page1, page2, page3, page4, page5, ...];
for (const pageId of pages) {
  notion-fetch({ id: pageId })  // 각 10k-20k 토큰 → 컨텍스트 폭발
  notion-update-page({ data: { page_id: pageId, command: "replace_content_range", ... } })
}
```

### 올바른 접근: Subagent 격리 패턴

```
┌─────────────────────────────────────────────────────────────┐
│ 메인 컨텍스트 (coordinator)                                  │
│                                                             │
│ 1. notion-search로 대상 페이지 목록 확보 (ID + 제목만)         │
│ 2. 변경사항 요약 (scratchpad 파일에 기록)                      │
│ 3. 각 페이지 업데이트를 subagent에 위임                        │
│    └─ Task tool로 subagent 생성 (page별 1개)                 │
│ 4. 결과 수집 및 보고                                         │
├─────────────────────────────────────────────────────────────┤
│ Subagent (per page)                                         │
│                                                             │
│ 1. notion-fetch({ id: "page_id" })로 현재 콘텐츠 조회         │
│ 2. 변경사항 적용                                              │
│ 3. notion-update-page({ data: { ... } })로 업데이트           │
│ 4. 결과만 반환 (전체 콘텐츠 X)                                │
└─────────────────────────────────────────────────────────────┘
```

### 구체적 패턴: 다수 기획문서 업데이트

```typescript
// ✅ 올바름 - Subagent 격리

// Step 1: 메인에서 대상 목록 확보 (가벼운 작업)
// notion-search 결과에서 page ID + 제목만 추출
const targets = [
  { id: "xxx", title: "창고 관리" },
  { id: "yyy", title: "제품 관리" },
];

// Step 2: 변경사항을 scratchpad에 기록
// .scratchpad/변경사항.md 파일에 정리

// Step 3: 각 페이지를 subagent에 위임
for (const target of targets) {
  Task({
    subagent_type: "general-purpose",
    prompt: `
      1. notion-fetch({ id: "${target.id}" })로 페이지 조회
      2. 아래 변경사항 적용:
         [scratchpad 파일 참조]
      3. notion-update-page({ data: {
           page_id: "${target.id}",
           command: "replace_content_range",
           selection_with_ellipsis: "시작텍스트...끝텍스트",
           new_str: "새 콘텐츠"
         } })로 업데이트
      4. 변경된 섹션 요약만 반환 (전체 콘텐츠 X)
    `
  })
}
```

### 핵심 규칙

1. **메인 컨텍스트에서 notion-fetch는 최대 2건까지만** 호출
2. **3건 이상 페이지 조작이 필요하면 반드시 subagent 사용**
3. **subagent는 결과 요약만 반환** (전체 Notion 콘텐츠를 반환하면 안 됨)
4. **변경사항은 scratchpad 파일로 전달** (컨텍스트가 아닌 파일 시스템 활용)
5. **병렬 subagent 활용** - 독립적인 페이지 업데이트는 동시에 실행 가능

### 속성만 필요한 경우

페이지 콘텐츠가 아닌 **메타데이터만** 필요할 때 (예: 상태 확인, 버전 확인):

```typescript
// ✅ notion-search로 DB 내 검색 (전체 콘텐츠 fetch 불필요, 가벼움)
notion-search({
  query: "원재료 관리",
  data_source_url: "collection://xxx"
})
// → 검색 결과에서 기본 속성 확인 가능

// ⚠️ 상세 속성이 필요하면 개별 fetch (but 무거움)
notion-fetch({ id: "page_id" })  // 전체 콘텐츠까지 로드됨
```

---

## Notion-flavored Markdown 참조

콘텐츠 작성/수정 시 반드시 확인:

```
ReadMcpResourceTool({
  server: "plugin:Notion:notion",
  uri: "notion://docs/enhanced-markdown-spec"
})
```

### 주요 차이점 (표준 Markdown과 다른 점)
- 테이블: HTML-like `<table>` 태그 사용
- 토글: `▶ 텍스트` + 탭 들여쓰기
- 색상: `{color="blue"}` 또는 `<span color="red">텍스트</span>`
- 콜아웃: `<callout icon="emoji">내용</callout>`
- 컬럼: `<columns><column>...</column></columns>`
- 멘션: `<mention-page url="...">제목</mention-page>`
- 빈 줄: `<empty-block/>` (일반 빈 줄은 무시됨)
- 인라인 줄바꿈: `<br>` (quote 블록 내)
