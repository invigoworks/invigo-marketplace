---
name: component-api-linker
description: |
  컴포넌트 & 로직 DB 페이지의 비즈니스 로직을 분석하여 관련 API를 자동 추천하고,
  API ID relation 필드에 매핑한 뒤, 비즈니스 로직 필드의 화면 필드와 API 필드 간
  매핑 테이블을 컴포넌트 페이지 본문에 추가하는 스킬입니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 사용자가 컴포넌트 & 로직 DB 페이지의 Notion 링크를 제공할 때
  - "비즈니스 로직 보고 API 연결해줘", "API 매핑해줘" 등을 요청할 때
  - 컴포넌트에 관련 API를 연결하고 필드 매핑 정보를 채울 때
---

# Component API Linker

컴포넌트 & 로직 DB 페이지의 **비즈니스 로직** 필드를 분석하여 관련 API를 자동 추천하고,
확인 후 **API ID** relation을 매핑한 뒤, 비즈니스 로직의 화면 필드와 API 요청/응답 필드 간 매핑 테이블을 컴포넌트 페이지 본문에 추가한다.

## 워크플로우

```
사용자: Notion 링크 제공
        ↓
[1] 페이지 조회 → 비즈니스 로직 필드 읽기
        ↓
[2] API 맵핑 DB 전체 조회 → API 목록 확보
        ↓
[3] 비즈니스 로직 분석 → 관련 API 추천
        ↓
[4] 사용자 확인 (추천 목록 제시)
        ↓
[5] API ID relation 필드 업데이트
        ↓
[6] API 상세 페이지에서 필드 정보 추출
        ↓
[7] 컴포넌트 페이지에 필드 매핑 테이블 추가
        ↓
[8] 변경이력 테이블 추가/업데이트
```

## Step 1: Notion 링크에서 페이지 ID 추출

Notion URL에서 페이지 ID를 추출한다. 형식 예시:

```
https://www.notion.so/workspace/페이지제목-{32자ID}
https://www.notion.so/{32자ID}
https://www.notion.so/workspace/{32자ID}?v=...
```

마지막 하이픈(`-`) 뒤 32자 또는 경로의 32자 hex 문자열이 페이지 ID이다.
추출 후 8-4-4-4-12 형식으로 변환한다. (예: `abcdef1234567890abcdef1234567890` → `abcdef12-3456-7890-abcd-ef1234567890`)

## Step 2: 컴포넌트 페이지 조회

Notion MCP `API-retrieve-a-page` 도구로 페이지 속성을 조회한다.

확인할 속성:
- **요소명(ID)** (title): 컴포넌트 이름
- **비즈니스 로직** (rich_text, ID: `usLE`): API 추천의 핵심 입력
- **API ID** (relation, ID: `\uoE`): 기존 매핑 여부 확인
- **화면 ID** (rollup): 연결된 화면 코드 (도메인 힌트)

기존 API ID relation에 값이 있으면 사용자에게 알리고 **추가 매핑인지 교체인지** 확인한다.

## Step 3: API 맵핑 DB에서 API 목록 조회

`API-query-data-source` 또는 `API-retrieve-a-database`로 API 맵핑 DB를 조회한다.

- **DB ID**: `2d3471f8-dcff-8017-8f2c-f3db7658c869`
- 필요한 속성: `API ID` (title), `Endpoint`, `Method`, `Request Spec`, `Response Spec`

> 상세 DB 스키마: `references/db_schema.md` 참조

## Step 4: 비즈니스 로직 분석 및 API 추천

비즈니스 로직 텍스트를 분석하여 관련 API를 추천한다.

### 분석 기준

1. **키워드 매칭**: 비즈니스 로직에 포함된 CRUD 키워드와 API 패턴 매칭
   - 조회/검색/목록 → `GET_*`, `SEARCH_*`
   - 등록/생성/추가 → `CREATE_*`, `REGISTER_*`
   - 수정/변경/업데이트 → `PATCH_*`, `UPDATE_*`
   - 삭제/제거 → `DELETE_*`
   - 다운로드/내보내기 → `EXPORT_*`
   - 업로드/가져오기 → `IMPORT_*`

2. **도메인 매칭**: 화면 ID rollup에서 도메인 코드를 추출하여 API 도메인과 매칭
   - 예: 화면 ID `BITDA-USR-ADM-*` → `USER` 도메인 API 우선

