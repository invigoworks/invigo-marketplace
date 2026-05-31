---
name: api-to-notion
description: |
  Swagger 스냅샷(api-docs.json)과 코드베이스를 기반으로 Notion API 맵핑 DB에
  API 문서를 등록하고 상세 페이지를 작성하는 스킬입니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 특정 API를 Notion에 문서화할 때
  - API 맵핑 DB에 API를 등록하고 상세 페이지를 채울 때
  - 사용자가 "API 노션에 등록", "노션 API 문서화", "api-to-notion" 등을 요청할 때
---

# API to Notion

Swagger 스냅샷(`api-docs.json`)과 코드베이스 분석을 기반으로 Notion API 맵핑 DB에 API를 등록하고, Notion native block으로 상세 페이지를 작성하는 스킬.

## 전제 조건

- `/tmp/bitda-swagger-snapshot/` 에 `api-docs.json` 이 존재해야 함 (`/swagger-snapshot` 스킬로 생성)
- 가장 최신 타임스탬프 디렉토리의 파일을 사용
- 스냅샷이 없으면 사용자에게 `/swagger-snapshot` 실행을 안내하고 중단

## 타협 불가능한 규칙

1. **API 명시 필수**: 사용자가 대상 API를 명시하지 않으면 반드시 질문. 전체 API 일괄 등록 불가.
   - 예: "WarehouseController의 모든 API", "GET /api/v1/admin/warehouses/{id}"
2. **추측 금지**: api-docs.json에서 해당 API를 찾지 못하면 임의로 생각하지 말고 사용자에게 재질문.
3. **코드베이스 기반 실패 응답**: 실패 응답은 반드시 실제 소스 코드의 throw 문을 분석하여 작성.
4. **Swagger description 원문 사용**: 설명 필드는 api-docs.json의 description을 그대로 사용. 번역/요약 금지.
5. **⚠️ 계층 구조 완전 전개 (Full Expansion) — 가장 중요한 규칙**:

   **원칙**: 요청/응답 스키마의 **모든** 중첩 객체와 배열 내 객체는 반드시 **재귀적으로 완전히 펼쳐서** 테이블에 표현해야 한다.

   **적용 대상**:
   - 중첩 객체 (`$ref`로 참조되는 DTO)
   - LabeledEnum (`value`, `label` 필드)
   - 배열 내 객체 (`items[].xxx`)
   - 다중 레벨 중첩 (`a.b.c.d`)

   **금지 사항**: `object` 또는 `array` 타입만 적고 하위 필드를 생략하면 **규칙 위반**. 이 규칙을 위반한 문서는 불완전한 것으로 간주된다.

   ```
   // ✅ 올바른 예시 (모든 하위 필드 완전 전개)
   필드                    타입      필수    설명
   warehouse               object    Yes     창고 정보
   warehouse.id            string    Yes     창고 ID
   warehouse.name          string    Yes     창고명
   warehouse.status        object    Yes     창고 상태 (LabeledEnum)
   warehouse.status.value  string    Yes     상태 코드
   warehouse.status.label  string    Yes     상태 표시명
   items                   array     Yes     품목 목록
   items[].id              string    Yes     품목 ID
   items[].quantity        number    Yes     수량
   items[].unit            object    Yes     단위 (LabeledEnum)
   items[].unit.value      string    Yes     단위 코드
   items[].unit.label      string    Yes     단위 표시명

   // ❌ 잘못된 예시 (하위 필드 생략 — 규칙 위반!)
   필드              타입      필수    설명
   warehouse         object    Yes     창고 정보      ← 하위 필드 누락!
   items             array     Yes     품목 목록      ← 하위 필드 누락!
   ```

   **검증 방법**: 테이블 완성 후, `object` 또는 `array` 타입이 있는 모든 행에 대해 하위 필드가 펼쳐져 있는지 확인한다.
