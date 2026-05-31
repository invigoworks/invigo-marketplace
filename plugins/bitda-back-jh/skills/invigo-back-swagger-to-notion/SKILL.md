---
name: invigo-back-swagger-to-notion
description: |
  Invigo BITDA 백엔드 API 명세를 노션에 동기화하는 스킬입니다.
  코드베이스(컨트롤러, Swagger 등)에서 API 정보를 추출하여 노션 API 맵핑 DB에 등록 및 업데이트합니다.
  이 스킬은 다음 상황에서 사용됩니다:
  - 백엔드 API를 노션에 문서화할 때
  - API 맵핑 DB에 새 API를 등록하거나 기존 API를 업데이트할 때
  - API 상세 페이지에 일관된 형식의 문서를 생성할 때
  - API와 화면/컴포넌트 DB 간의 연결 관계를 설정할 때
---

# Swagger to Notion API Sync

Swagger `/v3/api-docs` 엔드포인트와 코드베이스의 어노테이션을 기반으로 노션 API 맵핑 DB를 동기화하는 스킬입니다.

## 사용 시점

- 사용자가 "API를 노션에 동기화해줘", "swagger 기반으로 노션 업데이트해줘" 등을 요청할 때
- 새로운 API가 추가되어 문서화가 필요할 때
- 기존 API 스펙이 변경되어 노션 업데이트가 필요할 때

## 필수 확인 사항

동기화 작업 전 반드시 확인:

1. **대상 API 명시**: 사용자가 동기화할 API를 명시하지 않았다면 반드시 질문
   - "어떤 API를 동기화할까요? (예: AdminUserController의 모든 API, 특정 엔드포인트 등)"

2. **서버 실행 여부**: Swagger 엔드포인트 접근을 위해 로컬 서버가 실행 중이어야 함
   - 기본 URL: `http://localhost:8080/v3/api-docs`

## 워크플로우

### 1단계: API 정보 수집

Swagger JSON과 소스 코드에서 정보 추출:

```bash
# Swagger JSON 조회
curl -s http://localhost:8080/v3/api-docs | jq '.paths'
```

소스 코드에서 추가 정보 확인:
- `@Operation(summary, description)` - API 요약 및 설명
- `@ApiResponses`, `@ApiResponse` - 응답 코드별 설명
- `@Parameter` - 파라미터 설명
- `@PreAuthorize` - 필요 권한/역할 정보
- Request/Response DTO 클래스 - 스키마 정보

### 2단계: API ID 생성 규칙

API ID는 다음 형식으로 생성:
```
{METHOD}_{RESOURCE}_{ACTION}[_BY_{ROLE}]
```

#### 기본 규칙
- HTTP 메서드 + 리소스 + 액션 조합
- POST → CREATE, GET(목록) → GET_{복수}, GET(단일) → GET_{단수}_DETAIL
- PATCH → PATCH, PUT → UPDATE, DELETE → DELETE

#### 역할별 API 구분 (중요!)
- **Admin 전용 API**: `_BY_ADMIN` 접미사 추가
  - 예: `/api/v1/admin/users` → `GET_USERS_BY_ADMIN`
- **Owner/Member 전용 API**: `_BY_OWNER`, `_BY_MEMBER` 등 접미사 추가
- **공통 API**: 접미사 없음

#### 예시

**Admin 전용 API** (`/api/v1/admin/...`):
- `GET /api/v1/admin/users` → `GET_USERS_BY_ADMIN`
- `GET /api/v1/admin/users/{id}` → `GET_USER_DETAIL_BY_ADMIN`
- `POST /api/v1/admin/users` → `CREATE_USER_BY_ADMIN`
- `PATCH /api/v1/admin/users/{id}` → `PATCH_USER_BY_ADMIN`
- `DELETE /api/v1/admin/users/{id}` → `DELETE_USER_BY_ADMIN`

**일반 API** (역할 구분 없음):
- `GET /api/v1/users/me` → `GET_MY_PROFILE`
- `PATCH /api/v1/users/me` → `PATCH_MY_PROFILE`

### 3단계: 노션 DB 업데이트

**API 맵핑 DB ID**: `2d3471f8-dcff-8017-8f2c-f3db7658c869`