3. **역할 매칭**: 화면 ID에 `ADM`이 포함되면 `_BY_ADMIN` API 우선

4. **Endpoint 내용 매칭**: 비즈니스 로직에 언급된 리소스명이 Endpoint에 포함된 API 우선

### 추천 결과 제시 형식

사용자에게 추천 결과를 다음 형식으로 제시한다:

```
비즈니스 로직 분석 결과, 다음 API들이 관련되어 보입니다:

✅ 추천 API:
1. GET_USERS_BY_ADMIN - GET /api/v1/admin/users (사용자 목록 조회)
2. GET_USER_DETAIL_BY_ADMIN - GET /api/v1/admin/users/{id} (사용자 상세 조회)
3. PATCH_USER_BY_ADMIN - PATCH /api/v1/admin/users/{id} (사용자 수정)

매핑을 진행할까요? 제외하거나 추가할 API가 있으면 알려주세요.
```

**반드시 사용자 확인을 받은 후** 다음 단계로 진행한다.

## Step 5: API ID Relation 업데이트

사용자가 확인한 API 목록으로 컴포넌트 페이지의 `API ID` relation을 업데이트한다.

### 기존 매핑 보존 규칙

- **추가 매핑**: 기존 relation 값을 유지하면서 새 API 추가
- **교체 매핑**: 기존 값을 새 목록으로 대체

Notion MCP `API-patch-page`를 사용한다:

```json
{
  "page_id": "<컴포넌트 페이지 ID>",
  "properties": {
    "API ID": {
      "relation": [
        {"id": "<API1 페이지 ID>"},
        {"id": "<API2 페이지 ID>"}
      ]
    }
  }
}
```

> dual_property relation이므로 API 맵핑 DB 쪽의 `컴포넌트 & 로직 DB` 속성도 자동 동기화된다.

## Step 6: API 상세 페이지에서 필드 정보 추출

매핑된 각 API 페이지의 본문(children blocks)을 `API-get-block-children`으로 조회하여
요청/응답 필드 정보를 추출한다.

```
API-get-block-children(block_id=<API 페이지 ID>)
```

추출 대상:
- **요청 필드**: Request Body, Query Parameter, Path Parameter 테이블의 필드명과 타입
- **응답 필드**: 성공 응답 테이블의 필드명과 타입

## Step 7: 컴포넌트 페이지에 필드 매핑 테이블 추가

비즈니스 로직 필드에 기술된 화면 필드와 API 요청/응답 필드 간 매핑 테이블을 작성한다.

### 매핑 분석 방법

1. **비즈니스 로직 텍스트에서 화면 필드 추출**: 비즈니스 로직에 언급된 필드명/항목명 식별
2. **API 필드와 매칭**: 추출한 화면 필드를 API의 요청/응답 필드와 의미적으로 매칭
3. **미매핑 필드 식별**: 비즈니스 로직에는 있지만 어떤 API 필드에도 매칭되지 않는 화면 필드 식별
4. **매핑 테이블 작성**: 각 API별로 화면 필드 ↔ API 필드 매핑 관계를 테이블로 정리

### 테이블 구조

각 매핑된 API마다 구분 헤더와 매핑 테이블을 추가한다.

테이블은 **4열** 구성: `화면 필드`, `API 필드`, `요청/응답`, `타입`

```
---
## GET_USERS_BY_ADMIN

| 화면 필드 | API 필드          | 요청/응답 | 타입   |
|----------|-------------------|----------|--------|
| 검색어    | keyword           | 요청     | string |
| 사용자명  | name              | 응답     | string |
| 이메일    | email             | 응답     | string |
| 상태      | status.value      | 응답     | string |
| 상태 표시 | status.label      | 응답     | string |

---
## PATCH_USER_BY_ADMIN

| 화면 필드 | API 필드          | 요청/응답 | 타입   |
|----------|-------------------|----------|--------|
| 사용자명  | name              | 요청     | string |
| 이메일    | email             | 요청     | string |
| 상태      | status            | 요청     | string |
| 메모      | ⚠️ 미매핑          | -        | -      |
```

### 미매핑 필드 처리

비즈니스 로직에 언급되어 있지만 매핑된 API의 요청/응답 필드에서 찾을 수 없는 화면 필드는
매핑 테이블 **하단에 별도 행으로 추가**하고 강조 표시한다.