6. **테이블 셀 서식 일관성**: 4열 테이블의 첫 번째 열(파라미터명/필드명)은 **반드시** `"annotations": {"code": true}`를 적용하여 코드 블록 서식으로 표기한다. 헤더 행(파라미터, 필드 등 컬럼 제목)에는 적용하지 않고, 데이터 행의 첫 번째 셀에만 적용한다.
   ```json
   // ✅ 올바른 예시 (데이터 행 첫 번째 셀에 code annotation)
   [{"type": "text", "text": {"content": "name"}, "annotations": {"code": true}}]

   // ❌ 잘못된 예시 (code annotation 누락)
   [{"type": "text", "text": {"content": "name"}}]
   ```
7. **api-docs.json을 Read 도구로 직접 읽지 않는다.** 모든 접근은 jq 스크립트를 통해 필터링된 결과만 사용한다.

## 워크플로우

### 1단계: API 식별 및 추출 (jq 기반)

> **핵심 원칙**: `api-docs.json`(~194KB)을 Read 도구로 절대 로드하지 않는다. jq 스크립트로 필요한 부분만 추출한다.

1. 최신 스냅샷 디렉토리 확인:
   ```bash
   SNAPSHOT_DIR="/tmp/bitda-swagger-snapshot/$(ls -t /tmp/bitda-swagger-snapshot/ | head -1)"
   ```

2. 사용자가 태그/컨트롤러 이름으로 요청한 경우, **list-apis.jq**로 API 목록만 추출:
   ```bash
   # 태그 기반 검색
   jq --arg TAG "Warehouse" \
     -f .claude/skills/api-to-notion/scripts/list-apis.jq \
     "$SNAPSHOT_DIR/api-docs.json"

   # 전체 API 목록 (TAG를 빈 문자열로)
   jq --arg TAG "" \
     -f .claude/skills/api-to-notion/scripts/list-apis.jq \
     "$SNAPSHOT_DIR/api-docs.json"
   ```

3. 대상 API가 확정되면 **extract-api.jq**로 해당 엔드포인트 + 참조 스키마만 추출:
   ```bash
   jq --arg PATH "/api/v1/warehouses" --arg METHOD "post" \
     -f .claude/skills/api-to-notion/scripts/extract-api.jq \
     "$SNAPSHOT_DIR/api-docs.json"
   ```

4. 추출 결과는 Bash 출력에서 직접 확인 (별도 Read 불필요)
5. **스키마 완전 분석**: 추출된 스키마에서 `$ref`로 참조되는 모든 하위 DTO를 재귀적으로 분석한다.
   - Request Body 스키마 → 모든 중첩 객체/배열 내 객체 필드 식별
   - Response 스키마 → 모든 중첩 객체/배열 내 객체 필드 식별
   - LabeledEnum 타입 → `value`, `label` 필드 자동 추가
6. 못 찾으면 사용자에게 재질문 (추측 금지)
7. 찾은 API 목록을 사용자에게 확인

### 2단계: Notion DB 아이템 생성 또는 기존 페이지 준비

**DB ID**: `2d3471f8-dcff-8017-8f2c-f3db7658c869`

#### 2-A. 중복 확인

`mcp__notion__API-post-search`로 API ID를 검색하여 기존 페이지 존재 여부를 확인한다.

#### 2-B. 신규 등록 (기존 페이지 없음)

`mcp__notion__API-post-page`로 DB 아이템 생성.

**⚠️ parent 파라미터 직렬화 주의사항**:
`parent`는 반드시 **JSON 객체**로 전달해야 한다. 문자열로 직렬화하면 Notion API가 400 에러를 반환한다.

```
// ✅ 올바른 호출 (JSON 객체)
parent: {"database_id": "2d3471f8-dcff-8017-8f2c-f3db7658c869"}

// ❌ 잘못된 호출 (문자열 — 400 에러 발생)
parent: "{\"database_id\": \"2d3471f8-dcff-8017-8f2c-f3db7658c869\"}"
```