#### DB 속성 매핑

| 속성명 | 타입 | 값 |
|--------|------|-----|
| API ID | title | 생성된 API ID |
| Endpoint | rich_text | API 경로 (예: `/api/v1/admin/users`) |
| Method | select | HTTP 메서드 (GET, POST, PATCH, DELETE 등) |
| Git Link | url | 컨트롤러 파일 GitHub URL |
| Request Spec | rich_text | 요청 스키마 요약 |
| Response Spec | rich_text | 응답 스키마 요약 |

#### DB 아이템 생성 예시

```python
# Notion MCP 도구 사용
mcp__notion__notion_create_database_item(
    database_id="2d3471f8-dcff-8017-8f2c-f3db7658c869",
    properties={
        "API ID": {"title": [{"text": {"content": "GET_ADMIN_USERS"}}]},
        "Endpoint": {"rich_text": [{"text": {"content": "/api/v1/admin/users"}}]},
        "Method": {"select": {"name": "GET"}},
        "Git Link": {"url": "https://github.com/..."}
    }
)
```

### 4단계: 에러 응답 분석 (실제 코드 기반)

API에서 발생할 수 있는 실제 예외를 소스 코드에서 확인하여 문서화합니다.

#### 분석 순서

1. **UseCase/Service 클래스 확인**
   - 컨트롤러에서 호출하는 UseCase 클래스 찾기
   - 예: `GetUserByAdminUseCase`, `CreateUserByAdminUseCase`

2. **throw 문 검색**
   ```bash
   # UseCase 내 throw 문 확인
   grep -n "throw" GetUserByAdminUseCase.kt
   ```

3. **예외 클래스 → 에러 코드 매핑**
   - 예외 클래스가 사용하는 Error enum 확인
   - 예: `UserNotFoundException` → `UserError.USER_NOT_FOUND`

4. **예외 클래스의 data 파라미터 확인 (중요!)**
   - 예외 클래스 파일을 **반드시 직접 읽어서** `data` 파라미터 전달 여부 확인
   - 위치: `modules/application/api/src/main/kotlin/com/invigoworks/bitda/api/{도메인}/application/exception/`
   - `ApplicationException(error, data)` 형태로 data를 전달하는지 확인
   - **예외 클래스 확인 예시:**
     ```kotlin
     // data 없음 - 에러 응답에서 data 필드 생략
     class UserNotFoundException(userId: UUID) : ApplicationException(USER_NOT_FOUND)

     // data 있음 - 에러 응답에 data 필드 포함 필수!
     class DuplicateSubjectIdException(subjectId: String)
         : ApplicationException(DUPLICATE_SUBJECT_ID, mapOf("subjectId" to subjectId))
     ```

5. **Error enum에서 HTTP 상태 코드와 메시지 추출**
   - 위치: `modules/domain/src/main/kotlin/com/invigoworks/bitda/domain/{도메인}/error/{도메인}Error.kt`
   - 형식: `ERROR_CODE(httpStatus, "에러 메시지")`

#### 예외 구조

```
BusinessException (base)
├── ApplicationException (application layer) ← 주로 사용
│   └── UserNotFoundException
│   └── CompanyNotFoundException
│   └── ...
└── DomainException (domain layer)
    └── DuplicateSubjectIdException
    └── ...
```

**ApplicationException 생성자:**
```kotlin
open class ApplicationException(
    error: Error,        // Error enum 값
    data: Any? = null,   // 추가 데이터 (에러 응답에 포함됨)
    vararg messageArgs: Any,
) : BusinessException(error, data, *messageArgs)
```

**예외 생성 예시:**
```kotlin
// data 없이 생성
throw UserNotFoundException(userId)

// data 포함하여 생성 (예: 추가 정보 전달)
throw ApplicationException(UserError.USER_NOT_FOUND, mapOf("userId" to userId))
```

#### Error enum 예시

```kotlin
// modules/domain/src/main/kotlin/com/invigoworks/bitda/domain/user/error/UserError.kt
enum class UserError(
    override val status: Int,
    override val message: String,
) : Error {
    USER_NOT_FOUND(404, "사용자를 찾을 수 없습니다"),
    USER_ALREADY_DELETED(400, "이미 삭제된 사용자입니다"),
    DUPLICATE_SUBJECT_ID(409, "이미 등록된 사용자입니다"),
    // ...
}
```