- **API 필드**: `⚠️ 미매핑` 으로 표기
- **요청/응답**, **타입**: `-` 로 표기
- Notion 블록에서 API 필드 셀에 **bold** annotation 적용:
  ```json
  [{"type": "text", "text": {"content": "⚠️ 미매핑"}, "annotations": {"bold": true}}]
  ```

미매핑 필드가 있으면 테이블 작성 후 사용자에게 해당 필드에 대해 확인한다:
- 프론트엔드 전용 필드인지 (API 불필요)
- 아직 API에 반영되지 않은 필드인지
- 다른 API에 매핑되어야 하는지

### Notion 블록 작성

`API-patch-block-children`으로 블록을 추가한다:

```json
{
  "block_id": "<컴포넌트 페이지 ID>",
  "children": [
    {
      "type": "divider",
      "divider": {}
    },
    {
      "type": "heading_2",
      "heading_2": {
        "rich_text": [{"type": "text", "text": {"content": "GET_USERS_BY_ADMIN"}}]
      }
    },
    {
      "type": "table",
      "table": {
        "table_width": 4,
        "has_column_header": true,
        "has_row_header": false,
        "children": [
          {
            "type": "table_row",
            "table_row": {
              "cells": [
                [{"type": "text", "text": {"content": "화면 필드"}}],
                [{"type": "text", "text": {"content": "API 필드"}}],
                [{"type": "text", "text": {"content": "요청/응답"}}],
                [{"type": "text", "text": {"content": "타입"}}]
              ]
            }
          },
          {
            "type": "table_row",
            "table_row": {
              "cells": [
                [{"type": "text", "text": {"content": "검색어"}}],
                [{"type": "text", "text": {"content": "keyword"}, "annotations": {"code": true}}],
                [{"type": "text", "text": {"content": "요청"}}],
                [{"type": "text", "text": {"content": "string"}}]
              ]
            }
          }
        ]
      }
    }
  ]
}
```

### 셀 서식 규칙

- **API 필드** (2열, 데이터 행): `"annotations": {"code": true}` 적용
- **헤더 행**: annotation 적용하지 않음

### 기존 내용 처리

- 페이지 본문에 이미 해당 API 헤더가 있으면 **기존 매핑 테이블을 삭제** 후 새로 추가
- 처음 추가하는 경우 페이지 본문 끝에 추가

## Step 8: 변경이력 테이블 추가

컴포넌트 페이지 본문 **맨 하단**에 변경이력 테이블을 추가한다.

### 테이블 구조

2열 테이블: `날짜`, `변경내용`

```
| 날짜       | 변경내용                                |
|------------|----------------------------------------|
| 2026-02-06 | 최초 필드 매핑                           |
| 2026-02-10 | GET_USERS_BY_ADMIN: email 필드 추가      |
```

### 규칙

- **신규 매핑 시**: 날짜 `YYYY-MM-DD`, 변경내용 `최초 필드 매핑`
- **업데이트 시**: 새 행을 맨 아래에 추가 (최신이 하단)
  - 변경내용 형식: `{API_ID}: {변경 설명}` (예: `GET_USERS_BY_ADMIN: status 필드 추가`)
- **기존 변경이력 보존**: 이미 변경이력 테이블이 있으면 행만 추가

## 주의사항

1. **사용자 확인 필수**: API 추천 후 반드시 사용자 승인을 받은 뒤 매핑 진행
2. **기존 relation 보존**: 추가 매핑 시 기존 relation 배열을 먼저 조회하고 병합
3. **빈 비즈니스 로직**: 비즈니스 로직 필드가 비어있으면 사용자에게 직접 API를 지정하도록 안내
4. **API 미등록 상태**: 추천한 API가 API 맵핑 DB에 없으면 `api-to-notion` 스킬로 먼저 등록하도록 안내
5. **본문 블록 제한**: Notion API는 한 번에 최대 100개 블록까지 추가 가능. 초과 시 분할 요청
6. **매핑 불확실**: 화면 필드와 API 필드 매핑이 불확실한 경우 사용자에게 확인 후 진행

## 참조

- `references/db_schema.md` - DB 스키마 상세
- `api-to-notion` 스킬 - API 미등록 시 문서화 워크플로우