전체 파라미터 구조:

```
parent: { "database_id": "2d3471f8-dcff-8017-8f2c-f3db7658c869" }
properties:
  "": { "title": [{ "text": { "content": "{API_ID}" } }] }        ← title 속성 (이름이 빈 문자열)
  "Endpoint": { "rich_text": [{ "text": { "content": "{path}" } }] }
  "Method": { "select": { "name": "{METHOD}" } }
  "Version": { "rich_text": [{ "text": { "content": "1.0" } }] }  ← 문서화 버전 (기본 1.0)
```

#### 2-C. 기존 페이지 업데이트 (기존 페이지 있음)

기존 페이지를 업데이트할 때는 **반드시 기존 블록을 모두 삭제한 후** 새 블록을 추가한다.

**Step 1: 기존 블록 삭제**
1. `mcp__notion__API-get-block-children`으로 기존 페이지의 모든 자식 블록 ID를 조회
2. 각 블록을 `mcp__notion__API-delete-a-block`으로 삭제 (병렬 실행 가능)
3. 모든 블록이 삭제된 빈 페이지 상태에서 3단계 진행

**Step 2: Version 프로퍼티 갱신**
1. `mcp__notion__API-retrieve-a-page`로 현재 Version 값을 읽음
2. 버전 판단 후 `mcp__notion__API-patch-page`로 Version 프로퍼티 업데이트:
   ```
   properties:
     "Version": { "rich_text": [{ "text": { "content": "{new_version}" } }] }
   ```

**Version 규칙** (문서화 버전, API 버전과 무관):
- 신규 등록: `1.0`
- 기존 문서 업데이트 시 이전 Version을 읽어서 판단:
  - **Major 버전 증가** (1.0 → 2.0): 응답 구조 변경, 필드명 변경, 필드 삭제
  - **Minor 버전 증가** (1.0 → 1.1): 필드 추가, 설명 수정, 에러 코드 추가/변경 등

**API ID 생성 규칙**: `{METHOD}_{RESOURCE}_{ACTION}[_BY_{ROLE}]`
- Admin API (`/api/v1/admin/...`): `_BY_ADMIN` 접미사
- 목록 조회: `GET_{복수}`, 단건 조회: `GET_{단수}_DETAIL`
- 생성: `CREATE_{단수}`, 수정: `PATCH_{단수}`, 삭제: `DELETE_{단수}`

### 3단계: 상세 페이지 작성

page_id에 `mcp__notion__API-patch-block-children`으로 블록 추가.
(2-C에서 기존 블록을 삭제했으므로 항상 깨끗한 상태에서 시작)

#### 3-1. 개요 (H2)

api-docs.json에서 해당 operation의 `summary`와 `description` 추출.

#### 3-2. 인증 및 권한 (H2)

**테이블 블록** (2열: 항목, 값)
- 필요 역할: `ADMIN`, `OWNER`, `MEMBER` 등
- 필요 권한: 없으면 `X`, 있으면 권한 코드 (예: `warehouse:read`)

**⚠️ 추측 금지**: Controller 파일에 명시적으로 선언된 어노테이션만 사용한다. UseCase, Service 등 다른 계층은 확인하지 않는다.

**분석 대상 (Controller 파일만)**:
1. 해당 API의 Controller 파일을 찾아서 Read
2. 클래스 레벨 `@PreAuthorize` 확인
3. 메서드 레벨 `@PreAuthorize` 확인 (메서드가 클래스보다 우선)

**어노테이션 해석 규칙**:
| 어노테이션 패턴 | 필요 역할 | 필요 권한 |
|----------------|----------|----------|
| `hasRole('ADMIN')` | `ADMIN` | `X` |
| `hasAnyRole('OWNER', 'MEMBER')` | `OWNER`, `MEMBER` | `X` |
| `hasAuthority('warehouse:read')` | `X` | `warehouse:read` |
| `hasAnyAuthority('a:read', 'a:write')` | `X` | `a:read`, `a:write` |
| 클래스/메서드에 어노테이션 없음 | `X` | `X` |