#### 에러 응답 문서화 예시

**예시 1: data 없는 예외**

`GetUserByAdminUseCase`에서 `throw UserNotFoundException(input.id)` 발견 시:
1. `UserNotFoundException.kt` 파일 확인 → `ApplicationException(USER_NOT_FOUND)` (data 없음)
2. 에러 응답에서 data 필드 생략:

```json
{
  "error": "USER_NOT_FOUND",
  "message": "사용자를 찾을 수 없습니다"
}
```

**예시 2: data 있는 예외**

`CreateUserByAdminUseCase`에서 `throw DuplicateSubjectIdException(subjectId)` 발견 시:
1. `DuplicateSubjectIdException.kt` 파일 확인 → `ApplicationException(DUPLICATE_SUBJECT_ID, mapOf("subjectId" to subjectId))` (data 있음!)
2. 에러 응답에 data 필드 포함 필수:

```json
{
  "data": {
    "subjectId": "auth-system-user-id"
  },
  "error": "DUPLICATE_SUBJECT_ID",
  "message": "이미 등록된 사용자입니다"
}
```

### 5단계: 상세 페이지 작성

DB 아이템 생성 후, 해당 페이지에 상세 내용 추가. `references/api_detail_template.md` 참조하여 다음 구조로 작성:

1. **개요** (Heading 2)
   - Operation 어노테이션의 summary, description

2. **인증 및 권한** (Heading 2)
   - 필요 역할: `@PreAuthorize` 어노테이션에서 추출
   - 권한 패턴 예시:
     - `hasRole('ADMIN')` → ADMIN 역할 필요
     - `hasAnyRole('OWNER', 'MEMBER')` → OWNER 또는 MEMBER 역할 필요
     - `permitAll()` → 인증 불필요

3. **요청 (Request)** (Heading 2)
   - Parameters 또는 Request Body
   - 스키마 테이블 + JSON 예시 코드 블록

4. **응답 (Response)** (Heading 2)
   - 성공 응답 스키마 + JSON 예시
   - ApiResponses 어노테이션 기반 응답 코드 테이블

## 상세 페이지 블록 구조

노션 페이지에 다음 블록들을 순서대로 추가:

```
## 개요
{Operation.summary}
{Operation.description}

---

## 인증 및 권한

| 항목 | 값 |
|------|-----|
| 인증 필요 | Yes/No |
| 필요 역할 | ADMIN / OWNER, MEMBER / 없음 |

---

## 요청 (Request)

### Path Parameters (있는 경우)
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|

### Query Parameters (있는 경우)
| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|

### Request Body (있는 경우)
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|

### 요청 예시 (POST, PATCH, PUT 등 Request Body가 있는 경우 필수)
```json
{
  "email": "user@example.com",
  "name": "홍길동",
  "roleId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "ACTIVE",
  "organizationId": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

## 응답 (Response)

### 성공 응답 (200/201)

**중요**: 성공 응답은 반드시 다음 두 가지를 포함해야 합니다:
1. **스키마 테이블**: Swagger의 Response DTO 스키마에서 모든 필드 추출
2. **응답 예시**: 실제 JSON 응답 형태 (ApiResponse 래퍼 포함)

#### 스키마 테이블 작성 규칙
- Response DTO 클래스 파일을 읽거나 Swagger JSON에서 스키마 확인
- 모든 필드를 테이블에 나열 (중첩 객체 포함)
- description은 Swagger/코드의 설명을 그대로 사용

| 필드 | 타입 | 설명 |
|------|------|------|
| id | string (uuid) | 고유 식별자 |
| name | string | 이름 |
| status | object | 상태 정보 (LabeledEnum) |
| status.value | string | 상태 코드 |
| status.label | string | 상태 표시명 |
| createdAt | string (date-time) | 생성일시 |
| updatedAt | string (date-time) | 수정일시 |

### 응답 예시
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "테스트",
    "status": {
      "value": "ACTIVE",
      "label": "활성"
    },
    "createdAt": "2024-01-15T09:00:00Z",
    "updatedAt": "2024-01-15T09:00:00Z"
  }
}
```

### 에러 응답 예시 (실제 코드 기반)

**중요**: 에러 응답은 추측하지 않고, 4단계에서 분석한 실제 예외 정보를 기반으로 작성합니다.

#### 작성 방법
1. UseCase/Service에서 발견한 `throw` 문 기반으로 에러 목록 작성
2. Error enum에서 HTTP 상태 코드와 메시지 추출
3. 각 에러별로 JSON 코드 블록 작성

#### 예시 (GET /api/v1/admin/users/{id})

```
분석 결과:
- GetUserByAdminUseCase.kt:20 → throw UserNotFoundException(input.id)
- UserError.USER_NOT_FOUND(404, "사용자를 찾을 수 없습니다")
```

#### 404 Not Found - USER_NOT_FOUND
```json
{
  "error": "USER_NOT_FOUND",
  "message": "사용자를 찾을 수 없습니다"
}
```

#### 403 Forbidden (공통 - 권한 없음)
```json
{
  "error": "ACCESS_DENIED",
  "message": "접근 권한이 없습니다"
}
```

### 응답 코드
| 코드 | 설명 |
|------|------|
| 200 | 성공 |
| 400 | 잘못된 요청 |
| 401 | 인증 필요 |
| 403 | 권한 없음 |
| 404 | 리소스 없음 |
```

