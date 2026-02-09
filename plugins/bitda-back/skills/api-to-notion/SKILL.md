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
5. **계층 구조 표현**: 중첩 객체(LabeledEnum, 내장 DTO 등)는 `parent.child` 형태로 테이블에 표현.
6. **테이블 셀 서식 일관성**: 4열 테이블의 첫 번째 열(파라미터명/필드명)은 **반드시** `"annotations": {"code": true}`를 적용하여 코드 블록 서식으로 표기한다. 헤더 행(파라미터, 필드 등 컬럼 제목)에는 적용하지 않고, 데이터 행의 첫 번째 셀에만 적용한다.
   ```json
   // ✅ 올바른 예시 (데이터 행 첫 번째 셀에 code annotation)
   [{"type": "text", "text": {"content": "name"}, "annotations": {"code": true}}]

   // ❌ 잘못된 예시 (code annotation 누락)
   [{"type": "text", "text": {"content": "name"}}]
   ```

## 워크플로우

### 1단계: 스냅샷 로드 및 API 식별

1. `/tmp/bitda-swagger-snapshot/` 에서 가장 최신 디렉토리의 `api-docs.json`을 Read 도구로 로드
2. 사용자가 명시한 API를 `paths` 에서 검색
3. 못 찾으면 사용자에게 재질문 (추측 금지)
4. 찾은 API 목록을 사용자에게 확인

### 2단계: Notion DB 아이템 생성

**DB ID**: `2d3471f8-dcff-8017-8f2c-f3db7658c869`

각 API마다 `mcp__notion__API-post-page` 로 DB 아이템 생성.

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

생성된 page_id에 `mcp__notion__API-patch-block-children`으로 블록 추가.
블록 구조는 `references/block_templates.md` 참조.

#### 3-1. 개요 (H2)

api-docs.json에서 해당 operation의 `summary`와 `description` 추출.

#### 3-2. 인증 및 권한 (H2)

**테이블 블록** (2열: 항목, 값)
- 필요 역할: 코드베이스의 `@PreAuthorize` 분석 → `ADMIN`, `OWNER`, `MEMBER` 등
- 필요 권한: 없으면 `X`, 있으면 권한 코드 (예: `warehouse:read`)

권한 분석 순서:
1. 컨트롤러 클래스 레벨 `@PreAuthorize` 확인
2. 메서드 레벨 `@PreAuthorize` 확인 (메서드가 우선)
3. `hasRole('ADMIN')` → 역할: ADMIN
4. `hasAnyRole(...)` → 해당 역할 나열
5. 없으면 → 역할: X

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

중첩 객체 표현:
```
필드          타입        필수    설명
name          string      Yes    이름
address       object      Yes    주소 정보
address.city  string      Yes    도시
address.zip   string      Yes    우편번호
```

#### 3-4. 응답 (H2)

> **응답 섹션 이후 변경이력 섹션이 마지막에 추가됨 (3-5 참조)**

**성공 응답 (H3)** — 응답 바디가 존재하는 경우만:
- 테이블 (4열: 필드, 타입, 필수, 설명) — 계층 구조 표현
- 응답 예시 JSON 코드 블록 (ApiResponse 래퍼 포함)

LabeledEnum 표현:
```
필드           타입      필수    설명
status         object    Yes    상태 정보 (LabeledEnum)
status.value   string    Yes    상태 코드
status.label   string    Yes    상태 표시명
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

## Notion 블록 작성 참조

상세 블록 구조와 JSON 예시는 `references/block_templates.md` 참조.

## 주의사항

1. **중복 확인**: DB에 같은 API ID가 이미 있는지 검색 후, 있으면 사용자에게 보고 (덮어쓸지 질문)
2. **`"success": true` 금지**: ApiResponse에 해당 필드 없음
3. **에러 응답 data 필드**: 예외 클래스 파일을 반드시 직접 읽어서 확인. data 없으면 생략.
4. **요청 예시 필수**: POST, PATCH, PUT 등 Request Body가 있는 API는 요청 예시 JSON 필수