**금지 사항**:
- 다른 계층(UseCase, Service, Repository)의 코드를 보고 권한 추측 금지
- 비슷한 API의 패턴을 보고 추측 금지
- 어노테이션이 없으면 반드시 `X`로 표기

#### 3-3. 요청 (H2)

아래 항목은 **존재하는 경우에만** 추가:

**Path Parameter (H3)** — 테이블 (4열: 파라미터, 타입, 필수, 설명)
**Query Parameter (H3)** — 테이블 (4열: 파라미터, 타입, 필수, 설명)
**Header (H3)** — 테이블 (4열: 파라미터, 타입, 필수, 설명) — Idempotency-Key 등 커스텀 헤더가 있는 경우
**Request Body (H3)** — 테이블 (4열: 필드, 타입, 필수, 설명) + 요청 예시 JSON 코드 블록

**유효성 검사 (H3)** — 컨트롤러 메서드 파라미터에 `@Valid`가 붙은 경우에만 추가:
1. Request DTO 클래스를 읽어 `@field:NotBlank`, `@field:Size`, `@field:Pattern`, `@field:ValidEmail` 등 Bean Validation 어노테이션을 분석
2. 테이블 (3열: 필드, 규칙, 메시지) — 어노테이션의 `message` 파라미터 원문 사용
3. 유효성 실패 응답 예시 JSON 코드 블록 (`GlobalExceptionHandler.handleValidationException` 기준)

테이블 예시:
```
필드                        규칙              메시지
name                       NotBlank          세무사 사무소명은 필수입니다
name                       Size(max=255)     세무사 사무소명은 255자를 초과할 수 없습니다
businessRegistrationNumber NotBlank          사업자등록번호는 필수입니다
businessRegistrationNumber BRN(10자리)       사업자등록번호는 10자리 숫자여야 합니다
tel                        Phone(8~15자리)   전화번호는 8~15자리 숫자여야 합니다
email                      Email             이메일 형식이 올바르지 않습니다
```

유효성 실패 응답 예시:
```json
{
  "data": [
    { "field": "name", "reason": "세무사 사무소명은 필수입니다" },
    { "field": "tel", "reason": "전화번호는 8~15자리 숫자여야 합니다", "rejectedValue": "123" }
  ],
  "error": "VALIDATION_ERROR",
  "message": "입력값 검증 실패"
}
```
- HTTP 상태: `400 Bad Request`
- `data` 배열의 각 항목: `field`(필드명), `reason`(에러 사유), `rejectedValue`(거부된 값, 선택적)
- 예시의 필드/메시지는 해당 API의 실제 DTO 어노테이션을 기반으로 작성

**중첩 객체/배열 완전 전개 규칙**:
- 모든 중첩 객체는 `parent.child` 형태로 **모든 하위 필드** 펼침
- 배열 내 객체는 `parent[].child` 형태로 표현
- `object`나 `array` 타입만 적고 끝내면 **규칙 위반**

```
필드              타입        필수    설명
name              string      Yes     이름
address           object      Yes     주소 정보
address.city      string      Yes     도시
address.zip       string      Yes     우편번호
address.detail    string      No      상세 주소
items             array       Yes     품목 목록
items[].productId string      Yes     상품 ID
items[].quantity  number      Yes     수량
items[].unit      object      Yes     단위 정보 (LabeledEnum)
items[].unit.value   string   Yes     단위 코드
items[].unit.label   string   Yes     단위 표시명
```

#### 3-4. 응답 (H2)

> **응답 섹션 이후 변경이력 섹션이 마지막에 추가됨 (3-5 참조)**

**성공 응답 (H3)** — 응답 바디가 존재하는 경우만:
- 테이블 (4열: 필드, 타입, 필수, 설명) — 계층 구조 표현
- 응답 예시 JSON 코드 블록 (ApiResponse 래퍼 포함)