## 참조 파일

- `references/notion_db_schema.md` - 노션 DB 상세 스키마
- `references/api_detail_template.md` - API 상세 페이지 템플릿

## ApiResponse 래퍼 구조

이 프로젝트의 모든 API 응답은 `ApiResponse<T>` 래퍼로 감싸집니다. **`success` 필드는 없습니다.**

```kotlin
// modules/common/src/main/kotlin/com/invigoworks/bitda/common/response/ApiResponse.kt
data class ApiResponse<T>(
    val data: T? = null,      // 응답 데이터
    val error: String? = null, // 에러 코드 (에러 시에만)
    val message: String? = null // 에러 메시지 (에러 시에만)
)
```

### 응답 예시 작성 규칙

**성공 응답:**
```json
{
  "data": {
    // 실제 응답 데이터
  }
}
```

**에러 응답 (data 없는 경우 - data 필드 생략):**
```json
{
  "error": "USER_NOT_FOUND",
  "message": "사용자를 찾을 수 없습니다"
}
```

**에러 응답 (data 포함된 경우):**
```json
{
  "data": {
    "userId": "550e8400-e29b-41d4-a716-446655440000"
  },
  "error": "USER_NOT_FOUND",
  "message": "사용자를 찾을 수 없습니다"
}
```

> **참고**: 예외 생성 시 `data` 파라미터로 전달된 값이 에러 응답의 `data` 필드에 포함됩니다. data가 null인 경우 응답에서 `data` 필드를 생략합니다.

## 스키마 정확성 규칙

1. **Swagger 스키마 정확히 반영**: 중첩 객체(RoleInfo, LabeledEnum 등)도 `$ref`를 따라가서 모든 필드를 확인
2. **required 필드 확인**: Swagger의 `required` 배열에 있는 필드는 필수로 표시
3. **example 값 활용**: Swagger 스키마의 `example` 값을 응답 예시에 사용
4. **커스텀 타입 전개**: RoleInfo, LabeledEnum 등은 실제 필드 구조를 예시에 포함
5. **description 필드 그대로 사용**: 테이블의 "설명" 컬럼은 반드시 Swagger 스키마의 `description` 값을 그대로 사용. 임의로 번역하거나 요약하지 않음

### LabeledEnum 타입 처리 (중요!)

이 프로젝트의 Enum 필드(status 등)는 **LabeledEnum** 형태로 직렬화됩니다. Swagger에서 `type: object`로 표시되며 `value`와 `label` 필드를 가집니다.

**⚠️ 절대 단순 문자열로 작성하지 마세요!**

