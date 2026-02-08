# Notion 접근 규칙 (절대 준수)

> **⚠️ 절대 금지**: Notion 페이지나 데이터베이스에 접근할 때 다음 도구들을 **절대 사용하지 마세요**:
> - ❌ `WebFetch` - Notion URL을 직접 fetch하지 말 것
> - ❌ `Playwright` (browser_navigate, browser_snapshot 등) - Notion 페이지를 브라우저로 열지 말 것
> - ❌ 기타 웹 스크래핑 도구

> **✅ 반드시 사용**: Notion 관련 모든 작업은 **Notion MCP 도구**만 사용:
> - `notion-search`: 페이지/DB 검색
> - `notion-fetch`: 페이지 조회
> - `notion-fetch`: 페이지 콘텐츠 조회
> - `notion-update-page`: 페이지 업데이트
> - `notion-create-pages`: 페이지 생성
> - `notion-database-query`: DB 쿼리

## Notion URL에서 Page ID 추출

사용자가 Notion URL을 제공하면 다음 절차를 따릅니다:

1. **URL 형식 분석**
   ```
   https://www.notion.so/workspace/[페이지명]-[page_id]
   https://www.notion.so/[page_id]
   https://notion.so/workspace/[페이지명]-[page_id]?pvs=xx
   ```

2. **Page ID 추출**
   - URL의 마지막 32자리 16진수 문자열이 Page ID입니다
   - 예: `ENH-2e9471f8dcff81d9ba35c3c691ebc883` → Page ID: `2e9471f8dcff81d9ba35c3c691ebc883`
   - 하이픈을 추가하여 UUID 형식으로 변환: `2e9471f8-dcff-81d9-ba35-c3c691ebc883`

3. **Notion MCP로 페이지 조회**
   ```typescript
   // 1. 페이지 속성 조회
   notion-fetch(page_id: "2e9471f8-dcff-81d9-ba35-c3c691ebc883")

   // 2. 페이지 콘텐츠(본문) 조회
   notion-fetch(block_id: "2e9471f8-dcff-81d9-ba35-c3c691ebc883")
   ```

## 잘못된 접근 예시 (하지 말 것)

```typescript
// ❌ 잘못됨 - WebFetch 사용
WebFetch({ url: "https://www.notion.so/..." })

// ❌ 잘못됨 - Playwright 사용
browser_navigate({ url: "https://www.notion.so/..." })
browser_snapshot()
```

## 올바른 접근 예시

```typescript
// ✅ 올바름 - Notion MCP 사용
// URL: https://www.notion.so/invigoworks/ENH-2e9471f8dcff81d9ba35c3c691ebc883

// Step 1: Page ID 추출
const pageId = "2e9471f8-dcff-81d9-ba35-c3c691ebc883";

// Step 2: Notion MCP로 조회
notion-fetch({ page_id: pageId })
notion-fetch({ block_id: pageId })
```

---

## Notion MCP 연결 확인 (필수 선행 단계)

> **CRITICAL**: 이 스킬의 모든 작업을 시작하기 전에 반드시 Notion MCP 연결 상태를 확인해야 합니다.

### 연결 확인 절차

1. **연결 테스트 실행**:
   ```
   notion-get-self 도구를 호출하여 현재 연결 상태 확인
   ```

2. **성공 시**: 스킬 워크플로우 진행
   - Bot user 정보가 반환되면 연결 정상
   - Phase 1부터 정상 진행

3. **실패 시**: 재연결 안내
   ```markdown
   ⚠️ Notion MCP 연결 실패

   Notion MCP가 연결되지 않았습니다. 다음 단계를 수행해주세요:

   1. Claude Code 설정에서 Notion MCP 연결 상태 확인
   2. Notion 인증 토큰이 유효한지 확인
   3. MCP 서버 재시작 필요 시:
      - Claude Code 재시작
      - 또는 MCP 서버 수동 재연결

   연결 완료 후 다시 시도해주세요.
   ```

### 연결 상태별 동작

| 상태 | 동작 |
|------|------|
| ✅ 연결됨 | Phase 1부터 정상 진행 |
| ❌ 연결 안됨 | 에러 메시지 표시 + 재연결 안내 |
| ⚠️ 토큰 만료 | 재인증 안내 |

---

## 데이터베이스 속성 기반 쿼리 (중요)

> **⚠️ 주의**: `notion-search`는 **전문 검색(full-text search)**입니다.
> 특정 속성값(예: "진행 단계" = "기획 초벌")으로 필터링하려면 **데이터베이스 쿼리**를 사용해야 합니다.

### 잘못된 접근 (하지 말 것)

```typescript
// ❌ 잘못됨 - 텍스트 검색으로 속성 필터링 시도
notion-search({ query: "기획 초벌" })
// → 본문에 "기획 초벌" 텍스트가 있는 페이지를 찾음 (속성 필터 아님)
```

### 올바른 접근 (데이터베이스 쿼리)

```typescript
// ✅ 올바름 - 데이터베이스 스키마 먼저 확인
// Step 1: DB 스키마 조회
notion-fetch({ id: "2df471f8-dcff-80b2-9a6d-f9972b15aa06" })
// → 데이터베이스 구조, 속성명, 쿼리 방법 확인

// Step 2: 속성 기반 필터 쿼리 실행
// DB 스키마에서 제공하는 쿼리 문법 사용
```

### 데이터베이스 쿼리 워크플로우

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: 데이터베이스 스키마 확인                              │
│ → notion-fetch "collection://DB_ID"                         │
│ → 속성명, 타입, 쿼리 가능 여부 파악                          │
├─────────────────────────────────────────────────────────────┤
│ Step 2: 속성 기반 필터 쿼리                                  │
│ → "진행 단계" = "기획 초벌" 같은 조건으로 필터링              │
│ → 반환된 결과 목록 확인                                     │
├─────────────────────────────────────────────────────────────┤
│ Step 3: 결과 순회하며 작업 실행                              │
│ → 각 페이지에 대해 notion-update-page 등 실행               │
└─────────────────────────────────────────────────────────────┘
```

### 도구 선택 가이드

| 목적 | 올바른 도구 | 잘못된 도구 |
|------|------------|------------|
| 키워드로 페이지 찾기 | `notion-search` | - |
| **속성값으로 필터링** | `notion-fetch` (DB) → 쿼리 | ❌ `notion-search` |
| 특정 페이지 조회 | `notion-fetch` (page_id) | - |
| 페이지 업데이트 | `notion-update-page` | - |

### 실제 사용 예시: "기획 초벌" 상태 문서 찾기

```typescript
// 1. 기획문서 DB 스키마 확인
notion-fetch({ id: "2df471f8-dcff-80b2-9a6d-f9972b15aa06" })

// 2. 스키마에서 "진행 단계" 속성 확인 후 쿼리
// → DB 문서에서 제공하는 쿼리 문법 따라 필터 적용

// 3. 결과로 받은 각 페이지 업데이트
for (const page of results) {
  notion-update-page({ page_id: page.id, ... })
}
```

> **핵심**: 100개 미만의 문서에서도 속성 검색이 안 되는 이유는 **도구 선택 오류**입니다.
> 텍스트 검색(`search`)이 아닌 **속성 필터 쿼리**를 사용하세요.