**LabeledEnum 및 중첩 객체 완전 전개** (타협 불가능한 규칙 5번 참조):
```
필드                타입      필수    설명
status              object    Yes     상태 정보 (LabeledEnum)
status.value        string    Yes     상태 코드
status.label        string    Yes     상태 표시명
warehouse           object    Yes     창고 정보
warehouse.id        string    Yes     창고 ID
warehouse.name      string    Yes     창고명
warehouse.address   string    No      창고 주소
items               array     Yes     품목 목록
items[].id          string    Yes     품목 ID
items[].name        string    Yes     품목명
items[].status      object    Yes     품목 상태 (LabeledEnum)
items[].status.value   string Yes     상태 코드
items[].status.label   string Yes     상태 표시명
```

ApiResponse 래퍼 (success 필드 없음):
```json
{
  "data": { ... }
}
```

**실패 응답 (H3)** — 코드베이스 분석 기반:

분석 순서:
1. 컨트롤러 → UseCase 인터페이스 → Service 구현체 순서로 추적
2. `throw` 문 검색
3. 예외 클래스 파일을 직접 읽어서 Error enum 및 data 파라미터 확인
4. Error enum에서 HTTP 상태 코드와 메시지 추출

각 에러마다:
- `{status} - {ERROR_CODE}` 볼드 텍스트
- JSON 코드 블록:

data가 없는 경우:
```json
{
  "error": "WAREHOUSE_NOT_FOUND",
  "message": "창고를 찾을 수 없습니다"
}
```

data가 있는 경우:
```json
{
  "data": { "warehouseId": "..." },
  "error": "WAREHOUSE_NOT_FOUND",
  "message": "창고를 찾을 수 없습니다"
}
```

#### 3-5. 변경이력 (H2)

상세 페이지 **맨 하단**에 추가. 테이블 블록 (2열: 버전, 변경내용).

- 신규 등록 시: 버전 `1.0`, 변경내용 `최초 등록`
- 업데이트 시: 새 버전 행을 맨 아래에 추가 (최신이 하단)

## Notion 블록 패턴 레퍼런스

아래는 `mcp__notion__API-patch-block-children`의 `children` 배열에 사용하는 블록 JSON 패턴이다.

### 기본 블록 타입

```json
// heading_2
{"object":"block","type":"heading_2","heading_2":{"rich_text":[{"type":"text","text":{"content":"제목"}}]}}

// heading_3
{"object":"block","type":"heading_3","heading_3":{"rich_text":[{"type":"text","text":{"content":"소제목"}}]}}

// paragraph (일반 텍스트)
{"object":"block","type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"내용"}}]}}

// paragraph (볼드 — 실패 응답 라벨용)
{"object":"block","type":"paragraph","paragraph":{"rich_text":[{"type":"text","text":{"content":"404 - WAREHOUSE_NOT_FOUND"},"annotations":{"bold":true}}]}}

// divider
{"object":"block","type":"divider","divider":{}}

// code
{"object":"block","type":"code","code":{"rich_text":[{"type":"text","text":{"content":"{\n  \"key\": \"value\"\n}"}}],"language":"json"}}
```

### 4열 테이블 (파라미터/필드 테이블)

데이터 행의 첫 번째 셀에 `"annotations":{"code":true}` 필수.