**Swagger 스키마 예시:**
```json
"status": {
  "type": "object",
  "description": "세무사 상태",
  "example": {
    "value": "ACTIVE",
    "label": "활성"
  },
  "properties": {
    "value": {
      "type": "string",
      "enum": ["ACTIVE", "INACTIVE"]
    },
    "label": {
      "type": "string",
      "enum": ["활성", "비활성"]
    }
  }
}
```

**올바른 응답 예시:**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "status": {
      "value": "ACTIVE",
      "label": "활성"
    }
  }
}
```

**잘못된 응답 예시 (절대 금지!):**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "ACTIVE"
  }
}
```

**스키마 테이블 작성 시:**
| 필드 | 타입 | 설명 |
|------|------|------|
| status | object | 상태 정보 (LabeledEnum) |
| status.value | string | Enum 값 (ACTIVE, INACTIVE) |
| status.label | string | 표시 라벨 (활성, 비활성) |

### 설명 필드 작성 규칙 (중요)

테이블의 "설명" 컬럼 작성 시 **반드시 Swagger JSON의 description 값을 그대로 복사**해야 합니다.

**Swagger JSON 예시:**
```json
{
  "UserResponse": {
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid",
        "description": "사용자 고유 식별자"
      },
      "email": {
        "type": "string",
        "description": "사용자 이메일 주소"
      },
      "name": {
        "type": "string",
        "description": "사용자 이름"
      }
    }
  }
}
```

**올바른 테이블 작성:**
| 필드 | 타입 | 설명 |
|------|------|------|
| id | string (uuid) | 사용자 고유 식별자 |
| email | string | 사용자 이메일 주소 |
| name | string | 사용자 이름 |

**잘못된 예시 (임의로 작성):**
| 필드 | 타입 | 설명 |
|------|------|------|
| id | string (uuid) | 사용자 ID |
| email | string | 이메일 |
| name | string | 이름 |

> **핵심**: Swagger에 `"description": "사용자 고유 식별자"`라고 되어 있으면 테이블에도 정확히 "사용자 고유 식별자"라고 작성해야 함

예시 - RoleInfo가 포함된 응답:
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "role": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "code": "ROLE_ADMIN",
      "name": "관리자"
    }
  }
}
```

## 주의사항

1. 기존 API 업데이트 시 먼저 DB에서 해당 API ID로 검색하여 중복 방지
2. Git Link는 GitHub 저장소 URL 형식으로 작성
3. 코드 블록은 JSON 형식으로 작성하며, 예시 데이터는 Swagger example 값 활용
4. 한글 설명과 영문 기술 용어를 적절히 혼용
5. 권한 정보는 클래스 레벨과 메서드 레벨 모두 확인 (메서드 레벨이 우선)
6. **`"success": true` 절대 사용 금지** - ApiResponse에 해당 필드 없음
7. 중첩 스키마는 Swagger의 `components/schemas`에서 조회하여 정확히 반영
8. **에러 응답은 실제 코드 기반으로 작성** - UseCase/Service의 throw 문과 Error enum에서 추출
9. 에러 코드 형식: Error enum 이름 그대로 사용 (예: `USER_NOT_FOUND`, `DUPLICATE_SUBJECT_ID`)
10. **테이블 설명은 Swagger description 그대로 사용** - 임의로 번역, 요약, 변경 금지. Swagger JSON의 description 값을 복사하여 사용
11. **에러 응답 data 필드는 예외 클래스 확인 필수** - 예외 클래스 파일을 직접 읽어서 `ApplicationException(error, data)` 형태로 data를 전달하는지 확인. data가 있으면 반드시 포함, 없으면 생략
12. **요청 예시 필수 포함** - POST, PATCH, PUT 등 Request Body가 있는 API는 반드시 "요청 예시" 섹션에 JSON 코드 블록 추가. Swagger의 example 값 또는 현실적인 예시 데이터 사용
13. **성공 응답 스키마와 예시 필수 포함** - 모든 API는 성공 응답 섹션에 반드시 다음 두 가지를 포함:
    - **스키마 테이블**: Response DTO의 모든 필드를 테이블로 나열 (중첩 객체 필드 포함)
    - **응답 예시**: ApiResponse 래퍼를 포함한 완전한 JSON 예시
    - 단순히 "XXXResponse 스키마로 응답"이라고만 작성하면 안 됨