```json
{
  "object":"block","type":"table",
  "table":{
    "table_width":4,"has_column_header":true,"has_row_header":false,
    "children":[
      {"object":"block","type":"table_row","table_row":{"cells":[
        [{"type":"text","text":{"content":"필드"}}],
        [{"type":"text","text":{"content":"타입"}}],
        [{"type":"text","text":{"content":"필수"}}],
        [{"type":"text","text":{"content":"설명"}}]
      ]}},
      {"object":"block","type":"table_row","table_row":{"cells":[
        [{"type":"text","text":{"content":"name"},"annotations":{"code":true}}],
        [{"type":"text","text":{"content":"string"}}],
        [{"type":"text","text":{"content":"Yes"}}],
        [{"type":"text","text":{"content":"창고명"}}]
      ]}},
      {"object":"block","type":"table_row","table_row":{"cells":[
        [{"type":"text","text":{"content":"address.city"},"annotations":{"code":true}}],
        [{"type":"text","text":{"content":"string"}}],
        [{"type":"text","text":{"content":"Yes"}}],
        [{"type":"text","text":{"content":"도시"}}]
      ]}}
    ]
  }
}
```

### 2열 테이블 (인증/변경이력)

```json
{
  "object":"block","type":"table",
  "table":{
    "table_width":2,"has_column_header":true,"has_row_header":false,
    "children":[
      {"object":"block","type":"table_row","table_row":{"cells":[
        [{"type":"text","text":{"content":"항목"}}],
        [{"type":"text","text":{"content":"값"}}]
      ]}},
      {"object":"block","type":"table_row","table_row":{"cells":[
        [{"type":"text","text":{"content":"필요 역할"}}],
        [{"type":"text","text":{"content":"ADMIN"},"annotations":{"code":true}}]
      ]}}
    ]
  }
}
```

> 상세 블록 예시가 더 필요하면 `references/block_templates.md` 참조.

## 코드 탐색 최적화

컨텍스트 절약을 위해 코드 분석 시 다음 패턴을 사용한다:

- **권한 분석**: `@PreAuthorize` → Grep content mode로 해당 라인만 검색 (파일 전체 Read 불필요)
  ```
  Grep pattern="@PreAuthorize" path="modules/application/api" output_mode="content"
  ```
- **예외 분석**: `throw` → Grep으로 예외 throw 지점만 검색, 해당 클래스만 선택적 Read
  ```
  Grep pattern="throw " path="modules/application/core/src/main/kotlin/.../service/" output_mode="content"
  ```
- **DTO 분석**: 유효성 어노테이션 → Grep으로 검색 후 필요한 파일만 Read
  ```
  Grep pattern="@field:" path="modules/application/api/src/main/kotlin/.../dto/" output_mode="content"
  ```
- **파일 전체 Read는 최소화**: 해당 클래스만 선택적으로 Read하고, 대형 파일은 Grep으로 필요한 부분만 추출

## 주의사항

1. **중복 확인**: DB에 같은 API ID가 이미 있는지 검색 후, 있으면 사용자에게 보고 (덮어쓸지 질문). 덮어쓸 경우 반드시 2-C 절차(기존 블록 삭제 → Version 갱신)를 수행
2. **`"success": true` 금지**: ApiResponse에 해당 필드 없음
3. **에러 응답 data 필드**: 예외 클래스 파일을 반드시 직접 읽어서 확인. data 없으면 생략.
4. **요청 예시 필수**: POST, PATCH, PUT 등 Request Body가 있는 API는 요청 예시 JSON 필수

## ✅ 페이지 작성 완료 전 검증 체크리스트

**Notion 블록 추가 전 반드시 확인**:

- [ ] **요청 테이블**: `object` 또는 `array` 타입 필드가 있으면 모든 하위 필드가 펼쳐져 있는가?
- [ ] **응답 테이블**: `object` 또는 `array` 타입 필드가 있으면 모든 하위 필드가 펼쳐져 있는가?
- [ ] **LabeledEnum**: `.value`, `.label` 필드가 명시되어 있는가?
- [ ] **다중 레벨 중첩**: `a.b.c` 형태의 깊은 중첩도 모두 표현되어 있는가?
- [ ] **배열 내 객체**: `items[].xxx` 형태로 배열 요소의 필드도 모두 표현되어 있는가?

**위반 시**: 테이블을 다시 작성하고, 누락된 하위 필드를 모두 추가한다.
